import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class AppSettings {
  final int? id;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final double defaultTax;
  final int lowStockThreshold;
  final String receiptFooter;
  // Bank / QRIS settings
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;
  final String qrisImagePath;
  // PIN security
  final String? pin;
  final bool isPinEnabled;
  // Auto-allow permissions
  final bool autoAllowDelete; // Auto allow delete without PIN
  final bool autoAllowVoid; // Auto allow void transaction without PIN
  // POS / Transaction settings
  final String defaultPaymentMethod; // Cash, Transfer, QRIS, Tempo
  final String invoicePrefix; // Prefix for invoice number (e.g., "INV-", "Jual-")
  final bool showStockOnReceipt; // Show stock info on receipt
  final bool autoPrintAfterSale; // Auto print after successful sale
  final int? updatedAt;

  AppSettings({
    this.id,
    this.storeName = '',
    this.storeAddress = '',
    this.storePhone = '',
    this.defaultTax = 0.0,
    this.lowStockThreshold = 10,
    this.receiptFooter = 'Terima kasih',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountHolder = '',
    this.qrisImagePath = '',
    this.pin,
    this.isPinEnabled = false,
    this.autoAllowDelete = false,
    this.autoAllowVoid = false,
    this.defaultPaymentMethod = 'Cash',
    this.invoicePrefix = 'INV-',
    this.showStockOnReceipt = true,
    this.autoPrintAfterSale = false,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id ?? 1,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'storePhone': storePhone,
      'defaultTax': defaultTax,
      'lowStockThreshold': lowStockThreshold,
      'receiptFooter': receiptFooter,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountHolder': bankAccountHolder,
      'qrisImagePath': qrisImagePath,
      'pin': pin,
      'isPinEnabled': isPinEnabled ? 1 : 0,
      'autoAllowDelete': autoAllowDelete ? 1 : 0,
      'autoAllowVoid': autoAllowVoid ? 1 : 0,
      'defaultPaymentMethod': defaultPaymentMethod,
      'invoicePrefix': invoicePrefix,
      'showStockOnReceipt': showStockOnReceipt ? 1 : 0,
      'autoPrintAfterSale': autoPrintAfterSale ? 1 : 0,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'],
      storeName: map['storeName'] ?? '',
      storeAddress: map['storeAddress'] ?? '',
      storePhone: map['storePhone'] ?? '',
      defaultTax: (map['defaultTax'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: map['lowStockThreshold'] ?? 10,
      receiptFooter: map['receiptFooter'] ?? 'Terima kasih',
      bankName: map['bankName'] ?? '',
      bankAccountNumber: map['bankAccountNumber'] ?? '',
      bankAccountHolder: map['bankAccountHolder'] ?? '',
      qrisImagePath: map['qrisImagePath'] ?? '',
      pin: map['pin'] as String?,
      isPinEnabled: (map['isPinEnabled'] as int?) == 1,
      autoAllowDelete: (map['autoAllowDelete'] as int?) == 1,
      autoAllowVoid: (map['autoAllowVoid'] as int?) == 1,
      defaultPaymentMethod: map['defaultPaymentMethod'] ?? 'Cash',
      invoicePrefix: map['invoicePrefix'] ?? 'INV-',
      showStockOnReceipt: (map['showStockOnReceipt'] as int?) != 0,
      autoPrintAfterSale: (map['autoPrintAfterSale'] as int?) == 1,
      updatedAt: map['updatedAt'],
    );
  }

  AppSettings copyWith({
    int? id,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    double? defaultTax,
    int? lowStockThreshold,
    String? receiptFooter,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? qrisImagePath,
    String? pin,
    bool? isPinEnabled,
    bool? autoAllowDelete,
    bool? autoAllowVoid,
    String? defaultPaymentMethod,
    String? invoicePrefix,
    bool? showStockOnReceipt,
    bool? autoPrintAfterSale,
    int? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      defaultTax: defaultTax ?? this.defaultTax,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      qrisImagePath: qrisImagePath ?? this.qrisImagePath,
      pin: pin ?? this.pin,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      autoAllowDelete: autoAllowDelete ?? this.autoAllowDelete,
      autoAllowVoid: autoAllowVoid ?? this.autoAllowVoid,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      showStockOnReceipt: showStockOnReceipt ?? this.showStockOnReceipt,
      autoPrintAfterSale: autoPrintAfterSale ?? this.autoPrintAfterSale,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static Future<AppSettings> getSettings() async {
    final instance = SettingsService();
    await instance.ensureTableExists();
    final db = await DatabaseService.database;
    final result = await db.query('app_settings', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return AppSettings.fromMap(result.first);
    }
    return AppSettings();
  }

  Future<void> ensureTableExists() async {
    final db = await DatabaseService.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY CHECK(id = 1),
      storeName TEXT DEFAULT '',
        storeAddress TEXT DEFAULT '',
        storePhone TEXT DEFAULT '',
        defaultTax REAL DEFAULT 0.0,
        lowStockThreshold INTEGER DEFAULT 10,
        receiptFooter TEXT DEFAULT 'Terima kasih',
        bankName TEXT DEFAULT '',
        bankAccountNumber TEXT DEFAULT '',
        bankAccountHolder TEXT DEFAULT '',
        qrisImagePath TEXT DEFAULT '',
        pin TEXT,
        isPinEnabled INTEGER DEFAULT 0,
        updatedAt INTEGER
      )
    ''');

    // Insert default row if not exists
    final existing = await db.query('app_settings', where: 'id = ?', whereArgs: [1]);
    if (existing.isEmpty) {
      await db.insert('app_settings', {
        'id': 1,
        'storeName': '',
        'storeAddress': '',
        'storePhone': '',
        'defaultTax': 0.0,
        'lowStockThreshold': 10,
        'receiptFooter': 'Terima kasih',
        'bankName': '',
        'bankAccountNumber': '',
        'bankAccountHolder': '',
        'qrisImagePath': '',
        'pin': null,
        'isPinEnabled': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Add missing columns for existing databases (migration)
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN bankName TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN bankAccountNumber TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN bankAccountHolder TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN qrisImagePath TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN pin TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN isPinEnabled INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN autoAllowDelete INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN autoAllowVoid INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN defaultPaymentMethod TEXT DEFAULT 'Cash'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN invoicePrefix TEXT DEFAULT 'INV-'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN showStockOnReceipt INTEGER DEFAULT 1");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE app_settings ADD COLUMN autoPrintAfterSale INTEGER DEFAULT 0");
    } catch (_) {}
  }

  Future<bool> updateSettings(AppSettings settings) async {
    try {
      final db = await DatabaseService.database;
      await ensureTableExists();
      final count = await db.update(
        'app_settings',
        settings.toMap(),
        where: 'id = ?',
        whereArgs: [1],
      );
      if (count == 0) {
        await db.insert('app_settings', settings.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('Error updating settings: $e');
      return false;
    }
  }

  // User profile helpers
  Future<bool> updateUserProfile(int userId, String name, String? newPassword) async {
    try {
      final db = await DatabaseService.database;
      final values = <String, dynamic>{'name': name};
      if (newPassword != null && newPassword.isNotEmpty) {
        values['password'] = newPassword;
      }
      await db.update(
        'users',
        values,
        where: 'id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // PIN verification
  Future<bool> verifyPin(String pin) async {
    final settings = await getSettings();
    if (!settings.isPinEnabled || settings.pin == null) return true; // No PIN set, allow
    return settings.pin == pin;
  }

  // PIN update (requires login password verification)
  Future<bool> updatePin({
    required String currentLoginPassword,
    required String newPin,
    required bool enablePin,
    required int userId,
  }) async {
    try {
      // Verify user's login password first
      final db = await DatabaseService.database;
      final users = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (users.isEmpty) return false;

      final user = users.first;
      final storedPassword = user['password'] as String?;
      if (storedPassword != currentLoginPassword) {
        return false; // Wrong password
      }

      // Update PIN in settings
      await ensureTableExists();
      await db.update(
        'app_settings',
        {
          'pin': enablePin ? newPin : null,
          'isPinEnabled': enablePin ? 1 : 0,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating PIN: $e');
      return false;
    }
  }
}

