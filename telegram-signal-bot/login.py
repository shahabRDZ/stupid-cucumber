import asyncio
import os
import sys
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()
API_ID = int(os.getenv("API_ID"))
API_HASH = os.getenv("API_HASH")
PHONE = os.getenv("PHONE")
VERIFY_CODE = os.getenv("VERIFY_CODE")

async def main():
    client = TelegramClient("user_session", API_ID, API_HASH)
    await client.connect()

    if not await client.is_user_authorized():
        print(f"Sending code to {PHONE}...")
        await client.send_code_request(PHONE)
        print(f"Signing in with code: {VERIFY_CODE}")
        try:
            await client.sign_in(PHONE, VERIFY_CODE)
        except Exception as e:
            print(f"Error: {e}")
            await client.disconnect()
            sys.exit(1)

    me = await client.get_me()
    print(f"Logged in as: {me.first_name} (ID: {me.id})")
    await client.disconnect()
    print("Session saved! You can now run bot.py")

asyncio.run(main())
