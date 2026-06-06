import 'package:flutter/material.dart';

import 'web_portal_styles.dart';

/// Outlined text field with clear icon when text is present.
class WebPortalFilterTextField extends StatefulWidget {
  const WebPortalFilterTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.suffixIcon,
    this.onCleared,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final VoidCallback? onCleared;

  @override
  State<WebPortalFilterTextField> createState() =>
      _WebPortalFilterTextFieldState();
}

class _WebPortalFilterTextFieldState extends State<WebPortalFilterTextField> {
  static const _inputHeight = 40.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant WebPortalFilterTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final suffix = widget.suffixIcon ??
        (hasText
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _clear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              )
            : null);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: _inputHeight,
        width: double.infinity,
        child: TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          style: const TextStyle(fontSize: 14, height: 1.25),
          decoration: WebPortalStyles.muiOutlinedField(
            label: widget.label,
            hint: widget.hint,
            suffixIcon: suffix,
          ).copyWith(
            isCollapsed: true,
            constraints: const BoxConstraints(
              minHeight: _inputHeight,
              maxHeight: _inputHeight,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }
}
