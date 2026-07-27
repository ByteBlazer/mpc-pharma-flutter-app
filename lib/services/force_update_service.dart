import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../features/force_update/app_config_models.dart';
import '../utils/app_version_compare.dart';
import '../utils/open_external_url.dart';

enum ForceUpdateCheckResult {
  notApplicable,
  upToDate,
  updateRequired,
  checkFailed,
}

class ForceUpdateEvaluation {
  const ForceUpdateEvaluation({
    required this.result,
    this.config,
    this.currentVersion,
    this.minimumVersion,
    this.failureMessage,
  });

  final ForceUpdateCheckResult result;
  final AppConfig? config;
  final String? currentVersion;
  final String? minimumVersion;
  final String? failureMessage;

  bool get isBlocked =>
      result == ForceUpdateCheckResult.updateRequired ||
      result == ForceUpdateCheckResult.checkFailed;

  String get displayMessage {
    if (result == ForceUpdateCheckResult.checkFailed) {
      return failureMessage ??
          'Connect to the internet to verify your app version.';
    }
    final message = config?.updateMessage?.trim();
    if (message != null && message.isNotEmpty) return message;
    return 'A new version is required. Please update to continue.';
  }

  String? get storeUrl {
    final config = this.config;
    if (config == null) return null;
    if (!kIsWeb && Platform.isAndroid) {
      return config.androidStoreUrl;
    }
    if (!kIsWeb && Platform.isIOS) {
      return config.iosStoreUrl;
    }
    return null;
  }
}

abstract final class ForceUpdateService {
  static bool get appliesToCurrentPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<ForceUpdateEvaluation> evaluate({
    ApiClient? apiClient,
  }) async {
    if (!appliesToCurrentPlatform) {
      return const ForceUpdateEvaluation(result: ForceUpdateCheckResult.notApplicable);
    }

    final client = apiClient ?? ApiClient();
    AppConfig config;
    try {
      config = await client.getAppConfig();
    } catch (_) {
      return const ForceUpdateEvaluation(
        result: ForceUpdateCheckResult.checkFailed,
        failureMessage:
            'Unable to verify your app version. Connect to the internet and try again.',
      );
    } finally {
      if (apiClient == null) {
        client.close();
      }
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final isAndroid = Platform.isAndroid;
    final minimumVersion = config.minimumVersionFor(isAndroid: isAndroid)?.trim();

    if (minimumVersion == null || minimumVersion.isEmpty) {
      return ForceUpdateEvaluation(
        result: ForceUpdateCheckResult.upToDate,
        config: config,
        currentVersion: currentVersion,
      );
    }

    if (isAppVersionLowerThan(currentVersion, minimumVersion)) {
      return ForceUpdateEvaluation(
        result: ForceUpdateCheckResult.updateRequired,
        config: config,
        currentVersion: currentVersion,
        minimumVersion: minimumVersion,
      );
    }

    return ForceUpdateEvaluation(
      result: ForceUpdateCheckResult.upToDate,
      config: config,
      currentVersion: currentVersion,
      minimumVersion: minimumVersion,
    );
  }

  static Future<void> openStoreListing(String? storeUrl) async {
    final trimmed = storeUrl?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await openUrlInNewTab(trimmed);
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final packageInfo = await PackageInfo.fromPlatform();
      final marketUri = Uri.parse('market://details?id=${packageInfo.packageName}');
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=${packageInfo.packageName}',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// Tries Play immediate in-app update first on Android, then store URL.
  static Future<void> startUpdateFlow(ForceUpdateEvaluation evaluation) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable &&
            info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      } catch (_) {
        // Fall back to store URL (debug builds, sideload, Play unavailable).
      }
    }

    await openStoreListing(evaluation.storeUrl);
  }
}
