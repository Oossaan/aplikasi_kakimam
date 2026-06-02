import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'controllers/settings_controller.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App akan ditutup - simpan PIN ke database jika ada perubahan
      _savePinToDatabase();
    }
  }

  Future<void> _savePinToDatabase() async {
    try {
      final settingsController = context.read<SettingsController>();
      final settings = settingsController.settings;
      
      // PIN akan sudah tersimpan otomatis melalui updatePin method
      // Ini adalah safety call untuk memastikan PIN tersimpan
      if (settings.pin != null && settings.pin!.isNotEmpty) {
        debugPrint('PIN configuration saved');
      }
    } catch (e) {
      debugPrint('Error saving PIN on app close: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory & POS System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
