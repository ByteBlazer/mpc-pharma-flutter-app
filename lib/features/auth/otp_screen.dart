import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/providers.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> with CodeAutoFill {
  String _otp = '';
  bool _loading = false;
  String? _error;
  int _secondsLeft = 30;
  bool _timerRunning = true;
  String? _appCode;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initSmsAutofill();
    _loadAppCode();
  }

  Future<void> _loadAppCode() async {
    try {
      _appCode = await SmsAutoFill().getAppSignature;
    } catch (_) {
      _appCode = '';
    }
  }

  Future<void> _initSmsAutofill() async {
    await SmsAutoFill().listenForCode();
    listenForCode();
  }

  @override
  void codeUpdated() {
    final received = code;
    if (received != null && received.length == 6) {
      setState(() => _otp = received);
      _verify();
    }
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timerRunning = true;
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_timerRunning) return false;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        setState(() => _timerRunning = false);
        return false;
      }
      return true;
    });
  }

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).generateOtp(
            mobile: widget.phoneNumber,
            appCode: _appCode ?? '',
          );
      _startTimer();
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.verifyOtp(
        mobile: widget.phoneNumber,
        otp: _otp,
      );
      final prefs = await ref.read(prefsProvider.future);
      await SessionService(prefs).saveLoginSession(response);
      ref.read(lastLoginTimeProvider.notifier).state = DateTime.now();
      if (mounted) context.go(AppRoutes.home);
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    cancel();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        showBack: true,
        onBack: () => context.go(AppRoutes.login),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OTP verification',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the OTP sent to +91-${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PinFieldAutoFill(
                  codeLength: 6,
                  currentCode: _otp,
                  onCodeChanged: (value) {
                    setState(() => _otp = value ?? '');
                    if (_otp.length == 6) _verify();
                  },
                  decoration: BoxLooseDecoration(
                    gapSpace: 8,
                    textStyle: Theme.of(context).textTheme.titleLarge!,
                    strokeColorBuilder: FixedColorBuilder(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_timerRunning)
                  TextButton(
                    onPressed: null,
                    child: Text('Resend OTP in $_secondsLeft s'),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't receive the OTP?"),
                      TextButton(
                        onPressed: _loading ? null : _resend,
                        child: const Text('Resend OTP'),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                if (_loading)
                  const LoadingOverlay()
                else
                  FilledButton(
                    onPressed: _otp.length == 6 ? _verify : null,
                    child: const Text('VERIFY & PROCEED'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
