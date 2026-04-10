import os
from dataclasses import dataclass, field
from dotenv import load_dotenv


@dataclass(frozen=True)
class Config:
    api_id: int
    api_hash: str
    bot_token: str
    phone: str
    admin_ids: list[int]
    admin_password: str
    db_path: str
    web_port: int
    default_channels: list[str]

    @classmethod
    def from_env(cls, env_path=None) -> "Config":
        load_dotenv(env_path)
        raw_admins = os.getenv("ADMIN_IDS", os.getenv("ADMIN_ID", "0"))
        raw_channels = os.getenv("SOURCE_CHANNELS", "")

        return cls(
            api_id=int(os.getenv("API_ID", "0")),
            api_hash=os.getenv("API_HASH", ""),
            bot_token=os.getenv("BOT_TOKEN", ""),
            phone=os.getenv("PHONE", ""),
            admin_ids=[int(x) for x in raw_admins.split(",") if x.strip()],
            admin_password=os.getenv("ADMIN_PASSWORD", "admin123"),
            db_path=os.getenv("DB_PATH", "bot_data.db"),
            web_port=int(os.getenv("WEB_PORT", "8000")),
            default_channels=[ch.strip() for ch in raw_channels.split(",") if ch.strip()],
        )
