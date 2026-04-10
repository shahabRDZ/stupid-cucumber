from __future__ import annotations

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

        self.app = FastAPI(title="Signal Bot API", version="2.0")

        static_dir = Path(__file__).parent.parent / "static"
        self.app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

        router = create_router(config, repositories, market)
        self.app.include_router(router)

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
