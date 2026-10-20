# HTTP 延迟测试

一个面向 Android 15 及以上版本的 Flutter HTTP 完整响应耗时测试工具。

## 功能

- 内置 ChatGPT、Gemini、Google、GitHub、X、YouTube、Telegram、Reddit、Cloudflare、Notion 和 Bing。
- 首次启动默认选择 ChatGPT 和 Gemini；每个 URL 可预热 0–5 次、正式测试 1–5 次。
- 串行读取完整响应，统计最小值、最大值和平均值。
- 支持自定义 HTTP/HTTPS URL、1/2/3/5/10/15 秒超时、取消以及 10 MB 响应上限。
- 设置中的自定义 URL 可通过左侧手柄拖动排序，顺序自动保存并用于目标选择和测速。
- 测速期间可修改目标、次数、预热和超时等设置；本次测试使用开始时的参数，修改用于后续测试。
- 显示公网 IP 和近似地理位置，不读取 Wi-Fi 名称；设置中可选择 ipwho.is（默认）、IP.SB 或 FreeIPAPI，均无需 API Key。切换只保存选择，下次发起查询时使用所选接口。
- 每次测试开始前刷新公网 IP；IP 查询总超时在设置中单独选择，支持 1/2/3/5/10/15 秒，默认 3 秒。修改只保存设置，下次发起查询时生效；查询失败时记录未知 IP。
- 使用 SQLite 在本机保存最近 20 次完整测试结果。
- 支持 Android 15+ 与 Windows x64，并共用测试、统计和历史记录逻辑。

## 构建

项目使用 [Go Task](https://taskfile.dev/) 管理常用命令。在项目目录运行：

```powershell
task             # 检查、测试，然后构建 arm64-v8a Debug APK
task build       # 仅构建 arm64-v8a Debug APK
task arm64       # 仅构建手机用 arm64-v8a APK
task install-usb # 构建 Debug APK 并安装到 USB 设备
task release     # 构建 arm64-v8a Release APK
task release-arm64 # 仅构建手机用 arm64-v8a Release APK
task windows-run # 在 Windows 桌面运行 Debug 版本
task windows-debug # 构建 Windows Debug 版本
task windows-release # 构建 Windows Release 版本
task check       # 静态检查与测试
task format      # 格式化 Dart 代码
task --list      # 查看所有任务
```

如果尚未安装 Go Task，可在 Windows 上执行
`winget install Task.Task`。Android 构建任务只生成 arm64-v8a APK。`install-usb` 使用 `adb -d` 指定 USB 设备。

APK 输出到：

- `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`：Android 手机。
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`：Android 手机 Release 包。

当前 Android 配置使用调试密钥签署 Release APK，适合本机安装测试；正式发布前需要配置独立的发布密钥。

Windows Debug 输出到 `build/windows/x64/runner/Debug/`。分发 Windows
版本时需要保留输出目录内的 EXE、DLL 和 `data` 目录，不能只复制 EXE。
