import 'package:flutter/material.dart';

/// Shows a blocking progress dialog while [work] runs; always closes it.
Future<T> withProgress<T>(BuildContext context, String message, Future<T> work) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
  try {
    return await work;
  } finally {
    navigator.pop();
  }
}
