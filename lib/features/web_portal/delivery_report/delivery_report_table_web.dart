import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/models/web_portal_models.dart';

/// Renders the full report table in the browser DOM (React-equivalent performance).
class DeliveryReportTableView extends StatefulWidget {
  const DeliveryReportTableView({
    super.key,
    required this.tableHtml,
    required this.rows,
    required this.onViewSignature,
    required this.onViewComment,
  });

  final String tableHtml;
  final List<WebPortalDeliveryReportItem> rows;
  final void Function(String docId) onViewSignature;
  final void Function(String docId) onViewComment;

  @override
  State<DeliveryReportTableView> createState() =>
      _DeliveryReportTableViewState();
}

class _DeliveryReportTableViewState extends State<DeliveryReportTableView> {
  static int _nextViewId = 0;
  late final String _viewType;
  web.HTMLDivElement? _root;
  bool _factoryRegistered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'delivery-report-table-${_nextViewId++}';
    _registerFactory();
    _setHtml(widget.tableHtml);
  }

  @override
  void didUpdateWidget(covariant DeliveryReportTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableHtml != widget.tableHtml) {
      _setHtml(widget.tableHtml);
    }
  }

  void _registerFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;
    final initialHtml = widget.tableHtml;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final root = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'auto'
        ..style.boxSizing = 'border-box'
        ..innerHTML = initialHtml.toJS;
      _root = root;
      root.addEventListener('click', _handleClick.toJS);
      return root;
    });
  }

  void _setHtml(String html) {
    final root = _root;
    if (root == null) return;
    root.innerHTML = html.toJS;
  }

  void _handleClick(web.Event event) {
    web.Element? el = event.target as web.Element?;
    while (el != null) {
      final action = el.getAttribute('data-dr-action');
      if (action != null && action.isNotEmpty) {
        final docId = el.getAttribute('data-dr-doc-id');
        if (docId == null || docId.isEmpty) return;
        if (action == 'signature') {
          widget.onViewSignature(docId);
        } else if (action == 'comment') {
          widget.onViewComment(docId);
        }
        return;
      }
      el = el.parentElement;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_root == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setHtml(widget.tableHtml);
      });
    }
    return HtmlElementView(viewType: _viewType);
  }
}
