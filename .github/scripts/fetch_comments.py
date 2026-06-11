#!/usr/bin/env python3
"""
Fetch email comments and replies into source/data/comments.json.
"""

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
from zoneinfo import ZoneInfo

EMAIL = (os.environ.get("BLOG_EMAIL") or "").strip()
RAW_PASSWORD = (os.environ.get("BLOG_EMAIL_PASSWORD") or "").strip()
PASSWORD = RAW_PASSWORD.replace(" ", "")
IMAP_SERVER = os.environ.get("BLOG_IMAP_SERVER", "outlook.office365.com").strip()
IMAP_PORT = int(os.environ.get("BLOG_IMAP_PORT", "993"))
BOOTSTRAP_SINCE = os.environ.get("BLOG_COMMENTS_BOOTSTRAP_SINCE", "01-Jan-2026").strip()

COMMENTS_FILE = "source/data/comments.json"
STATE_FILE = ".github/comments_state.json"
LOCAL_TZ = ZoneInfo("Asia/Shanghai")


def decode_mime(value):
    if value is None:
        return ""

    parts = decode_header(value)
    result = []
    for part, charset in parts:
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


def parse_subject(subject):
    match = re.search(r"\[(评论|回复)\]\s*(.+)", subject)
    if not match:
        return None, None
    return match.group(1), match.group(2).strip()


def parse_template_fields(body):
    fields = {}
    active_key = None
    active_lines = []

    field_names = ("文章", "回复给", "回复ID", "用户名", "评论内容", "回复内容")
    pattern = re.compile(r"^(" + "|".join(field_names) + r")[:：]\s*(.*)$")

    def flush():
        if active_key:
            fields[active_key] = "\n".join(active_lines).strip()

    for raw_line in body.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw_line.strip()

        if line.startswith(">") or re.match(r"^(发件人|From|On .+ wrote):", line):
            break
        if line.startswith("请不要修改") or line.startswith("只填写"):
            continue

        match = pattern.match(line)
        if match:
            flush()
            active_key = match.group(1)
            first_value = match.group(2).strip()
            active_lines = [first_value] if first_value else []
            continue

        if active_key in ("评论内容", "回复内容"):
            active_lines.append(raw_line.rstrip())

    flush()
    return fields


def load_json(path, fallback):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as file:
            return json.load(file)
    return fallback


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=2)
        file.write("\n")


def message_time(msg):
    parsed = None
    date_header = msg.get("Date")
    if date_header:
        try:
            parsed = parsedate_to_datetime(date_header)
        except (TypeError, ValueError):
            parsed = None

    if parsed is None:
        parsed = datetime.now(timezone.utc)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)

    local = parsed.astimezone(LOCAL_TZ)
    return local.isoformat(), local.strftime("%Y-%m-%d %H:%M")


def make_id(prefix, *parts):
    digest = hashlib.sha1("|".join(parts).encode("utf-8", errors="replace")).hexdigest()[:12]
    return f"{prefix}_{digest}"


def normalize_comments(comments):
    if not isinstance(comments, dict):
        return {}

    for article, items in list(comments.items()):
        if not isinstance(items, list):
            comments[article] = []
            continue
        for item in items:
            if not isinstance(item, dict):
                continue
            item.setdefault("id", make_id("c", article, item.get("user", ""), item.get("content", ""), item.get("date", "")))
            item.setdefault("timestamp", item.get("date", ""))
            item.setdefault("replies", [])
    return comments


def processed_ids(comments):
    seen = set()
    for items in comments.values():
        for item in items:
            if not isinstance(item, dict):
                continue
            if item.get("messageId"):
                seen.add(item["messageId"])
            if item.get("id"):
                seen.add(item["id"])
            for reply in item.get("replies", []):
                if reply.get("messageId"):
                    seen.add(reply["messageId"])
                if reply.get("id"):
                    seen.add(reply["id"])
    return seen


def find_comment(comments, reply_id):
    for items in comments.values():
        for item in items:
            if item.get("id") == reply_id:
                return item
    return None


def sort_comments(comments):
    for items in comments.values():
        items.sort(key=lambda item: item.get("timestamp", item.get("date", "")))
        for item in items:
            item.setdefault("replies", [])
            item["replies"].sort(key=lambda reply: reply.get("timestamp", reply.get("date", "")))


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


