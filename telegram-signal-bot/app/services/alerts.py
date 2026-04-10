from __future__ import annotations

import asyncio
import logging
from typing import Callable, Awaitable

from app.database import AlertRepository
from app.services.market import MarketService

logger = logging.getLogger(__name__)

# Callback: (chat_id, pair, target_price, current_price, direction) -> None
AlertCallback = Callable[[int, str, float, float, str], Awaitable[None]]


class AlertService:
    """Background service that monitors price alerts and triggers notifications."""

    CHECK_INTERVAL = 30  # seconds

    def __init__(
        self,
        alerts_repo: AlertRepository,
        market: MarketService,
    ) -> None:
        self._alerts = alerts_repo
        self._market = market
        self._on_triggered: AlertCallback | None = None
        self._running = False

    def on_triggered(self, callback: AlertCallback) -> None:
        self._on_triggered = callback

    def create(self, chat_id: int, pair: str, target_price: float, direction: str) -> int:
        return self._alerts.create(chat_id, pair, target_price, direction)

    def get_user_alerts(self, chat_id: int) -> list:
        return self._alerts.get_by_user(chat_id)

    def delete(self, alert_id: int, chat_id: int) -> bool:
        return self._alerts.delete(alert_id, chat_id)

    async def start(self) -> None:
        self._running = True
        logger.info("Alert service started")
        while self._running:
            try:
                await self._check_alerts()
            except Exception as exc:
                logger.error(f"Alert check error: {exc}")
            await asyncio.sleep(self.CHECK_INTERVAL)

    def stop(self) -> None:
        self._running = False

    async def _check_alerts(self) -> None:
        active = self._alerts.get_active()
        if not active:
            return

        # Group by pair to minimize API calls
        pairs = {a.pair for a in active}
        prices: dict[str, float] = {}
        for pair in pairs:
            data = await self._market.get_price(pair)
            if data:
                prices[pair] = data.price

        for alert in active:
            current = prices.get(alert.pair)
            if current is None:
                continue

            triggered = False
            if alert.direction == "above" and current >= alert.target_price:
                triggered = True
            elif alert.direction == "below" and current <= alert.target_price:
                triggered = True

            if triggered:
                self._alerts.mark_triggered(alert.id)
                logger.info(f"Alert triggered: {alert.pair} {alert.direction} {alert.target_price} (now {current})")

                if self._on_triggered:
                    await self._on_triggered(
                        alert.chat_id,
                        alert.pair,
                        alert.target_price,
                        current,
                        alert.direction,
                    )
