import 'package:flutter/foundation.dart';

/// 每次胶囊数据发生变化（创建/删除/更新）就 tick++
/// CapsuleListPage 监听它并自动 reload。
final ValueNotifier<int> capsuleRefreshTick = ValueNotifier<int>(0);

void notifyCapsulesChanged() {
  capsuleRefreshTick.value++;
}
