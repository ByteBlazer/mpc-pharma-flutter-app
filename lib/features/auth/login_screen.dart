import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../api/auth_token_store.dart';
import '../../app_environment.dart';
import '../home/home_screen.dart';
import 'user_profile_screen.dart';

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
  bool get _canSendOtp =>
      !_isLoading && !_otpSent && _isValidPhone(_phoneController.text.trim());
  bool get _canVerifyOtp =>
      !_isLoading && _otpSent && _isValidOtp(_otpController.text.trim());

  @override
  void initState() {
    super.initState();
    _apiClient = widget._apiClient ?? ApiClient();
    _tokenStore = widget._tokenStore ?? AuthTokenStore();
    _phoneController.addListener(_handlePhoneChange);
    _otpController.addListener(_handleOtpChange);
    _loadExistingSession();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.removeListener(_handlePhoneChange);
    _otpController.removeListener(_handleOtpChange);
    _phoneController.dispose();
    _otpController.dispose();
    if (widget._apiClient == null) {
      _apiClient.close();
    }
    super.dispose();
  }

  void _handlePhoneChange() {
    if (mounted) setState(() {});
  }

  void _handleOtpChange() {
    if (mounted) setState(() {});
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_appTitle()),
        actions: [
          if (_isLoggedIn)
            IconButton(
              tooltip: 'User profile',
              icon: const Icon(Icons.account_circle),
              onPressed: _openUserProfile,
            ),
        ],
      ),
      body: _isCheckingSession
          ? const Center(child: CircularProgressIndicator())
          : _isLoggedIn
          ? HomeScreen(apiClient: _apiClient)
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _LoginCard(
                      phoneController: _phoneController,
                      otpController: _otpController,
                      otpSent: _otpSent,
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      resendSeconds: _resendSeconds,
                      canSendOtp: _canSendOtp,
                      canVerifyOtp: _canVerifyOtp,
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
    );
  }

  void _openUserProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            UserProfileScreen(tokenStore: _tokenStore, onLogout: _logout),
      ),
    );
  }

  String _appTitle() {
    return switch (AppEnvironment.name) {
      AppEnvironment.local => 'MPC Pharma (Local)',
      AppEnvironment.staging => 'MPC Pharma (Staging)',
      _ => 'MPC Pharma',
    };
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
    required this.canSendOtp,
    required this.canVerifyOtp,
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
  final bool canSendOtp;
  final bool canVerifyOtp;
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
                textInputAction: TextInputAction.done,
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
                onSubmitted: (_) {
                  if (canSendOtp) onSendOtp();
                },
              ),
              if (otpSent) ...[
                const SizedBox(height: 18),
                _OtpCodeField(
                  controller: otpController,
                  enabled: !isLoading,
                  onCompleted: onVerifyOtp,
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
                  onPressed: canVerifyOtp ? onVerifyOtp : null,
                  child: const Text('Verify and continue'),
                )
              else
                ElevatedButton(
                  onPressed: canSendOtp ? onSendOtp : null,
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

class _OtpCodeField extends StatefulWidget {
  const _OtpCodeField({
    required this.controller,
    required this.enabled,
    this.onCompleted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onCompleted;

  @override
  State<_OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<_OtpCodeField> {
  static const _otpLength = 6;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focusNode.requestFocus : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 64,
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                autofillHints: const [AutofillHints.oneTimeCode],
                cursorColor: Colors.transparent,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.transparent),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                onChanged: (value) {
                  if (value.length == _otpLength) {
                    TextInput.finishAutofillContext();
                    widget.onCompleted?.call();
                  }
                },
                onSubmitted: (_) => widget.onCompleted?.call(),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final otp = widget.controller.text;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_otpLength, (index) {
                    final digit = index < otp.length ? otp[index] : '';
                    final isFocused =
                        _focusNode.hasFocus && index == otp.length.clamp(0, 5);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused
                                    ? colorScheme.primary
                                    : Colors.black,
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                digit,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
