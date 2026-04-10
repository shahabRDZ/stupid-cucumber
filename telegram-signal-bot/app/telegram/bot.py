import logging
from datetime import datetime

from telethon import events, Button
from telethon.tl.types import ChannelParticipantsRecent

from app.config import Config
from app.database import (
    AlertRepository, LogRepository, SettingsRepository, SignalRepository, SubscriberRepository,
)
from app.services.market import MarketService
from app.services.alerts import AlertService
from app.telegram.base import BaseTelegramClient

# --- i18n ---

# fallback texts (used if not set in DB)
_FALLBACK = {
    "en": {"hello": "Hello", "choose_lang": "Choose your language:", "unsubscribed": "Unsubscribed. Send /start to re-subscribe."},
    "fa": {"hello": "سلام", "choose_lang": "زبان خود را انتخاب کنید:", "unsubscribed": "عضویت لغو شد. برای مجدد /start بزنید."},
    "tr": {"hello": "Merhaba", "choose_lang": "Dilinizi seçin:", "unsubscribed": "Abonelikten çıktınız. /start ile tekrar abone olun."},
}

# settings_repo gets set in __init__
_settings_ref = None

def _set_settings_ref(s):
    global _settings_ref
    _settings_ref = s

_LANGS = {"en": "English", "fa": "فارسی", "tr": "Türkçe"}

_KEYBOARDS = {
    "en": [
        [Button.text("📡 Get Signals", resize=True), Button.text("💹 Prices", resize=True)],
        [Button.text("📅 Calendar", resize=True), Button.text("🧭 Sentiment", resize=True)],
        [Button.text("🔔 My Alerts", resize=True), Button.text("📖 Help", resize=True)],
        [Button.text("🌐 Language", resize=True)],
    ],
    "fa": [
        [Button.text("📡 دریافت سیگنال", resize=True), Button.text("💹 قیمت لحظه‌ای", resize=True)],
        [Button.text("📅 تقویم اقتصادی", resize=True), Button.text("🧭 احساسات بازار", resize=True)],
        [Button.text("🔔 هشدارهای من", resize=True), Button.text("📖 راهنما", resize=True)],
        [Button.text("🌐 زبان", resize=True)],
    ],
    "tr": [
        [Button.text("📡 Sinyal Al", resize=True), Button.text("💹 Fiyatlar", resize=True)],
        [Button.text("📅 Takvim", resize=True), Button.text("🧭 Duyarlılık", resize=True)],
        [Button.text("🔔 Alarmlarım", resize=True), Button.text("📖 Yardım", resize=True)],
        [Button.text("🌐 Dil", resize=True)],
    ],
}

_SUBSCRIBE_BTNS = {"📡 دریافت سیگنال", "📡 Sinyal Al", "📡 Get Signals"}
_STATUS_BTNS = {"📊 وضعیت", "📊 Durum", "📊 Status"}
_HELP_BTNS = {"📖 راهنما", "📖 Yardım", "📖 Help"}
_LANG_BTNS = {"🌐 زبان", "🌐 Dil", "🌐 Language"}
_UNSUB_BTNS = {"❌ لغو عضویت", "❌ Abonelikten Çık", "❌ Unsubscribe"}
_PRICE_BTNS = {"💹 قیمت لحظه‌ای", "💹 Fiyatlar", "💹 Prices"}
_CALENDAR_BTNS = {"📅 تقویم اقتصادی", "📅 Takvim", "📅 Calendar"}
_SENTIMENT_BTNS = {"🧭 احساسات بازار", "🧭 Duyarlılık", "🧭 Sentiment"}
_ALERTS_BTNS = {"🔔 هشدارهای من", "🔔 Alarmlarım", "🔔 My Alerts"}
_ALL_BTNS = (
    _SUBSCRIBE_BTNS | _STATUS_BTNS | _HELP_BTNS | _LANG_BTNS |
    _UNSUB_BTNS | _PRICE_BTNS | _CALENDAR_BTNS | _SENTIMENT_BTNS | _ALERTS_BTNS
)


def _t(lang: str, key: str) -> str:
    # try from DB first
    if _settings_ref:
        db_key = f"{key}_{lang}"
        val = _settings_ref.get(db_key)
        if val:
            return val
    return _FALLBACK.get(lang, _FALLBACK["en"]).get(key, _FALLBACK["en"].get(key, ""))


def _kb(lang: str):
    return _KEYBOARDS.get(lang, _KEYBOARDS["en"])


