import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../api/auth_token_store.dart';
import '../../app_environment.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    ApiClient? apiClient,
    AuthTokenStore? tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final ApiClient? _apiClient;
  final AuthTokenStore? _tokenStore;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final ApiClient _apiClient;
  late final AuthTokenStore _tokenStore;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isCheckingSession = true;
  bool _isLoggedIn = false;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _apiClient = widget._apiClient ?? ApiClient();
    _tokenStore = widget._tokenStore ?? AuthTokenStore();
    _loadExistingSession();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    if (widget._apiClient == null) {
      _apiClient.close();
    }
    super.dispose();
  }

  Future<void> _loadExistingSession() async {
    final token = await _tokenStore.readToken();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null;
      _isCheckingSession = false;
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() => _errorMessage = 'Enter a valid 10 digit mobile number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.generateOtp(
        mobile: phone,
        appCode: AppEnvironment.appCode,
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      _startResendTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (!_isValidOtp(otp)) {
      setState(() => _errorMessage = 'Enter the 6 digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.verifyOtp(mobile: phone, otp: otp);
      if (response.accessToken == null || response.accessToken!.isEmpty) {
        throw Exception('OTP verified, but no access token was returned.');
      }
      if (!mounted) return;
      setState(() => _isLoggedIn = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await _tokenStore.clearToken();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _otpSent = false;
      _errorMessage = null;
      _phoneController.clear();
      _otpController.clear();
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      if (mounted) setState(() => _resendSeconds -= 1);
    });
  }

  bool _isValidPhone(String phone) {
    return phone.length == 10 && phone.runes.every(_isAsciiDigit);
  }

  bool _isValidOtp(String otp) {
    return otp.length == 6 && otp.runes.every(_isAsciiDigit);
  }

  bool _isAsciiDigit(int rune) => rune >= 48 && rune <= 57;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('MPC Pharma')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _isCheckingSession
                  ? const Center(child: CircularProgressIndicator())
                  : _isLoggedIn
                  ? _SignedInCard(onLogout: _logout)
                  : _LoginCard(
                      phoneController: _phoneController,
                      otpController: _otpController,
                      otpSent: _otpSent,
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      resendSeconds: _resendSeconds,
                      onSendOtp: _sendOtp,
                      onVerifyOtp: _verifyOtp,
                      onChangePhone: () {
                        setState(() {
                          _otpSent = false;
                          _errorMessage = null;
                          _otpController.clear();
                        });
                      },
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: colorScheme.primary,
        padding: const EdgeInsets.all(12),
        child: Text(
          AppEnvironment.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.phoneController,
    required this.otpController,
    required this.otpSent,
    required this.isLoading,
    required this.errorMessage,
    required this.resendSeconds,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onChangePhone,
  });

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final bool otpSent;
  final bool isLoading;
  final String? errorMessage;
  final int resendSeconds;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onChangePhone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                otpSent ? 'Verify OTP' : 'Login',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                otpSent
                    ? 'Enter the OTP sent to +91-${phoneController.text}.'
                    : 'Enter your registered mobile number to receive an OTP.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: Colors.black),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: phoneController,
                enabled: !isLoading && !otpSent,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                ),
                onChanged: (_) {
                  if (errorMessage != null) onChangePhone();
                },
              ),
              if (otpSent) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: otpController,
                  enabled: !isLoading,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: 'OTP'),
                  onSubmitted: (_) => isLoading ? null : onVerifyOtp(),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 18),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black),
                ),
              ],
              const SizedBox(height: 24),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (otpSent)
                ElevatedButton(
                  onPressed: onVerifyOtp,
                  child: const Text('Verify and continue'),
                )
              else
                ElevatedButton(
                  onPressed: onSendOtp,
                  child: const Text('Send OTP'),
                ),
              if (otpSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isLoading || resendSeconds > 0 ? null : onSendOtp,
                  child: Text(
                    resendSeconds > 0
                        ? 'Resend OTP in ${resendSeconds}s'
                        : 'Resend OTP',
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : onChangePhone,
                  child: const Text('Change mobile number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You are signed in',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The access token is saved locally and will be sent with authenticated API calls.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onLogout, child: const Text('Logout')),
          ],
        ),
      ),
    );
  }
}
