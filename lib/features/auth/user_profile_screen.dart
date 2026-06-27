import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/auth_token_store.dart';
import '../../auth/app_role.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.tokenStore,
    required this.onLogout,
  });

  final AuthTokenStore tokenStore;
  final Future<void> Function() onLogout;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final Future<_JwtProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<_JwtProfile?> _loadProfile() async {
    final token = await widget.tokenStore.readToken();
    if (token == null) return null;
    return _JwtProfile.fromToken(token);
  }

  Future<void> _logout() async {
    await widget.onLogout();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Profile')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: FutureBuilder<_JwtProfile?>(
                future: _profile,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final profile = snapshot.data;
                  if (profile == null) {
                    return _ProfileCard(
                      title: 'No user token found',
                      onLogout: _logout,
                      children: const [
                        Text(
                          'Please login again to view user details.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }

                  return _ProfileCard(
                    title: profile.username,
                    onLogout: _logout,
                    children: [
                      _InfoRow(label: 'User ID', value: profile.id),
                      _InfoRow(label: 'Mobile', value: profile.mobile),
                      _InfoRow(
                        label: 'Base location',
                        value: profile.baseLocationName,
                      ),
                      _InfoRow(
                        label: 'Login Token Issued At',
                        value: profile.issuedAt,
                      ),
                      _InfoRow(
                        label: 'Login Token Expires At',
                        value: profile.expiresAt,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Roles',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.roles
                            .map((role) => _RoleChip(role: role))
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.children,
    required this.onLogout,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
            const SizedBox(height: 28),
            ElevatedButton(onPressed: onLogout, child: const Text('Logout')),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 520;
          final labelText = Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          );
          final valueText = Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(color: Colors.black),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), valueText],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 220, child: labelText),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(role.label, style: TextStyle(color: colorScheme.onPrimary)),
      ),
    );
  }
}

class _JwtProfile {
  const _JwtProfile({
    required this.id,
    required this.username,
    required this.mobile,
    required this.roles,
    required this.baseLocationName,
    required this.issuedAt,
    required this.expiresAt,
  });

  factory _JwtProfile.fromToken(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      throw const FormatException('Invalid JWT token');
    }

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT payload');
    }

    return _JwtProfile(
      id: _stringValue(json['id']),
      username: _stringValue(json['username']),
      mobile: _stringValue(json['mobile']),
      roles: _stringValue(json['roles']).split(',').toAppRoles(),
      baseLocationName: _stringValue(json['baseLocationName']),
      issuedAt: _formatEpochSeconds(json['iat']),
      expiresAt: _formatEpochSeconds(json['exp']),
    );
  }

  final String id;
  final String username;
  final String mobile;
  final List<AppRole> roles;
  final String baseLocationName;
  final String issuedAt;
  final String expiresAt;

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static String _formatEpochSeconds(Object? value) {
    final seconds = int.tryParse(value?.toString() ?? '');
    if (seconds == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final local = dateTime.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final hourOfPeriod = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$month ${local.day} $hourOfPeriod:$minute $period';
  }
}
