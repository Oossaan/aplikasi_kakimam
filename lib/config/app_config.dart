class AppConfig {
  static const String appName = 'Inventory & POS System';
  static const String appVersion = '1.0.1';
  static const String companyName = '';
  static const String companyAddress = '';
  static const String companyPhone = '';

  // Database - Production
  static const String dbName = 'inventory.db';
  static const int dbVersion = 2;

  // Production note: Update company info via Settings page

  // Default Values
  static const double defaultTax = 0.0;
  static const String defaultCurrency = 'IDR';
  static const int lowStockThreshold = 10;

  // API Configuration - Set your production API endpoint here if needed
  static const String baseUrl = '';
  static const Duration timeout = Duration(seconds: 30);
}
