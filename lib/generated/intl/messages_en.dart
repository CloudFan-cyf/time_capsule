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

  static String m0(capsuleName) =>
      "Are you sure you want to delete the capsule \"${capsuleName}\"?";

  static String m1(error) => "Creation failed: ${error}";

  static String m2(error) => "Master key export failed: ${error}";

  static String m3(error) => "Master key import failed: ${error}";

  static String m4(path) => "Using custom directory:\n${path}";

  static String m5(path) => "Using app private directory:\n${path}";

  static String m6(seconds) => "Time synced ${seconds} seconds ago";

  static String m7(seconds) =>
      "Please wait ${seconds} seconds before refreshing again";

  static String m8(source, now, last) =>
      "Source: ${source}\nCurrent time: ${now}\nLast sync: ${last}";

  static String m9(source, time, ago) => "${source}\nCurrent: ${time}\n${ago}";

  static String m10(source, time, ago, err) =>
      "${source}\nCurrent: ${time}\n${ago}\nError: ${err}";

  static String m11(source, now, last, error) =>
      "Source: ${source}\nCurrent time: ${now}\nLast sync: ${last}\nError: ${error}";

  static String m12(time) => "Unlock time: ${time}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "Cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "Delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "DeleteCapsuleConfirmation": m0,
    "Refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "aboutSubtitle": MessageLookupByLibrary.simpleMessage(
      "Time Capsule App · MVP",
    ),
    "aboutTitle": MessageLookupByLibrary.simpleMessage("About"),
    "appTitle": MessageLookupByLibrary.simpleMessage("Time Capsule"),
    "capsuleListTitle": MessageLookupByLibrary.simpleMessage("Capsule List"),
    "capsuleName": MessageLookupByLibrary.simpleMessage("Capsule Name"),
    "capsules": MessageLookupByLibrary.simpleMessage("Capsules"),
    "createCapsule": MessageLookupByLibrary.simpleMessage("Create Capsule"),
    "createFailed": m1,
    "createPageTitle": MessageLookupByLibrary.simpleMessage("Create Capsule"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "decryptSuccess": MessageLookupByLibrary.simpleMessage(
      "Decrypted successfully, preparing preview",
    ),
    "exportFailed": m2,
    "exportMasterKey": MessageLookupByLibrary.simpleMessage(
      "Export Master Key",
    ),
    "exportMasterKeyDesc": MessageLookupByLibrary.simpleMessage(
      "Export a master key file that can be imported on other devices",
    ),
    "exportMasterKeyHint": MessageLookupByLibrary.simpleMessage(
      "Exporting the master key can be used on other devices",
    ),
    "exportMasterKeyTitle": MessageLookupByLibrary.simpleMessage(
      "Export Master Key",
    ),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "Master key exported successfully",
    ),
    "importFailed": m3,
    "importMasterKey": MessageLookupByLibrary.simpleMessage(
      "Import Master Key",
    ),
    "importMasterKeyDesc": MessageLookupByLibrary.simpleMessage(
      "Restore access from an exported master key file",
    ),
    "importSuccess": MessageLookupByLibrary.simpleMessage(
      "Master key imported successfully",
    ),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "locked": MessageLookupByLibrary.simpleMessage("Locked"),
    "navCapsules": MessageLookupByLibrary.simpleMessage("Capsules"),
    "navDashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "navSettings": MessageLookupByLibrary.simpleMessage("Settings"),
    "notSynced": MessageLookupByLibrary.simpleMessage("Not synced"),
    "openFailed": MessageLookupByLibrary.simpleMessage("Open failed"),
    "pleaseFillAll": MessageLookupByLibrary.simpleMessage(
      "Please fill all fields",
    ),
    "selectFile": MessageLookupByLibrary.simpleMessage("Select file"),
    "selectUnlockTime": MessageLookupByLibrary.simpleMessage(
      "Select unlock time",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsPickDir": MessageLookupByLibrary.simpleMessage("Choose directory"),
    "settingsRestoreDefault": MessageLookupByLibrary.simpleMessage(
      "Restore default",
    ),
    "settingsSecuritySubtitle": MessageLookupByLibrary.simpleMessage(
      "Add master key management and time verification strategies later",
    ),
    "settingsSecurityTitle": MessageLookupByLibrary.simpleMessage(
      "Security settings (placeholder)",
    ),
    "settingsStorageLoading": MessageLookupByLibrary.simpleMessage("Loading…"),
    "settingsStorageTitle": MessageLookupByLibrary.simpleMessage(
      "Capsule storage location",
    ),
    "settingsStorageUsingCustom": m4,
    "settingsStorageUsingDefault": m5,
    "shareExportText": MessageLookupByLibrary.simpleMessage(
      "TimeCapsule Master Key Export",
    ),
    "storageDirReset": MessageLookupByLibrary.simpleMessage(
      "Restored to default storage directory",
    ),
    "storageDirSet": MessageLookupByLibrary.simpleMessage(
      "New capsule storage directory set",
    ),
    "switchToDark": MessageLookupByLibrary.simpleMessage("Switch to dark"),
    "switchToLight": MessageLookupByLibrary.simpleMessage("Switch to light"),
    "syncedSecondsAgo": m6,
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "timeRefreshCooldown": m7,
    "timeStatusSubtitle": m8,
    "timeStatusSubtitleWithAgo": m9,
    "timeStatusSubtitleWithAgoAndError": m10,
    "timeStatusSubtitleWithError": m11,
    "timeStatusTitle": MessageLookupByLibrary.simpleMessage(
      "Network time status",
    ),
    "totalCapsules": MessageLookupByLibrary.simpleMessage("Total Capsules"),
    "unlockTime": m12,
    "unlockable": MessageLookupByLibrary.simpleMessage("Unlockable"),
  };
}
