import logging
import time
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles

from app.config import Config
from app.services.market import MarketService
from app.web.routes import create_router

MAX_WS_CONNECTIONS = 50
WS_IDLE_TIMEOUT = 1800  # 30 minutes


class WebSocketManager:
    def __init__(self) -> None:
        self._connections: dict[WebSocket, float] = {}  # ws -> last_active

    @property
    def count(self) -> int:
        return len(self._connections)

    async def connect(self, ws: WebSocket) -> bool:
        if len(self._connections) >= MAX_WS_CONNECTIONS:
            await ws.close(code=1013, reason="Too many connections")
            return False
        await ws.accept()
        self._connections[ws] = time.time()
        return True

    def disconnect(self, ws: WebSocket) -> None:
        self._connections.pop(ws, None)

    def touch(self, ws: WebSocket) -> None:
        if ws in self._connections:
            self._connections[ws] = time.time()

    def cleanup_idle(self) -> list[WebSocket]:
        now = time.time()
        idle = [ws for ws, ts in self._connections.items() if now - ts > WS_IDLE_TIMEOUT]
        for ws in idle:
            self.disconnect(ws)
        return idle

    async def broadcast(self, data: dict) -> None:
        dead: list[WebSocket] = []
        for ws in list(self._connections):
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
        self._channel_posts_callback = None
        self._channel_delete_post_callback = None
        self._post_comments_callback = None
        self._delete_comments_callback = None

        self.app = FastAPI(title="Signal Bot API", version="2.0")

        static_dir = Path(__file__).parent.parent / "static"
        self.app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

        router = create_router(config, repositories, market, self)
        self.app.include_router(router)

        # WebSocket endpoint — must be registered here, not inside a method
        ws_mgr = self.ws_manager

        @self.app.websocket("/ws")
        async def _ws_endpoint(ws: WebSocket) -> None:
            if not await ws_mgr.connect(ws):
                return
            try:
                while True:
                    data = await ws.receive_text()
                    ws_mgr.touch(ws)
                    if data == "ping":
                        await ws.send_text("pong")
            except WebSocketDisconnect:
                ws_mgr.disconnect(ws)

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

    def on_channel_posts(self, callback):
        self._channel_posts_callback = callback

    def on_channel_delete_post(self, callback):
        self._channel_delete_post_callback = callback

    async def delete_channel_message(self, msg_type: str, item_id: int):
        if self._channel_delete_callback:
            await self._channel_delete_callback(msg_type, item_id)

    async def get_channel_posts(self, limit: int = 50) -> list[dict]:
        if self._channel_posts_callback:
            return await self._channel_posts_callback(limit)
        return []

    def on_post_comments(self, callback):
        self._post_comments_callback = callback

    def on_delete_comments(self, callback):
        self._delete_comments_callback = callback

    async def delete_channel_post(self, message_id: int) -> bool:
        if self._channel_delete_post_callback:
            return await self._channel_delete_post_callback(message_id)
        return False

    async def get_post_comments(self, post_id: int, limit: int = 50) -> list[dict]:
        if self._post_comments_callback:
            return await self._post_comments_callback(post_id, limit)
        return []

    async def delete_post_comments(self, post_id: int) -> int:
        if self._delete_comments_callback:
            return await self._delete_comments_callback(post_id)
        return 0

    async def notify_signal(self, signal_data: dict) -> None:
        await self.ws_manager.broadcast({"type": "new_signal", "data": signal_data})

    async def notify_message(self, message_data: dict) -> None:
        await self.ws_manager.broadcast({"type": "new_message", "data": message_data})
