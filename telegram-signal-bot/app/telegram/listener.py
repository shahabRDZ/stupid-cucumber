import logging
from typing import Callable, Awaitable

from telethon import events

from app.config import Config
from app.database import (
    ChannelRepository, LogRepository, MessageRepository,
    SettingsRepository, SignalRepository,
)
from app.formatter import SignalFormatter
from app.models import ParsedSignal
from app.parser import SignalParser
from app.telegram.base import BaseTelegramClient

import re

SignalCallback = Callable[[int, str, object, str], Awaitable[None]]
MessageCallback = Callable[[dict], Awaitable[None]]
UpdateCallback = Callable[[int, str, str], Awaitable[None]]  # signal_id, update_text, status


class ChannelListener(BaseTelegramClient):

    def __init__(
        self,
        config: Config,
        channels: ChannelRepository,
        messages: MessageRepository,
        signals: SignalRepository,
        settings: SettingsRepository,
        logs: LogRepository,
    ) -> None:
        super().__init__("user_session", config)
        self._channels = channels
        self._messages = messages
        self._signals = signals
        self._settings = settings
        self._logs = logs
        self._parser = SignalParser()
        self._formatter = SignalFormatter()

        self._on_signal: SignalCallback | None = None
        self._on_message: MessageCallback | None = None
        self._on_update: UpdateCallback | None = None

    def on_signal(self, callback: SignalCallback) -> None:
        self._on_signal = callback

    def on_update(self, callback: UpdateCallback) -> None:
        self._on_update = callback

    def on_message(self, callback: MessageCallback) -> None:
        self._on_message = callback

    async def start(self) -> bool:
        await self.connect()
        if not await self._client.is_user_authorized():
            self._logger.error("Not logged in — run 'python login.py' first")
            return False
        self._register_handlers()
        self._logger.info("Listener started")
        self._logs.add("INFO", "listener", "Listener started")
        return True

    def _register_handlers(self) -> None:

        @self._client.on(events.NewMessage())
        async def _on_new_message(event: events.NewMessage.Event) -> None:
            chat = await event.get_chat()
            username = getattr(chat, "username", None) or ""
            title = getattr(chat, "title", None) or username or "unknown"

            active = self._channels.get_active_usernames()
            if username and username.lower() not in [u.lower() for u in active]:
                return

            raw_text = event.message.text or ""
            if not raw_text:
                return

            media_type = type(event.message.media).__name__ if event.message.media else None
            is_sig = self._parser.is_signal(raw_text)

            raw_id = self._messages.save(
                channel_username=username,
                channel_title=title,
                message_id=event.message.id,
                text=raw_text,
                media_type=media_type,
                is_signal=is_sig,
            )
            if raw_id is None:
                return  # duplicate

            self._logger.info(f"@{username} | signal={is_sig}")
            self._logs.add("INFO", "listener", f"Message from @{username} | signal={is_sig}")

            if self._on_message:
                await self._on_message({
                    "id": raw_id, "channel": username,
                    "text": raw_text[:200], "is_signal": is_sig,
                })

            # detect TP/SL hit updates
            lower = raw_text.lower()
            tp_hit = bool(re.search(r"(tp\d?\s*(hit|reached|done|✅)|take profit.*hit|target.*hit)", lower))
            sl_hit = bool(re.search(r"(sl\s*(hit|reached|done|❌)|stop loss.*hit|stopped out)", lower))

            if (tp_hit or sl_hit) and self._on_update:
                pair = self._parser._detect_pair(raw_text)
                if pair:
                    recent = self._signals.get_by_pair_recent(pair)
                    if recent:
                        sig = recent[0]
                        if tp_hit:
                            status = "tp_hit"
                            update_text = "✅ <b>TP HIT!</b>"
                            tp_num = re.search(r"tp\s*(\d)", lower)
                            if tp_num:
                                update_text = f"✅ <b>TP{tp_num.group(1)} HIT!</b>"
                        else:
                            status = "sl_hit"
                            update_text = "❌ <b>SL HIT</b>"

                        self._signals.update_status(sig.id, status)
                        await self._on_update(sig.id, update_text, status)
                        self._logs.add("INFO", "listener", f"{pair} → {status}")

            if self._settings.filter_enabled and not is_sig:
                return

            parsed = self._parser.parse(raw_text)
            if not parsed and is_sig:
                parsed = ParsedSignal(pair="UNKNOWN", direction="UNKNOWN")

            if parsed:
                formatted = self._formatter.format(parsed, self._settings.message_template)
                signal_id = self._signals.save(
                    raw_message_id=raw_id,
                    parsed=parsed,
                    raw_text=raw_text,
                    formatted_text=formatted,
                )
                self._logger.info(f"Signal: {parsed.pair} {parsed.direction}")
                self._logs.add("INFO", "parser", f"Signal: {parsed.pair} {parsed.direction}")

                if self._settings.send_enabled and self._on_signal:
                    await self._on_signal(signal_id, formatted, event.message.media, parsed.pair)
