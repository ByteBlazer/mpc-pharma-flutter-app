import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/api_message.dart';
import '../../widgets/app_load_error_state.dart';
import '../trip_dashboard/trip_dashboard_helpers.dart';
import 'delivery_tracking_models.dart';

const _compactBreakpoint = 560.0;

Future<void> showDocLineItemsDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String docId,
  required Future<void> Function() onLoginAgain,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _DocLineItemsDialog(
      apiClient: apiClient,
      docId: docId,
      onLoginAgain: onLoginAgain,
    ),
  );
}

class _DocLineItemsDialog extends StatefulWidget {
  const _DocLineItemsDialog({
    required this.apiClient,
    required this.docId,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final String docId;
  final Future<void> Function() onLoginAgain;

  @override
  State<_DocLineItemsDialog> createState() => _DocLineItemsDialogState();
}

class _DocLineItemsDialogState extends State<_DocLineItemsDialog> {
  late Future<DocLineItemsResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.getDocLineItems(docId: widget.docId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.apiClient.getDocLineItems(docId: widget.docId);
    });
    await _future;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      switch (error.statusCode) {
        case 403:
          return 'You cannot view line items for this document.';
        case 404:
          return 'Document not found.';
        default:
          return error.toString();
      }
    }
    return formatApiMessage(error.toString());
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < _compactBreakpoint;
    final horizontalInset = isCompact ? 16.0 : 40.0;
    final dialogWidth = isCompact
        ? screenSize.width - (horizontalInset * 2)
        : 720.0;
    final maxContentHeight = screenSize.height * (isCompact ? 0.62 : 0.7);

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: isCompact ? 20 : 24,
      ),
      title: Text(
        'Line items — ${widget.docId}',
        maxLines: isCompact ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: isCompact ? 16 : 20),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: FutureBuilder<DocLineItemsResponse>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: 'Could not load line items',
                message: _errorMessage(snapshot.error!),
                onRetry: _reload,
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final response = snapshot.data!;
            if (response.lineItems.isEmpty) {
              return const Text('No line items available.');
            }

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    response.lineItems.length == 1
                        ? '1 line item in this invoice'
                        : '${response.lineItems.length} line items in this invoice',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _LineItemsTable(
                        lineItems: response.lineItems,
                        isCompact: isCompact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InvoiceTotalBar(
                    total: response.invoiceTotal,
                    isCompact: isCompact,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InvoiceTotalBar extends StatelessWidget {
  const _InvoiceTotalBar({required this.total, required this.isCompact});

  final double total;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final formatted = formatInrAmount(total.toStringAsFixed(2));
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 14,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Invoice total',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            formatted,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineItemsTable extends StatelessWidget {
  const _LineItemsTable({
    required this.lineItems,
    required this.isCompact,
  });

  final List<DocLineItem> lineItems;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lineItems.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _LineItemCard(item: lineItems[index]),
          ],
        ],
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(0.6),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
          ),
          children: const [
            _TableHeaderCell('Medicine'),
            _TableHeaderCell('Unit'),
            _TableHeaderCell('Qty'),
            _TableHeaderCell('Unit price'),
            _TableHeaderCell('Amount'),
          ],
        ),
        for (final item in lineItems)
          TableRow(
            children: [
              _TableBodyCell(item.medicineName),
              _TableBodyCell(item.unit),
              _TableBodyCell('${item.qty}'),
              _TableBodyCell(
                formatInrAmount(item.unitPrice.toStringAsFixed(2)),
              ),
              _TableBodyCell(
                formatInrAmount(item.lineItemPrice.toStringAsFixed(2)),
              ),
            ],
          ),
      ],
    );
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.item});

  final DocLineItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.medicineName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatInrAmount(item.lineItemPrice.toStringAsFixed(2)),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.qty} ${item.unit} · '
            '${formatInrAmount(item.unitPrice.toStringAsFixed(2))} each',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TableBodyCell extends StatelessWidget {
  const _TableBodyCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        value,
        style: const TextStyle(color: Colors.black87, fontSize: 13),
      ),
    );
  }
}
