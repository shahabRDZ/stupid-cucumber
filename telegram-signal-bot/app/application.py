import asyncio
import logging

import uvicorn

from app.config import Config
from app.database import (
    AlertRepository, Database, ChannelRepository, LogRepository,
    MessageRepository, SettingsRepository, SignalRepository,
    SignalMessageRepository, StatsRepository, SubscriberRepository,
)
from app.services.market import MarketService
from app.services.channel import ChannelManager
from app.telegram.bot import SignalBot
from app.telegram.listener import ChannelListener
from app.web.server import WebServer

logger = logging.getLogger(__name__)


class Application:

    def __init__(self, config: Config) -> None:
        self._config = config

        self._db = Database(config.db_path)
        self.channels = ChannelRepository(self._db)
        self.messages = MessageRepository(self._db)
        self.signals = SignalRepository(self._db)
        self.subscribers = SubscriberRepository(self._db)
        self.settings = SettingsRepository(self._db)
        self.logs = LogRepository(self._db)
        self.stats = StatsRepository(self._db)
        self.alerts = AlertRepository(self._db)
        self.signal_msgs = SignalMessageRepository(self._db)

        repos = {
            "channels": self.channels,
            "messages": self.messages,
            "signals": self.signals,
            "subscribers": self.subscribers,
            "settings": self.settings,
            "logs": self.logs,
            "stats": self.stats,
            "alerts": self.alerts,
        }

        self.market = MarketService()

        self.listener = ChannelListener(
            config, self.channels, self.messages,
            self.signals, self.settings, self.logs,
        )
        self.bot = SignalBot(
            config, self.subscribers, self.signals,
            self.logs, self.alerts, self.settings, self.market,
            user_client=self.listener.client,
        )

        self.channel_mgr = None
        self.web = WebServer(config, repos, self.market)

    async def start(self) -> None:
        logger.info("Starting application...")
        self._db.init_schema()

        for admin_id in self._config.admin_ids:
            if admin_id:
                self.subscribers.set_admin(admin_id)

        if not self.channels.get_all():
            for ch in self._config.default_channels:
                self.channels.add(ch, ch)
                logger.info(f"Seeded channel: @{ch}")

        self.listener.on_signal(self._handle_signal)
        self.listener.on_message(self._handle_message)
        self.listener.on_update(self._handle_signal_update)

        if not await self.listener.start():
            logger.error("Listener failed — run 'python login.py' first")
            return

        await self.bot.start()

        self.channel_mgr = ChannelManager(
            self.bot.client, self.settings, self.signals,
            self.signal_msgs, self.subscribers, self.logs, self.market,
        )

        self.logs.add("INFO", "app", f"System ready — port {self._config.web_port}")
        logger.info(f"Dashboard : http://localhost:{self._config.web_port}")
        logger.info(f"Signals   : http://localhost:{self._config.web_port}/signals")

        await asyncio.gather(
            self._run_web(),
            self._watchdog(),
            self.bot.alert_service.start(),
            self.channel_mgr.start_scheduler(),
        )

    async def stop(self) -> None:
        self.bot.alert_service.stop()
        if self.channel_mgr:
            self.channel_mgr.stop()
        await self.market.close()
        await self.listener.disconnect()
        await self.bot.disconnect()
        logger.info("Application stopped")

    async def _handle_signal(self, signal_id: int, formatted: str, media, pair: str = "") -> None:
        approval_mode = self.settings.get("approval_mode", "0") == "1"

        chart = None
        if pair and self.settings.get("chart_enabled", "1") == "1":
            chart = await self.market.get_chart_image(pair)

        if approval_mode:
            await self.bot.send_approval_request(signal_id, formatted, pair)
            self.logs.add("INFO", "app", f"Signal #{signal_id} sent for admin approval")
        else:
            await self.bot.broadcast_signal(signal_id, formatted, media, pair)
            if self.channel_mgr:
                await self.channel_mgr.send_signal(signal_id, formatted, pair, chart)

        latest = self.signals.get_many(limit=1)
        if latest:
            await self.web.notify_signal(latest[0].to_dict())

    async def _handle_message(self, msg_data: dict) -> None:
        await self.web.notify_message(msg_data)

    async def _handle_signal_update(self, signal_id: int, update_text: str, status: str) -> None:
        # update in channel
        if self.channel_mgr:
            await self.channel_mgr.update_signal(signal_id, update_text)
        # notify subscribers
        sig = None
        for s in self.signals.get_many(limit=50):
            if s.id == signal_id:
                sig = s
                break
        if sig:
            msg = f"{update_text}\n📡 {sig.pair} — Signal #{signal_id}"
            for sub in self.subscribers.get_active():
                await self.bot.send_to_user(sub.chat_id, msg)

    async def _run_web(self) -> None:
        server = uvicorn.Server(uvicorn.Config(
            self.web.app, host="0.0.0.0",
            port=self._config.web_port,
            log_level="info", access_log=False,
        ))
        await server.serve()

    async def _watchdog(self) -> None:
        while True:
            try:
                await asyncio.sleep(60)
                await self.listener.reconnect()
                await self.bot.reconnect()
            except Exception as exc:
                logger.error(f"Watchdog: {exc}")
                await asyncio.sleep(5)
