// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_page.dart';

Future<void> main() async {
  // IMPORTANT: ensure bindings first so platform plugins register
  WidgetsFlutterBinding.ensureInitialized();

  // single-instance check (non-platform API) after bindings
  final firstInstance = await _checkSingleInstance();
  if (!firstInstance) {
    print("Rescue Radar already running - exiting");
    exit(0);
  }

  runApp(const MyApp());
}

Future<bool> _checkSingleInstance() async {
  try {
    // bind to a random ephemeral port to detect another instance
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    await server.close();
    return true;
  } catch (e) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RRRS Rescue Radar',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const DashboardPage(),
    );
  }
}