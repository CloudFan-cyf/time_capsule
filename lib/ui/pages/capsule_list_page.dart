import 'package:flutter/material.dart';
import '../../features/capsules/data/capsule_repository.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/time/time_service.dart';
import 'create_capsule_page.dart';
import '../../features/capsules/data/models/capsule.dart';
import 'package:time_capsule/generated/l10n.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).capsuleListTitle)),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final c = items[index];
          return ListTile(
            title: Text(c.title),
            subtitle: Text(
              '${c.origFilename} · ${S.of(context).unlockTime}: ${DateTime.fromMillisecondsSinceEpoch(c.unlockAtUtcMs).toLocal()}',
            ),
            onTap: () async {
              final res = await repo.openCapsule(c);
              if (res.opened) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.of(context).decryptSuccess)),
                );
                // TODO: navigate to preview or open with system
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res.error?.message ?? S.of(context).openFailed,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
