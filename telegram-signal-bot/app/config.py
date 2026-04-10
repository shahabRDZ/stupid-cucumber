import os
import sys
from dataclasses import dataclass
from dotenv import load_dotenv

from app.auth import hash_password, init_secret


@dataclass(frozen=True)
class Config:
    api_id: int
    api_hash: str
    bot_token: str
    phone: str
    admin_ids: list[int]
    password_hash: str
    db_path: str
    web_port: int
    default_channels: list[str]

    @classmethod
    def from_env(cls, env_path=None) -> "Config":
        load_dotenv(env_path)

        api_id = int(os.getenv("API_ID", "0"))
        api_hash = os.getenv("API_HASH", "")
        bot_token = os.getenv("BOT_TOKEN", "")

        # validate critical config
        missing = []
        if api_id <= 0:
            missing.append("API_ID")
        if not api_hash:
            missing.append("API_HASH")
        if not bot_token:
            missing.append("BOT_TOKEN")
        if missing:
            print(f"FATAL: Missing required env vars: {', '.join(missing)}", file=sys.stderr)
            print("Copy .env.example to .env and fill in values.", file=sys.stderr)
            sys.exit(1)

        raw_admins = os.getenv("ADMIN_IDS", os.getenv("ADMIN_ID", "0"))
        raw_channels = os.getenv("SOURCE_CHANNELS", "")
        plain_password = os.getenv("ADMIN_PASSWORD", "")
        if not plain_password or plain_password in ("admin123", "123456", "password"):
            print("WARNING: Set a strong ADMIN_PASSWORD in .env!", file=sys.stderr)
            if not plain_password:
                plain_password = "admin123"

        pwd_hash = hash_password(plain_password)
        init_secret(pwd_hash)

        return cls(
            api_id=api_id,
            api_hash=api_hash,
            bot_token=bot_token,
            phone=os.getenv("PHONE", ""),
            admin_ids=[int(x) for x in raw_admins.split(",") if x.strip()],
            password_hash=pwd_hash,
            db_path=os.getenv("DB_PATH", "bot_data.db"),
            web_port=int(os.getenv("WEB_PORT", "8000")),
            default_channels=[ch.strip() for ch in raw_channels.split(",") if ch.strip()],
        )
