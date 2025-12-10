import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../repository/capsule_repository.dart';
import '../../services/crypto_service.dart';
import '../../services/time_service.dart';
import 'create_capsule_page.dart';
import '../../models/capsule.dart';

class CapsuleListPage extends StatefulWidget {
  const CapsuleListPage({super.key});

  @override
  State<CapsuleListPage> createState() => _CapsuleListPageState();
}

class _CapsuleListPageState extends State<CapsuleListPage> {
  late final CapsuleRepository repo;
  List<Capsule> items = [];

  @override
  void initState() {
    super.initState();
    repo = CapsuleRepositoryImpl(
      cryptoService: CryptoServiceImpl(),
      timeService: TimeServiceImpl(),
    );
    _load();
  }

  Future<void> _load() async {
    final list = await repo.listCapsules();
    setState(() => items = list);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.capsuleListTitle)),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final c = items[index];
          return ListTile(
            title: Text(c.title),
            subtitle: Text(
              '${c.origFilename} · ${l10n.unlockTime(DateTime.fromMillisecondsSinceEpoch(c.unlockAtUtcMs).toLocal().toString())}',
            ),
            onTap: () async {
              final res = await repo.openCapsule(c);
              if (res.opened) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.decryptSuccess)));
                // TODO: navigate to preview or open with system
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.error?.message ?? l10n.openFailed),
                  ),
                );
              }
            },
          );
        },
      ),
      // FAB handled by AppShell for consistency; keep page simple
    );
  }
}
