import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Footer actions for [WebPortalMuiDialog.show]; use [dialogContext] from the builder.
typedef WebPortalDialogActionsBuilder = List<Widget> Function(
  BuildContext dialogContext,
);

/// MUI [Dialog] layout for the web portal 
abstract final class WebPortalMuiDialog {
  static const _titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.6,
    letterSpacing: 0.15,
    color: Colors.black87,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.15,
    color: Colors.black87,
  );

  /// Shows a modal with MUI spacing — [maxWidth] 600 ≈ `maxWidth="sm"`.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    WebPortalDialogActionsBuilder? actionsBuilder,
    double maxWidth = 600,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 24,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text(title, style: _titleStyle),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: DefaultTextStyle(style: _bodyStyle, child: content),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _actionsRow(
                    dialogContext,
                    actionsBuilder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _actionsRow(
    BuildContext dialogContext,
    WebPortalDialogActionsBuilder? actionsBuilder,
  ) {
    final actions = actionsBuilder != null
        ? actionsBuilder(dialogContext)
        : [closeButton(dialogContext)];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ],
    );
  }

  static Widget closeButton(BuildContext dialogContext) {
    return TextButton(
      onPressed: () => Navigator.of(dialogContext).pop(),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
      child: const Text('Close'),
    );
  }

  /// MUI contained primary action (e.g. signature Download).
  static Widget downloadButton({
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Download'),
    );
  }

  /// Body text for simple modals (MUI `Typography` body1 + pre-wrap).
  static Widget bodyText(String text) {
    return SelectableText(
      text,
      style: _bodyStyle,
    );
  }
}
