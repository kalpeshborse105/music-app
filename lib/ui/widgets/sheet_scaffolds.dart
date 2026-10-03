import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A simple text-input dialog used for creating/renaming playlists.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String hint = '',
  String? initialValue,
  String confirmLabel = 'Save',
}) async {
  final TextEditingController controller =
      TextEditingController(text: initialValue ?? '');
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (String v) => Navigator.pop(ctx, v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

/// Reusable confirmation dialog.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// A section title used inside bottom sheets.
class SheetSectionTitle extends StatelessWidget {
  final String text;
  const SheetSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
