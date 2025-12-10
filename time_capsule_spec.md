# 时光胶囊（Time Capsule）Flutter App Specification

## 0. 项目目标（Goals）

本项目旨在实现一个 Flutter App，用于生成和管理"时光胶囊"（Time
Capsules），其中每个胶囊由：

-   用户选择的本地文件（src）
-   用户设定的访问解锁时间（unlockAt）

组成，并被 App
加密为一个独立的加密副本，仅允许在**到期且通过联网校时验证**后由 App
解密查看。

### 功能目标

1.  **创建时光胶囊**
    -   用户选择本地文件\
    -   设置未来访问时间\
    -   系统生成该文件的加密副本，仅本 App 可解密\
    -   加密后的胶囊存储在 App 私有目录中
2.  **展示本地时光胶囊列表**
    -   列表项包含标题、原文件名、解锁时间、状态等
3.  **打开时光胶囊**
    -   必须联网校时成功\
    -   未到 unlockAt 时间则拒绝访问\
    -   到期后解密文件到临时目录并打开预览（内建或系统应用）\
    -   解密文件不会长期存储（临时文件将清理）

### 非目标

-   跨设备同步、云存储\
-   避免 root/越狱后泄露（本方案不能达到绝对的安全性）\
-   高级 MITM 防护（可作为第二阶段工作）

------------------------------------------------------------------------

## 1. 系统架构概述（Architecture Overview）

系统包含以下核心模块：

  --------------------------------------------------------------------------
  模块                                职责
  ----------------------------------- --------------------------------------
  SecureKeyStore                      管理主密钥 MasterKey（用于 wrapKey 和
                                      hmacKey 派生）

  CryptoService                       加密、解密、生成胶囊、解析
                                      manifest、维护文件格式

  TimeService                         联网校时，支持 NTP + HTTPS Date
                                      双通道策略

  CapsuleRepository                   胶囊生命周期管理（创建、打开、列表）

  SQLite 数据库                       持久记录胶囊元信息

  UI 模块                             胶囊列表 / 创建 / 打开预览
  --------------------------------------------------------------------------

------------------------------------------------------------------------

## 2. 密钥管理（Key Hierarchy）

### 2.1 MasterKey（设备级主密钥）

-   启动 App 第一次生成：32 字节随机值\
-   保存在系统安全存储\
-   用途：
    -   HKDF 派生 wrapKey\
    -   HKDF 派生 hmacKey

### 2.2 DEK（胶囊级数据加密密钥）

-   每个胶囊独立随机 32B\
-   负责加密 payload.enc\
-   在 manifest.json 以 wrapKey 包裹后存储

------------------------------------------------------------------------

## 3. 文件格式（On-Disk Format）

每个胶囊一个目录：

    {ApplicationSupport}/capsules/{capsuleId}/
      payload.enc
      manifest.json

### 3.1 payload.enc（含 Header + 分块加密）

### 3.2 manifest.json（含 metadata + wrappedDEK + HMAC）

------------------------------------------------------------------------

## 4. 联网校时策略（Time Verification）

必须使用：

-   NTP\
-   HTTPS Date Header

选择逻辑：

-   两者成功且差值 \< 5 秒 → 使用 HTTPS\
-   单个成功 → 使用成功项\
-   全部失败 → 拒绝打开

解锁规则：

    nowUtc >= unlockAtUtcMs

------------------------------------------------------------------------

## 5. 数据库 Schema（SQLite）

表 capsules：

  字段                     类型               含义
  ------------------------ ------------------ ---------------
  id                       TEXT PRIMARY KEY   胶囊 ID
  title                    TEXT               标题
  orig_filename            TEXT               原文件名
  mime                     TEXT               MIME 类型
  created_at_utc_ms        INTEGER            创建时间
  unlock_at_utc_ms         INTEGER            解锁时间
  orig_size                INTEGER            原始文件大小
  enc_path                 TEXT               加密文件路径
  manifest_path            TEXT               Manifest 路径
  status                   INTEGER            状态（0/1/2）
  last_time_check_utc_ms   INTEGER?           最近校时
  last_time_source         TEXT?              校时来源

------------------------------------------------------------------------

## 6. 服务接口（Service Layer）

### SecureKeyStore

    Future<Uint8List> getOrCreateMasterKey();

### TimeService

    Future<NetworkTimeResult> getTrustedNowUtc();
    Future<bool> canOpen({required int unlockAtUtcMs});

### CryptoService

    Future<CapsuleCreateResult> createCapsuleFromFile(File src, CapsuleParams params);
    Future<File> decryptCapsuleToTemp({required File payloadFile, required File manifestFile});

### CapsuleRepository

    Future<List<Capsule>> listCapsules();
    Future<Capsule> createCapsuleFromFile(...);
    Future<OpenResult> openCapsule(Capsule capsule);

------------------------------------------------------------------------

## 7. UI 要求（MVP）

-   列表页：展示全部胶囊\
-   创建页：选择文件 + 解锁时间 + 标题\
-   打开胶囊：必须联网校时、到期后解密

------------------------------------------------------------------------

## 8. 错误码（Error Codes）

  错误码                 说明
  ---------------------- -----------------
  TIME_VERIFY_REQUIRED   校时失败
  LOCKED                 未到解锁时间
  MANIFEST_TAMPERED      manifest 被篡改
  DECRYPT_FAIL           解密失败
  IO_FAIL                文件读写错误

------------------------------------------------------------------------

## 9. 验收标准（Acceptance Checklist）

1.  创建胶囊成功，文件写入正确\
2.  列表可展示\
3.  修改系统时间不能提前解锁\
4.  篡改 manifest 无法解密\
5.  到期后可正常解密并打开
