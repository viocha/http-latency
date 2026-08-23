# HTTP 延迟测试

一个面向 Android 15 及以上版本的 Flutter HTTP 完整响应耗时测试工具。

## 功能

- 内置 Google、YouTube、GitHub、ChatGPT、X、Facebook、Instagram 和 Wikipedia。
- 首次启动默认选择前四项，预热默认开启，支持每个 URL 测试 1–5 次。
- 串行读取完整响应，统计最小值、最大值和平均值。
- 支持自定义 HTTP/HTTPS URL、3/5/10/15 秒超时、取消以及 10 MB 响应上限。
- 通过无需 API Key 的 ipwho.is 显示公网 IP 和近似地理位置，不读取 Wi-Fi 名称。
- 使用 SQLite 在本机保存最近 20 次完整测试结果。
- 支持 Android 15+ 与 Windows x64，并共用测试、统计和历史记录逻辑。

## 构建

项目使用 [Go Task](https://taskfile.dev/) 管理常用命令。在项目目录运行：

```powershell
task             # 检查、测试，然后构建两个架构
task build       # 仅构建两个架构
task arm64       # 仅构建手机用 arm64-v8a APK
task x64         # 仅构建模拟器用 x86_64 APK
task release     # 构建两个架构的 Release APK
task release-arm64 # 仅构建手机用 arm64-v8a Release APK
task release-x64 # 仅构建模拟器用 x86_64 Release APK
task windows-run # 在 Windows 桌面运行 Debug 版本
task windows-debug # 构建 Windows Debug 版本
task windows-release # 构建 Windows Release 版本
task check       # 静态检查与测试
task format      # 格式化 Dart 代码
task --list      # 查看所有任务
```

如果尚未安装 Go Task，可在 Windows 上执行
`winget install Task.Task`。所有构建任务都明确指定单一 ABI，不会生成通用 APK。

Debug APK 分别输出到：

- `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`：Android 手机。
- `build/app/outputs/flutter-apk/app-x86_64-debug.apk`：本机 x64 模拟器。
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`：Android 手机 Release 包。
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`：本机 x64 模拟器 Release 包。

当前 Android 配置使用调试密钥签署 Release APK，适合本机安装测试；正式发布前需要配置独立的发布密钥。

Windows Debug 输出到 `build/windows/x64/runner/Debug/`。分发 Windows
版本时需要保留输出目录内的 EXE、DLL 和 `data` 目录，不能只复制 EXE。
