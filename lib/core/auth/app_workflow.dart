import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../../routing/app_routes.dart';

enum AppWorkflow {
  logistics,
  customer,
  web;

  String get title => switch (this) {
        AppWorkflow.logistics => 'Logistics',
        AppWorkflow.customer => 'Customer',
        AppWorkflow.web => 'Web Portal',
      };

  String get subtitle => switch (this) {
        AppWorkflow.logistics => 'Scan, queue, trips & deliveries',
        AppWorkflow.customer => 'Orders & account',
        AppWorkflow.web => 'Browser-based tools',
      };

  IconData get icon => switch (this) {
        AppWorkflow.logistics => Icons.local_shipping_outlined,
        AppWorkflow.customer => Icons.storefront_outlined,
        AppWorkflow.web => Icons.language_outlined,
      };

  bool get isImplemented =>
      this == AppWorkflow.logistics || this == AppWorkflow.web;
}

class AppWorkflowResolver {
  AppWorkflowResolver._();

  static List<AppWorkflow> eligible(Set<UserType> roles) {
    final workflows = <AppWorkflow>[];
    if (_isLogisticsEligible(roles)) {
      workflows.add(AppWorkflow.logistics);
    }
    if (roles.contains(UserType.customer)) {
      workflows.add(AppWorkflow.customer);
    }
    if (roles.contains(UserType.webAccess)) {
      workflows.add(AppWorkflow.web);
    }
    return workflows;
  }

  static bool _isLogisticsEligible(Set<UserType> roles) {
    return HomeTab.values.any(
      (tab) => tab.visibleFor.any(roles.contains),
    );
  }

  static String routeFor(AppWorkflow workflow) => switch (workflow) {
        AppWorkflow.logistics => AppRoutes.home,
        AppWorkflow.customer => AppRoutes.workflowCustomer,
        AppWorkflow.web => AppRoutes.workflowWebHome,
      };

  /// After login: show workflow picker when 2+ options; otherwise go straight in.
  static String destinationRoute(Set<UserType> roles) {
    final workflows = eligible(roles);
    if (workflows.length <= 1) {
      return workflows.isNotEmpty
          ? routeFor(workflows.first)
          : AppRoutes.home;
    }
    return AppRoutes.workflowSelect;
  }
}
