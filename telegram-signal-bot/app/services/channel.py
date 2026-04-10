import asyncio
import logging
from datetime import datetime, timedelta

from telethon import TelegramClient, events, Button

from app.database import (
    LogRepository, SettingsRepository, SignalRepository,
    SignalMessageRepository, SubscriberRepository,
)
from app.services.market import MarketService

logger = logging.getLogger(__name__)

# market session times (UTC hours)
SESSIONS = [
    (0, "🌏 Sydney Session Opened"),
    (3, "🌏 Tokyo Session Opened"),
    (8, "🇬🇧 London Session Opened"),
    (13, "🇺🇸 New York Session Opened"),
    (17, "🇺🇸 New York Session Closed"),
    (22, "🌏 Sydney Session Closing Soon"),
]


class ChannelManager:

    def __init__(
        self,
        bot_client: TelegramClient,
        settings: SettingsRepository,
        signals: SignalRepository,
        signal_msgs: SignalMessageRepository,
        subscribers: SubscriberRepository,
        logs: LogRepository,
        market: MarketService,
    ):
        self._bot = bot_client
        self._settings = settings
        self._signals = signals
        self._signal_msgs = signal_msgs
        self._subs = subscribers
        self._logs = logs
        self._market = market
        self._running = False
        self._last_session_hour = -1
        self._last_summary_day = -1
        self._last_news_check = 0

    @property
    def _channel(self) -> str:
        return self._settings.get("target_channel", "")

    def _next_signal_number(self) -> int:
        counter = int(self._settings.get("signal_counter", "0")) + 1
        self._settings.set("signal_counter", str(counter))
        return counter

    def _should_send_cta(self) -> bool:
        counter = int(self._settings.get("signal_counter", "0"))
        interval = int(self._settings.get("cta_interval", "5"))
        return interval > 0 and counter % interval == 0

    # --- send signal to channel with all features ---

    def _bot_username(self) -> str:
        return self._settings.get("bot_username", "AcademySignalbot")

    def _channel_username(self) -> str:
        return self._settings.get("channel_username", "AcademySignalsss")

    async def send_signal(self, signal_id: int, formatted_text: str, pair: str = "", chart: bytes = None):
        ch = self._channel
        if not ch:
            return

        num = self._next_signal_number()
        bot_un = self._bot_username()
        ch_un = self._channel_username()

        # build message with branding from DB
        header_tpl = self._settings.get("channel_signal_header", "📡 <b>Signal #{num}</b>")
        header = header_tpl.replace("{num}", str(num)) + "\n\n"

        footer_tpl = self._settings.get("channel_signal_footer", "💬 Details → @{bot}\n📺 Channel → @{channel}")
        footer = "\n\n" + footer_tpl.replace("{bot}", bot_un).replace("{channel}", ch_un)

        full_msg = header + formatted_text + footer

        # inline buttons
        buttons = [
            [
                Button.url("📊 Open Bot", f"https://t.me/{bot_un}"),
                Button.url("📺 Channel", f"https://t.me/{ch_un}"),
            ]
        ]

        try:
            if chart:
                msg = await self._bot.send_file(
                    ch, chart, caption=full_msg,
                    parse_mode="html", buttons=buttons,
                )
            else:
                msg = await self._bot.send_message(
                    ch, full_msg, parse_mode="html", buttons=buttons,
                )

            # track message id for later editing
            self._signal_msgs.save(signal_id, ch, msg.id)

            # auto-pin
            try:
                await self._bot.pin_message(ch, msg.id, notify=False)
            except Exception:
                pass

            # poll after signal
            try:
                await self._bot.send_message(
                    ch,
                    f"📊 <b>Signal #{num} — {pair}</b>\nWhat do you think?",
                    parse_mode="html",
                    buttons=[[
                        Button.inline("👍 Agree", data=f"poll_agree_{signal_id}".encode()),
                        Button.inline("👎 Disagree", data=f"poll_disagree_{signal_id}".encode()),
                    ]]
                )
            except Exception:
                pass

            # CTA every N signals
            if self._should_send_cta():
                await asyncio.sleep(2)
                cta_tpl = self._settings.get("channel_cta", "")
                if cta_tpl:
                    cta = cta_tpl.replace("{bot}", bot_un).replace("{channel}", ch_un)
                else:
                    cta = f"🤖 <b>Want more features?</b>\n\n👉 @{bot_un}"
                await self._bot.send_message(ch, cta, parse_mode="html")

            logger.info(f"Channel signal #{num} sent to {ch}")

        except Exception as exc:
            logger.error(f"Channel send error: {exc}")

    # --- update signal (TP/SL hit) ---

    async def update_signal(self, signal_id: int, update_text: str):
        ch = self._channel
        if not ch:
            return
        msg_id = self._signal_msgs.get_message_id(signal_id, ch)
        if not msg_id:
            return

        try:
            msg = await self._bot.get_messages(ch, ids=msg_id)
            if msg:
                old_text = msg.text or msg.raw_text or ""
                new_text = old_text + f"\n\n{update_text}"
                await self._bot.edit_message(ch, msg_id, new_text, parse_mode="html")
                logger.info(f"Signal #{signal_id} updated in channel")
        except Exception as exc:
            logger.warning(f"Signal update error: {exc}")

    # --- scheduled tasks (runs in background) ---

    async def start_scheduler(self):
        self._running = True
        logger.info("Channel scheduler started")
        while self._running:
            try:
                now = datetime.utcnow()

                # market session alerts (check every minute)
                await self._check_sessions(now)

                # daily summary at 21:00 UTC (00:30 Tehran)
                await self._check_daily_summary(now)

                # weekly stats on Sunday
                await self._check_weekly_stats(now)

                # monthly stats on 1st
                await self._check_monthly_stats(now)

                # news alerts (every 15 min)
                await self._check_news_alerts(now)

                # member milestones (every hour)
                await self._check_milestones(now)

            except Exception as exc:
                logger.error(f"Scheduler error: {exc}")

            await asyncio.sleep(60)

    def stop(self):
        self._running = False

    async def _check_sessions(self, now: datetime):
        hour = now.hour
        if hour == self._last_session_hour:
            return
        ch = self._channel
        if not ch:
            return

        for session_hour, text in SESSIONS:
            if hour == session_hour and self._last_session_hour != hour:
                try:
                    await self._bot.send_message(ch, f"🕐 {text}", parse_mode="html")
                except Exception:
                    pass
                break
        self._last_session_hour = hour

    async def _check_daily_summary(self, now: datetime):
        if now.hour != 21 or now.day == self._last_summary_day:
            return
        self._last_summary_day = now.day
        ch = self._channel
        if not ch:
            return

        today = self._signals.get_today()
        if not today:
            return

        stats = self._signals.win_loss_stats(days=1)
        msg = (
            f"📋 <b>Daily Summary — {now.strftime('%Y-%m-%d')}</b>\n\n"
            f"📡 Signals: {len(today)}\n"
            f"✅ Wins: {stats['wins']}\n"
            f"❌ Losses: {stats['losses']}\n"
            f"⏳ Active: {stats['active']}\n"
        )
        if stats['wins'] + stats['losses'] > 0:
            rate = round(stats['wins'] / (stats['wins'] + stats['losses']) * 100, 1)
            msg += f"📊 Win Rate: {rate}%\n"

        bot_un = self._bot_username()
        ch_un = self._channel_username()
        summary_footer = self._settings.get("daily_summary_footer", "💬 @{bot} | 📺 @{channel}")
        msg += "\n" + summary_footer.replace("{bot}", bot_un).replace("{channel}", ch_un)

        try:
            sent = await self._bot.send_message(ch, msg, parse_mode="html")
            await self._bot.pin_message(ch, sent.id, notify=False)
        except Exception as exc:
            logger.warning(f"Daily summary error: {exc}")

    async def _check_weekly_stats(self, now: datetime):
        # Sunday at 20:00 UTC
        if now.weekday() != 6 or now.hour != 20:
            return
        ch = self._channel
        if not ch:
            return

        stats = self._signals.win_loss_stats(days=7)
        if stats["total"] == 0:
            return

        win_rate = 0
        if stats["wins"] + stats["losses"] > 0:
            win_rate = round(stats["wins"] / (stats["wins"] + stats["losses"]) * 100, 1)

        msg = (
            f"📊 <b>Weekly Report</b>\n\n"
            f"📡 Total Signals: {stats['total']}\n"
            f"✅ Wins: {stats['wins']}\n"
            f"❌ Losses: {stats['losses']}\n"
            f"📈 Win Rate: {win_rate}%\n"
            f"\n🤖 @{self._bot_username()}"
        )
        try:
            await self._bot.send_message(ch, msg, parse_mode="html")
        except Exception:
            pass

    async def _check_monthly_stats(self, now: datetime):
        # 1st of month at 10:00 UTC
        if now.day != 1 or now.hour != 10:
            return
        ch = self._channel
        if not ch:
            return

        stats = self._signals.win_loss_stats(days=30)
        if stats["total"] == 0:
            return

        win_rate = 0
        if stats["wins"] + stats["losses"] > 0:
            win_rate = round(stats["wins"] / (stats["wins"] + stats["losses"]) * 100, 1)

        msg = (
            f"📊 <b>Monthly Report</b>\n\n"
            f"📡 Total Signals: {stats['total']}\n"
            f"✅ Wins: {stats['wins']}\n"
            f"❌ Losses: {stats['losses']}\n"
            f"📈 Win Rate: {win_rate}%\n"
            f"\n🤖 @{self._bot_username()} | 📺 @{self._channel_username()}"
        )
        try:
            await self._bot.send_message(ch, msg, parse_mode="html")
        except Exception:
            pass

    async def _check_news_alerts(self, now: datetime):
        # check every 15 min
        ts = int(now.timestamp())
        if ts - self._last_news_check < 900:
            return
        self._last_news_check = ts
        ch = self._channel
        if not ch:
            return

        try:
            events = await self._market.get_calendar()
            for ev in events:
                if ev.impact != "High":
                    continue
                # parse event time
                try:
                    ev_time = datetime.fromisoformat(ev.time.replace("Z", "+00:00").replace(" ", "T")[:19])
                except Exception:
                    continue
                diff = (ev_time - now).total_seconds()
                # alert 30 min before
                if 0 < diff < 1800:
                    msg = (
                        f"⚠️ <b>High Impact News in {int(diff/60)} min!</b>\n\n"
                        f"🏳️ {ev.currency} — {ev.event}\n"
                        f"📊 Forecast: {ev.forecast} | Previous: {ev.previous}\n"
                        f"🕐 {ev.time[:16]}"
                    )
                    await self._bot.send_message(ch, msg, parse_mode="html")
                    break
        except Exception:
            pass

    async def _check_milestones(self, now: datetime):
        if now.minute != 0:
            return
        ch = self._channel
        if not ch:
            return

        try:
            full = await self._bot.get_entity(ch)
            count = getattr(full, 'participants_count', 0)
            if count <= 0:
                return

            milestones = [50, 100, 250, 500, 1000, 2500, 5000, 10000]
            for m in milestones:
                if count >= m and count < m + 5:
                    msg = f"🎉 <b>We reached {m} members!</b>\n\nThank you for being part of our community! 🙏"
                    await self._bot.send_message(ch, msg, parse_mode="html")
                    break
        except Exception:
            pass
