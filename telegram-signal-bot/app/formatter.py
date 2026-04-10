from datetime import datetime

from app.models import ParsedSignal


class SignalFormatter:

    _DEFAULT_TEMPLATE = (
        "━━━━━━━━━━━━━━━━━━━━\n{signal}\n━━━━━━━━━━━━━━━━━━━━\n📅 {time}\n📡 Signal Bot"
    )

    def format(self, signal: ParsedSignal, template: str | None = None) -> str:
        emoji = "🟢" if signal.direction == "BUY" else "🔴"
        lines = [f"{emoji} <b>{signal.pair} — {signal.direction}</b>"]

        if signal.entry:
            lines.append(f"📍 Entry: <code>{signal.entry}</code>")
        for i, val in enumerate([signal.tp1, signal.tp2, signal.tp3], 1):
            if val:
                lines.append(f"🎯 TP{i}: <code>{val}</code>")
        if signal.sl:
            lines.append(f"🛑 SL: <code>{signal.sl}</code>")

        now = datetime.now().strftime("%Y-%m-%d  %H:%M:%S")
        body = "\n".join(lines)
        tpl = template or self._DEFAULT_TEMPLATE
        return tpl.replace("{signal}", body).replace("{time}", now)
