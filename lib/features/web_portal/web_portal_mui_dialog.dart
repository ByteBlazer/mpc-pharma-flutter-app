import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'web_portal_styles.dart';
import 'web_portal_theme.dart';

/// Result from doc search — keeps dialog open with a message or closes on success.
class FindByDocIdOutcome {
  const FindByDocIdOutcome({
    this.closeDialog = false,
    this.dialogMessage,
    this.dialogIsError = false,
    this.snackMessage,
  });

  final bool closeDialog;
  final String? dialogMessage;
  final bool dialogIsError;
  final String? snackMessage;

  static FindByDocIdOutcome validation(String message) =>
      FindByDocIdOutcome(dialogMessage: message);

  static FindByDocIdOutcome error(String message) =>
      FindByDocIdOutcome(dialogMessage: message, dialogIsError: true);

  static const FindByDocIdOutcome found = FindByDocIdOutcome(closeDialog: true);
}

typedef FindByDocIdSearchCallback = Future<FindByDocIdOutcome> Function(
  String docId,
);

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
              _actionsRow(dialogContext, actionsBuilder),
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
    return dialogActionsBar(actions);
  }

  /// MUI `DialogActions` row — right-aligned with 8px gap between buttons.
  static Widget dialogActionsBar(List<Widget> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }

  static Widget closeButton(BuildContext dialogContext) {
    return _MuiDialogTextButton(
      label: 'CLOSE',
      onPressed: () => Navigator.of(dialogContext).pop(),
    );
  }

  /// MUI `DialogActions` text button (Cancel).
  static Widget cancelActionButton(
    BuildContext dialogContext, {
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return _MuiDialogTextButton(
      label: 'CANCEL',
      onPressed: enabled
          ? (onPressed ?? () => Navigator.of(dialogContext).pop())
          : null,
    );
  }

  /// MUI `DialogActions` contained primary button.
  static Widget containedActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return _MuiDialogContainedButton(
      label: label.toUpperCase(),
      onPressed: onPressed,
    );
  }

  /// Outlined form field decoration — MUI `TextField` `variant="outlined"`.
  static const _errorOutlineBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
    borderSide: BorderSide(color: WebPortalStyles.errorMain),
  );

  static InputDecoration outlinedFieldLabel(
    String label, {
    bool required = false,
    bool error = false,
  }) {
    final fieldHeight = WebPortalStyles.dialogFormFieldHeight;
    final labelSizeStyle = WebPortalStyles.dialogFormFloatingLabelStyle.copyWith(
      color: null,
    );
    final decoration = InputDecoration(
      label: required
          ? Text.rich(
              TextSpan(
                text: label,
                style: labelSizeStyle,
                children: [
                  TextSpan(
                    text: ' *',
                    style: labelSizeStyle.copyWith(
                      color: WebPortalStyles.errorMain,
                    ),
                  ),
                ],
              ),
            )
          : Text(label, style: labelSizeStyle),
      counterText: '',
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      constraints: BoxConstraints(
        minHeight: fieldHeight,
        maxHeight: fieldHeight,
      ),
    );
    if (!error) return decoration;
    return decoration.copyWith(
      enabledBorder: _errorOutlineBorder,
      focusedBorder: _errorOutlineBorder,
      errorBorder: _errorOutlineBorder,
      focusedErrorBorder: _errorOutlineBorder,
    );
  }

  /// MUI result dialog after create/update (Success or Error).
  static Future<void> showResultDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 24,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
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
                child: bodyText(message),
              ),
              dialogActionsBar([
                containedActionButton(
                  label: 'OK',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ]),
            ],
          ),
        ),
      ),
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

  /// Find By Doc ID — matches React `TripDashboard` doc search dialog.
  static Future<void> showFindByDocId({
    required BuildContext context,
    required FindByDocIdSearchCallback onSearch,
    void Function(String message)? onSnack,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Theme(
        data: WebPortalTheme.light(),
        child: _FindByDocIdDialog(
          onSearch: onSearch,
          onSnack: onSnack,
        ),
      ),
    );
  }

  /// Force End Trip confirmation — matches React `TripDashboard` warning dialog.
  static Future<bool?> showForceEndTripWarning({
    required BuildContext context,
    required int tripId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 24,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                decoration: const BoxDecoration(
                  color: WebPortalStyles.errorMain,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: const Text(
                  '⚠️ Force End Trip - Warning',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    letterSpacing: 0.15,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _forceEndWarningAlert(),
                    const SizedBox(height: 16),
                    Text(
                      'Are you sure you want to force end Trip #$tripId?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.43,
                        letterSpacing: 0.15,
                        color: WebPortalStyles.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.25,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: WebPortalStyles.errorMain,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                        child: const Text('Yes, Force End Trip'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _muiAlert({
    required String message,
    required bool isError,
  }) {
    final bg = isError ? const Color(0xFFFDEDED) : const Color(0xFFE5F6FD);
    final fg = isError ? const Color(0xFF5F2120) : const Color(0xFF014361);
    final icon = isError ? Icons.error_outline : Icons.info_outline;
    final iconColor =
        isError ? WebPortalStyles.errorMain : const Color(0xFF0288D1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.43,
                letterSpacing: 0.15,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _forceEndWarningAlert() {
    const bodyStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.43,
      letterSpacing: 0.15,
      color: Color(0xFF663C00),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: WebPortalStyles.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: WebPortalStyles.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.43,
                    letterSpacing: 0.15,
                    color: Color(0xFF663C00),
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: bodyStyle,
                    children: const [
                      TextSpan(
                        text:
                            'All pending deliveries will be automatically marked as ',
                      ),
                      TextSpan(
                        text: 'FAILED DELIVERY',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            '. They can be boarded on the next trip if needed.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FindByDocIdDialog extends StatefulWidget {
  const _FindByDocIdDialog({
    required this.onSearch,
    this.onSnack,
  });

  final FindByDocIdSearchCallback onSearch;
  final void Function(String message)? onSnack;

  @override
  State<_FindByDocIdDialog> createState() => _FindByDocIdDialogState();
}

class _FindByDocIdDialogState extends State<_FindByDocIdDialog> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _errorIsSevere = false;
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final docId = _controller.text.trim();
    if (docId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a document ID.';
        _errorIsSevere = false;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _searching = true;
    });

    try {
      final outcome = await widget.onSearch(docId);
      if (!mounted) return;

      if (outcome.closeDialog) {
        Navigator.of(context).pop();
        final snack = outcome.snackMessage;
        if (snack != null) widget.onSnack?.call(snack);
        return;
      }

      setState(() {
        _searching = false;
        _errorMessage = outcome.dialogMessage;
        _errorIsSevere = outcome.dialogIsError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _errorMessage = 'Doc ID not found.';
        _errorIsSevere = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text(
                    'Find By Doc ID',
                    style: WebPortalMuiDialog._titleStyle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _controller,
                        enabled: !_searching,
                        decoration: const InputDecoration(
                          labelText: 'Document ID',
                          hintText: 'Enter document ID to search',
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        WebPortalMuiDialog._muiAlert(
                          message: _errorMessage!,
                          isError: _errorIsSevere,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _searching
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.25,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _searching ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                          child: Text(_searching ? 'Searching...' : 'Find'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_searching)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Searching document... Please wait.',
                          style: TextStyle(
                            fontSize: 14,
                            color: WebPortalStyles.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// MUI `DialogActions` text `Button` — uppercase, hover wash.
class _MuiDialogTextButton extends StatefulWidget {
  const _MuiDialogTextButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_MuiDialogTextButton> createState() => _MuiDialogTextButtonState();
}

class _MuiDialogTextButtonState extends State<_MuiDialogTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: WebPortalStyles.dialogActionTextLabelStyle.copyWith(
                color: enabled
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// MUI `DialogActions` contained `Button` — matches page primary buttons.
class _MuiDialogContainedButton extends StatefulWidget {
  const _MuiDialogContainedButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_MuiDialogContainedButton> createState() =>
      _MuiDialogContainedButtonState();
}

class _MuiDialogContainedButtonState extends State<_MuiDialogContainedButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled
                ? (_hovered
                    ? WebPortalStyles.usersPrimaryDark
                    : AppColors.primary)
                : AppColors.primary.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(4),
            boxShadow: enabled && _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: WebPortalStyles.dialogActionContainedLabelStyle.copyWith(
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
