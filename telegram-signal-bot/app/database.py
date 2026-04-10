from __future__ import annotations

import hashlib
import logging
import sqlite3
from contextlib import contextmanager
from typing import Iterator

from app.models import (
    Channel, DashboardStats, LogEntry, ParsedSignal,
    PriceAlert, RawMessage, Signal, Subscriber,
)

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
#  Database connection manager
# ──────────────────────────────────────────────

class Database:
    """Thin wrapper around SQLite for connection management."""

    def __init__(self, path: str) -> None:
        self._path = path

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    @contextmanager
    def session(self) -> Iterator[sqlite3.Connection]:
        conn = self._connect()
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()

    def init_schema(self) -> None:
        with self.session() as conn:
            conn.executescript(_SCHEMA_SQL)
            for key, value in _DEFAULT_SETTINGS.items():
                conn.execute(
                    "INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)",
                    (key, value),
                )
        logger.info("Database schema initialized")


_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS raw_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_username TEXT,
    channel_title TEXT,
    message_id INTEGER,
    text TEXT,
    media_type TEXT,
    hash TEXT UNIQUE,
    is_signal BOOLEAN DEFAULT 0,
    processed BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS signals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_message_id INTEGER REFERENCES raw_messages(id),
    pair TEXT,
    direction TEXT,
    entry_price TEXT,
    tp1 TEXT, tp2 TEXT, tp3 TEXT,
    sl TEXT,
    raw_text TEXT,
    formatted_text TEXT,
    status TEXT DEFAULT 'active',
    sent_to_bot BOOLEAN DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS channels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    title TEXT,
    is_active BOOLEAN DEFAULT 1,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS subscribers (
    chat_id INTEGER PRIMARY KEY,
    username TEXT,
    first_name TEXT,
    lang TEXT DEFAULT 'en',
    is_active BOOLEAN DEFAULT 1,
    is_admin BOOLEAN DEFAULT 0,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level TEXT,
    source TEXT,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS price_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id INTEGER,
    pair TEXT,
    target_price REAL,
    direction TEXT DEFAULT 'above',
    is_active BOOLEAN DEFAULT 1,
    triggered BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    triggered_at TIMESTAMP
);
"""

_DEFAULT_SETTINGS = {
    "filter_enabled": "1",
    "send_enabled": "1",
    "message_template": "━━━━━━━━━━━━━━━━━━━━\n{signal}\n━━━━━━━━━━━━━━━━━━━━\n📡 Signal Bot",
}


# ──────────────────────────────────────────────
#  Base repository
# ──────────────────────────────────────────────

class BaseRepository:
    """Shared DB access for all repositories."""

    def __init__(self, db: Database) -> None:
        self._db = db


# ──────────────────────────────────────────────
#  Channel repository
# ──────────────────────────────────────────────

class ChannelRepository(BaseRepository):

    def get_all(self, active_only: bool = False) -> list[Channel]:
        with self._db.session() as conn:
            sql = "SELECT * FROM channels"
            if active_only:
                sql += " WHERE is_active=1"
            sql += " ORDER BY added_at DESC"
            return [Channel(**dict(r)) for r in conn.execute(sql).fetchall()]

    def get_active_usernames(self) -> list[str]:
        return [ch.username for ch in self.get_all(active_only=True)]

    def add(self, username: str, title: str = "") -> None:
        username = username.lstrip("@").strip()
        with self._db.session() as conn:
            conn.execute(
                "INSERT OR IGNORE INTO channels (username, title) VALUES (?, ?)",
                (username, title or username),
            )

    def remove(self, username: str) -> None:
        username = username.lstrip("@").strip()
        with self._db.session() as conn:
            conn.execute("DELETE FROM channels WHERE username=?", (username,))

    def toggle(self, username: str, active: bool) -> None:
        username = username.lstrip("@").strip()
        with self._db.session() as conn:
            conn.execute(
                "UPDATE channels SET is_active=? WHERE username=?",
                (1 if active else 0, username),
            )


# ──────────────────────────────────────────────
#  Message repository
# ──────────────────────────────────────────────

class MessageRepository(BaseRepository):

    @staticmethod
    def _hash(text: str, channel: str, msg_id: int) -> str:
        return hashlib.sha256(f"{channel}:{msg_id}:{text}".encode()).hexdigest()

    def save(
        self,
        channel_username: str,
        channel_title: str,
        message_id: int,
        text: str,
        media_type: str | None = None,
        is_signal: bool = False,
    ) -> int | None:
        h = self._hash(text or "", channel_username, message_id)
        with self._db.session() as conn:
            try:
                cur = conn.execute(
                    """INSERT INTO raw_messages
                       (channel_username, channel_title, message_id, text,
                        media_type, hash, is_signal)
                       VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (channel_username, channel_title, message_id,
                     text, media_type, h, is_signal),
                )
                return cur.lastrowid
            except sqlite3.IntegrityError:
                return None  # duplicate

    def get_many(self, limit: int = 50, offset: int = 0) -> list[RawMessage]:
        with self._db.session() as conn:
            rows = conn.execute(
                "SELECT * FROM raw_messages ORDER BY created_at DESC LIMIT ? OFFSET ?",
                (limit, offset),
            ).fetchall()
            return [RawMessage(**dict(r)) for r in rows]

    def count(self) -> int:
        with self._db.session() as conn:
            return conn.execute("SELECT COUNT(*) AS c FROM raw_messages").fetchone()["c"]


