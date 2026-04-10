import re
from app.models import ParsedSignal


class SignalParser:

    FOREX_PAIRS = [
        "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD",
        "EURGBP", "EURJPY", "GBPJPY", "AUDJPY", "CADJPY", "CHFJPY", "NZDJPY",
        "EURAUD", "EURCHF", "EURCAD", "EURNZD", "GBPAUD", "GBPCAD", "GBPCHF",
        "GBPNZD", "AUDCAD", "AUDCHF", "AUDNZD", "CADCHF", "NZDCAD", "NZDCHF",
        "XAUUSD", "XAGUSD", "GOLD", "SILVER",
        "US30", "NAS100", "SPX500", "USTEC", "DJ30",
        "BTCUSD", "ETHUSD", "USOIL", "UKOIL", "WTI", "BRENT",
    ]

    PAIR_ALIASES = {
        "GOLD": "XAUUSD", "SILVER": "XAGUSD",
        "WTI": "USOIL", "BRENT": "UKOIL",
        "DJ30": "US30", "USTEC": "NAS100",
    }

    _SIGNAL_PATTERNS = [
        r"\bbuy\b", r"\bsell\b", r"\blong\b", r"\bshort\b",
        r"\btp\d?\b", r"\bsl\b", r"\btake\s*profit\b", r"\bstop\s*loss\b",
        r"\bentry\b", r"\btarget\b",
    ]

    _NOISE_PATTERNS = [
        r"https?://\S+", r"@\w+", r"t\.me/\S+",
        r"join\s+(us|our|now)", r"www\.\S+",
        r"👉.*(?:join|click|subscribe)",
    ]

    def is_signal(self, text: str) -> bool:
        if not text or len(text) < 10:
            return False
        lower = text.lower()
        hits = sum(1 for p in self._SIGNAL_PATTERNS if re.search(p, lower))
        return hits >= 2 and self._detect_pair(text) is not None

    def parse(self, text: str) -> ParsedSignal | None:
        if not self.is_signal(text):
            return None

        cleaned = self._clean(text)
        pair = self._detect_pair(cleaned)
        direction = self._detect_direction(cleaned)
        if not pair or not direction:
            return None

        entry = self._price_after(cleaned, r"(?:entry|enter|price|at)")
        sl = self._price_after(cleaned, r"(?:sl|stop\s*loss|stoploss)")
        tps = self._prices_after(cleaned, r"(?:tp\s*\d?|take\s*profit\s*\d?|target\s*\d?)")

        if not tps:
            for i in range(1, 4):
                tp = self._price_after(cleaned, rf"tp\s*{i}")
                if tp:
                    tps.append(tp)

        if not entry:
            m = re.search(
                r"\b(?:buy|sell|long|short)\b[\s@:]*(\d+\.?\d*)",
                cleaned, re.IGNORECASE,
            )
            if m:
                entry = m.group(1)

        return ParsedSignal(
            pair=pair,
            direction=direction,
            entry=entry or "",
            tp1=tps[0] if len(tps) > 0 else "",
            tp2=tps[1] if len(tps) > 1 else "",
            tp3=tps[2] if len(tps) > 2 else "",
            sl=sl or "",
        )

    def clean(self, text: str) -> str:
        return self._clean(text)

    def _detect_pair(self, text: str) -> str | None:
        normalized = re.sub(r"[/\-_\s]", "", text.upper())
        for pair in self.FOREX_PAIRS:
            if pair in normalized:
                return self.PAIR_ALIASES.get(pair, pair)
        for pair in self.FOREX_PAIRS:
            if len(pair) == 6:
                slashed = f"{pair[:3]}/{pair[3:]}"
                if slashed in text.upper():
                    return self.PAIR_ALIASES.get(pair, pair)
        return None

    def _detect_direction(self, text: str) -> str | None:
        lower = text.lower()
        buy_m = re.search(r"\b(buy|long)\b", lower)
        sell_m = re.search(r"\b(sell|short)\b", lower)
        if buy_m and not sell_m:
            return "BUY"
        if sell_m and not buy_m:
            return "SELL"
        if buy_m and sell_m:
            return "BUY" if buy_m.start() < sell_m.start() else "SELL"
        return None

    def _clean(self, text: str) -> str:
        out = text
        for pat in self._NOISE_PATTERNS:
            out = re.sub(pat, "", out, flags=re.IGNORECASE)
        out = re.sub(r"[🔥💰💵💎🚀⭐🌟✨💫🔔📢📣]+", "", out)
        out = re.sub(r"\n{3,}", "\n\n", out)
        out = re.sub(r"[ \t]{2,}", " ", out)
        return out.strip()

    @staticmethod
    def _price_after(text: str, pattern: str) -> str | None:
        m = re.search(pattern + r"[\s:@]*(\d+\.?\d*)", text, re.IGNORECASE)
        return m.group(1) if m else None

    @staticmethod
    def _prices_after(text: str, pattern: str) -> list[str]:
        return re.findall(pattern + r"[\s:@]*(\d+\.?\d*)", text, re.IGNORECASE)
