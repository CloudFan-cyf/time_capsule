// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh_CN';

  static String m0(capsuleName) => "确定要删除胶囊“${capsuleName}”吗？";

  static String m1(error) => "创建失败：${error}";

  static String m2(error) => "主密钥导出失败：${error}";

  static String m3(error) => "导入主密钥失败：${error}";

  static String m4(path) => "使用自定义目录：\n${path}";

  static String m5(path) => "使用应用私有目录：\n${path}";

  static String m6(source, now, last) =>
      "来源：${source}\n当前时间：${now}\n上次同步：${last}";

  static String m7(source, now, last, error) =>
      "来源：${source}\n当前时间：${now}\n上次同步：${last}\n错误：${error}";

  static String m8(time) => "解锁时间：${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "Cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "Delete": MessageLookupByLibrary.simpleMessage("删除"),
    "DeleteCapsuleConfirmation": m0,
    "Refresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "aboutSubtitle": MessageLookupByLibrary.simpleMessage(
      "时光胶囊 App · version 0.1",
    ),
    "aboutTitle": MessageLookupByLibrary.simpleMessage("关于"),
    "appTitle": MessageLookupByLibrary.simpleMessage("时光胶囊"),
    "capsuleListTitle": MessageLookupByLibrary.simpleMessage("时光胶囊列表"),
    "capsuleName": MessageLookupByLibrary.simpleMessage("胶囊名称"),
    "capsules": MessageLookupByLibrary.simpleMessage("胶囊列表"),
    "createCapsule": MessageLookupByLibrary.simpleMessage("创建胶囊"),
    "createFailed": m1,
    "createPageTitle": MessageLookupByLibrary.simpleMessage("创建胶囊"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("统计数据"),
    "decryptSuccess": MessageLookupByLibrary.simpleMessage("解密成功，准备预览"),
    "exportFailed": m2,
    "exportMasterKey": MessageLookupByLibrary.simpleMessage("导出主密钥"),
    "exportMasterKeyDesc": MessageLookupByLibrary.simpleMessage(
      "导出可在其他设备导入的主密钥文件",
    ),
    "exportMasterKeyHint": MessageLookupByLibrary.simpleMessage(
      "导出主密钥可用于在其他设备上恢复访问权限",
    ),
    "exportMasterKeyTitle": MessageLookupByLibrary.simpleMessage("导出主密钥"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("主密钥导出成功"),
    "importFailed": m3,
    "importMasterKey": MessageLookupByLibrary.simpleMessage("导入主密钥"),
    "importMasterKeyDesc": MessageLookupByLibrary.simpleMessage(
      "从导出的主密钥文件恢复访问权限",
    ),
    "importSuccess": MessageLookupByLibrary.simpleMessage("导入主密钥成功"),
    "light": MessageLookupByLibrary.simpleMessage("浅色"),
    "locked": MessageLookupByLibrary.simpleMessage("未到期"),
    "navCapsules": MessageLookupByLibrary.simpleMessage("胶囊列表"),
    "navDashboard": MessageLookupByLibrary.simpleMessage("统计数据"),
    "navSettings": MessageLookupByLibrary.simpleMessage("设置"),
    "notSynced": MessageLookupByLibrary.simpleMessage("未同步"),
    "openFailed": MessageLookupByLibrary.simpleMessage("打开失败"),
    "pleaseFillAll": MessageLookupByLibrary.simpleMessage("请完整填写信息"),
    "selectFile": MessageLookupByLibrary.simpleMessage("选择文件"),
    "selectUnlockTime": MessageLookupByLibrary.simpleMessage("请选择解锁时间"),
    "settings": MessageLookupByLibrary.simpleMessage("设置"),
    "settingsPickDir": MessageLookupByLibrary.simpleMessage("选择目录"),
    "settingsRestoreDefault": MessageLookupByLibrary.simpleMessage("恢复默认"),
    "settingsSecuritySubtitle": MessageLookupByLibrary.simpleMessage(
      "后续添加主密钥管理、校时策略等设置选项",
    ),
    "settingsSecurityTitle": MessageLookupByLibrary.simpleMessage("安全设置（占位）"),
    "settingsStorageLoading": MessageLookupByLibrary.simpleMessage("加载中…"),
    "settingsStorageTitle": MessageLookupByLibrary.simpleMessage("胶囊文件存储位置"),
    "settingsStorageUsingCustom": m4,
    "settingsStorageUsingDefault": m5,
    "shareExportText": MessageLookupByLibrary.simpleMessage("时光胶囊主密钥导出"),
    "storageDirReset": MessageLookupByLibrary.simpleMessage("已恢复为默认存储目录"),
    "storageDirSet": MessageLookupByLibrary.simpleMessage("已设置新的胶囊存储目录"),
    "switchToDark": MessageLookupByLibrary.simpleMessage("切换到深色"),
    "switchToLight": MessageLookupByLibrary.simpleMessage("切换到浅色"),
    "system": MessageLookupByLibrary.simpleMessage("跟随系统"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "timeStatusSubtitle": m6,
    "timeStatusSubtitleWithError": m7,
    "timeStatusTitle": MessageLookupByLibrary.simpleMessage("联网校时状态"),
    "totalCapsules": MessageLookupByLibrary.simpleMessage("总胶囊数"),
    "unlockTime": m8,
    "unlockable": MessageLookupByLibrary.simpleMessage("可解锁数"),
  };
}