def append_comment(comments, article, fields, msg, message_id):
    user = fields.get("用户名") or "匿名"
    content = fields.get("评论内容", "").strip()
    if not content:
        return False, "没有找到评论内容"

    timestamp, date_text = message_time(msg)
    comment_id = make_id("c", message_id, article, user, content)
    comments.setdefault(article, []).append({
        "id": comment_id,
        "user": user,
        "content": content,
        "date": date_text,
        "timestamp": timestamp,
        "messageId": message_id,
        "replies": []
    })
    return True, f"{user}: {content[:50]}"


def append_reply(comments, article, fields, msg, message_id):
    reply_id = fields.get("回复ID", "").strip()
    parent = find_comment(comments, reply_id)
    if parent is None:
        return False, f"找不到回复ID {reply_id}"

    user = fields.get("用户名") or "匿名"
    content = fields.get("回复内容", "").strip()
    if not content:
        return False, "没有找到回复内容"

    timestamp, date_text = message_time(msg)
    parent.setdefault("replies", []).append({
        "id": make_id("r", message_id, article, reply_id, user, content),
        "parentId": reply_id,
        "replyTo": fields.get("回复给", parent.get("user", "")),
        "user": user,
        "content": content,
        "date": date_text,
        "timestamp": timestamp,
        "messageId": message_id
    })
    return True, f"{user} -> {parent.get('user', '匿名')}: {content[:50]}"


def auth_failed_message():
    return (
        "AUTHENTICATE failed. 请检查 GitHub Secrets 中的 BLOG_EMAIL 和 BLOG_EMAIL_PASSWORD："
        "BLOG_EMAIL 必须是完整邮箱；BLOG_EMAIL_PASSWORD 建议使用 Microsoft app password，"
        "不要使用网页登录密码；如果复制的 app password 带空格，本脚本会自动去掉空格。"
    )


def main():
    if not EMAIL or not PASSWORD:
        print("❌ 环境变量 BLOG_EMAIL 或 BLOG_EMAIL_PASSWORD 未设置")
        sys.exit(1)

    comments = normalize_comments(load_json(COMMENTS_FILE, {}))
    state = load_json(STATE_FILE, {"last_uid": 0})

    try:
        mail = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
        mail.login(EMAIL, PASSWORD)
        mail.select("INBOX")

        uids = uid_search(mail, state)
        if not uids:
            print("📭 没有新的邮件")
            mail.logout()
            return

        print(f"📬 找到 {len(uids)} 封新邮件，开始筛选评论")
        seen = processed_ids(comments)
        updated_comments = False
        max_uid = int(state.get("last_uid", 0) or 0)

        for uid in uids:
            max_uid = max(max_uid, int(uid))
            msg = fetch_message(mail, uid)
            if msg is None:
                continue

            subject = decode_mime(msg.get("Subject"))
            kind, article_from_subject = parse_subject(subject)
            if not kind:
                continue

            message_id = (msg.get("Message-ID") or f"uid-{uid.decode()}").strip()
            if message_id in seen:
                print(f"  ↩️ 已处理过: {subject}")
                continue

            body = extract_text_body(msg)
            fields = parse_template_fields(body)
            article = fields.get("文章") or article_from_subject

            if kind == "评论":
                ok, detail = append_comment(comments, article, fields, msg, message_id)
            else:
                ok, detail = append_reply(comments, article, fields, msg, message_id)

            if ok:
                print(f"  ✅ [{article}] {detail}")
                updated_comments = True
                seen.add(message_id)
            else:
                print(f"  ⚠️ [{article}] {detail}")

        state["last_uid"] = max_uid
        state["updated_at"] = datetime.now(timezone.utc).isoformat()
        save_json(STATE_FILE, state)

        if updated_comments:
            sort_comments(comments)
            save_json(COMMENTS_FILE, comments)
            print(f"💾 已保存到 {COMMENTS_FILE}")
        else:
            print("📭 没有可写入的新评论")

        mail.logout()

    except imaplib.IMAP4.error as error:
        text = str(error)
        if "AUTHENTICATE failed" in text:
            print(f"❌ {auth_failed_message()}")
        else:
            print(f"❌ IMAP 错误: {error}")
        sys.exit(1)
    except Exception as error:
        print(f"❌ 错误: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
