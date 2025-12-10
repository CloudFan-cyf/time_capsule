import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../features/capsules/data/capsule_repository.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/time/time_service.dart';
import '../../features/capsules/data/models/capsule.dart';
import 'package:time_capsule/generated/l10n.dart';

class CreateCapsulePage extends StatefulWidget {
  const CreateCapsulePage({super.key});

  @override
  State<CreateCapsulePage> createState() => _CreateCapsulePageState();
}

class _CreateCapsulePageState extends State<CreateCapsulePage> {
  final titleCtrl = TextEditingController();
  DateTime? unlockAt;
  File? pickedFile; // TODO: integrate a file picker later
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
      appBar: AppBar(title: Text(S.of(context).createCapsule)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: S.of(context).capsuleName),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    unlockAt == null
                        ? S.of(context).selectUnlockTime
                        : S.of(context).unlockTime(unlockAt!.toLocal()),
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
                  child: Text(S.of(context).selectUnlockTime),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(pickedFile?.path ?? S.of(context).selectFile),
                ),
                TextButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      withData: true,
                    );
                    if (result == null || result.files.isEmpty) return;

                    final picked = result.files.first;
                    setState(() {
                      pickedFile = File(picked.path!);
                    });
                  },
                  child: Text(S.of(context).selectFile),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                if (pickedFile == null ||
                    unlockAt == null ||
                    titleCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).pleaseFillAll)),
                  );
                  return;
                }
                try {
                  final params = CapsuleParams(
                    title: titleCtrl.text,
                    unlockAtUtcMs: unlockAt!.millisecondsSinceEpoch,
                  );
                  await repo.createCapsuleFromFile(pickedFile!, params);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(S.of(context).createFailed(e.toString())),
                    ),
                  );
                }
              },
              child: Text(S.of(context).createCapsule),
            ),
          ],
        ),
      ),
    );
  }
}
