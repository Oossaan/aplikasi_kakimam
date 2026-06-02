import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'app.dart';
import 'services/database_service.dart';
import 'controllers/auth_controller.dart';
import 'controllers/inventory_controller.dart';
import 'controllers/pos_controller.dart';
import 'controllers/report_controller.dart';
import 'controllers/outlet_controller.dart';
import 'controllers/supplier_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/invoice_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/sales_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting untuk Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Database
  await DatabaseService().initializeDatabase();

// PRODUCTION: Dummy data PERMANENTLY DISABLED
  // WARNING: Never enable in production! Use admin panel to add data.
  //if (!kReleaseMode) await DatabaseService().insertDummyData();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => InventoryController()),
        ChangeNotifierProvider(create: (_) => POSController()),
        ChangeNotifierProvider(create: (_) => ReportController()),
        ChangeNotifierProvider(create: (_) => OutletController()),
        ChangeNotifierProvider(create: (_) => SupplierController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => InvoiceController()),
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => SalesController()),
      ],
      child: const MyApp(),
    ),
  );
}
