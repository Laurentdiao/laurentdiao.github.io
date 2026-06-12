#!/usr/bin/env python3
"""Shared helpers for encrypted email subscriber storage."""

import base64
import hashlib
import json
import os
from pathlib import Path

from cryptography.fernet import Fernet

SUBSCRIBERS_FILE = Path(".github/subscribers.enc")


def cipher():
    raw = (os.environ.get("SUBSCRIBERS_ENCRYPTION_KEY") or "").strip()
    if not raw:
        raise RuntimeError("SUBSCRIBERS_ENCRYPTION_KEY is not set")
    digest = hashlib.sha256(raw.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


def load_subscribers():
    if not SUBSCRIBERS_FILE.exists():
        return []
    token = SUBSCRIBERS_FILE.read_bytes()
    plaintext = cipher().decrypt(token)
    return json.loads(plaintext.decode("utf-8"))


def save_subscribers(subscribers):
    plaintext = json.dumps(subscribers, ensure_ascii=False, sort_keys=True, indent=2).encode("utf-8")
    token = cipher().encrypt(plaintext)
    SUBSCRIBERS_FILE.parent.mkdir(parents=True, exist_ok=True)
    SUBSCRIBERS_FILE.write_bytes(token + b"\n")
