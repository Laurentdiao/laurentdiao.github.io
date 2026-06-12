# 邮件订阅配置

订阅入口在网站右上角三横线菜单里。访客填写邮箱和文章类型后，会打开邮件 App，把订阅模板发到 `BLOG_EMAIL` 对应的 Gmail。

## GitHub Secrets

已有的两个 Secret 继续使用：

- `BLOG_EMAIL`: Gmail 地址，例如 `dwinnie137@gmail.com`
- `BLOG_EMAIL_PASSWORD`: Gmail app password

新增一个 Secret：

- `SUBSCRIBERS_ENCRYPTION_KEY`: 订阅者列表加密密钥

建议在本地运行下面命令生成：

```bash
python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(48))
PY
```

把输出整段复制到 GitHub Secret。不要发给别人，也不要提交到仓库。

## 数据如何保存

- 公开仓库只保存 `.github/subscribers.enc`，里面是加密后的订阅者列表。
- 明文邮箱只会在 GitHub Actions 运行时通过 `SUBSCRIBERS_ENCRYPTION_KEY` 解密使用。
- 如果没有配置 `SUBSCRIBERS_ENCRYPTION_KEY`，订阅 workflow 会跳过，不会失败，也不会保存明文。

## Workflow

- `Fetch Email Subscribers`: 每 10 分钟从 Gmail 收件箱读取 `[订阅]` 邮件，更新加密订阅库。
- `Notify Email Subscribers`: 当 `source/_posts/**` 新增文章时，按长文/短文/both 给订阅者逐个发邮件。

通知脚本只对新增文章发送邮件，修改旧文章不会触发订阅通知。
