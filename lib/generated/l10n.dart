// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Time Capsule`
  String get appTitle {
    return Intl.message('Time Capsule', name: 'appTitle', desc: '', args: []);
  }

  /// `Dashboard`
  String get dashboard {
    return Intl.message('Dashboard', name: 'dashboard', desc: '', args: []);
  }

  /// `Capsules`
  String get capsules {
    return Intl.message('Capsules', name: 'capsules', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Create Capsule`
  String get createCapsule {
    return Intl.message(
      'Create Capsule',
      name: 'createCapsule',
      desc: '',
      args: [],
    );
  }

  /// `Total Capsules`
  String get totalCapsules {
    return Intl.message(
      'Total Capsules',
      name: 'totalCapsules',
      desc: '',
      args: [],
    );
  }

  /// `Unlockable`
  String get unlockable {
    return Intl.message('Unlockable', name: 'unlockable', desc: '', args: []);
  }

  /// `Locked`
  String get locked {
    return Intl.message('Locked', name: 'locked', desc: '', args: []);
  }

  /// `Capsule List`
  String get capsuleListTitle {
    return Intl.message(
      'Capsule List',
      name: 'capsuleListTitle',
      desc: '',
      args: [],
    );
  }

  /// `Create Capsule`
  String get createPageTitle {
    return Intl.message(
      'Create Capsule',
      name: 'createPageTitle',
      desc: '',
      args: [],
    );
  }

  /// `Select unlock time`
  String get selectUnlockTime {
    return Intl.message(
      'Select unlock time',
      name: 'selectUnlockTime',
      desc: '',
      args: [],
    );
  }

  /// `Capsule Name`
  String get capsuleName {
    return Intl.message(
      'Capsule Name',
      name: 'capsuleName',
      desc: '',
      args: [],
    );
  }

  /// `Unlock time: {time}`
  String unlockTime(Object time) {
    return Intl.message(
      'Unlock time: $time',
      name: 'unlockTime',
      desc: '',
      args: [time],
    );
  }

  /// `Select file`
  String get selectFile {
    return Intl.message('Select file', name: 'selectFile', desc: '', args: []);
  }

  /// `Please fill all fields`
  String get pleaseFillAll {
    return Intl.message(
      'Please fill all fields',
      name: 'pleaseFillAll',
      desc: '',
      args: [],
    );
  }

  /// `Creation failed: {error}`
  String createFailed(Object error) {
    return Intl.message(
      'Creation failed: $error',
      name: 'createFailed',
      desc: '',
      args: [error],
    );
  }

  /// `Decrypted successfully, preparing preview`
  String get decryptSuccess {
    return Intl.message(
      'Decrypted successfully, preparing preview',
      name: 'decryptSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Open failed`
  String get openFailed {
    return Intl.message('Open failed', name: 'openFailed', desc: '', args: []);
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Light`
  String get light {
    return Intl.message('Light', name: 'light', desc: '', args: []);
  }

  /// `Dark`
  String get dark {
    return Intl.message('Dark', name: 'dark', desc: '', args: []);
  }

  /// `System`
  String get system {
    return Intl.message('System', name: 'system', desc: '', args: []);
  }

  /// `Dashboard`
  String get navDashboard {
    return Intl.message('Dashboard', name: 'navDashboard', desc: '', args: []);
  }

  /// `Capsules`
  String get navCapsules {
    return Intl.message('Capsules', name: 'navCapsules', desc: '', args: []);
  }

  /// `Settings`
  String get navSettings {
    return Intl.message('Settings', name: 'navSettings', desc: '', args: []);
  }

  /// `Security settings (placeholder)`
  String get settingsSecurityTitle {
    return Intl.message(
      'Security settings (placeholder)',
      name: 'settingsSecurityTitle',
      desc: '',
      args: [],
    );
  }

  /// `Add master key management and time verification strategies later`
  String get settingsSecuritySubtitle {
    return Intl.message(
      'Add master key management and time verification strategies later',
      name: 'settingsSecuritySubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Capsule storage location`
  String get settingsStorageTitle {
    return Intl.message(
      'Capsule storage location',
      name: 'settingsStorageTitle',
      desc: '',
      args: [],
    );
  }

  /// `Loading…`
  String get settingsStorageLoading {
    return Intl.message(
      'Loading…',
      name: 'settingsStorageLoading',
      desc: '',
      args: [],
    );
  }

  /// `Using app private directory:\n{path}`
  String settingsStorageUsingDefault(String path) {
    return Intl.message(
      'Using app private directory:\n$path',
      name: 'settingsStorageUsingDefault',
      desc: '',
      args: [path],
    );
  }

  /// `Using custom directory:\n{path}`
  String settingsStorageUsingCustom(String path) {
    return Intl.message(
      'Using custom directory:\n$path',
      name: 'settingsStorageUsingCustom',
      desc: '',
      args: [path],
    );
  }

  /// `Choose directory`
  String get settingsPickDir {
    return Intl.message(
      'Choose directory',
      name: 'settingsPickDir',
      desc: '',
      args: [],
    );
  }

  /// `Restore default`
  String get settingsRestoreDefault {
    return Intl.message(
      'Restore default',
      name: 'settingsRestoreDefault',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get aboutTitle {
    return Intl.message('About', name: 'aboutTitle', desc: '', args: []);
  }

  /// `Time Capsule App · MVP`
  String get aboutSubtitle {
    return Intl.message(
      'Time Capsule App · MVP',
      name: 'aboutSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `New capsule storage directory set`
  String get storageDirSet {
    return Intl.message(
      'New capsule storage directory set',
      name: 'storageDirSet',
      desc: '',
      args: [],
    );
  }

  /// `Restored to default storage directory`
  String get storageDirReset {
    return Intl.message(
      'Restored to default storage directory',
      name: 'storageDirReset',
      desc: '',
      args: [],
    );
  }

  /// `Switch to light`
  String get switchToLight {
    return Intl.message(
      'Switch to light',
      name: 'switchToLight',
      desc: '',
      args: [],
    );
  }

  /// `Switch to dark`
  String get switchToDark {
    return Intl.message(
      'Switch to dark',
      name: 'switchToDark',
      desc: '',
      args: [],
    );
  }

  /// `Export Master Key`
  String get exportMasterKeyTitle {
    return Intl.message(
      'Export Master Key',
      name: 'exportMasterKeyTitle',
      desc: '',
      args: [],
    );
  }

  /// `Exporting the master key can be used on other devices`
  String get exportMasterKeyHint {
    return Intl.message(
      'Exporting the master key can be used on other devices',
      name: 'exportMasterKeyHint',
      desc: '',
      args: [],
    );
  }

  /// `Master key exported successfully`
  String get exportSuccess {
    return Intl.message(
      'Master key exported successfully',
      name: 'exportSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Master key export failed: {error}`
  String exportFailed(Object error) {
    return Intl.message(
      'Master key export failed: $error',
      name: 'exportFailed',
      desc: '',
      args: [error],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
