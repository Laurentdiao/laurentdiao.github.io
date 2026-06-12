#!/usr/bin/env python3
"""Send Gmail notifications to encrypted subscribers for new or updated posts."""

import os
import re
import smtplib
import subprocess
import sys
from email.message import EmailMessage
from pathlib import Path

from subscription_crypto import load_subscribers

EMAIL = (os.environ.get("BLOG_EMAIL") or "").strip()
RAW_PASSWORD = (os.environ.get("BLOG_EMAIL_PASSWORD") or "").strip()
PASSWORD = re.sub(r"[\s\u200b\u200c\u200d\ufeff]+", "", RAW_PASSWORD)
SITE_URL = (os.environ.get("BLOG_SITE_URL") or "https://laurentdiao.github.io").rstrip("/")
BEFORE = (os.environ.get("BEFORE_SHA") or "").strip()
AFTER = (os.environ.get("AFTER_SHA") or "HEAD").strip()
VALID_TYPES = {"长文", "短文"}


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def changed_posts():
    if not BEFORE or re.fullmatch(r"0+", BEFORE):
        diff_range = f"{AFTER}~1..{AFTER}"
    else:
        diff_range = f"{BEFORE}..{AFTER}"

    try:
        output = git("diff", "--name-only", "--diff-filter=A", diff_range, "--", "source/_posts")
    except subprocess.CalledProcessError:
        output = git("diff", "--name-only", "--diff-filter=A", "HEAD~1..HEAD", "--", "source/_posts")

    return [Path(line) for line in output.splitlines() if line.endswith(".md")]


def parse_front_matter(markdown):
    if not markdown.startswith("---\n"):
        return {}, markdown
    end = markdown.find("\n---", 4)
    if end == -1:
        return {}, markdown
    front = markdown[4:end]
    body_start = end + 4
    if body_start < len(markdown) and markdown[body_start] == "\n":
        body_start += 1

    data = {}
    active_key = None
    for line in front.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") and active_key:
            data.setdefault(active_key, []).append(stripped[2:].strip().strip("'\""))
            continue
        active_key = None
        if ":" not in stripped:
            continue
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        if value:
            data[key] = value
        else:
            data[key] = []
            active_key = key
    return data, markdown[body_start:].strip()


def post_url(path):
    markdown = path.read_text(encoding="utf-8")
    front, body = parse_front_matter(markdown)
    title = front.get("title") or path.stem
    categories = front.get("categories") or []
    if isinstance(categories, str):
        categories = [categories]
    kind = next((item for item in categories if item in VALID_TYPES), "长文")
    date = str(front.get("date") or "")
    slug = path.stem
    match = re.match(r"(\d{4})-(\d{2})-(\d{2})", date)
    if match:
        url = f"{SITE_URL}/{match.group(1)}/{match.group(2)}/{match.group(3)}/{slug}/"
    else:
        url = f"{SITE_URL}/"
    excerpt = re.sub(r"\s+", " ", body).strip()[:180]
    return {"title": title, "type": kind, "url": url, "excerpt": excerpt}


def interested(subscriber, kind):
    sub_type = subscriber.get("type", "both")
    return sub_type == "both" or sub_type == kind


def send_one(subscriber, post):
    msg = EmailMessage()
    msg["From"] = EMAIL
    msg["To"] = subscriber["email"]
    msg["Subject"] = f"Winnie's Blog 更新：{post['title']}"
    msg.set_content(
        "\n".join([
            f"新{post['type']}：{post['title']}",
            "",
            post["excerpt"],
            "",
            post["url"],
            "",
            "你收到这封邮件是因为订阅了 Winnie's Blog。"
        ])
    )
    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
        smtp.login(EMAIL, PASSWORD)
        smtp.send_message(msg)


def main():
    if not EMAIL or not PASSWORD:
        print("❌ BLOG_EMAIL 或 BLOG_EMAIL_PASSWORD 未设置")
        sys.exit(1)
    if not (os.environ.get("SUBSCRIBERS_ENCRYPTION_KEY") or "").strip():
        print("⏭️ SUBSCRIBERS_ENCRYPTION_KEY 未设置，跳过订阅通知")
        return

    posts = [post_url(path) for path in changed_posts()]
    posts = [post for post in posts if post["type"] in VALID_TYPES]
    if not posts:
        print("📭 没有需要通知的新文章")
        return

    subscribers = load_subscribers()
    if not subscribers:
        print("📭 没有订阅者")
        return

    sent = 0
    for post in posts:
        targets = [item for item in subscribers if interested(item, post["type"])]
        print(f"📨 {post['title']} -> {len(targets)} subscribers")
        for subscriber in targets:
            send_one(subscriber, post)
            sent += 1
    print(f"✅ 已发送 {sent} 封订阅通知")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"❌ 错误: {error}")
        sys.exit(1)
