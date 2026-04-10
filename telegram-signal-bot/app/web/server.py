import logging
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles

from app.config import Config
from app.services.market import MarketService
from app.web.routes import create_router


class WebSocketManager:
    def __init__(self) -> None:
        self._connections: list[WebSocket] = []

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        self._connections.append(ws)

    def disconnect(self, ws: WebSocket) -> None:
        if ws in self._connections:
            self._connections.remove(ws)

    async def broadcast(self, data: dict) -> None:
        dead: list[WebSocket] = []
        for ws in self._connections:
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


class WebServer:
    def __init__(self, config: Config, repositories: dict, market: MarketService) -> None:
        self._config = config
        self._logger = logging.getLogger("WebServer")
        self.ws_manager = WebSocketManager()
        self._channel_send_callback = None
        self._bot_broadcast_callback = None
        self._channel_delete_callback = None

        self.app = FastAPI(title="Signal Bot API", version="2.0")

        static_dir = Path(__file__).parent.parent / "static"
        self.app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

        router = create_router(config, repositories, market, self)
        self.app.include_router(router)

    def on_channel_send(self, callback):
        self._channel_send_callback = callback

    def on_bot_broadcast(self, callback):
        self._bot_broadcast_callback = callback

    def on_channel_delete(self, callback):
        self._channel_delete_callback = callback

    async def send_to_channel(self, text: str):
        if self._channel_send_callback:
            await self._channel_send_callback(text)

    async def send_to_bot(self, text: str) -> int:
        if self._bot_broadcast_callback:
            return await self._bot_broadcast_callback(text)
        return 0

    async def delete_channel_message(self, msg_type: str, item_id: int):
        if self._channel_delete_callback:
            await self._channel_delete_callback(msg_type, item_id)

        @self.app.websocket("/ws")
        async def _ws_endpoint(ws: WebSocket) -> None:
            await self.ws_manager.connect(ws)
            try:
                while True:
                    data = await ws.receive_text()
                    if data == "ping":
                        await ws.send_text("pong")
            except WebSocketDisconnect:
                self.ws_manager.disconnect(ws)

    async def notify_signal(self, signal_data: dict) -> None:
        await self.ws_manager.broadcast({"type": "new_signal", "data": signal_data})

    async def notify_message(self, message_data: dict) -> None:
        await self.ws_manager.broadcast({"type": "new_message", "data": message_data})
