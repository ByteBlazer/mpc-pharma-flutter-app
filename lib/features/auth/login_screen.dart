import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.prefillPhone});

  final String? prefillPhone;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _phoneController;
  bool _loading = false;
  String? _error;
  String? _appCode;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.prefillPhone ?? '');
    _loadAppCode();
  }

  Future<void> _loadAppCode() async {
    try {
      final code = await SmsAutoFill().getAppSignature;
      if (mounted) setState(() => _appCode = code);
    } catch (_) {
      _appCode = '';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _phoneController.text.length == 10 &&
      RegExp(r'^\d+$').hasMatch(_phoneController.text);

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.generateOtp(
        mobile: _phoneController.text,
        appCode: _appCode ?? '',
      );
      if (mounted) {
        context.go(
          '${AppRoutes.otp}?phone=${Uri.encodeComponent(_phoneController.text)}',
        );
      }
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter your registered mobile number to receive a one-time password (OTP).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_loading,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixText: '+91-',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const LoadingOverlay()
                else
                  FilledButton(
                    onPressed: _isValid ? _submit : null,
                    child: const Text('GET OTP'),
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
