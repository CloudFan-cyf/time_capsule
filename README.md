# time_capsule

A new Flutter project.

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
