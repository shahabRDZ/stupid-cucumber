import logging
from abc import ABC, abstractmethod

from telethon import TelegramClient

from app.config import Config


class BaseTelegramClient(ABC):

    def __init__(self, session_name: str, config: Config) -> None:
        self._config = config
        self._client = TelegramClient(session_name, config.api_id, config.api_hash)
        self._logger = logging.getLogger(self.__class__.__name__)

    @property
    def client(self) -> TelegramClient:
        return self._client

    @property
    def is_connected(self) -> bool:
        return self._client.is_connected()

    async def connect(self) -> None:
        if not self.is_connected:
            await self._client.connect()
            self._logger.info("Connected")

    async def disconnect(self) -> None:
        if self.is_connected:
            await self._client.disconnect()
            self._logger.info("Disconnected")

    async def reconnect(self) -> None:
        if not self.is_connected:
            self._logger.warning("Connection lost — reconnecting...")
            await self.connect()

    @abstractmethod
    async def start(self) -> bool: ...

    @abstractmethod
    def _register_handlers(self) -> None: ...
