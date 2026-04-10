"""Entry point — boots the entire application."""
import asyncio
import logging

from app.config import Config
from app.application import Application

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.FileHandler("bot.log", encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger("main")


def main() -> None:
    config = Config.from_env()
    app = Application(config)
    try:
        asyncio.run(app.start())
    except KeyboardInterrupt:
        logger.info("Stopped by user")
    except Exception as exc:
        logger.error(f"Fatal: {exc}", exc_info=True)


if __name__ == "__main__":
    main()
