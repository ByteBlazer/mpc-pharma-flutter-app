import 'package:flutter/material.dart';

import 'app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.load();
  runApp(const MpcPharmaApp());
}

class MpcPharmaApp extends StatelessWidget {
  const MpcPharmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPC Pharma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B87),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('MPC Pharma'),
        centerTitle: false,
        actions: compact
            ? null
            : const [
                _HeaderAction(label: 'Android'),
                _HeaderAction(label: 'iOS'),
                _HeaderAction(label: 'Web'),
                SizedBox(width: 16),
              ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 48,
              vertical: compact ? 32 : 56,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: const _HomeContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final gap = wide ? 40.0 : 28.0;

        return Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: wide
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            Flexible(
              flex: wide ? 3 : 0,
              fit: wide ? FlexFit.tight : FlexFit.loose,
              child: const _HeroCopy(),
            ),
            SizedBox(width: wide ? gap : 0, height: wide ? 0 : gap),
            Flexible(
              flex: wide ? 2 : 0,
              fit: wide ? FlexFit.tight : FlexFit.loose,
              child: const _StatusCard(),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Badge(label: 'Flutter starter'),
        const SizedBox(height: 20),
        Text(
          'Hello World from MPC Pharma',
          style: textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A clean, web-first Flutter foundation that also packages for Android and iOS.',
          style: textTheme.titleLarge?.copyWith(
            color: Colors.black.withValues(alpha: 0.68),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.public),
              label: const Text('Web ready'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone_android),
              label: const Text('Mobile ready'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.medical_services_outlined,
              color: theme.colorScheme.primary,
              size: compact ? 36 : 44,
            ),
            const SizedBox(height: 20),
            Text(
              'Application status',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const _StatusRow(label: 'UI', value: 'Hello World shell'),
            const _StatusRow(label: 'Targets', value: 'Android, iOS, Web'),
            const _StatusRow(label: 'Domain', value: 'mpcpharma.in'),
            _StatusRow(label: 'Env', value: AppEnvironment.name),
            const Divider(height: 32),
            Text(
              'API base URL',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.black.withValues(alpha: 0.64),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              AppEnvironment.apiBaseUrl,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.56)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(onPressed: () {}, child: Text(label)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
