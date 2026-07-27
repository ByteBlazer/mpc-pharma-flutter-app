import 'package:flutter/material.dart';

/// True when [error] looks like an auth/session failure (expired JWT, 401, etc.).
bool isAuthErrorMessage(Object? error) {
  final normalized = error?.toString().toLowerCase() ?? '';
  if (normalized.isEmpty) return false;
  return normalized.contains('token') ||
      normalized.contains('expired') ||
      normalized.contains('unauthorized') ||
      normalized.contains('401') ||
      normalized.contains('403') ||
      normalized.contains('forbidden');
}

/// Shared load-failure UI: Retry for normal errors, Login Again for auth errors.
class AppLoadErrorState extends StatelessWidget {
  const AppLoadErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLoginAgain,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLoginAgain;

  Future<void> _loginAgain(BuildContext context) async {
    await onLoginAgain();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthError = isAuthErrorMessage(message);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isAuthError
                        ? () => _loginAgain(context)
                        : onRetry,
                    child: Text(isAuthError ? 'Login Again' : 'Retry'),
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
