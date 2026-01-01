import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:time_capsule/core/storage/file_store.dart';
import 'package:time_capsule/core/crypto/crypto_service.dart';
import 'package:time_capsule/core/time/time_service.dart';
import 'package:time_capsule/features/capsules/data/capsule_events.dart';
import 'package:time_capsule/features/capsules/data/capsule_repository.dart';
import 'package:time_capsule/features/capsules/data/models/capsule.dart';
import 'package:time_capsule/generated/l10n.dart';
import 'package:time_capsule/utlis/showsnackbar.dart';

class CreateCapsulePage extends StatefulWidget {
  const CreateCapsulePage({super.key});

  @override
  State<CreateCapsulePage> createState() => _CreateCapsulePageState();
}

class _CreateCapsulePageState extends State<CreateCapsulePage> {
  final titleCtrl = TextEditingController();
  DateTime? unlockAt;
  List<File> pickedFiles = [];

  late final CapsuleRepository repo;
  bool _creating = false;
  CryptoProgress? _progress;

  bool _deleteSource = false;

  @override
  void initState() {
    super.initState();
    final fs = FileStoreImpl();
    repo = CapsuleRepositoryImpl(
      cryptoService: CryptoServiceImpl(fileStore: fs),
      timeService: TimeServiceImpl(),
      fileStore: fs,
    );
  }

  Future<bool> _confirmDeleteSources(S l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteSourcesConfirmTitle),
        content: Text(l10n.deleteSourcesConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.Confirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createCapsule)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: l10n.capsuleName),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    unlockAt == null
                        ? l10n.selectUnlockTime
                        : l10n.unlockTime(unlockAt!.toLocal()),
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
                  child: Text(l10n.selectUnlockTime),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pickedFiles.isEmpty
                        ? l10n.selectFile
                        : l10n.selectedFilesCount(pickedFiles.length),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      withData: false,
                      allowMultiple: true,
                    );
                    if (result == null || result.files.isEmpty) return;

                    final files = result.files
                        .where((f) => f.path != null)
                        .map((f) => File(f.path!))
                        .toList();
                    if (files.isEmpty) return;

                    setState(() {
                      pickedFiles = files;
                    });
                  },
                  child: Text(l10n.selectFile),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ✅ 自动删除源文件开关（勾选时弹确认）
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _deleteSource,
              title: Text(l10n.deleteSourcesToggleTitle),
              subtitle: Text(l10n.deleteSourcesToggleSubtitle),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _creating
                  ? null
                  : (v) async {
                      final next = v ?? false;
                      if (next) {
                        final ok = await _confirmDeleteSources(l10n);
                        if (!mounted) return;
                        if (!ok) {
                          setState(() => _deleteSource = false);
                          return;
                        }
                      }
                      setState(() => _deleteSource = next);
                    },
            ),

            if (_creating) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_progress == null) ? null : _progress!.fraction,
              ),
              const SizedBox(height: 8),
              Text(
                _progress == null
                    ? l10n.encrypting
                    : l10n.encryptingWithProgress(
                        _progress!.fileName,
                        _progress!.percent,
                      ),
              ),
            ],

            const Spacer(),
            ElevatedButton(
              onPressed: _creating
                  ? null
                  : () async {
                      if (pickedFiles.isEmpty ||
                          unlockAt == null ||
                          titleCtrl.text.isEmpty) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.pleaseFillAll)),
                        );
                        return;
                      }
                      try {
                        setState(() {
                          _creating = true;
                          _progress = null;
                        });
                        final params = CapsuleParams(
                          title: titleCtrl.text,
                          unlockAtUtcMs: unlockAt!.millisecondsSinceEpoch,
                        );
                        await repo.createCapsuleFromFiles(
                          pickedFiles,
                          params,
                          onProgress: (p) {
                            if (!mounted) return;
                            setState(() => _progress = p);
                          },
                          deleteSourceFiles: _deleteSource,
                        );
                        notifyCapsulesChanged();
                        if (!mounted) return;
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (!mounted) return;
                        showSnack(context, l10n.createFailed(e.toString()));
                      } finally {
                        if (mounted) {
                          setState(() => _creating = false);
                        }
                      }
                    },
              child: Text(l10n.createCapsule),
            ),
          ],
        ),
      ),
    );
  }
}
