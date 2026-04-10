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


@dataclass
class RiskResult:
    pair: str
    balance: float
    risk_pct: float
    risk_amount: float
    entry: float
    sl: float
    sl_pips: float
    pip_value: float  # per standard lot
    lot_size: float
    position_size_units: float

    def to_dict(self) -> dict:
        return {
            "pair": self.pair, "balance": self.balance,
            "risk_pct": self.risk_pct, "risk_amount": self.risk_amount,
            "entry": self.entry, "sl": self.sl,
            "sl_pips": self.sl_pips, "pip_value": self.pip_value,
            "lot_size": self.lot_size,
            "position_size_units": self.position_size_units,
        }


# pip size per pair type
_PIP_SIZES: dict[str, float] = {
    "USDJPY": 0.01, "EURJPY": 0.01, "GBPJPY": 0.01,
    "AUDJPY": 0.01, "CADJPY": 0.01, "CHFJPY": 0.01,
    "XAUUSD": 0.1, "XAGUSD": 0.01,
}
_DEFAULT_PIP = 0.0001


def calc_risk(
    pair: str, balance: float, risk_pct: float,
    entry: float, sl: float, price_usd: float | None = None,
) -> RiskResult:
    pair = pair.upper().replace("/", "")
    pip_size = _PIP_SIZES.get(pair, _DEFAULT_PIP)
    sl_pips = abs(entry - sl) / pip_size

    # pip value per standard lot (100,000 units)
    quote = pair[-3:]
    if quote == "USD":
        pip_value = pip_size * 100_000
    elif pair.startswith("USD"):
        # USD is base → pip value = pip_size / price * 100,000
        pip_value = (pip_size / entry) * 100_000 if entry else 10
    else:
        # cross pair — approximate via USD price
        pip_value = (pip_size / (price_usd or entry)) * 100_000 if entry else 10

    # special: gold = $10 per 0.1 pip move on 1 lot (100 oz)
    if pair == "XAUUSD":
        pip_value = 10.0  # $10 per pip (0.1) per lot
    elif pair == "XAGUSD":
        pip_value = 50.0  # $50 per pip (0.01) per lot (5000 oz)

    risk_amount = balance * (risk_pct / 100)
    lot_size = round(risk_amount / (sl_pips * pip_value), 2) if sl_pips > 0 and pip_value > 0 else 0
    position_units = round(lot_size * 100_000, 0)

    return RiskResult(
        pair=pair, balance=balance, risk_pct=risk_pct,
        risk_amount=round(risk_amount, 2),
        entry=entry, sl=sl,
        sl_pips=round(sl_pips, 1),
        pip_value=round(pip_value, 2),
        lot_size=lot_size,
        position_size_units=position_units,
    )


class MarketService:

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

    async def get_sentiment(self, pair: str) -> SentimentData | None:
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

    async def get_chart_image(self, pair: str) -> bytes | None:
        pair = pair.upper().replace("/", "")
        symbol = self.YAHOO_SYMBOLS.get(pair)
        if not symbol:
            return None

        try:
            session = await self._get_session()
            # Fetch 4h data for last 2 days
            url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=15m&range=2d"
            async with session.get(url) as resp:
                if resp.status != 200:
                    return None
                raw = await resp.json()

            result = raw["chart"]["result"][0]
            timestamps = result.get("timestamp", [])
            quotes = result.get("indicators", {}).get("quote", [{}])[0]
            closes = quotes.get("close", [])

            # Filter None values
            prices = []
            labels = []
            for i, (ts, c) in enumerate(zip(timestamps, closes)):
                if c is not None:
                    prices.append(round(c, 5))
                    if i % 8 == 0:
                        from datetime import datetime as dt
                        labels.append(dt.fromtimestamp(ts).strftime("%H:%M"))
                    else:
                        labels.append("")

            if len(prices) < 5:
                return None

            # Determine line color based on trend
            color = "rgb(16,185,129)" if prices[-1] >= prices[0] else "rgb(239,68,68)"
            bg_color = "rgba(16,185,129,0.1)" if prices[-1] >= prices[0] else "rgba(239,68,68,0.1)"

            import json
            chart_config = {
                "type": "line",
                "data": {
                    "labels": labels,
                    "datasets": [{
                        "label": pair,
                        "data": prices,
                        "borderColor": color,
                        "backgroundColor": bg_color,
                        "borderWidth": 2,
                        "pointRadius": 0,
                        "fill": True,
                        "tension": 0.3,
                    }]
                },
                "options": {
                    "responsive": True,
                    "plugins": {
                        "title": {"display": True, "text": f"{pair} — 2D Chart", "color": "#e2e8f0", "font": {"size": 16}},
                        "legend": {"display": False},
                    },
                    "scales": {
                        "x": {"ticks": {"color": "#94a3b8", "maxRotation": 0}, "grid": {"color": "rgba(148,163,184,0.1)"}},
                        "y": {"ticks": {"color": "#94a3b8"}, "grid": {"color": "rgba(148,163,184,0.1)"}},
                    },
                },
            }

            chart_url = "https://quickchart.io/chart"
            payload = {
                "chart": json.dumps(chart_config),
                "width": 600,
                "height": 350,
                "backgroundColor": "#0f172a",
                "format": "png",
            }

            async with session.post(chart_url, json=payload) as resp:
                if resp.status == 200:
                    return await resp.read()

            return None

        except Exception as exc:
            logger.error(f"Chart error ({pair}): {exc}")
            return None
