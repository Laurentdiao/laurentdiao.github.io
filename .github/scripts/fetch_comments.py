#!/usr/bin/env python3
"""
邮件评论抓取脚本
从收件箱中提取 [评论] 邮件, 更新 comments.json
运行于 GitHub Actions
"""

import imaplib
import email
from email.header import decode_header
import json
import os
import re
import sys
from datetime import datetime

# 配置 (从 GitHub Secrets 获取)
EMAIL = os.environ.get("BLOG_EMAIL")
PASSWORD = os.environ.get("BLOG_EMAIL_PASSWORD")
IMAP_SERVER = os.environ.get("BLOG_IMAP_SERVER", "outlook.office365.com")
IMAP_PORT = int(os.environ.get("BLOG_IMAP_PORT", "993"))
COMMENTS_FILE = "source/data/comments.json"

def decode_mime(s):
    """解码 MIME 标题"""
    if s is None:
        return ""
    parts = decode_header(s)
    result = []
    for part, charset in parts:
        if isinstance(part, bytes):
            result.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            result.append(str(part))
    return "".join(result)

def parse_comment_body(body):
    """从邮件正文提取 用户名 和 评论内容"""
    user = "匿名"
    content_lines = []
    in_content = False

    for raw_line in body.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw_line.strip()

        user_match = re.match(r"^用户名[:：]\s*(.*)$", line)
        if user_match:
            user = user_match.group(1).strip() or "匿名"
            in_content = False
            continue

        content_match = re.match(r"^评论内容[:：]\s*(.*)$", line)
        if content_match:
            in_content = True
            first_line = content_match.group(1).strip()
            if first_line:
                content_lines.append(first_line)
            continue

        if in_content:
            if line.startswith(">") or re.match(r"^(发件人|From|On .+ wrote):", line):
                break
            content_lines.append(raw_line.rstrip())

    content = "\n".join(content_lines).strip()
    return user, content

def parse_article_title(subject):
    """从邮件标题提取文章名"""
    # 格式: [评论] 文章标题
    match = re.search(r"\[评论\]\s*(.+)", subject)
    return match.group(1).strip() if match else None

def load_comments():
    """加载现有评论"""
    if os.path.exists(COMMENTS_FILE):
        with open(COMMENTS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def decode_part(part):
    """按邮件声明的 charset 解码正文片段"""
    payload = part.get_payload(decode=True)
    if not payload:
        return ""
    charset = part.get_content_charset() or "utf-8"
    return payload.decode(charset, errors="replace")

def extract_text_body(msg):
    """优先提取 text/plain 正文"""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_maintype() == "multipart":
                continue
            if part.get_content_disposition() == "attachment":
                continue
            if part.get_content_type() == "text/plain":
                return decode_part(part)
        return ""
    return decode_part(msg)

def save_comments(comments):
    """保存评论"""
    os.makedirs(os.path.dirname(COMMENTS_FILE), exist_ok=True)
    with open(COMMENTS_FILE, "w", encoding="utf-8") as f:
        json.dump(comments, f, ensure_ascii=False, indent=2)

def main():
    if not EMAIL or not PASSWORD:
        print("❌ 环境变量 BLOG_EMAIL 或 BLOG_EMAIL_PASSWORD 未设置")
        sys.exit(1)

    try:
        mail = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
        mail.login(EMAIL, PASSWORD)
        mail.select("INBOX")

        # 只在 IMAP 里搜索 ASCII 条件；中文标题在 Python 中解析，避免编码兼容问题。
        status, messages = mail.search(None, "UNSEEN")
        if status != "OK" or not messages[0]:
            print("📭 没有新的评论邮件")
            mail.logout()
            return

        msg_ids = messages[0].split()
        print(f"📬 找到 {len(msg_ids)} 封未读邮件，开始筛选评论")

        comments = load_comments()
        updated = False

        for msg_id in msg_ids:
            status, data = mail.fetch(msg_id, "(RFC822)")
            if status != "OK":
                continue

            raw = data[0][1]
            msg = email.message_from_bytes(raw)

            subject = decode_mime(msg["Subject"])
            article = parse_article_title(subject)
            if not article:
                continue

            # 提取正文
            body = extract_text_body(msg)

            user, content = parse_comment_body(body)
            if not content:
                print(f"  ⚠️ [{article}] 没有找到评论内容")
                mail.store(msg_id, "+FLAGS", "\\Seen")
                continue

            # 使用文章标题作为 key
            date_str = datetime.now().strftime("%Y-%m-%d %H:%M")

            if article not in comments:
                comments[article] = []

            comments[article].append({
                "user": user,
                "content": content,
                "date": date_str
            })

            print(f"  ✅ [{article}] {user}: {content[:50]}...")
            updated = True

            # 标记为已读
            mail.store(msg_id, "+FLAGS", "\\Seen")

        mail.logout()

        if updated:
            save_comments(comments)
            print(f"💾 已保存到 {COMMENTS_FILE}")

    except Exception as e:
        print(f"❌ 错误: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
