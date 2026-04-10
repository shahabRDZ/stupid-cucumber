from dataclasses import dataclass, field, asdict
from datetime import datetime


@dataclass
class RawMessage:
    id: int = 0
    channel_username: str = ""
    channel_title: str = ""
    message_id: int = 0
    text: str = ""
    media_type: str | None = None
    hash: str = ""
    is_signal: bool = False
    processed: bool = False
    created_at: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Signal:
    id: int = 0
    raw_message_id: int = 0
    pair: str = ""
    direction: str = ""
    entry_price: str = ""
    tp1: str = ""
    tp2: str = ""
    tp3: str = ""
    sl: str = ""
    raw_text: str = ""
    formatted_text: str = ""
    status: str = "active"
    sent_to_bot: bool = False
    sent_count: int = 0
    created_at: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Channel:
    id: int = 0
    username: str = ""
    title: str = ""
    is_active: bool = True
    added_at: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Subscriber:
    chat_id: int = 0
    username: str | None = None
    first_name: str | None = None
    lang: str = "en"
    is_active: bool = True
    is_admin: bool = False
    joined_at: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class LogEntry:
    id: int = 0
    level: str = "INFO"
    source: str = ""
    message: str = ""
    created_at: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class ParsedSignal:
    pair: str = ""
    direction: str = ""
    entry: str = ""
    tp1: str = ""
    tp2: str = ""
    tp3: str = ""
    sl: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class PriceAlert:
    id: int = 0
    chat_id: int = 0
    pair: str = ""
    target_price: float = 0.0
    direction: str = "above"  # "above" or "below"
    is_active: bool = True
    triggered: bool = False
    created_at: str = ""
    triggered_at: str | None = None

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class DashboardStats:
    total_subscribers: int = 0
    active_subscribers: int = 0
    total_signals: int = 0
    total_raw_messages: int = 0
    active_channels: int = 0
    signals_today: int = 0
    send_enabled: bool = True
    filter_enabled: bool = True

    def to_dict(self) -> dict:
        return asdict(self)
