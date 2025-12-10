import 'dart:io';
import 'package:flutter/material.dart';
import '../../repository/capsule_repository.dart';
import '../../services/crypto_service.dart';
import '../../services/time_service.dart';
import '../../models/capsule.dart';

class CreateCapsulePage extends StatefulWidget {
  const CreateCapsulePage({super.key});

  @override
  State<CreateCapsulePage> createState() => _CreateCapsulePageState();
}

class _CreateCapsulePageState extends State<CreateCapsulePage> {
  final titleCtrl = TextEditingController();
  DateTime? unlockAt;
  File? srcFile; // TODO: integrate a file picker later
  late final CapsuleRepository repo;

  @override
  void initState() {
    super.initState();
    repo = CapsuleRepositoryImpl(
      cryptoService: CryptoServiceImpl(),
      timeService: TimeServiceImpl(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建胶囊')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    unlockAt == null
                        ? '请选择解锁时间'
                        : '解锁时间：${unlockAt!.toLocal()}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      final dt = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        time?.hour ?? 0,
                        time?.minute ?? 0,
                      );
                      setState(() => unlockAt = dt.toUtc());
                    }
                  },
                  child: const Text('选择时间'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(srcFile?.path ?? '请选择源文件（稍后实现文件选择）')),
                TextButton(onPressed: () {}, child: const Text('选择文件')),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                if (srcFile == null ||
                    unlockAt == null ||
                    titleCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('请完整填写信息')));
                  return;
                }
                try {
                  final params = CapsuleParams(
                    title: titleCtrl.text,
                    unlockAtUtcMs: unlockAt!.millisecondsSinceEpoch,
                  );
                  await repo.createCapsuleFromFile(srcFile!, params);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('创建失败：$e')));
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}
