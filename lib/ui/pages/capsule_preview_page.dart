import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'package:time_capsule/features/capsules/data/models/capsule.dart';

class CapsulePreviewPage extends StatefulWidget {
  final Capsule capsule;
  final List<File> files;

  const CapsulePreviewPage({
    super.key,
    required this.capsule,
    required this.files,
  });

  @override
  State<CapsulePreviewPage> createState() => _CapsulePreviewPageState();
}

class _CapsulePreviewPageState extends State<CapsulePreviewPage> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Widget _buildSingleFileContent(File file) {
    final ext = p.extension(file.path).toLowerCase();
    final filename = p.basename(file.path);

    if (_isImageExt(ext)) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(
            file,
            errorBuilder: (_, __, ___) => const Text('图片无法预览'),
          ),
        ),
      );
    } else if (_isTextExt(ext)) {
      return FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('文本读取失败：${snap.error}'));
          }
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
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('暂不支持内置预览该类型文件（$ext）'),
            const SizedBox(height: 12),
            Text('文件名：$filename'),
            const SizedBox(height: 8),
            Text('路径：${file.path}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await OpenFilex.open(file.path);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('用系统打开'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files;

    if (files.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.capsule.title)),
        body: const Center(child: Text('胶囊中没有文件')),
      );
    }

    // 单文件：沿用原来的逻辑
    if (files.length == 1) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.capsule.title)),
        body: _buildSingleFileContent(files.first),
      );
    }

    final exts = files.map((f) => p.extension(f.path).toLowerCase()).toList();
    final allImages = exts.every(_isImageExt);

    // 多文件 & 全是图片：相册式浏览
    if (allImages) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.capsule.title)),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                },
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return InteractiveViewer(
                    child: Center(
                      child: Image.file(
                        file,
                        errorBuilder: (_, __, ___) => const Text('图片无法预览'),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentIndex + 1}/${files.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Flexible(
                    child: Text(
                      p.basename(files[_currentIndex].path),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // 混合类型 / 非全部图片：列出文件列表，点击用系统打开或单文件预览
    return Scaffold(
      appBar: AppBar(title: Text(widget.capsule.title)),
      body: ListView.separated(
        itemCount: files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final f = files[index];
          final ext = p.extension(f.path).toLowerCase();
          final name = p.basename(f.path);

          IconData icon;
          if (_isImageExt(ext)) {
            icon = Icons.image;
          } else if (_isTextExt(ext)) {
            icon = Icons.description;
          } else {
            icon = Icons.insert_drive_file;
          }

          return ListTile(
            leading: Icon(icon),
            title: Text(name),
            subtitle: Text(f.path),
            onTap: () async {
              // 简单起见：混合模式下直接用系统打开
              await OpenFilex.open(f.path);
            },
          );
        },
      ),
    );
  }
}
