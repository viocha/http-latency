import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_ui.dart';
import 'platform_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePlatformServices();
  runApp(const HttpLatencyApp());
}

class HttpLatencyApp extends StatefulWidget {
  const HttpLatencyApp({super.key});

  @override
  State<HttpLatencyApp> createState() => _HttpLatencyAppState();
}

class _HttpLatencyAppState extends State<HttpLatencyApp> {
  late final AppController controller;
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    controller = AppController()..addListener(_showMessage);
    controller.initialize();
  }

  void _showMessage() {
    final text = controller.takeMessage();
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
  }

  @override
  void dispose() {
    controller
      ..removeListener(_showMessage)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: messengerKey,
    title: 'HTTP 延迟测试',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0969C3)),
      useMaterial3: true,
      fontFamily: defaultTargetPlatform == TargetPlatform.windows
          ? 'Microsoft YaHei UI'
          : null,
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: AppShell(controller: controller),
  );
}
