#!/usr/bin/env python3
"""Fetch subscription emails from Gmail and store subscribers encrypted."""

import email
import hashlib
import html
import imaplib
import json
import os
import re
import sys
from datetime import datetime, timezone
from email.header import decode_header
from email.utils import parsedate_to_datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from subscription_crypto import SUBSCRIBERS_FILE, load_subscribers, save_subscribers

EMAIL = (os.environ.get("BLOG_EMAIL") or "").strip()
RAW_PASSWORD = (os.environ.get("BLOG_EMAIL_PASSWORD") or "").strip()
PASSWORD = re.sub(r"[\s\u200b\u200c\u200d\ufeff]+", "", RAW_PASSWORD)
IMAP_SERVER = os.environ.get("BLOG_IMAP_SERVER", "imap.gmail.com").strip()
IMAP_PORT = int(os.environ.get("BLOG_IMAP_PORT", "993"))
BOOTSTRAP_SINCE = os.environ.get("BLOG_SUBSCRIBERS_BOOTSTRAP_SINCE", "01-Jan-2026").strip()
STATE_FILE = Path(".github/subscribers_state.json")
LOCAL_TZ = ZoneInfo("Asia/Shanghai")
VALID_TYPES = {"长文", "短文", "both"}


def decode_mime(value):
    if value is None:
        return ""
    result = []
    for part, charset in decode_header(value):
        if isinstance(part, bytes):
            result.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            result.append(str(part))
    return "".join(result)


def strip_html(value):
    text = re.sub(r"(?i)<\s*br\s*/?\s*>", "\n", value)
    text = re.sub(r"(?i)</\s*p\s*>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    return html.unescape(text)


def decode_part(part):
    payload = part.get_payload(decode=True)
    if not payload:
        return ""
    charset = part.get_content_charset() or "utf-8"
    return payload.decode(charset, errors="replace")


def extract_text_body(msg):
    html_body = ""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_maintype() == "multipart":
                continue
            if part.get_content_disposition() == "attachment":
                continue
            content_type = part.get_content_type()
            if content_type == "text/plain":
                return decode_part(part)
            if content_type == "text/html" and not html_body:
                html_body = decode_part(part)
        return strip_html(html_body) if html_body else ""
    if msg.get_content_type() == "text/html":
        return strip_html(decode_part(msg))
    return decode_part(msg)


def load_json(path, fallback):
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return fallback


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def ensure_encrypted_store(subscribers):
    if not SUBSCRIBERS_FILE.exists():
        save_subscribers(subscribers)
        print("💾 已初始化加密订阅者列表")


def parse_fields(body):
    fields = {}
    pattern = re.compile(r"^(订阅邮箱|文章类型)[:：]\s*(.*)$")
    for raw_line in body.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw_line.strip()
        if line.startswith(">") or re.match(r"^(发件人|From|On .+ wrote):", line):
            break
        match = pattern.match(line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def normalize_type(value):
    value = (value or "both").strip()
    if value.lower() in {"both", "all", "全部"}:
        return "both"
    return value if value in VALID_TYPES else "both"


def normalize_email(value):
    value = (value or "").strip().lower()
    return value if re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", value) else ""


def message_time(msg):
    parsed = None
    if msg.get("Date"):
        try:
            parsed = parsedate_to_datetime(msg.get("Date"))
        except (TypeError, ValueError):
            parsed = None
    if parsed is None:
        parsed = datetime.now(timezone.utc)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(LOCAL_TZ).isoformat()


def subscriber_id(address):
    return hashlib.sha256(address.encode("utf-8")).hexdigest()[:16]


def merge_subscriber(subscribers, address, kind, timestamp):
    existing = next((item for item in subscribers if item.get("email", "").lower() == address), None)
    if existing:
        existing["type"] = kind
        existing["updated_at"] = timestamp
        return "updated"

    subscribers.append({
        "id": subscriber_id(address),
        "email": address,
        "type": kind,
        "created_at": timestamp,
        "updated_at": timestamp
    })
    return "added"


def uid_search(mail, state):
    last_uid = int(state.get("last_uid", 0) or 0)
    if last_uid > 0:
        status, data = mail.uid("search", None, "UID", f"{last_uid + 1}:*")
    else:
        status, data = mail.uid("search", None, "SINCE", BOOTSTRAP_SINCE)
    if status != "OK" or not data or not data[0]:
        return []
    return [uid for uid in data[0].split() if int(uid) > last_uid]


def fetch_message(mail, uid):
    status, data = mail.uid("fetch", uid, "(RFC822)")
    if status != "OK" or not data or not data[0]:
        return None
    return email.message_from_bytes(data[0][1])


def main():
    if not EMAIL or not PASSWORD:
        print("❌ BLOG_EMAIL 或 BLOG_EMAIL_PASSWORD 未设置")
        sys.exit(1)
    if not (os.environ.get("SUBSCRIBERS_ENCRYPTION_KEY") or "").strip():
        print("⏭️ SUBSCRIBERS_ENCRYPTION_KEY 未设置，跳过订阅者抓取")
        return

    subscribers = load_subscribers()
    ensure_encrypted_store(subscribers)
    state = load_json(STATE_FILE, {"last_uid": 0})

    try:
        mail = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
        mail.login(EMAIL, PASSWORD)
        mail.select("INBOX")

        uids = uid_search(mail, state)
        if not uids:
            print("📭 没有新的订阅邮件")
            mail.logout()
            return

        changed = False
        max_uid = int(state.get("last_uid", 0) or 0)
        for uid in uids:
            max_uid = max(max_uid, int(uid))
            msg = fetch_message(mail, uid)
            if msg is None:
                continue
            subject = decode_mime(msg.get("Subject"))
            if not subject.startswith("[订阅]"):
                continue

            fields = parse_fields(extract_text_body(msg))
            address = normalize_email(fields.get("订阅邮箱"))
            kind = normalize_type(fields.get("文章类型"))
            if not address:
                print(f"  ⚠️ 跳过无效订阅邮件: {subject}")
                continue

            action = merge_subscriber(subscribers, address, kind, message_time(msg))
            print(f"  ✅ {action}: {address[:2]}*** -> {kind}")
            changed = True

        state["last_uid"] = max_uid
        state["updated_at"] = datetime.now(timezone.utc).isoformat()
        save_json(STATE_FILE, state)

        if changed:
            subscribers.sort(key=lambda item: item.get("email", ""))
            save_subscribers(subscribers)
            print("💾 已加密保存订阅者列表")
        else:
            print("📭 没有可写入的新订阅")

        mail.logout()
    except imaplib.IMAP4.error as error:
        print(f"❌ IMAP 错误: {error}")
        sys.exit(1)
    except Exception as error:
        print(f"❌ 错误: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
