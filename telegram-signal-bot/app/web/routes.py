from pathlib import Path

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel

from app.config import Config
from app.database import (
    AlertRepository, ChannelRepository, LogRepository, MessageRepository,
    SettingsRepository, SignalRepository, StatsRepository,
    SubscriberRepository,
)
from app.services.market import MarketService

STATIC_DIR = Path(__file__).parent.parent / "static"


class ChannelIn(BaseModel):
    username: str
    title: str = ""

class SettingIn(BaseModel):
    key: str
    value: str

class LoginIn(BaseModel):
    password: str

class ChannelMessageIn(BaseModel):
    text: str

class TextsIn(BaseModel):
    texts: dict


def _check_auth(request: Request, password: str) -> None:
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    if token != password:
        raise HTTPException(status_code=401, detail="Unauthorized")


def create_router(config: Config, repos: dict, market: MarketService, web_server=None) -> APIRouter:
    router = APIRouter()

    channels: ChannelRepository = repos["channels"]
    messages: MessageRepository = repos["messages"]
    signals: SignalRepository = repos["signals"]
    subscribers: SubscriberRepository = repos["subscribers"]
    settings: SettingsRepository = repos["settings"]
    logs: LogRepository = repos["logs"]
    stats: StatsRepository = repos["stats"]
    alerts: AlertRepository = repos["alerts"]
    pwd = config.admin_password

    def auth(request: Request) -> None:
        _check_auth(request, pwd)

    # --- pages ---

    @router.get("/", response_class=HTMLResponse)
    async def admin_page():
        return FileResponse(STATIC_DIR / "admin.html")

    @router.get("/signals", response_class=HTMLResponse)
    async def signals_page():
        return FileResponse(STATIC_DIR / "signals.html")

    # --- auth ---

    @router.post("/api/login")
    async def login(data: LoginIn):
        if data.password == pwd:
            return {"token": pwd, "status": "ok"}
        raise HTTPException(status_code=401, detail="Wrong password")

    # --- dashboard ---

    @router.get("/api/dashboard")
    async def dashboard(request: Request):
        auth(request)
        return stats.dashboard().to_dict()

    # --- channels ---

    @router.get("/api/channels")
    async def list_channels(request: Request):
        auth(request)
        return [ch.to_dict() for ch in channels.get_all()]

    @router.post("/api/channels")
    async def add_channel(data: ChannelIn, request: Request):
        auth(request)
        channels.add(data.username, data.title or data.username)
        logs.add("INFO", "api", f"Channel added: @{data.username}")
        return {"status": "ok"}

    @router.delete("/api/channels/{username}")
    async def delete_channel(username: str, request: Request):
        auth(request)
        channels.remove(username)
        logs.add("INFO", "api", f"Channel removed: @{username}")
        return {"status": "ok"}

    @router.put("/api/channels/{username}/toggle")
    async def toggle_channel(username: str, request: Request, active: bool = True):
        auth(request)
        channels.toggle(username, active)
        logs.add("INFO", "api", f"Channel @{username} active={active}")
        return {"status": "ok"}

    # --- signals ---

    @router.get("/api/signals")
    async def list_signals(
        request: Request,
        limit: int = Query(50, le=200),
        offset: int = Query(0, ge=0),
        status: str = Query(None),
    ):
        auth(request)
        return [s.to_dict() for s in signals.get_many(limit, offset, status)]

    @router.get("/api/signals/count")
    async def signal_count(request: Request):
        auth(request)
        return {"count": signals.count()}

    # --- messages ---

    @router.get("/api/messages")
    async def list_messages(
        request: Request,
        limit: int = Query(50, le=200),
        offset: int = Query(0, ge=0),
    ):
        auth(request)
        return [m.to_dict() for m in messages.get_many(limit, offset)]

    @router.get("/api/messages/count")
    async def message_count(request: Request):
        auth(request)
        return {"count": messages.count()}

    # --- subscribers ---

    @router.get("/api/subscribers")
    async def list_subscribers(request: Request):
        auth(request)
        return [s.to_dict() for s in subscribers.get_all()]

    @router.get("/api/subscribers/count")
    async def subscriber_count(request: Request):
        auth(request)
        total, active = subscribers.count()
        return {"total": total, "active": active}

    # --- settings ---

    @router.get("/api/settings")
    async def get_settings(request: Request):
        auth(request)
        return {
            "filter_enabled": settings.get("filter_enabled", "1"),
            "send_enabled": settings.get("send_enabled", "1"),
            "approval_mode": settings.get("approval_mode", "0"),
            "chart_enabled": settings.get("chart_enabled", "1"),
            "target_channel": settings.get("target_channel", ""),
            "message_template": settings.get("message_template", ""),
        }

    @router.put("/api/settings")
    async def update_setting(data: SettingIn, request: Request):
        auth(request)
        settings.set(data.key, data.value)
        logs.add("INFO", "api", f"Setting: {data.key}={data.value}")
        return {"status": "ok"}

    # --- logs ---

    @router.get("/api/logs")
    async def list_logs(
        request: Request,
        limit: int = Query(100, le=500),
        offset: int = Query(0, ge=0),
        level: str = Query(None),
    ):
        auth(request)
        return [l.to_dict() for l in logs.get_many(limit, offset, level)]

    # --- market ---

    @router.get("/api/market/prices")
    async def market_prices(request: Request, pairs: str = Query("")):
        auth(request)
        pair_list = [p.strip() for p in pairs.split(",") if p.strip()] if pairs else None
        data = await market.get_prices(pair_list)
        return [d.to_dict() for d in data]

    @router.get("/api/market/calendar")
    async def market_calendar(request: Request):
        auth(request)
        events = await market.get_calendar()
        return [e.to_dict() for e in events]

    @router.get("/api/market/sentiment")
    async def market_sentiment(request: Request, pairs: str = Query("")):
        auth(request)
        pair_list = [p.strip() for p in pairs.split(",") if p.strip()] or [
            "EURUSD", "GBPUSD", "USDJPY", "XAUUSD", "BTCUSD",
        ]
        results = []
        for pair in pair_list:
            s = await market.get_sentiment(pair)
            if s:
                results.append(s.to_dict())
        return results

    # --- public ---

    @router.get("/api/public/signals")
    async def public_signals(limit: int = Query(20, le=50)):
        return [
            {
                "id": s.id, "pair": s.pair, "direction": s.direction,
                "entry_price": s.entry_price, "tp1": s.tp1, "tp2": s.tp2,
                "tp3": s.tp3, "sl": s.sl, "status": s.status,
                "created_at": s.created_at,
            }
            for s in signals.get_many(limit)
        ]

    @router.get("/api/public/prices")
    async def public_prices():
        data = await market.get_prices()
        return [d.to_dict() for d in data]

    # --- bot texts ---

    @router.get("/api/texts")
    async def get_texts(request: Request):
        auth(request)
        keys = [
            "welcome_fa", "welcome_en", "welcome_tr",
            "subscribed_fa", "subscribed_en", "subscribed_tr",
            "help_fa", "help_en", "help_tr",
            "signal_footer", "channel_cta",
            "bot_username", "channel_username",
            "channel_signal_header", "channel_signal_footer",
            "daily_summary_footer",
        ]
        return {k: settings.get(k, "") for k in keys}

    @router.put("/api/texts")
    async def update_texts(data: TextsIn, request: Request):
        auth(request)
        for k, v in data.texts.items():
            settings.set(k, v)
        logs.add("INFO", "api", "Bot texts updated")
        return {"status": "ok"}

    # --- channel management ---

    @router.post("/api/channel/send")
    async def channel_send(data: ChannelMessageIn, request: Request):
        auth(request)
        ch = settings.get("target_channel", "")
        if not ch:
            raise HTTPException(400, "No target channel set")
        if web_server:
            await web_server.send_to_channel(data.text)
        logs.add("INFO", "api", f"Channel message sent to {ch}")
        return {"status": "sent", "channel": ch}

    return router
