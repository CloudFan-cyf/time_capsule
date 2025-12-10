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

  static String m0(error) => "创建失败：${error}";

  static String m1(time) => "解锁时间：${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appTitle": MessageLookupByLibrary.simpleMessage("时光胶囊"),
    "capsuleListTitle": MessageLookupByLibrary.simpleMessage("时光胶囊列表"),
    "capsuleName": MessageLookupByLibrary.simpleMessage("胶囊名称"),
    "capsules": MessageLookupByLibrary.simpleMessage("胶囊列表"),
    "createCapsule": MessageLookupByLibrary.simpleMessage("创建胶囊"),
    "createFailed": m0,
    "createPageTitle": MessageLookupByLibrary.simpleMessage("创建胶囊"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "decryptSuccess": MessageLookupByLibrary.simpleMessage("解密成功，准备预览"),
    "light": MessageLookupByLibrary.simpleMessage("浅色"),
    "locked": MessageLookupByLibrary.simpleMessage("未到期"),
    "navCapsules": MessageLookupByLibrary.simpleMessage("胶囊列表"),
    "navDashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "navSettings": MessageLookupByLibrary.simpleMessage("设置"),
    "openFailed": MessageLookupByLibrary.simpleMessage("打开失败"),
    "pleaseFillAll": MessageLookupByLibrary.simpleMessage("请完整填写信息"),
    "selectFile": MessageLookupByLibrary.simpleMessage("选择文件"),
    "selectUnlockTime": MessageLookupByLibrary.simpleMessage("请选择解锁时间"),
    "settings": MessageLookupByLibrary.simpleMessage("设置"),
    "system": MessageLookupByLibrary.simpleMessage("跟随系统"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "totalCapsules": MessageLookupByLibrary.simpleMessage("总胶囊数"),
    "unlockTime": m1,
    "unlockable": MessageLookupByLibrary.simpleMessage("可解锁数"),
  };
}
