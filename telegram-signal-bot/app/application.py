from __future__ import annotations

import asyncio
import logging

import uvicorn

from app.config import Config
from app.database import (
    AlertRepository, Database, ChannelRepository, LogRepository,
    MessageRepository, SettingsRepository, SignalRepository,
    StatsRepository, SubscriberRepository,
)
from app.services.market import MarketService
from app.telegram.bot import SignalBot
from app.telegram.listener import ChannelListener
from app.web.server import WebServer

logger = logging.getLogger(__name__)


class Application:
    """
    Top-level orchestrator.
    Wires together database, Telegram clients, market services, and web server.
    """

    def __init__(self, config: Config) -> None:
        self._config = config

        # ── database & repositories ──
        self._db = Database(config.db_path)
        self.channels = ChannelRepository(self._db)
        self.messages = MessageRepository(self._db)
        self.signals = SignalRepository(self._db)
        self.subscribers = SubscriberRepository(self._db)
        self.settings = SettingsRepository(self._db)
        self.logs = LogRepository(self._db)
        self.stats = StatsRepository(self._db)
        self.alerts = AlertRepository(self._db)

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

        # ── services ──
        self.market = MarketService()

        # ── telegram ──
        self.listener = ChannelListener(
            config, self.channels, self.messages,
            self.signals, self.settings, self.logs,
        )
        self.bot = SignalBot(
            config, self.subscribers, self.signals,
            self.logs, self.alerts, self.settings, self.market,
            user_client=self.listener.client,
        )

        # ── web ──
        self.web = WebServer(config, repos, self.market)

    # ── lifecycle ──

    async def start(self) -> None:
        logger.info("Starting application...")
        self._db.init_schema()

        # Register admin users
        for admin_id in self._config.admin_ids:
            if admin_id:
                self.subscribers.set_admin(admin_id)

        # Seed default channels
        if not self.channels.get_all():
            for ch in self._config.default_channels:
                self.channels.add(ch, ch)
                logger.info(f"Seeded channel: @{ch}")

        # Wire callbacks
        self.listener.on_signal(self._handle_signal)
        self.listener.on_message(self._handle_message)

        # Start services
        if not await self.listener.start():
            logger.error("Listener failed — run 'python login.py' first")
            return

        await self.bot.start()

        self.logs.add("INFO", "app", f"System ready — port {self._config.web_port}")
        logger.info(f"Dashboard : http://localhost:{self._config.web_port}")
        logger.info(f"Signals   : http://localhost:{self._config.web_port}/signals")

        # Run all services concurrently
        await asyncio.gather(
            self._run_web(),
            self._watchdog(),
            self.bot.alert_service.start(),
        )

    async def stop(self) -> None:
        self.bot.alert_service.stop()
        await self.market.close()
        await self.listener.disconnect()
        await self.bot.disconnect()
        logger.info("Application stopped")

    # ── internal callbacks ──

    async def _handle_signal(self, signal_id: int, formatted: str, media, pair: str = "") -> None:
        approval_mode = self.settings.get("approval_mode", "0") == "1"

        if approval_mode:
            # Send to admin for approval instead of broadcasting
            await self.bot.send_approval_request(signal_id, formatted, pair)
            self.logs.add("INFO", "app", f"Signal #{signal_id} sent for admin approval")
        else:
            # Auto-broadcast
            await self.bot.broadcast_signal(signal_id, formatted, media, pair)

        latest = self.signals.get_many(limit=1)
        if latest:
            await self.web.notify_signal(latest[0].to_dict())

    async def _handle_message(self, msg_data: dict) -> None:
        await self.web.notify_message(msg_data)

    # ── runners ──

    async def _run_web(self) -> None:
        server = uvicorn.Server(uvicorn.Config(
            self.web.app,
            host="0.0.0.0",
            port=self._config.web_port,
            log_level="info",
            access_log=False,
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
