import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const supportedLocales = [Locale('en'), Locale('zh')];

  String get appTitle => _t('appTitle');
  String get dashboard => _t('dashboard');
  String get capsules => _t('capsules');
  String get settings => _t('settings');
  String get createCapsule => _t('createCapsule');
  String get totalCapsules => _t('totalCapsules');
  String get unlockable => _t('unlockable');
  String get locked => _t('locked');
  String get capsuleListTitle => _t('capsuleListTitle');
  String get createPageTitle => _t('createPageTitle');
  String selectUnlockTime() => _t('selectUnlockTime');
  String unlockTime(String time) => _t('unlockTime', {'time': time});
  String get selectFile => _t('selectFile');
  String get pleaseFillAll => _t('pleaseFillAll');
  String createFailed(String error) => _t('createFailed', {'error': error});
  String get decryptSuccess => _t('decryptSuccess');
  String get openFailed => _t('openFailed');
  String get theme => _t('theme');
  String get light => _t('light');
  String get dark => _t('dark');
  String get system => _t('system');

  String _t(String key, [Map<String, Object?> params = const {}]) {
    final localeName = intl.Intl.canonicalizedLocale(locale.languageCode);
    switch (localeName) {
      case 'zh':
        return _zh[key]?.replaceAllMapped(
              RegExp(r'\{(\w+)\}'),
              (m) => '${params[m.group(1)] ?? m.group(0)}',
            ) ??
            key;
      default:
        return _en[key]?.replaceAllMapped(
              RegExp(r'\{(\w+)\}'),
              (m) => '${params[m.group(1)] ?? m.group(0)}',
            ) ??
            key;
    }
  }

  static const Map<String, String> _en = {
    'appTitle': 'Time Capsule',
    'dashboard': 'Dashboard',
    'capsules': 'Capsules',
    'settings': 'Settings',
    'createCapsule': 'Create Capsule',
    'totalCapsules': 'Total Capsules',
    'unlockable': 'Unlockable',
    'locked': 'Locked',
    'capsuleListTitle': 'Capsule List',
    'createPageTitle': 'Create Capsule',
    'selectUnlockTime': 'Select unlock time',
    'unlockTime': 'Unlock time: {time}',
    'selectFile': 'Select file',
    'pleaseFillAll': 'Please fill all fields',
    'createFailed': 'Creation failed: {error}',
    'decryptSuccess': 'Decrypted successfully, preparing preview',
    'openFailed': 'Open failed',
    'theme': 'Theme',
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
  };

  static const Map<String, String> _zh = {
    'appTitle': '时光胶囊',
    'dashboard': 'Dashboard',
    'capsules': '胶囊列表',
    'settings': '设置',
    'createCapsule': '创建胶囊',
    'totalCapsules': '总胶囊数',
    'unlockable': '可解锁数',
    'locked': '未到期',
    'capsuleListTitle': '时光胶囊列表',
    'createPageTitle': '创建胶囊',
    'selectUnlockTime': '请选择解锁时间',
    'unlockTime': '解锁时间：{time}',
    'selectFile': '选择文件',
    'pleaseFillAll': '请完整填写信息',
    'createFailed': '创建失败：{error}',
    'decryptSuccess': '解密成功，准备预览',
    'openFailed': '打开失败',
    'theme': '主题',
    'light': '浅色',
    'dark': '深色',
    'system': '跟随系统',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
