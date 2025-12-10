import 'package:flutter/material.dart';
import '../../features/capsules/data/capsule_repository.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/time/time_service.dart';
import '../../features/capsules/data/models/capsule.dart';
import 'package:time_capsule/generated/l10n.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final CapsuleRepository repo;
  int total = 0;
  int unlockable = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repo = CapsuleRepositoryImpl(
      cryptoService: CryptoServiceImpl(),
      timeService: TimeServiceImpl(),
    );
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    final list = await repo.listCapsules();
    final nowCheck = TimeServiceImpl();
    int canOpen = 0;
    for (final c in list) {
      final ok = await nowCheck.canOpen(unlockAtUtcMs: c.unlockAtUtcMs);
      if (ok) canOpen++;
    }
    setState(() {
      total = list.length;
      unlockable = canOpen;
      loading = false;
    });
  }

  Widget _statCard(String title, String value, {Color? color, IconData? icon}) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard(
            S.of(context).totalCapsules,
            '$total',
            icon: Icons.inventory_2_outlined,
          ),
          _statCard(
            S.of(context).unlockable,
            '$unlockable',
            icon: Icons.lock_open_outlined,
          ),
          _statCard(
            S.of(context).locked,
            '${total - unlockable}',
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '快速操作',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text('使用右下角按钮创建新胶囊或切换到列表页进行管理。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
