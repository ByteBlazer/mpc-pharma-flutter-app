import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../routing/app_routes.dart';
import 'web_portal_styles.dart';

class WebPortalReportsScreen extends StatelessWidget {
  const WebPortalReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports',
            style: WebPortalStyles.pageTitle(context),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a report to view detailed information and analytics.',
            style: TextStyle(
              fontSize: 16,
              color: WebPortalStyles.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;
              const gap = 24.0;
              final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cellW,
                    child: _ReportCard(
                      title: 'Delivery Report',
                      description:
                          'View delivery status reports for documents with DELIVERED or UNDELIVERED status',
                      icon: Icons.local_shipping,
                      onTap: () => context.go(AppRoutes.workflowWebDeliveryReport),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        child: Material(
          elevation: _hovered ? 4 : 1,
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: WebPortalStyles.textSecondary,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