class SignalBot(BaseTelegramClient):

    def __init__(
        self,
        config: Config,
        subscribers: SubscriberRepository,
        signals: SignalRepository,
        logs: LogRepository,
        alerts_repo: AlertRepository,
        settings: SettingsRepository,
        market: MarketService,
        user_client=None,
    ) -> None:
        super().__init__("bot_session", config)
        self._subscribers = subscribers
        self._signals = signals
        self._logs = logs
        self._alerts_repo = alerts_repo
        self._settings = settings
        self._market = market
        self._user_client = user_client
        self._alert_service = AlertService(alerts_repo, market)
        _set_settings_ref(settings)

    @property
    def alert_service(self) -> AlertService:
        return self._alert_service

    async def start(self) -> bool:
        await self._client.start(bot_token=self._config.bot_token)
        me = await self._client.get_me()
        self._logger.info(f"Bot started: @{me.username}")
        self._logs.add("INFO", "bot", f"Bot started: @{me.username}")
        self._register_handlers()

        # Set up alert notification callback
        self._alert_service.on_triggered(self._on_alert_triggered)
        return True

    async def _on_alert_triggered(
        self, chat_id: int, pair: str, target: float, current: float, direction: str,
    ) -> None:
        arrow = "⬆️" if direction == "above" else "⬇️"
        msg = (
            f"🔔 <b>Price Alert Triggered!</b>\n\n"
            f"{arrow} <b>{pair}</b>\n"
            f"📍 Target: <code>{target}</code>\n"
            f"💹 Current: <code>{current}</code>\n"
            f"📊 Direction: {direction}"
        )
        await self.send_to_user(chat_id, msg)

    async def send_to_user(self, chat_id: int, text: str, media=None) -> bool:
        try:
            if media:
                await self._client.send_file(chat_id, media, caption=text, parse_mode="html")
            else:
                await self._client.send_message(chat_id, text, parse_mode="html")
            return True
        except Exception as exc:
            self._logger.warning(f"Send failed → {chat_id}: {exc}")
            if "blocked" in str(exc).lower() or "deactivated" in str(exc).lower():
                self._subscribers.deactivate(chat_id)
            return False

    async def broadcast_signal(self, signal_id: int, text: str, media=None, pair: str = "") -> int:
        chart_bytes = None
        # Generate chart if enabled
        if pair and self._settings.get("chart_enabled", "1") == "1":
            chart_bytes = await self._market.get_chart_image(pair)

        # Send to subscribers
        subs = self._subscribers.get_active()
        sent = 0
        for s in subs:
            if chart_bytes:
                await self.send_to_user(s.chat_id, text, media=chart_bytes)
            else:
                await self.send_to_user(s.chat_id, text, media=media)
            sent += 1

        # Send to target channel
        target_ch = self._settings.get("target_channel", "")
        if target_ch:
            try:
                if chart_bytes:
                    await self._client.send_file(target_ch, chart_bytes, caption=text, parse_mode="html")
                else:
                    await self._client.send_message(target_ch, text, parse_mode="html")
                self._logger.info(f"Signal #{signal_id} → channel @{target_ch}")
            except Exception as exc:
                self._logger.warning(f"Channel send failed @{target_ch}: {exc}")

        self._signals.mark_sent(signal_id, sent)
        self._logger.info(f"Signal #{signal_id} → {sent}/{len(subs)} subscribers")
        self._logs.add("INFO", "bot", f"Signal #{signal_id} sent to {sent}/{len(subs)} + channel")
        return sent

    async def send_approval_request(self, signal_id: int, text: str, pair: str = "") -> None:
        buttons = [
            [
                Button.inline("✅ Approve", data=f"approve_{signal_id}".encode()),
                Button.inline("❌ Reject", data=f"reject_{signal_id}".encode()),
            ]
        ]
        admin_msg = f"🔔 <b>New Signal — Awaiting Approval</b>\n\n{text}"
        for admin_id in self._config.admin_ids:
            try:
                await self._client.send_message(admin_id, admin_msg, parse_mode="html", buttons=buttons)
            except Exception as exc:
                self._logger.warning(f"Approval msg failed → {admin_id}: {exc}")
        # Store pair for later use when approved
        self._pending_pairs[signal_id] = pair

    _pending_pairs: dict[int, str] = {}

    def _register_handlers(self) -> None:
        cli = self._client

        @cli.on(events.NewMessage(pattern="/start"))
        async def _start(event):
            user = await event.get_sender()
            self._subscribers.upsert(
                event.chat_id,
                getattr(user, "username", None),
                getattr(user, "first_name", None),
            )
            lang = self._subscribers.get_lang(event.chat_id)
            name = getattr(user, "first_name", "") or ""
            msg = (
                f"{_t(lang, 'hello')} <b>{name}</b>! 👋\n\n"
                f"{_t(lang, 'welcome')}\n\n✅ {_t(lang, 'subscribed')}"
            )
            await event.reply(msg, parse_mode="html", buttons=_kb(lang))
            # cross-promo: invite to channel
            ch_un = self._settings.get("channel_username", "")
            if ch_un:
                promo = self._settings.get("bot_to_channel_promo", "")
                if not promo:
                    promo = "📺 برای دریافت سیگنال در کانال هم عضو شوید!\nJoin our channel for signals too!"
                await event.respond(
                    promo, parse_mode="html",
                    buttons=[[Button.url(f"📺 @{ch_un}", f"https://t.me/{ch_un}")]],
                )

        @cli.on(events.NewMessage(pattern="/stop"))
        async def _stop(event):
            lang = self._subscribers.get_lang(event.chat_id)
            self._subscribers.deactivate(event.chat_id)
            await event.reply(_t(lang, "unsubscribed"), parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern="/status"))
        async def _status(event):
            lang = self._subscribers.get_lang(event.chat_id)
            total, active = self._subscribers.count()
            sig_count = self._signals.count()
            msg = (
                f"📊 <b>Status</b>\n\n"
                f"👥 Subscribers: {active}/{total}\n"
                f"📡 Signals: {sig_count}\n"
                f"🕐 {datetime.now().strftime('%Y-%m-%d %H:%M')}"
            )
            await event.reply(msg, parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern="/help"))
        async def _help(event):
            lang = self._subscribers.get_lang(event.chat_id)
            await event.reply(_t(lang, "help"), parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern="/menu"))
        async def _menu(event):
            lang = self._subscribers.get_lang(event.chat_id)
            await event.reply("📋 Menu:", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern="/lang"))
        async def _lang(event):
            lang = self._subscribers.get_lang(event.chat_id)
            buttons = [
                [Button.inline(name, data=f"lang_{code}".encode())]
                for code, name in _LANGS.items()
            ]
            await event.reply(_t(lang, "choose_lang"), buttons=buttons)

        @cli.on(events.CallbackQuery(pattern=b"lang_"))
        async def _lang_cb(event):
            code = event.data.decode().replace("lang_", "")
            if code in _LANGS:
                self._subscribers.set_lang(event.chat_id, code)
                await event.answer("✅")
                await event.delete()
                await cli.send_message(event.chat_id, f"✅ Language: {_LANGS[code]}", buttons=_kb(code))

        @cli.on(events.CallbackQuery(pattern=rb"approve_(\d+)"))
        async def _approve(event):
            if event.chat_id not in set(self._config.admin_ids):
                await event.answer("❌ Not authorized")
                return
            signal_id = int(event.data.decode().split("_")[1])
            signals = self._signals.get_many(limit=1, offset=0)
            # Find the signal
            from app.database import Database
            sig = None
            for s in self._signals.get_many(limit=50):
                if s.id == signal_id:
                    sig = s
                    break
            if sig and sig.formatted_text:
                pair = self._pending_pairs.pop(signal_id, "")
                await self.broadcast_signal(signal_id, sig.formatted_text, pair=pair)
                await event.answer("✅ Approved & Sent!")
                await event.edit(f"✅ <b>APPROVED</b>\n\n{sig.formatted_text}", parse_mode="html")
            else:
                await event.answer("⚠️ Signal not found")

        @cli.on(events.CallbackQuery(pattern=rb"reject_(\d+)"))
        async def _reject(event):
            if event.chat_id not in set(self._config.admin_ids):
                await event.answer("❌ Not authorized")
                return
            signal_id = int(event.data.decode().split("_")[1])
            self._pending_pairs.pop(signal_id, None)
            await event.answer("❌ Rejected")
            await event.edit("❌ <b>REJECTED</b> — Signal was not sent.", parse_mode="html")

        @cli.on(events.NewMessage(pattern=r"/price\s*(.*)"))
        async def _price(event):
            lang = self._subscribers.get_lang(event.chat_id)
            arg = event.pattern_match.group(1).strip().upper()

            if not arg:
                # Show top pairs
                pairs = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "BTCUSD", "USOIL"]
                msg = "💹 <b>Live Prices</b>\n\n"
                for pair in pairs:
                    data = await self._market.get_price(pair)
                    if data:
                        arrow = "🟢" if data.change >= 0 else "🔴"
                        msg += f"{arrow} <b>{data.pair}</b>: <code>{data.price}</code>  ({data.change_pct:+.2f}%)\n"
                msg += f"\n🕐 {datetime.now().strftime('%H:%M:%S')}"
                await event.reply(msg, parse_mode="html", buttons=_kb(lang))
                return

            data = await self._market.get_price(arg)
            if not data:
                await event.reply(f"❌ Pair not found: {arg}", buttons=_kb(lang))
                return

            arrow = "🟢" if data.change >= 0 else "🔴"
            msg = (
                f"💹 <b>{data.pair}</b>\n\n"
                f"{arrow} Price: <code>{data.price}</code>\n"
                f"📈 Change: <code>{data.change:+.5f}</code> ({data.change_pct:+.2f}%)\n"
                f"⬆️ High: <code>{data.high}</code>\n"
                f"⬇️ Low: <code>{data.low}</code>\n"
                f"\n🕐 {datetime.now().strftime('%H:%M:%S')}"
            )
            await event.reply(msg, parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern="/calendar"))
        async def _calendar(event):
            lang = self._subscribers.get_lang(event.chat_id)
            events_list = await self._market.get_calendar()

            if not events_list:
                await event.reply("📅 No major events this week.", buttons=_kb(lang))
                return

            msg = "📅 <b>Economic Calendar</b>\n<i>High & Medium Impact</i>\n\n"
            for i, ev in enumerate(events_list[:15]):
                impact_icon = "🔴" if ev.impact == "High" else "🟡"
                msg += (
                    f"{impact_icon} <b>{ev.currency}</b> — {ev.event}\n"
                    f"   📊 F: {ev.forecast} | P: {ev.previous} | A: {ev.actual}\n"
                    f"   🕐 {ev.time[:16] if len(ev.time) > 16 else ev.time}\n\n"
                )

            await event.reply(msg, parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern=r"/sentiment\s*(.*)"))
        async def _sentiment(event):
            lang = self._subscribers.get_lang(event.chat_id)
            arg = event.pattern_match.group(1).strip().upper()

            if not arg:
                # Show sentiment for top pairs
                pairs = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "BTCUSD"]
                msg = "🧭 <b>Market Sentiment</b>\n\n"
                for pair in pairs:
                    s = await self._market.get_sentiment(pair)
                    if s:
                        icon = "🟢" if s.trend == "bullish" else "🔴" if s.trend == "bearish" else "⚪"
                        bar = _sentiment_bar(s.buyers_pct)
                        msg += f"{icon} <b>{s.pair}</b>: {bar} B:{s.buyers_pct}% S:{s.sellers_pct}%\n"
                msg += f"\n🕐 {datetime.now().strftime('%H:%M:%S')}"
                await event.reply(msg, parse_mode="html", buttons=_kb(lang))
                return

            s = await self._market.get_sentiment(arg)
            if not s:
                await event.reply(f"❌ Pair not found: {arg}", buttons=_kb(lang))
                return

            icon = "🟢" if s.trend == "bullish" else "🔴" if s.trend == "bearish" else "⚪"
            bar = _sentiment_bar(s.buyers_pct)
            msg = (
                f"🧭 <b>Sentiment: {s.pair}</b>\n\n"
                f"Buyers  {bar}  Sellers\n"
                f"🟢 {s.buyers_pct}%          🔴 {s.sellers_pct}%\n\n"
                f"{icon} Trend: <b>{s.trend.upper()}</b>"
            )
            await event.reply(msg, parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern=r"/alert\s+(\S+)\s+(\S+)\s*(above|below)?"))
        async def _alert(event):
            lang = self._subscribers.get_lang(event.chat_id)
            pair = event.pattern_match.group(1).upper()
            try:
                target = float(event.pattern_match.group(2))
            except ValueError:
                await event.reply("❌ Invalid price. Usage: /alert EURUSD 1.0900 above", buttons=_kb(lang))
                return
            direction = event.pattern_match.group(3) or "above"

            # Verify pair exists
            price_data = await self._market.get_price(pair)
            if not price_data:
                await event.reply(f"❌ Unknown pair: {pair}", buttons=_kb(lang))
                return

            alert_id = self._alert_service.create(event.chat_id, pair, target, direction)
            arrow = "⬆️" if direction == "above" else "⬇️"
            msg = (
                f"🔔 <b>Alert Created!</b>\n\n"
                f"📍 {pair} {arrow} {target}\n"
                f"💹 Current: <code>{price_data.price}</code>\n"
                f"🆔 Alert ID: {alert_id}\n\n"
                f"I'll notify you when price reaches your target."
            )
            await event.reply(msg, parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern="/myalerts"))
        async def _myalerts(event):
            lang = self._subscribers.get_lang(event.chat_id)
            alerts = self._alert_service.get_user_alerts(event.chat_id)

            if not alerts:
                await event.reply("🔔 No active alerts.\nUse /alert EURUSD 1.0900 above", buttons=_kb(lang))
                return

            msg = "🔔 <b>Your Price Alerts</b>\n\n"
            for a in alerts:
                arrow = "⬆️" if a.direction == "above" else "⬇️"
                status = "✅ Active" if not a.triggered else "🔔 Triggered"
                msg += f"#{a.id} | <b>{a.pair}</b> {arrow} {a.target_price} | {status}\n"

            msg += "\nDelete: /delalert <id>"
            await event.reply(msg, parse_mode="html", buttons=_kb(lang))

        @cli.on(events.NewMessage(pattern=r"/delalert\s+(\d+)"))
        async def _delalert(event):
            lang = self._subscribers.get_lang(event.chat_id)
            alert_id = int(event.pattern_match.group(1))
            if self._alert_service.delete(alert_id, event.chat_id):
                await event.reply(f"✅ Alert #{alert_id} deleted.", buttons=_kb(lang))
            else:
                await event.reply(f"❌ Alert #{alert_id} not found.", buttons=_kb(lang))

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _SUBSCRIBE_BTNS))
        async def _btn_sub(event):
            user = await event.get_sender()
            self._subscribers.upsert(
                event.chat_id, getattr(user, "username", None), getattr(user, "first_name", None),
            )
            lang = self._subscribers.get_lang(event.chat_id)

            # Show last 3 signals from DB
            recent = self._signals.get_many(limit=3)
            if recent:
                await event.reply("✅ " + _t(lang, "subscribed") + "\n\n📡 <b>Last 3 Signals:</b>", parse_mode="html", buttons=_kb(lang))
                for s in recent:
                    ts = _format_signal_time(s.created_at)
                    arrow = "🟢" if s.direction == "BUY" else "🔴"
                    msg = (
                        f"━━━━━━━━━━━━━━━━━━━━\n"
                        f"{arrow} <b>{s.pair} — {s.direction}</b>\n"
                        f"📍 Entry: <code>{s.entry_price or '-'}</code>\n"
                        f"🎯 TP1: <code>{s.tp1 or '-'}</code>\n"
                    )
                    if s.tp2:
                        msg += f"🎯 TP2: <code>{s.tp2}</code>\n"
                    if s.tp3:
                        msg += f"🎯 TP3: <code>{s.tp3}</code>\n"
                    msg += (
                        f"🛑 SL: <code>{s.sl or '-'}</code>\n"
                        f"━━━━━━━━━━━━━━━━━━━━\n"
                        f"📅 {ts}\n"
                        f"📡 Signal Bot"
                    )
                    await self.send_to_user(event.chat_id, msg)
            else:
                # No signals in DB — fetch last 3 from source channel via userbot
                if not self._user_client:
                    await event.reply("✅ " + _t(lang, "subscribed") + "\n\n📭 No signals yet.", parse_mode="html", buttons=_kb(lang))
                    return
                from app.parser import SignalParser
                from app.formatter import SignalFormatter
                parser = SignalParser()
                formatter = SignalFormatter()
                found = 0
                await event.reply("✅ " + _t(lang, "subscribed") + "\n\n📡 <b>Fetching latest signals...</b>", parse_mode="html", buttons=_kb(lang))
                for ch in self._config.default_channels:
                    try:
                        entity = await self._user_client.get_entity(ch)
                        async for message in self._user_client.iter_messages(entity, limit=30):
                            if not message.text:
                                continue
                            if parser.is_signal(message.text):
                                parsed = parser.parse(message.text)
                                if parsed:
                                    ts = _format_signal_time(str(message.date))
                                    fmt = formatter.format(parsed) + f"\n📅 {ts}"
                                    await self.send_to_user(event.chat_id, fmt)
                                    found += 1
                                    if found >= 3:
                                        break
                    except Exception as exc:
                        self._logger.warning(f"Fetch from @{ch}: {exc}")
                if found == 0:
                    await self.send_to_user(event.chat_id, "📭 No signals found yet. You'll be notified when new ones arrive!")

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _STATUS_BTNS))
        async def _btn_status(event):
            await _status(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _HELP_BTNS))
        async def _btn_help(event):
            await _help(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _LANG_BTNS))
        async def _btn_lang(event):
            await _lang(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _UNSUB_BTNS))
        async def _btn_unsub(event):
            await _stop(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _PRICE_BTNS))
        async def _btn_price(event):
            event.pattern_match = type("M", (), {"group": lambda s, i: ""})()
            await _price(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _CALENDAR_BTNS))
        async def _btn_calendar(event):
            await _calendar(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _SENTIMENT_BTNS))
        async def _btn_sentiment(event):
            event.pattern_match = type("M", (), {"group": lambda s, i: ""})()
            await _sentiment(event)

        @cli.on(events.NewMessage(func=lambda e: e.is_private and e.text in _ALERTS_BTNS))
        async def _btn_alerts(event):
            await _myalerts(event)

        admin_ids = set(self._config.admin_ids)

        @cli.on(events.NewMessage(pattern="/broadcast"))
        async def _broadcast(event):
            if event.chat_id not in admin_ids and not self._subscribers.is_admin(event.chat_id):
                return
            text = event.text.replace("/broadcast", "", 1).strip()
            if not text:
                await event.reply("Usage: /broadcast <message>")
                return
            subs = self._subscribers.get_active()
            sent = sum([await self.send_to_user(s.chat_id, f"📢 <b>Announcement:</b>\n\n{text}") for s in subs])
            await event.reply(f"✅ Sent to {sent}/{len(subs)}")

        @cli.on(events.NewMessage(pattern="/users"))
        async def _users(event):
            if event.chat_id not in admin_ids and not self._subscribers.is_admin(event.chat_id):
                return
            total, active = self._subscribers.count()
            await event.reply(f"👥 Active: {active} | Total: {total}")

        @cli.on(events.NewMessage(func=lambda e: e.is_private and not e.text.startswith("/")))
        async def _fallback(event):
            if event.text in _ALL_BTNS:
                return
            lang = self._subscribers.get_lang(event.chat_id)
            await event.reply("📋 /menu", buttons=_kb(lang))

        # cross-promo: when user joins the target channel, welcome with bot link
        @cli.on(events.ChatAction())
        async def _channel_join(event):
            if not event.user_joined and not event.user_added:
                return
            target_ch = self._settings.get("target_channel", "")
            if not target_ch:
                return
            try:
                chat = await event.get_chat()
                chat_un = getattr(chat, "username", "") or ""
                # match target channel (could be @name or -100xxx)
                if not (chat_un and f"@{chat_un}" == target_ch) and str(event.chat_id) != target_ch.lstrip("@"):
                    return
            except Exception:
                return
            bot_un = self._settings.get("bot_username", "")
            if not bot_un:
                return
            promo = self._settings.get("channel_to_bot_promo", "")
            if not promo:
                promo = "🤖 خوش آمدید! برای دریافت سیگنال، قیمت لحظه‌ای و هشدارها ربات ما را استارت کنید!\nWelcome! Start our bot for signals, live prices & alerts!"
            try:
                await cli.send_message(
                    event.chat_id, promo, parse_mode="html",
                    buttons=[[Button.url(f"🤖 @{bot_un}", f"https://t.me/{bot_un}")]],
                )
            except Exception as exc:
                self._logger.warning(f"Channel welcome failed: {exc}")


def _format_signal_time(dt_str: str) -> str:
    try:
        from datetime import datetime as dt
        if "T" in dt_str:
            d = dt.fromisoformat(dt_str.replace("+00:00", "").replace("Z", ""))
        else:
            d = dt.strptime(dt_str[:19], "%Y-%m-%d %H:%M:%S")
        return d.strftime("%Y-%m-%d  %H:%M:%S")
    except Exception:
        return dt_str[:19] if len(dt_str) >= 19 else dt_str


def _sentiment_bar(buyers_pct: float) -> str:
    total = 10
    green = round(buyers_pct / 10)
    red = total - green
    return "🟩" * green + "🟥" * red
