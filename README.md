# 时光胶囊Time Capsule：封存回忆，让时光疗伤
一款用于加密数据，定时打开的软件，可以封存回忆，交给未来的自己。

## Quick Start
### 安装包下载

从[Release页面](https://github.com/CloudFan-cyf/time_capsule/releases "Release页面")下载对应平台的安装文件。目前支持以下几个平台：
- Windows平台，提供的安装文件为`app-版本号-windows.zip`，下载后解压，运行`time_capsule.exe`即可。
- Android平台，提供的安装文件为`app-版本号-android.apk`，下载后在安卓手机上安装即可。
- ios平台和macOS平台，由于我没有对应的设备进行测试，目前使用AI编写的action workflow进行构建，感兴趣的朋友可以下载尝试。

### 运行环境

- Flutter 3.38.3。

### 获取依赖

```powershell
flutter pub get
```

### 运行项目（示例）

- 运行到桌面（Windows）：

```powershell
flutter run -d windows
```

- 运行到已连接的设备或模拟器（自动选择设备）：

```powershell
flutter run
```

### 从源码构建发布包

- Windows 桌面：

```powershell
flutter build windows
```

- Android APK：

```powershell
flutter build apk
```

> 其他平台请参考 Flutter 官方构建文档（可能需要额外平台工具链，如 Xcode/Android SDK 等）。

### 使用流程

1. 在 Dashboard 或胶囊列表点击右下角「+」创建胶囊。
2. 在创建页选择一个或多个本地文件，设定解锁时间，确认创建。
3. 在列表页管理胶囊：刷新、排序（桌面）、删除（右键/更多菜单或移动端左滑）。
4. 到期后点击胶囊进行解锁预览；若未到期或联网校时失败，将提示无法打开。

### 数据与存储

- 默认存储在应用私有目录；可在 设置 → 胶囊文件存储位置 中切换为自定义目录或恢复默认。
- 可在 设置 中导出/导入主密钥（UMK）以便在其他设备恢复访问权限。
## 功能介绍

- 主页 Dashboard：以卡片展示统计信息（总胶囊数、可解锁数、未到期等），支持右下角快速创建胶囊。
- 胶囊列表：查看标题、原文件名、创建/解锁时间；支持刷新、桌面端拖拽排序、右键/更多菜单删除；移动端支持左滑删除。
- 创建胶囊：多文件选择；设置未来的解锁时间（界面显示本地时区，内部按 UTC 保存）；生成加密副本并写入应用目录。
- 打开胶囊：必须联网校时成功，未到期拒绝；到期后解密到临时目录并预览或交由系统打开。
- 设置：
  - 胶囊文件存储位置：可选择自定义目录或恢复默认应用私有目录。
  - 主密钥导出/导入：用于换设备迁移（Android 通过分享，桌面/其他平台保存为 JSON 文件）。
  - 联网校时状态：显示来源、当前可信时间、上次同步时间，支持手动刷新。
- 主题与本地化：支持亮/暗/跟随系统主题切换；内置中英文本地化。

## 加密原理

加密方案使用“每胶囊独立数据密钥 + 用户主密钥包裹”的分层方案，核心流程如下：

- UMK（User Master Key）用户主密钥：32 字节随机密钥。它不直接加密文件内容，而是用来“包裹/解包”每个胶囊的文件加密密钥。UMK 在本机以加密 blob 形式保存（由设备密钥 DPK 保护），并支持导入/导出以实现换设备迁移。
- DEK（Data Encryption Key）数据密钥：每创建一个胶囊就随机生成一个新的 32 字节 DEK，用于加密该胶囊中的所有文件内容。

### 文件内容加密（DEK → 文件）

- 每个文件使用 AES-256-GCM 加密。
- 加密输出文件是 *.enc，其二进制格式为：
`nonce(12 bytes) + ciphertext + tag(16 bytes)`,其中 nonce 每个文件随机生成，tag 用于完整性校验。
- 加密后的文件存放在胶囊目录的 files/ 下。

### DEK 包裹（UMK → DEK）

为了避免把 DEK 明文写进磁盘，我们用 UMK + AES-256-GCM 把 DEK 加密（包裹）。

包裹结果写入 `manifest.json` 的 `keyWrap` 字段，包含：

- `nonceB64`（12B nonce）
- `wrappedDekB64`（加密后的 DEK）
- `tagB64`（GCM tag）

### 解锁/预览（解包 DEK → 解密文件）

打开胶囊时，先通过联网校时确认已到解锁时间。

然后从 `manifest.json`读取 `keyWrap`，用 UMK 解包得到 DEK。

再用 DEK 解密 `files/*.enc`，输出明文到胶囊目录的 open/ 下，供应用内预览或系统打开。

### 安全性要点

加密使用的 AES-GCM 同时提供保密性与篡改检测（认证失败会解密报错）。

每个胶囊的 DEK 都不同，单个胶囊泄露不会影响其它胶囊。

UMK 可导出/导入实现设备迁移；本机存储时由设备密钥 DPK 保护，降低 UMK 明文落盘风险。


## 开源协议 License

本项目采用 MIT 许可证。详情请查看 [LICENSE](LICENSE) 文件。

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
