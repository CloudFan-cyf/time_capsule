import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'package:time_capsule/features/capsules/data/models/capsule.dart';

class CapsulePreviewPage extends StatefulWidget {
  final Capsule capsule;
  final File file;
  final bool deleteOnClose;

  const CapsulePreviewPage({
    super.key,
    required this.capsule,
    required this.file,
    this.deleteOnClose = true,
  });

  @override
  State<CapsulePreviewPage> createState() => _CapsulePreviewPageState();
}

class _CapsulePreviewPageState extends State<CapsulePreviewPage> {
  bool _deleted = false;

  @override
  void dispose() {
    // 删除临时文件（占位版 decrypt 返回 temp copy；后续真解密也建议如此）
    if (widget.deleteOnClose) {
      _safeDelete(widget.file);
    }
    super.dispose();
  }

  Future<void> _safeDelete(File f) async {
    if (_deleted) return;
    try {
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // ignore
    }
    _deleted = true;
  }

  bool _isImageExt(String ext) {
    return {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}.contains(ext);
  }

  bool _isTextExt(String ext) {
    return {
      '.txt',
      '.md',
      '.json',
      '.log',
      '.csv',
      '.yaml',
      '.yml',
    }.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(widget.file.path).toLowerCase();
    final filename = p.basename(widget.file.path);

    Widget content;

    if (_isImageExt(ext)) {
      content = InteractiveViewer(
        child: Center(
          child: Image.file(
            widget.file,
            errorBuilder: (_, _, _) => const Text('图片无法预览'),
          ),
        ),
      );
    } else if (_isTextExt(ext)) {
      content = FutureBuilder<String>(
        future: widget.file.readAsString(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('文本读取失败：${snap.error}'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snap.data ?? '',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          );
        },
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('暂不支持内置预览该类型文件（$ext）'),
            const SizedBox(height: 12),
            Text('文件名：$filename'),
            const SizedBox(height: 8),
            Text('路径：${widget.file.path}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await OpenFilex.open(widget.file.path);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('用系统打开'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.capsule.title)),
      body: content,
    );
  }
}
