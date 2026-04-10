"""Authentication: bcrypt password hashing, JWT tokens, rate limiting."""
import hashlib
import time
from collections import defaultdict

import bcrypt
import jwt

JWT_SECRET_KEY = None  # set at startup from hashed password
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_SECONDS = 3600 * 8  # 8 hours


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_token(password_hash: str) -> str:
    payload = {
        "sub": hashlib.sha256(password_hash.encode()).hexdigest()[:16],
        "iat": int(time.time()),
        "exp": int(time.time()) + JWT_EXPIRE_SECONDS,
    }
    return jwt.encode(payload, _get_secret(), algorithm=JWT_ALGORITHM)


def verify_token(token: str) -> bool:
    try:
        jwt.decode(token, _get_secret(), algorithms=[JWT_ALGORITHM])
        return True
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return False


def _get_secret() -> str:
    if not JWT_SECRET_KEY:
        raise RuntimeError("JWT secret not initialized — call init_secret() first")
    return JWT_SECRET_KEY


def init_secret(password_hash: str) -> None:
    global JWT_SECRET_KEY
    JWT_SECRET_KEY = hashlib.sha256(password_hash.encode()).hexdigest()


# --- Rate limiter ---

class RateLimiter:
    """Simple in-memory rate limiter per IP."""

    def __init__(self, max_attempts: int = 5, window_seconds: int = 60) -> None:
        self._max = max_attempts
        self._window = window_seconds
        self._attempts: dict[str, list[float]] = defaultdict(list)

    def is_allowed(self, key: str) -> bool:
        now = time.time()
        attempts = self._attempts[key]
        # clean old entries
        self._attempts[key] = [t for t in attempts if now - t < self._window]
        if len(self._attempts[key]) >= self._max:
            return False
        self._attempts[key].append(now)
        return True

    def remaining(self, key: str) -> int:
        now = time.time()
        recent = [t for t in self._attempts[key] if now - t < self._window]
        return max(0, self._max - len(recent))
