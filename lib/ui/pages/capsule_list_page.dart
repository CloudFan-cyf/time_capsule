import 'dart:io';

import 'package:flutter/material.dart';
import 'package:time_capsule/generated/l10n.dart';

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

    if (res.opened && res.decryptedFile != null) {
      final file = res.decryptedFile!;
      // 进入预览页（关闭时会自动删除临时文件，见 PreviewPage 实现）
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CapsulePreviewPage(capsule: c, file: file, deleteOnClose: true),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.error?.message ?? S.of(context).openFailed)),
    );
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
      body = Center(child: Text('暂无胶囊')); // 你也可以加到 l10n
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final c = items[index];
          final unlockLocal = DateTime.fromMillisecondsSinceEpoch(
            c.unlockAtUtcMs,
          ).toLocal();

          return ListTile(
            title: Text(c.title),
            subtitle: Text(
              '${c.origFilename} · ${l10n.unlockTime(unlockLocal)}',
            ),
            onTap: () => _openCapsule(c),
          );
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
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
