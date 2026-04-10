"""Entry point — boots the entire application."""
import asyncio
import logging
import signal
from logging.handlers import RotatingFileHandler

from app.config import Config
from app.application import Application

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        RotatingFileHandler(
            "bot.log", encoding="utf-8",
            maxBytes=10 * 1024 * 1024,  # 10 MB
            backupCount=5,
        ),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger("main")


def main() -> None:
    config = Config.from_env()
    app = Application(config)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    shutdown_event = asyncio.Event()

    async def _run():
        try:
            await app.start()
        except asyncio.CancelledError:
            pass
        finally:
            logger.info("Shutting down...")
            await app.stop()
            logger.info("Shutdown complete")

    def _signal_handler():
        logger.info("Received shutdown signal")
        for task in asyncio.all_tasks(loop):
            task.cancel()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, _signal_handler)

    try:
        loop.run_until_complete(_run())
    except KeyboardInterrupt:
        logger.info("Stopped by user")
    finally:
        loop.close()


if __name__ == "__main__":
    main()
