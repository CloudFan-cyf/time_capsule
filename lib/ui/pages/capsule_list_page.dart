import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:time_capsule/generated/l10n.dart';
import 'package:time_capsule/utlis/showsnackbar.dart';

import '../../features/capsules/data/capsule_events.dart';
import '../../features/capsules/data/capsule_repository.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/time/time_service.dart';
import '../../features/capsules/data/models/capsule.dart';
import 'capsule_preview_page.dart';

class CapsuleListPage extends StatefulWidget {
  const CapsuleListPage({super.key});

  @override
  State<CapsuleListPage> createState() => _CapsuleListPageState();
}

class _CapsuleListPageState extends State<CapsuleListPage> {
  late final CapsuleRepository repo;

  List<Capsule> items = [];
  bool loading = true;
  String? loadError;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();

    repo = CapsuleRepositoryImpl(
      cryptoService: CryptoServiceImpl(),
      timeService: TimeServiceImpl(),
    );

    capsuleRefreshTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    capsuleRefreshTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
          loadError = null;
        });
      }

      final list = await repo.listCapsules();

      if (!mounted) return;
      setState(() {
        items = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
      });
    }
  }

  Future<void> _openCapsule(Capsule c) async {
    final res = await repo.openCapsule(c);

    if (!mounted) return;

    if (res.opened && res.files.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CapsulePreviewPage(capsule: c, files: res.files),
        ),
      );
    } else {
      showSnack(context, res.error?.message ?? S.of(context).openFailed);
    }
  }

  Future<bool> _confirmDelete(Capsule c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除胶囊'),
        content: Text('确定删除“${c.title}”吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _doDelete(Capsule c) async {
    try {
      await repo.deleteCapsule(c);
      notifyCapsulesChanged();
      if (!mounted) return;
      setState(() => items.removeWhere((x) => x.id == c.id));
      showSnack(context, '已删除');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, '删除失败：$e');
      await _load();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final moved = items.removeAt(oldIndex);
      items.insert(newIndex, moved);
    });

    // 持久化顺序
    try {
      await repo.saveCustomOrder(items.map((e) => e.id).toList());
    } catch (e) {
      if (!mounted) return;
      showSnack(context, '保存排序失败：$e');
    }
  }

  Future<void> _showContextMenu(Capsule c, Offset globalPos) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPos.dx, globalPos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'delete', child: Text('删除')),
        // 未来拓展：重命名、导出、标记等
      ],
    );

    if (selected == 'delete') {
      final ok = await _confirmDelete(c);
      if (ok) await _doDelete(c);
    }
  }

  Widget _buildCard(BuildContext context, Capsule c, int index) {
    final l10n = S.of(context);

    final unlockLocal = DateTime.fromMillisecondsSinceEpoch(
      c.unlockAtUtcMs,
    ).toLocal();
    final createdLocal = DateTime.fromMillisecondsSinceEpoch(
      c.createdAtUtcMs,
    ).toLocal();

    final now = DateTime.now();
    final isLikelyUnlocked = now.isAfter(unlockLocal); // 仅 UI 展示，不用于安全
    final statusIcon = isLikelyUnlocked ? Icons.lock_open : Icons.lock;
    final statusText = isLikelyUnlocked ? '可解锁' : '未到期';

    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(c.origFilename, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('解锁：${DateFormat('yyyy-MM-dd HH:mm').format(unlockLocal)}'),
        Text('创建：${DateFormat('yyyy-MM-dd HH:mm').format(createdLocal)}'),
      ],
    );

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCapsule(c),
        onSecondaryTapDown: _isDesktop
            ? (d) => _showContextMenu(c, d.globalPosition)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon),
                const SizedBox(height: 4),
                Text(statusText, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: subtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isDesktop)
                  Builder(
                    builder: (btnCtx) => IconButton(
                      tooltip: '管理',
                      icon: const Icon(Icons.more_vert),
                      onPressed: () async {
                        // 使用按钮自身的 RenderBox 计算弹出位置，避免对 Sliver 的错误类型转换
                        final box = btnCtx.findRenderObject() as RenderBox?;
                        final overlay =
                            Overlay.of(btnCtx).context.findRenderObject()
                                as RenderBox;
                        if (box != null) {
                          final targetRect =
                              box.localToGlobal(Offset.zero) & box.size;
                          final position = RelativeRect.fromRect(
                            targetRect,
                            Offset.zero & overlay.size,
                          );
                          final selected = await showMenu<String>(
                            context: btnCtx,
                            position: position,
                            items: const [
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          );
                          if (selected == 'delete') {
                            final ok = await _confirmDelete(c);
                            if (ok) await _doDelete(c);
                          }
                        } else {
                          // 回退：使用默认位置
                          await _showContextMenu(c, const Offset(200, 200));
                        }
                      },
                    ),
                  ),
                // 拖拽把手：桌面更好用；移动端也可用
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 移动端：左滑删除（endToStart）
    if (_isMobile) {
      return Dismissible(
        key: ValueKey(c.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(c),
        onDismissed: (_) => _doDelete(c),
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.only(right: 16),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.delete, color: Colors.white),
              const SizedBox(width: 8),
              Text(l10n.Delete, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        child: card,
      );
    }

    // 桌面端：返回带 key 的子树给 ReorderableListView
    return KeyedSubtree(key: ValueKey(c.id), child: card);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (loadError != null) {
      body = Center(child: Text(loadError!));
    } else if (items.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('暂无胶囊')),
        ],
      );
    } else {
      body = ReorderableListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: _onReorder,
        itemCount: items.length,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final c = items[index];
          return _buildCard(context, c, index);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.capsuleListTitle),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.Refresh,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