# ──────────────────────────────────────────────
#  Signal repository
# ──────────────────────────────────────────────

class SignalRepository(BaseRepository):

    def save(
        self,
        raw_message_id: int,
        parsed: ParsedSignal,
        raw_text: str,
        formatted_text: str,
    ) -> int:
        with self._db.session() as conn:
            cur = conn.execute(
                """INSERT INTO signals
                   (raw_message_id, pair, direction, entry_price,
                    tp1, tp2, tp3, sl, raw_text, formatted_text)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (raw_message_id, parsed.pair, parsed.direction, parsed.entry,
                 parsed.tp1, parsed.tp2, parsed.tp3, parsed.sl,
                 raw_text, formatted_text),
            )
            return cur.lastrowid

    def get_many(
        self, limit: int = 50, offset: int = 0, status: str | None = None,
    ) -> list[Signal]:
        with self._db.session() as conn:
            if status:
                rows = conn.execute(
                    "SELECT * FROM signals WHERE status=? ORDER BY created_at DESC LIMIT ? OFFSET ?",
                    (status, limit, offset),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM signals ORDER BY created_at DESC LIMIT ? OFFSET ?",
                    (limit, offset),
                ).fetchall()
            return [Signal(**dict(r)) for r in rows]

    def count(self) -> int:
        with self._db.session() as conn:
            return conn.execute("SELECT COUNT(*) AS c FROM signals").fetchone()["c"]

    def mark_sent(self, signal_id: int, sent_count: int) -> None:
        with self._db.session() as conn:
            conn.execute(
                "UPDATE signals SET sent_to_bot=1, sent_count=? WHERE id=?",
                (sent_count, signal_id),
            )


# ──────────────────────────────────────────────
#  Subscriber repository
# ──────────────────────────────────────────────

class SubscriberRepository(BaseRepository):

    def upsert(
        self, chat_id: int, username: str | None = None, first_name: str | None = None,
    ) -> None:
        with self._db.session() as conn:
            conn.execute(
                """INSERT INTO subscribers (chat_id, username, first_name, is_active)
                   VALUES (?, ?, ?, 1)
                   ON CONFLICT(chat_id) DO UPDATE SET
                   username=excluded.username, first_name=excluded.first_name, is_active=1""",
                (chat_id, username, first_name),
            )

    def deactivate(self, chat_id: int) -> None:
        with self._db.session() as conn:
            conn.execute("UPDATE subscribers SET is_active=0 WHERE chat_id=?", (chat_id,))

    def get_active(self) -> list[Subscriber]:
        with self._db.session() as conn:
            rows = conn.execute(
                "SELECT * FROM subscribers WHERE is_active=1",
            ).fetchall()
            return [Subscriber(**dict(r)) for r in rows]

    def get_all(self) -> list[Subscriber]:
        with self._db.session() as conn:
            rows = conn.execute(
                "SELECT * FROM subscribers ORDER BY joined_at DESC",
            ).fetchall()
            return [Subscriber(**dict(r)) for r in rows]

    def count(self) -> tuple[int, int]:
        with self._db.session() as conn:
            total = conn.execute("SELECT COUNT(*) AS c FROM subscribers").fetchone()["c"]
            active = conn.execute(
                "SELECT COUNT(*) AS c FROM subscribers WHERE is_active=1",
            ).fetchone()["c"]
            return total, active

    def is_admin(self, chat_id: int) -> bool:
        with self._db.session() as conn:
            row = conn.execute(
                "SELECT is_admin FROM subscribers WHERE chat_id=?", (chat_id,),
            ).fetchone()
            return bool(row and row["is_admin"])

    def set_admin(self, chat_id: int) -> None:
        with self._db.session() as conn:
            conn.execute(
                """INSERT INTO subscribers (chat_id, is_admin, is_active)
                   VALUES (?, 1, 1)
                   ON CONFLICT(chat_id) DO UPDATE SET is_admin=1""",
                (chat_id,),
            )

    def get_lang(self, chat_id: int) -> str:
        with self._db.session() as conn:
            row = conn.execute(
                "SELECT lang FROM subscribers WHERE chat_id=?", (chat_id,),
            ).fetchone()
            return row["lang"] if row else "en"

    def set_lang(self, chat_id: int, lang: str) -> None:
        with self._db.session() as conn:
            conn.execute("UPDATE subscribers SET lang=? WHERE chat_id=?", (lang, chat_id))


# ──────────────────────────────────────────────
#  Settings repository
# ──────────────────────────────────────────────

class SettingsRepository(BaseRepository):

    def get(self, key: str, default: str | None = None) -> str | None:
        with self._db.session() as conn:
            row = conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
            return row["value"] if row else default

    def set(self, key: str, value: str) -> None:
        with self._db.session() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                (key, str(value)),
            )

    @property
    def filter_enabled(self) -> bool:
        return self.get("filter_enabled", "1") == "1"

    @property
    def send_enabled(self) -> bool:
        return self.get("send_enabled", "1") == "1"

    @property
    def message_template(self) -> str | None:
        return self.get("message_template")


# ──────────────────────────────────────────────
#  Log repository
# ──────────────────────────────────────────────

class LogRepository(BaseRepository):

    def add(self, level: str, source: str, message: str) -> None:
        with self._db.session() as conn:
            conn.execute(
                "INSERT INTO logs (level, source, message) VALUES (?, ?, ?)",
                (level, source, message),
            )

    def get_many(
        self, limit: int = 100, offset: int = 0, level: str | None = None,
    ) -> list[LogEntry]:
        with self._db.session() as conn:
            if level:
                rows = conn.execute(
                    "SELECT * FROM logs WHERE level=? ORDER BY created_at DESC LIMIT ? OFFSET ?",
                    (level, limit, offset),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM logs ORDER BY created_at DESC LIMIT ? OFFSET ?",
                    (limit, offset),
                ).fetchall()
            return [LogEntry(**dict(r)) for r in rows]

    def count(self) -> int:
        with self._db.session() as conn:
            return conn.execute("SELECT COUNT(*) AS c FROM logs").fetchone()["c"]


# ──────────────────────────────────────────────
#  Stats (reads across repositories)
# ──────────────────────────────────────────────

class StatsRepository(BaseRepository):

    def dashboard(self) -> DashboardStats:
        with self._db.session() as conn:
            total = conn.execute("SELECT COUNT(*) AS c FROM subscribers").fetchone()["c"]
            active = conn.execute(
                "SELECT COUNT(*) AS c FROM subscribers WHERE is_active=1",
            ).fetchone()["c"]
            return DashboardStats(
                total_subscribers=total,
                active_subscribers=active,
                total_signals=conn.execute(
                    "SELECT COUNT(*) AS c FROM signals",
                ).fetchone()["c"],
                total_raw_messages=conn.execute(
                    "SELECT COUNT(*) AS c FROM raw_messages",
                ).fetchone()["c"],
                active_channels=conn.execute(
                    "SELECT COUNT(*) AS c FROM channels WHERE is_active=1",
                ).fetchone()["c"],
                signals_today=conn.execute(
                    "SELECT COUNT(*) AS c FROM signals WHERE date(created_at)=date('now')",
                ).fetchone()["c"],
                send_enabled=conn.execute(
                    "SELECT value FROM settings WHERE key='send_enabled'",
                ).fetchone()["value"] == "1",
                filter_enabled=conn.execute(
                    "SELECT value FROM settings WHERE key='filter_enabled'",
                ).fetchone()["value"] == "1",
            )


# ──────────────────────────────────────────────
#  Alert repository
# ──────────────────────────────────────────────

class AlertRepository(BaseRepository):

    def create(self, chat_id: int, pair: str, target_price: float, direction: str) -> int:
        with self._db.session() as conn:
            cur = conn.execute(
                """INSERT INTO price_alerts (chat_id, pair, target_price, direction)
                   VALUES (?, ?, ?, ?)""",
                (chat_id, pair.upper(), target_price, direction),
            )
            return cur.lastrowid

    def get_by_user(self, chat_id: int) -> list[PriceAlert]:
        with self._db.session() as conn:
            rows = conn.execute(
                "SELECT * FROM price_alerts WHERE chat_id=? AND is_active=1 ORDER BY created_at DESC",
                (chat_id,),
            ).fetchall()
            return [PriceAlert(**dict(r)) for r in rows]

    def get_active(self) -> list[PriceAlert]:
        with self._db.session() as conn:
            rows = conn.execute(
                "SELECT * FROM price_alerts WHERE is_active=1 AND triggered=0",
            ).fetchall()
            return [PriceAlert(**dict(r)) for r in rows]

    def mark_triggered(self, alert_id: int) -> None:
        with self._db.session() as conn:
            conn.execute(
                "UPDATE price_alerts SET triggered=1, is_active=0, triggered_at=CURRENT_TIMESTAMP WHERE id=?",
                (alert_id,),
            )

    def delete(self, alert_id: int, chat_id: int) -> bool:
        with self._db.session() as conn:
            cur = conn.execute(
                "DELETE FROM price_alerts WHERE id=? AND chat_id=?",
                (alert_id, chat_id),
            )
            return cur.rowcount > 0
