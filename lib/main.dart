import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.load();
  runApp(const MpcPharmaApp());
}

typedef GreetingFetcher = Future<String> Function();

class MpcPharmaApp extends StatelessWidget {
  const MpcPharmaApp({super.key, GreetingFetcher? fetchGreeting})
    : _fetchGreeting = fetchGreeting ?? fetchGreetingFromApi;

  final GreetingFetcher _fetchGreeting;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPC Pharma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
        useMaterial3: true,
      ),
      home: GreetingPage(fetchGreeting: _fetchGreeting),
    );
  }
}

class GreetingPage extends StatelessWidget {
  const GreetingPage({super.key, required this.fetchGreeting});

  final GreetingFetcher fetchGreeting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder<String>(
          future: fetchGreeting(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load greeting: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.data ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<String> fetchGreetingFromApi() async {
  final uri = _apiUri('/greeting');
  final response = await http.get(uri);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('GET $uri failed with status ${response.statusCode}');
  }

  return _extractGreeting(response.body);
}

Uri _apiUri(String path) {
  final base = AppEnvironment.apiBaseUrl;
  final normalizedBase = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return Uri.parse('$normalizedBase$normalizedPath');
}

String _extractGreeting(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return '';

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'] ?? decoded['greeting'];
      if (message != null) return message.toString();
    }
    if (decoded is String) return decoded;
  } on FormatException {
    // Plain text response.
  }

  return trimmed;
}
