// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(error) => "Creation failed: ${error}";

  static String m1(time) => "Unlock time: ${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appTitle": MessageLookupByLibrary.simpleMessage("Time Capsule"),
    "capsuleListTitle": MessageLookupByLibrary.simpleMessage("Capsule List"),
    "capsuleName": MessageLookupByLibrary.simpleMessage("Capsule Name"),
    "capsules": MessageLookupByLibrary.simpleMessage("Capsules"),
    "createCapsule": MessageLookupByLibrary.simpleMessage("Create Capsule"),
    "createFailed": m0,
    "createPageTitle": MessageLookupByLibrary.simpleMessage("Create Capsule"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "decryptSuccess": MessageLookupByLibrary.simpleMessage(
      "Decrypted successfully, preparing preview",
    ),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "locked": MessageLookupByLibrary.simpleMessage("Locked"),
    "navCapsules": MessageLookupByLibrary.simpleMessage("Capsules"),
    "navDashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "navSettings": MessageLookupByLibrary.simpleMessage("Settings"),
    "openFailed": MessageLookupByLibrary.simpleMessage("Open failed"),
    "pleaseFillAll": MessageLookupByLibrary.simpleMessage(
      "Please fill all fields",
    ),
    "selectFile": MessageLookupByLibrary.simpleMessage("Select file"),
    "selectUnlockTime": MessageLookupByLibrary.simpleMessage(
      "Select unlock time",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "totalCapsules": MessageLookupByLibrary.simpleMessage("Total Capsules"),
    "unlockTime": m1,
    "unlockable": MessageLookupByLibrary.simpleMessage("Unlockable"),
  };
}
