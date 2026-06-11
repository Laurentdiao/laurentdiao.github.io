# MyBlogApp iPhone 部署与使用

## 功能

MyBlogApp 是 Winnie 博客的手机端管理器，支持：

- 写新文章
- 编辑已有文章
- 删除文章
- 修改 About Me 页面

每次保存都会直接提交到 GitHub 仓库 `Laurentdiao/laurentdiao.github.io` 的 `main` 分支。GitHub Actions 随后自动重新生成网页。

## 第一次部署到 iPhone 17

1. 用 USB-C 线连接 iPhone 17 和 Mac，并在 iPhone 上点“信任此电脑”。
2. 在 Mac 上打开 `MyBlogApp/MyBlogApp.xcodeproj`。
3. Xcode 顶部选择运行设备为你的 iPhone 17。
4. 打开项目 target `MyBlogApp` 的 `Signing & Capabilities`：
   - Team 选择你的 Apple ID 或开发者账号。
   - Bundle Identifier 如果冲突，改成唯一值，例如 `com.laurentdiao.MyBlogApp`。
5. 点击 Run。第一次安装后，如果手机提示未信任开发者：
   - iPhone 设置 -> 通用 -> VPN 与设备管理
   - 信任你的 Apple ID 开发者证书
6. 回到 Xcode 再点 Run。

如果使用免费的 Apple ID 签名，App 通常需要每 7 天用 Xcode 重新安装一次；付费开发者账号签名有效期更长。第一次真机运行时，Xcode 可能会要求打开 Developer Mode，按手机提示重启并开启即可。

## GitHub Token

推荐使用 Fine-grained personal access token：

1. 打开 GitHub 的 Personal access tokens 页面。
2. 创建 Fine-grained token。
3. Repository access 只选择 `Laurentdiao/laurentdiao.github.io`。
4. Permissions 里给 `Contents` 设置 `Read and write`。
5. 复制 token。
6. 打开 MyBlogApp -> 设置 -> 粘贴 token -> 保存。

Token 只保存在 iPhone 本机 Keychain 中。换手机或重装 App 后需要重新粘贴。

不要把 token 写进文章、截图或发给别人。如果 token 泄露，立刻在 GitHub 删除旧 token 并重新创建。

## 日常使用

### 写文章

1. 点首页右上角 `+`，或快捷入口“写文章”。
2. 输入标题、分类、标签和正文。
3. 可点“插入图片”，选择照片后会自动上传并插入 Markdown 图片链接。
4. 点“发布”。

### 编辑文章

1. 在文章列表点一篇文章。
2. 修改标题、分类、标签或正文。
3. 点“保存”。

如果修改标题，App 会把旧文件删除，再用新标题创建新文件。

### 删除文章

1. 在文章列表对文章左滑。
2. 点“删除”。
3. 在确认弹窗里再次确认。

### 修改 About Me

1. 点快捷入口 “About”，或右上角 `+` 菜单里的“改 About Me”。
2. 修改内容。
3. 点“保存”。

## 等待网页更新

保存后 GitHub Actions 会自动部署。通常 1-3 分钟后刷新 `https://laurentdiao.github.io` 即可看到变化。

如果没有更新，去 GitHub 仓库的 Actions 页面查看 `Fetch Email Comments` 和 `Deploy Hexo to GitHub Pages` 是否成功。

如果 App 显示保存成功但网页没变，优先看 `Deploy Hexo to GitHub Pages`；如果邮件评论没出现，优先看 `Fetch Email Comments`。

## 建议

- 发长文前先在备忘录里保留一份草稿，防止网络中断。
- Token 权限只给这个博客仓库，不要给所有仓库。
- App 修改的是源码；网页更新依赖 Actions，因此保存成功和网页立刻可见之间会有短暂延迟。
- 删除和改标题都会直接影响 GitHub 仓库；操作前建议确认一下文章标题。
