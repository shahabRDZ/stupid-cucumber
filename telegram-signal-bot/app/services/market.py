from __future__ import annotations

import logging
import time
from dataclasses import dataclass

import aiohttp

logger = logging.getLogger(__name__)


@dataclass
class PriceData:
    pair: str
    price: float
    change: float
    change_pct: float
    high: float
    low: float
    timestamp: int

    def to_dict(self) -> dict:
        return {
            "pair": self.pair,
            "price": self.price,
            "change": self.change,
            "change_pct": self.change_pct,
            "high": self.high,
            "low": self.low,
            "timestamp": self.timestamp,
        }


@dataclass
class CalendarEvent:
    time: str
    currency: str
    impact: str
    event: str
    actual: str
    forecast: str
    previous: str

    def to_dict(self) -> dict:
        return {
            "time": self.time,
            "currency": self.currency,
            "impact": self.impact,
            "event": self.event,
            "actual": self.actual,
            "forecast": self.forecast,
            "previous": self.previous,
        }


@dataclass
class SentimentData:
    pair: str
    buyers_pct: float
    sellers_pct: float
    trend: str  # "bullish" / "bearish" / "neutral"

    def to_dict(self) -> dict:
        return {
            "pair": self.pair,
            "buyers_pct": self.buyers_pct,
            "sellers_pct": self.sellers_pct,
            "trend": self.trend,
        }


class MarketService:
    """Fetches live prices, economic calendar, and market sentiment."""

    # Yahoo Finance ticker mapping
    YAHOO_SYMBOLS = {
        "EURUSD": "EURUSD=X", "GBPUSD": "GBPUSD=X", "USDJPY": "USDJPY=X",
        "USDCHF": "USDCHF=X", "AUDUSD": "AUDUSD=X", "NZDUSD": "NZDUSD=X",
        "USDCAD": "USDCAD=X", "EURGBP": "EURGBP=X", "EURJPY": "EURJPY=X",
        "GBPJPY": "GBPJPY=X", "AUDJPY": "AUDJPY=X", "CADJPY": "CADJPY=X",
        "CHFJPY": "CHFJPY=X", "EURAUD": "EURAUD=X", "EURCHF": "EURCHF=X",
        "GBPAUD": "GBPAUD=X", "GBPCAD": "GBPCAD=X", "GBPCHF": "GBPCHF=X",
        "XAUUSD": "GC=F", "XAGUSD": "SI=F",
        "BTCUSD": "BTC-USD", "ETHUSD": "ETH-USD",
        "USOIL": "CL=F", "US30": "YM=F", "NAS100": "NQ=F", "SPX500": "ES=F",
    }

    # Price cache (pair -> (PriceData, timestamp))
    _cache: dict[str, tuple[PriceData, float]] = {}
    _CACHE_TTL = 15  # seconds

    CALENDAR_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
    YAHOO_URL = "https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1m&range=1d"

    def __init__(self) -> None:
        self._session: aiohttp.ClientSession | None = None

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(
                headers={"User-Agent": "Mozilla/5.0"},
                timeout=aiohttp.ClientTimeout(total=10),
            )
        return self._session

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()

    # ── Live Prices ──────────────────────────────

    async def get_price(self, pair: str) -> PriceData | None:
        pair = pair.upper().replace("/", "")
        # Check cache
        if pair in self._cache:
            data, ts = self._cache[pair]
            if time.time() - ts < self._CACHE_TTL:
                return data

        symbol = self.YAHOO_SYMBOLS.get(pair)
        if not symbol:
            return None

        try:
            session = await self._get_session()
            url = self.YAHOO_URL.format(symbol=symbol)
            async with session.get(url) as resp:
                if resp.status != 200:
                    logger.warning(f"Yahoo API {resp.status} for {pair}")
                    return None
                raw = await resp.json()

            result = raw["chart"]["result"][0]
            meta = result["meta"]
            price = meta["regularMarketPrice"]
            prev_close = meta.get("chartPreviousClose", meta.get("previousClose", price))
            change = round(price - prev_close, 5)
            change_pct = round((change / prev_close) * 100, 3) if prev_close else 0

            indicators = result.get("indicators", {}).get("quote", [{}])[0]
            highs = [h for h in (indicators.get("high") or []) if h is not None]
            lows = [lo for lo in (indicators.get("low") or []) if lo is not None]

            data = PriceData(
                pair=pair,
                price=round(price, 5),
                change=change,
                change_pct=change_pct,
                high=round(max(highs), 5) if highs else price,
                low=round(min(lows), 5) if lows else price,
                timestamp=int(time.time()),
            )
            self._cache[pair] = (data, time.time())
            return data

        except Exception as exc:
            logger.error(f"Price fetch error ({pair}): {exc}")
            return None

    async def get_prices(self, pairs: list[str] | None = None) -> list[PriceData]:
        if pairs is None:
            pairs = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "BTCUSD", "USOIL"]
        results = []
        for pair in pairs:
            data = await self.get_price(pair)
            if data:
                results.append(data)
        return results

    # ── Economic Calendar ────────────────────────

    async def get_calendar(self, currency: str | None = None) -> list[CalendarEvent]:
        try:
            session = await self._get_session()
            async with session.get(self.CALENDAR_URL) as resp:
                if resp.status != 200:
                    return []
                raw = await resp.json(content_type=None)

            events = []
            for item in raw:
                impact = item.get("impact", "").lower()
                if impact not in ("high", "medium"):
                    continue
                if currency and item.get("country", "").upper() != currency.upper():
                    continue

                events.append(CalendarEvent(
                    time=item.get("date", ""),
                    currency=item.get("country", ""),
                    impact=impact.capitalize(),
                    event=item.get("title", ""),
                    actual=item.get("actual", "") or "-",
                    forecast=item.get("forecast", "") or "-",
                    previous=item.get("previous", "") or "-",
                ))

            return events[:30]

        except Exception as exc:
            logger.error(f"Calendar fetch error: {exc}")
            return []

    # ── Market Sentiment ─────────────────────────

    async def get_sentiment(self, pair: str) -> SentimentData | None:
        """
        Calculate sentiment from price action:
        - Compare current price vs daily high/low midpoint.
        - Use intraday range position as a proxy.
        """
        data = await self.get_price(pair)
        if not data:
            return None

        mid = (data.high + data.low) / 2
        rng = data.high - data.low

        if rng == 0:
            buyers_pct = 50.0
        else:
            # Position in range: 0 = at low (bearish), 1 = at high (bullish)
            position = (data.price - data.low) / rng
            buyers_pct = round(position * 100, 1)

        # Adjust with change direction
        if data.change > 0:
            buyers_pct = min(95, buyers_pct + 5)
        elif data.change < 0:
            buyers_pct = max(5, buyers_pct - 5)

        sellers_pct = round(100 - buyers_pct, 1)
        buyers_pct = round(buyers_pct, 1)

        if buyers_pct > 60:
            trend = "bullish"
        elif sellers_pct > 60:
            trend = "bearish"
        else:
            trend = "neutral"

        return SentimentData(
            pair=pair,
            buyers_pct=buyers_pct,
            sellers_pct=sellers_pct,
            trend=trend,
        )
