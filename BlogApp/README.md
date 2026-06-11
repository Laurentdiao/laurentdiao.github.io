# BlogApp - iPhone 博客管理 App

## 一、在电脑上创建项目并调试

1. 打开 Xcode（App Store 免费下载）
2. File → New → Project
3. 选 iOS → App → Next
4. 填写：
   - Product Name: BlogApp
   - Interface: SwiftUI
   - Language: Swift
   - 取消勾选 Include Tests
5. 选保存位置为桌面 → Create

6. 把 Gh_pages/BlogApp/ 里的 5 个 .swift 文件拖入 Xcode 左侧项目导航栏
   （勾选 Copy items if needed → Finish）

7. 点左上角 ▶️ 运行按钮，模拟器里就能看到 App

## 二、传到自己 iPhone 使用

1. 用数据线连接 iPhone 到 Mac
2. Xcode 顶部设备选择器 → 选你的 iPhone
3. 点 ▶️ 运行，第一次会提示签名：
   - 点 Xcode → Settings → Accounts → 左下角 + → 登录你的 Apple ID
   - 回到项目 → Signing & Capabilities → Team 选你的 Apple ID
4. 再次点 ▶️，App 就会装到 iPhone 上
5. iPhone 上首次打开：设置 → 通用 → VPN与设备管理 → 信任开发者

## 三、使用 App

1. 第一次打开 → 点左上角 ⚙️ 设置
2. 粘贴 GitHub Token：
   - 电脑打开 https://github.com/settings/tokens
   - Generate new token (classic) → 勾选 repo → 生成
   - 复制 token，在手机上粘贴保存
3. 保存后自动拉取文章列表
4. 点右上角 + 写新文章
5. 左滑文章 → 删除
6. 点文章 → 编辑修改
