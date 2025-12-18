import 'package:flutter/material.dart';

void showSnack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
