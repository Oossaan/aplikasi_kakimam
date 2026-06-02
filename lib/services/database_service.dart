
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path_pkg;

class DatabaseService {
  static Database? _database;

  Future<void> initializeDatabase() async {
    // Only initialize if not already done
    if (_database != null) return;

    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Use a custom path that's writable
    String dbPath;
    if (Platform.isWindows) {
      // For Windows, use user's documents folder
      final docsPath = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      dbPath = path_pkg.join(docsPath, 'Documents', 'inventory_app', 'inventory.db');
    } else {
      dbPath = path_pkg.join(await getDatabasesPath(), 'inventory.db');
    }

    // Ensure directory exists
    final dir = Directory(path_pkg.dirname(dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Debug: print database path
    debugPrint('Database path: $dbPath');

// Open existing database or create new one
    _database = await openDatabase(
      dbPath,
      version: 8,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      singleInstance: true,
    );

    // Enable WAL mode for better concurrency (skip on Android due to sqflite compat)
    try {
      if (!Platform.isAndroid) {
        await _database!.execute('PRAGMA journal_mode=WAL');
      }
    } catch (e) {
      debugPrint('WAL mode failed: $e - using default journal mode');
    }
    // Set PRAGMA safe for Android sqflite
    try {
      await _database!.execute('PRAGMA busy_timeout = 30000');
      await _database!.execute('PRAGMA foreign_keys = ON');
    } catch (e) {
      debugPrint('PRAGMA settings failed on Android: $e');
    }

    debugPrint('Database opened successfully');

    // After database is opened, ensure all required columns exist
    await _ensureColumnsExist(_database!);

    // Ensure default admin user exists (runs on every startup for safety)
    await _ensureDefaultAdminUser(_database!);
  }

  Future<void> _ensureDefaultAdminUser(Database db) async {
    final existingUsers = await db.query('users LIMIT 1');
    if (existingUsers.isEmpty) {
      await db.insert('users', {
        'username': 'admin',
        'password': 'prod2024!',
        'name': 'Administrator',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
      });
      debugPrint('Production default admin created - CHANGE PASSWORD IMMEDIATELY after first login!');
    }
  }

  // Helper to ensure all required columns exist (runs after every open)
  Future<void> _ensureColumnsExist(Database db) async {
    try {
      // Products table columns
      final productColumns = await db.rawQuery("PRAGMA table_info(products)");
      final columnNames =
          productColumns.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('minStock')) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN minStock INTEGER DEFAULT 10');
      }
      if (!columnNames.contains('categoryId')) {
        await db.execute('ALTER TABLE products ADD COLUMN categoryId INTEGER');
      }
      if (!columnNames.contains('supplierId')) {
        await db.execute('ALTER TABLE products ADD COLUMN supplierId INTEGER');
      }
      if (!columnNames.contains('isActive')) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN isActive INTEGER DEFAULT 1');
      }
      if (!columnNames.contains('berat')) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN berat REAL');
      }
      if (!columnNames.contains('hargaPerGram')) {
        await db.execute(
            'ALTER TABLE products ADD COLUMN hargaPerGram REAL');
      }

      // Transactions table columns
      final transColumns = await db.rawQuery("PRAGMA table_info(transactions)");
      final transColumnNames =
          transColumns.map((c) => c['name'] as String).toSet();

      if (!transColumnNames.contains('status')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT "PAID"');
      }
      if (!transColumnNames.contains('outletId')) {
        await db
            .execute('ALTER TABLE transactions ADD COLUMN outletId INTEGER');
      }
      if (!transColumnNames.contains('voidReason')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN voidReason TEXT');
      }
      if (!transColumnNames.contains('payment_status')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN payment_status TEXT DEFAULT "PAID"');
      }
      if (!transColumnNames.contains('due_date')) {
        await db.execute('ALTER TABLE transactions ADD COLUMN due_date TEXT');
      }
if (!transColumnNames.contains('remaining_amount')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN remaining_amount REAL DEFAULT 0');
      }
if (!transColumnNames.contains('originalTransactionId')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN originalTransactionId INTEGER');
      }
if (!transColumnNames.contains('originalInvoiceNumber')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN originalInvoiceNumber TEXT');
      }
      if (!transColumnNames.contains('supplierId')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN supplierId INTEGER');
      }
      if (!transColumnNames.contains('transactionType')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN transactionType TEXT DEFAULT "sale"');
      }
      if (!transColumnNames.contains('discountPercent')) {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN discountPercent REAL DEFAULT 0');
      }

      // TransactionItems table columns (for return tracking)
      final itemColumns = await db.rawQuery("PRAGMA table_info(transactionItems)");
      final itemColumnNames = itemColumns.map((c) => c['name'] as String).toSet();

      if (!itemColumnNames.contains('isReturned')) {
        await db.execute(
            'ALTER TABLE transactionItems ADD COLUMN isReturned INTEGER DEFAULT 0');
      }
      if (!itemColumnNames.contains('returnedQuantity')) {
        await db.execute(
            'ALTER TABLE transactionItems ADD COLUMN returnedQuantity INTEGER DEFAULT 0');
      }
      if (!itemColumnNames.contains('returnReason')) {
        await db.execute(
            'ALTER TABLE transactionItems ADD COLUMN returnReason TEXT');
      }

      // Outlets table columns (for credit management)
      final outletColumns = await db.rawQuery("PRAGMA table_info(outlets)");
      final outletColumnNames =
          outletColumns.map((c) => c['name'] as String).toSet();

      if (!outletColumnNames.contains('credit_limit')) {
        await db.execute(
            'ALTER TABLE outlets ADD COLUMN credit_limit REAL DEFAULT 0');
      }
      if (!outletColumnNames.contains('current_credit')) {
        await db.execute(
            'ALTER TABLE outlets ADD COLUMN current_credit REAL DEFAULT 0');
      }

      // Create payment_details table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_details (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          payment_type TEXT NOT NULL,
          amount REAL NOT NULL,
          reference_no TEXT,
          card_last_four TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE)
      ''');

      // Add missing columns to payment_details if needed (for old databases)
      try {
        await db.execute(
            'ALTER TABLE payment_details ADD COLUMN transaction_id INTEGER');
      } catch (e) {/* column might exist */}

// Create indexes for better performance
      await _createIndexes(db);

      // Create returns table if not exists (for databases created before version 5)
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            cost REAL DEFAULT 0,
            returnType TEXT NOT NULL,
            referenceId INTEGER,
            referenceNumber TEXT,
            notes TEXT,
            createdAt TEXT NOT NULL,
            createdBy INTEGER,
            FOREIGN KEY (productId) REFERENCES products(id),
            FOREIGN KEY (referenceId) REFERENCES transactions(id),
            FOREIGN KEY (createdBy) REFERENCES users(id)
          )
        ''');
      } catch (e) {
        debugPrint('Error ensuring returns table: $e');
      }
    } catch (e) {
      debugPrint('Error ensuring columns: $e');
    }

    // Ensure supplierHutang table exists (for supplier tempo payments)
    try {
      final hutangTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='supplierHutang'");
      if (hutangTables.isEmpty) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS supplierHutang (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierId INTEGER NOT NULL,
            supplierName TEXT NOT NULL,
            invoiceNumber TEXT NOT NULL,
            totalAmount REAL NOT NULL,
            paidAmount REAL DEFAULT 0,
            remainingAmount REAL NOT NULL,
            dueDate TEXT NOT NULL,
            status TEXT DEFAULT 'UNPAID',
            notes TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            createdBy INTEGER,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id),
            FOREIGN KEY (createdBy) REFERENCES users(id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_supplier ON supplierHutang(supplierId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_status ON supplierHutang(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_dueDate ON supplierHutang(dueDate)');
      }
    } catch (e) {
      debugPrint('Error ensuring supplierHutang table: $e');
    }
  }

  // Create database indexes for better query performance
  Future<void> _createIndexes(Database db) async {
    try {
      // Products indexes
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)');

      // Transactions indexes
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transactionDate)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_outlet ON transactions(outletId)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(payment_status)');

      // Payment details index
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payment_details_transaction ON payment_details(transaction_id)');
    } catch (e) {
      debugPrint('Error creating indexes: $e');
    }
  }

  // Batch operation helper for multiple inserts/updates
  Future<void> batchInsert(
      String table, List<Map<String, dynamic>> records) async {
    final db = await database;
    final batch = db.batch();

    for (var record in records) {
      batch.insert(table, record);
    }

    await batch.commit(noResult: true);
  }

  Future<void> batchUpdate(String table, List<Map<String, dynamic>> records,
      String where, List<dynamic> whereArgs) async {
    final db = await database;
    final batch = db.batch();

    for (var record in records) {
      batch.update(table, record, where: where, whereArgs: whereArgs);
    }

    await batch.commit(noResult: true);
  }

  // Debounce helper for search
  static Function(T) debounce<T>(Duration duration, Function(T) callback) {
    DateTime? lastCall;
    return (T arg) {
      final now = DateTime.now();
      if (lastCall == null || now.difference(lastCall!) > duration) {
        lastCall = now;
        callback(arg);
      }
    };
  }

  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add outlets and priceHistory (already done in v2)
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS outlets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT DEFAULT '',
            phone TEXT DEFAULT '',
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS priceHistory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            oldPrice REAL NOT NULL,
            newPrice REAL NOT NULL,
            outletId INTEGER,
            transactionId INTEGER,
            changedBy TEXT NOT NULL,
            changedAt TEXT NOT NULL
          )
        ''');

        // Insert default outlet
        final existingOutlets = await db.query('outlets LIMIT 1');
        if (existingOutlets.isEmpty) {
          await db.insert('outlets', {
            'name': 'Toko Utama',
            'address': 'Jl. Example No. 123, Jakarta',
            'phone': '021-12345678',
            'isActive': 1,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        // Tables might already exist
      }
    }

    // Version 3: Add all new tables
    if (oldVersion < 3) {
      try {
        // Suppliers table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            contactPerson TEXT DEFAULT '',
            phone TEXT DEFAULT '',
            email TEXT DEFAULT '',
            address TEXT DEFAULT '',
            notes TEXT DEFAULT '',
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        // Product-Supplier many-to-many relation
        await db.execute('''
          CREATE TABLE IF NOT EXISTS productSuppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            supplierId INTEGER NOT NULL,
            supplierPrice REAL DEFAULT 0,
            isPrimary INTEGER DEFAULT 0,
            lastUpdated TEXT,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE CASCADE,
            UNIQUE(productId, supplierId)
          )
        ''');

        // Categories table (with parent-child support)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT DEFAULT '',
            color TEXT DEFAULT '#2196F3',
            icon TEXT DEFAULT 'folder',
            parentId INTEGER,
            sortOrder INTEGER DEFAULT 0,
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (parentId) REFERENCES categories(id) ON DELETE SET NULL
          )
        ''');

        // Discounts table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS discounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT DEFAULT '',
            type TEXT NOT NULL, -- 'percentage' or 'nominal'
            value REAL NOT NULL,
            minPurchase REAL DEFAULT 0,
            maxDiscount REAL,
            startDate TEXT NOT NULL,
            endDate TEXT NOT NULL,
            isActive INTEGER DEFAULT 1,
            applicableProducts TEXT, -- JSON array of product IDs
            applicableCategories TEXT, -- JSON array of category IDs
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        // Transaction Discounts
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transactionDiscounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transactionId INTEGER NOT NULL,
            discountId INTEGER,
            discountName TEXT NOT NULL,
            discountType TEXT NOT NULL,
            discountValue REAL NOT NULL,
            discountAmount REAL NOT NULL,
            FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE,
            FOREIGN KEY (discountId) REFERENCES discounts(id)
          )
        ''');

        // Stock Movements (history)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stockMovements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            type TEXT NOT NULL, -- 'in', 'out', 'adjustment', 'return'
            quantity INTEGER NOT NULL,
            previousStock INTEGER NOT NULL,
            newStock INTEGER NOT NULL,
            referenceId INTEGER, -- transactionId or adjustmentId
            referenceType TEXT, -- 'transaction', 'adjustment', etc.
            notes TEXT DEFAULT '',
            userId INTEGER,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY (userId) REFERENCES users(id)
          )
        ''');

        // Add referenceType column if not exists (for existing databases)
        try {
          await db.execute('ALTER TABLE stockMovements ADD COLUMN referenceType TEXT');
        } catch (e) {
          // Column already exists, ignore
        }

        // Audit Logs
        await db.execute('''
          CREATE TABLE IF NOT EXISTS auditLogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tableName TEXT NOT NULL,
            recordId INTEGER NOT NULL,
            action TEXT NOT NULL, -- 'create', 'update', 'delete', 'void'
            oldValues TEXT, -- JSON
            newValues TEXT, -- JSON
            changedBy TEXT,
            reason TEXT,
            createdAt TEXT NOT NULL
          )
        ''');

        // Add new columns to existing tables if they don't exist
        try {
          await db.execute(
              'ALTER TABLE products ADD COLUMN minStock INTEGER DEFAULT 10');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE products ADD COLUMN categoryId INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE products ADD COLUMN supplierId INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE products ADD COLUMN isActive INTEGER DEFAULT 1');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT "PAID"');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE transactions ADD COLUMN voidReason TEXT');
        } catch (e) {/* column might exist */}

        try {
          await db.execute('ALTER TABLE transactions ADD COLUMN voidDate TEXT');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE transactions ADD COLUMN voidBy INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE transactions ADD COLUMN customerName TEXT');
        } catch (e) {/* column might exist */}

        try {
          await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN supplierId INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN transactionType TEXT DEFAULT "sale"');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN isPriceModified INTEGER DEFAULT 0');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN originalPrice REAL');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN discountId INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN itemDiscount REAL DEFAULT 0');
        } catch (e) {/* column might exist */}

try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN cost REAL DEFAULT 0');
        } catch (e) {/* column might exist */}

        // Track returned items
        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN isReturned INTEGER DEFAULT 0');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN returnedQuantity INTEGER DEFAULT 0');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE transactionItems ADD COLUMN returnReason TEXT');
        } catch (e) {/* column might exist */}

        // Version 4: Fix missing columns for products (for databases that started before v3)
        try {
          await db.execute(
              'ALTER TABLE products ADD COLUMN minStock INTEGER DEFAULT 10');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE products ADD COLUMN categoryId INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db
              .execute('ALTER TABLE products ADD COLUMN supplierId INTEGER');
        } catch (e) {/* column might exist */}

        try {
          await db.execute(
              'ALTER TABLE products ADD COLUMN isActive INTEGER DEFAULT 1');
        } catch (e) {/* column might exist */}

        // Insert default category
        final existingCategories = await db.query('categories LIMIT 1');
        if (existingCategories.isEmpty) {
          await db.insert('categories', {
            'name': 'Uncategorized',
            'description': 'Default category',
            'color': '#9E9E9E',
            'icon': 'folder',
            'parentId': null,
            'sortOrder': 0,
            'isActive': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }

        // Insert default supplier
        final existingSuppliers = await db.query('suppliers LIMIT 1');
        if (existingSuppliers.isEmpty) {
          await db.insert('suppliers', {
            'name': 'Supplier Utama',
            'contactPerson': '-',
            'phone': '',
            'email': '',
            'address': '',
            'notes': 'Default supplier',
            'isActive': 1,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
} catch (e) {
        // ignore: avoid_print
        print('Error upgrading to v3: $e');
      }
    }

    // Add returns table for existing databases (version 5)
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            cost REAL DEFAULT 0,
            returnType TEXT NOT NULL,
            referenceId INTEGER,
            referenceNumber TEXT,
            notes TEXT,
            createdAt TEXT NOT NULL,
            createdBy INTEGER,
            FOREIGN KEY (productId) REFERENCES products(id),
            FOREIGN KEY (referenceId) REFERENCES transactions(id),
            FOREIGN KEY (createdBy) REFERENCES users(id)
          )
        ''');

        // Create index for returns table
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_returns_reference ON returns(referenceId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_returns_date ON returns(createdAt)');
      } catch (e) {
        // ignore: avoid_print
        print('Error adding returns table: $e');
      }
    }

    // Version 6: Add supplierHutang table for tracking supplier tempo payments
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS supplierHutang (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierId INTEGER NOT NULL,
            supplierName TEXT NOT NULL,
            invoiceNumber TEXT NOT NULL,
            totalAmount REAL NOT NULL,
            paidAmount REAL DEFAULT 0,
            remainingAmount REAL NOT NULL,
            dueDate TEXT NOT NULL,
            status TEXT DEFAULT 'UNPAID',
            notes TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            createdBy INTEGER,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id),
            FOREIGN KEY (createdBy) REFERENCES users(id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_supplier ON supplierHutang(supplierId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_status ON supplierHutang(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_dueDate ON supplierHutang(dueDate)');
      } catch (e) {
        // ignore: avoid_print
        print('Error adding supplierHutang table: $e');
      }
    }

    // Version 7: Add sales table
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT DEFAULT '',
            phone TEXT DEFAULT '',
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');
      } catch (e) {
        // ignore: avoid_print
        print('Error adding sales table: $e');
      }
    }

    // Version 8: Add salesId column to transactions for existing databases
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN salesId INTEGER');
        await db.execute('ALTER TABLE transactions ADD COLUMN salesName TEXT');
      } catch (e) {
        // ignore: avoid_print
        print('Error adding salesId to transactions: $e');
      }
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Tabel Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Tabel Products
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        purchasePrice REAL NOT NULL,
        sellingPrice REAL NOT NULL,
        stock INTEGER DEFAULT 0,
        minStock INTEGER DEFAULT 10,
        categoryId INTEGER,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Tabel Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        color TEXT DEFAULT '#2196F3',
        icon TEXT DEFAULT 'folder',
        parentId INTEGER,
        sortOrder INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (parentId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // Tabel Suppliers
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contactPerson TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Tabel Product-Supplier
    await db.execute('''
      CREATE TABLE productSuppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        supplierId INTEGER NOT NULL,
        supplierPrice REAL DEFAULT 0,
        isPrimary INTEGER DEFAULT 0,
        lastUpdated TEXT,
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE CASCADE,
        UNIQUE(productId, supplierId)
      )
    ''');

    // Tabel Outlets
    await db.execute('''
      CREATE TABLE outlets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Tabel Sales
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Tabel Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL UNIQUE,
        transactionDate TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        discount REAL DEFAULT 0,
        finalAmount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        userId INTEGER,
        outletId INTEGER,
        supplierId INTEGER,
        salesId INTEGER,
        transactionType TEXT DEFAULT 'sale',
        status TEXT DEFAULT 'PAID',
        voidReason TEXT,
        voidDate TEXT,
        voidBy INTEGER,
        customerName TEXT,
        notes TEXT,
        FOREIGN KEY (userId) REFERENCES users(id),
        FOREIGN KEY (outletId) REFERENCES outlets(id),
        FOREIGN KEY (voidBy) REFERENCES users(id),
        FOREIGN KEY (salesId) REFERENCES sales(id)
      )
    ''');

    // Tabel Transaction Items
    await db.execute('''
      CREATE TABLE transactionItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        price REAL NOT NULL,
        originalPrice REAL,
        isPriceModified INTEGER DEFAULT 0,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        discountId INTEGER,
        itemDiscount REAL DEFAULT 0,
        cost REAL DEFAULT 0,
        FOREIGN KEY (transactionId) REFERENCES transactions(id),
        FOREIGN KEY (productId) REFERENCES products(id),
        FOREIGN KEY (discountId) REFERENCES discounts(id)
      )
    ''');

    // Tabel Discounts
    await db.execute('''
      CREATE TABLE discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        type TEXT NOT NULL,
        value REAL NOT NULL,
        minPurchase REAL DEFAULT 0,
        maxDiscount REAL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        applicableProducts TEXT,
        applicableCategories TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Tabel Transaction Discounts
    await db.execute('''
      CREATE TABLE transactionDiscounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        discountId INTEGER,
        discountName TEXT NOT NULL,
        discountType TEXT NOT NULL,
        discountValue REAL NOT NULL,
        discountAmount REAL NOT NULL,
        FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (discountId) REFERENCES discounts(id)
      )
    ''');

    // Tabel Price History
    await db.execute('''
      CREATE TABLE priceHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        oldPrice REAL NOT NULL,
        newPrice REAL NOT NULL,
        outletId INTEGER,
        transactionId INTEGER,
        changedBy TEXT NOT NULL,
        changedAt TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products(id),
        FOREIGN KEY (outletId) REFERENCES outlets(id),
        FOREIGN KEY (transactionId) REFERENCES transactions(id)
      )
    ''');

    // Tabel Stock Movements
    await db.execute('''
      CREATE TABLE stockMovements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        previousStock INTEGER NOT NULL,
        newStock INTEGER NOT NULL,
        referenceId INTEGER,
        referenceType TEXT,
        notes TEXT DEFAULT '',
        userId INTEGER,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (userId) REFERENCES users(id)
      )
    ''');

// Tabel Audit Logs
    await db.execute('''
      CREATE TABLE auditLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT NOT NULL,
        recordId INTEGER NOT NULL,
        action TEXT NOT NULL,
        oldValues TEXT,
        newValues TEXT,
        changedBy TEXT,
        reason TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

// Tabel Returns (separate from transactions)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        returnType TEXT NOT NULL,
        referenceId INTEGER,
        referenceNumber TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        createdBy INTEGER,
        FOREIGN KEY (productId) REFERENCES products(id),
        FOREIGN KEY (referenceId) REFERENCES transactions(id),
        FOREIGN KEY (createdBy) REFERENCES users(id)
      )
    ''');

    // Create indexes for returns table
    await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_reference ON returns(referenceId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_date ON returns(createdAt)');

    // Supplier Hutang table - for tracking purchases from suppliers with tempo payments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplierHutang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplierId INTEGER NOT NULL,
        supplierName TEXT NOT NULL,
        invoiceNumber TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        paidAmount REAL DEFAULT 0,
        remainingAmount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        status TEXT DEFAULT 'UNPAID',
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        createdBy INTEGER,
        FOREIGN KEY (supplierId) REFERENCES suppliers(id),
        FOREIGN KEY (createdBy) REFERENCES users(id)
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_supplier ON supplierHutang(supplierId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_status ON supplierHutang(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_supplierHutang_dueDate ON supplierHutang(dueDate)');

    // Deletion Log table - for tracking deleted records with reason
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deletion_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        invoice_number TEXT,
        deleted_by TEXT,
        reason TEXT,
        deleted_at TEXT NOT NULL
      )
    ''');

    // Insert default admin user only (for login) - only if users table is empty
    final existingUsers = await db.query('users LIMIT 1');
    if (existingUsers.isEmpty) {
      await db.insert('users', {
        'username': 'admin',
        'password': 'admin123',
        'name': 'Administrator',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
    // NOTE: Other dummy data removed - add via app
  }

  static Future<Database> get database async {
    if (_database == null) {
      throw Exception('Database not initialized. Call initializeDatabase() first.');
    }
    return _database!;
  }

  // Generic methods for CRUD operations
  static Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  static Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  static Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // Insert dummy data for testing
  Future<void> insertDummyData() async {
    final db = await database;

    // Check if data already exists
    final existingProducts = await db.query('products LIMIT 1');
    if (existingProducts.isNotEmpty) {
      debugPrint('Dummy data already exists, skipping...');
      return;
    }

    debugPrint('Inserting dummy data...');

    // Insert additional categories
    final categories = [
      {'name': 'Makanan', 'description': 'Makanan ringan & cemilan', 'color': '#FF5722', 'icon': 'restaurant'},
      {'name': 'Minuman', 'description': 'Minuman berbagai jenis', 'color': '#2196F3', 'icon': 'local_cafe'},
      {'name': 'Snack', 'description': 'Snack & keripik', 'color': '#FFC107', 'icon': 'cookie'},
      {'name': 'Makanan Instan', 'description': 'Makanan instan & mie', 'color': '#9C27B0', 'icon': 'takeout_dining'},
      {'name': 'Sembako', 'description': 'Beras, minyak, gula', 'color': '#795548', 'icon': 'shopping_bag'},
      {'name': 'Rokok', 'description': 'Rokok & tembakau', 'color': '#607D8B', 'icon': 'smoking_rooms'},
    ];

    for (var cat in categories) {
      await db.insert('categories', {
        ...cat,
        'parentId': null,
        'sortOrder': categories.indexOf(cat),
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Insert additional suppliers
    final suppliers = [
      {'name': 'PT Sumber Berkah', 'contactPerson': 'Budi Santoso', 'phone': '081234567890', 'email': 'budi@sumberberkah.com', 'address': 'Jl. Supplier No. 1, Jakarta', 'notes': 'Supplier utama', 'isActive': 1},
      {'name': 'CV Maju Mundur', 'contactPerson': 'Siti Aminah', 'phone': '082345678901', 'email': 'siti@majumundur.com', 'address': 'Jl. Supplier No. 2, Bandung', 'notes': 'Supplier snack', 'isActive': 1},
      {'name': 'UD Sejahtera', 'contactPerson': 'Ahmad Dahlan', 'phone': '083456789012', 'email': 'ahmad@sejahtera.com', 'address': 'Jl. Supplier No. 3, Surabaya', 'notes': 'Supplier minuman', 'isActive': 1},
    ];

    for (var sup in suppliers) {
      await db.insert('suppliers', {
        ...sup,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Insert additional outlets
    final outlets = [
      {'name': 'Toko Utama', 'address': 'Jl. Sudirman No. 100, Jakarta', 'phone': '021-98765432', 'isActive': 1, 'credit_limit': 10000000, 'current_credit': 0},
      {'name': 'Cabang Kemang', 'address': 'Jl. Kemang Raya No. 50, Jakarta', 'phone': '021-12345678', 'isActive': 1, 'credit_limit': 5000000, 'current_credit': 0},
      {'name': 'Cabang Blok M', 'address': 'Jl. Blok M No. 25, Jakarta', 'phone': '021-87654321', 'isActive': 1, 'credit_limit': 5000000, 'current_credit': 0},
    ];

    for (var out in outlets) {
      await db.insert('outlets', {
        ...out,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    // Get category IDs
    final catList = await db.query('categories', columns: ['id', 'name']);
    final catMap = {for (var c in catList) c['name'] as String: c['id'] as int};

    // Get supplier IDs
    final supList = await db.query('suppliers', columns: ['id', 'name']);
    final supMap = {for (var s in supList) s['name'] as String: s['id'] as int};

    // Static products list (20 predefined products)
    final products = [
      // Makanan Instan
      {'barcode': '8901234567890', 'name': 'Nasi Goreng Instan', 'category': 'Makanan Instan', 'purchasePrice': 4000.0, 'sellingPrice': 6000.0, 'stock': 50, 'minStock': 10, 'categoryId': catMap['Makanan Instan'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8901234567891', 'name': 'Mie Goreng Original', 'category': 'Makanan Instan', 'purchasePrice': 3500.0, 'sellingPrice': 5000.0, 'stock': 100, 'minStock': 20, 'categoryId': catMap['Makanan Instan'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8901234567892', 'name': 'Indomie Goreng', 'category': 'Makanan Instan', 'purchasePrice': 3200.0, 'sellingPrice': 4500.0, 'stock': 200, 'minStock': 50, 'categoryId': catMap['Makanan Instan'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8901234567893', 'name': 'Sup Mi Instan', 'category': 'Makanan Instan', 'purchasePrice': 3000.0, 'sellingPrice': 4000.0, 'stock': 150, 'minStock': 30, 'categoryId': catMap['Makanan Instan'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},

      // Minuman
      {'barcode': '8902345678901', 'name': 'Aqua 600ml', 'category': 'Minuman', 'purchasePrice': 3000.0, 'sellingPrice': 4000.0, 'stock': 100, 'minStock': 20, 'categoryId': catMap['Minuman'], 'supplierId': supMap['UD Sejahtera'], 'isActive': 1},
      {'barcode': '8902345678902', 'name': 'Teh Botol', 'category': 'Minuman', 'purchasePrice': 3500.0, 'sellingPrice': 5000.0, 'stock': 80, 'minStock': 15, 'categoryId': catMap['Minuman'], 'supplierId': supMap['UD Sejahtera'], 'isActive': 1},
      {'barcode': '8902345678903', 'name': 'Kopi Sachet', 'category': 'Minuman', 'purchasePrice': 1500.0, 'sellingPrice': 2500.0, 'stock': 200, 'minStock': 50, 'categoryId': catMap['Minuman'], 'supplierId': supMap['UD Sejahtera'], 'isActive': 1},
      {'barcode': '8902345678904', 'name': 'Susu Kotak', 'category': 'Minuman', 'purchasePrice': 4500.0, 'sellingPrice': 6000.0, 'stock': 60, 'minStock': 10, 'categoryId': catMap['Minuman'], 'supplierId': supMap['UD Sejahtera'], 'isActive': 1},
      {'barcode': '8902345678905', 'name': 'Jus Jeruk 500ml', 'category': 'Minuman', 'purchasePrice': 5000.0, 'sellingPrice': 7000.0, 'stock': 40, 'minStock': 10, 'categoryId': catMap['Minuman'], 'supplierId': supMap['UD Sejahtera'], 'isActive': 1},

      // Snack
      {'barcode': '8903456789012', 'name': 'Kripik Kentang', 'category': 'Snack', 'purchasePrice': 8000.0, 'sellingPrice': 12000.0, 'stock': 30, 'minStock': 10, 'categoryId': catMap['Snack'], 'supplierId': supMap['CV Maju Mundur'], 'isActive': 1},
      {'barcode': '8903456789013', 'name': 'Kripik Tempe', 'category': 'Snack', 'purchasePrice': 6000.0, 'sellingPrice': 9000.0, 'stock': 40, 'minStock': 10, 'categoryId': catMap['Snack'], 'supplierId': supMap['CV Maju Mundur'], 'isActive': 1},
      {'barcode': '8903456789014', 'name': 'Rautan Cheese', 'category': 'Snack', 'purchasePrice': 5000.0, 'sellingPrice': 7500.0, 'stock': 50, 'minStock': 15, 'categoryId': catMap['Snack'], 'supplierId': supMap['CV Maju Mundur'], 'isActive': 1},
      {'barcode': '8903456789015', 'name': 'Coklat Batangan', 'category': 'Snack', 'purchasePrice': 10000.0, 'sellingPrice': 15000.0, 'stock': 25, 'minStock': 5, 'categoryId': catMap['Snack'], 'supplierId': supMap['CV Maju Mundur'], 'isActive': 1},

      // Sembako
      {'barcode': '8904567890123', 'name': 'Beras 5kg', 'category': 'Sembako', 'purchasePrice': 65000.0, 'sellingPrice': 75000.0, 'stock': 20, 'minStock': 5, 'categoryId': catMap['Sembako'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8904567890124', 'name': 'Minyak Goreng 2L', 'category': 'Sembako', 'purchasePrice': 25000.0, 'sellingPrice': 30000.0, 'stock': 30, 'minStock': 10, 'categoryId': catMap['Sembako'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8904567890125', 'name': 'Gula Pasir 1kg', 'category': 'Sembako', 'purchasePrice': 12000.0, 'sellingPrice': 15000.0, 'stock': 40, 'minStock': 10, 'categoryId': catMap['Sembako'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8904567890126', 'name': 'Telur 1kg', 'category': 'Sembako', 'purchasePrice': 20000.0, 'sellingPrice': 25000.0, 'stock': 35, 'minStock': 10, 'categoryId': catMap['Sembako'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},

      // Makanan
      {'barcode': '8905678901234', 'name': 'Nugget 250g', 'category': 'Makanan', 'purchasePrice': 15000.0, 'sellingPrice': 20000.0, 'stock': 25, 'minStock': 5, 'categoryId': catMap['Makanan'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8905678901235', 'name': 'Sosis Sapi', 'category': 'Makanan', 'purchasePrice': 20000.0, 'sellingPrice': 28000.0, 'stock': 30, 'minStock': 5, 'categoryId': catMap['Makanan'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},

      // Rokok
      {'barcode': '8906789012345', 'name': 'Gudang Garam', 'category': 'Rokok', 'purchasePrice': 18000.0, 'sellingPrice': 22000.0, 'stock': 50, 'minStock': 10, 'categoryId': catMap['Rokok'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8906789012346', 'name': 'Sampoerna Mild', 'category': 'Rokok', 'purchasePrice': 22000.0, 'sellingPrice': 27000.0, 'stock': 40, 'minStock': 10, 'categoryId': catMap['Rokok'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
      {'barcode': '8906789012347', 'name': 'Dji Sam Soe', 'category': 'Rokok', 'purchasePrice': 25000.0, 'sellingPrice': 30000.0, 'stock': 35, 'minStock': 10, 'categoryId': catMap['Rokok'], 'supplierId': supMap['PT Sumber Berkah'], 'isActive': 1},
    ];

    // Insert predefined products
    for (var prod in products) {
      await db.insert('products', {
        ...prod,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Generate 10,000 products for performance testing
    final categoryEntries = catMap.entries.toList();
    final supplierEntries = supMap.entries.toList();
    int barcodeCounter = 1000000000000;
    int productsAdded = products.length;

    debugPrint('Generating 10,000 products - this may take a while...');

    // Product name prefixes per category for generating variety
    final productPrefixes = {
      'Makanan Instan': ['Mie', 'Supermi', 'Pop', 'Bakmi', 'Kwetiau', 'Bihun', 'Spaghetti', 'Macaroni', 'Fideos', 'Ramen'],
      'Minuman': ['Teh', 'Kopi', 'Susu', 'Jus', 'Air', 'Soda', 'Jamu', 'Wedang', 'Cincau', 'Es'],
      'Snack': ['Kripik', 'Biskuit', 'Coklat', 'Permen', 'Wafer', 'Cookies', 'Crackers', 'Makaroni', 'Edamame', 'Kacang'],
      'Sembako': ['Beras', 'Minyak', 'Gula', 'Tepung', 'Garam', 'Terasi', 'Sambal', 'Kecap', 'Sauce', 'Abon'],
      'Makanan': ['Nugget', 'Sosis', 'Patty', 'Dimsum', 'Kebab', 'Pizza', 'Burger', 'Steak', 'Pastel', 'Risotto'],
      'Rokok': ['Sigaret', 'Rokok', 'Cerutu', 'Tembakau', 'Vape', 'Liquid', 'Pod', 'Coil', 'Cotton', 'Wire'],
    };

    // Product suffixes for generating variations
    final productSuffixes = [
      'Original', 'Manis', 'Pedas', 'Asin', 'Jumbo', 'Mini', 'Premium', 'Gold', 'Silver', 'Basic',
      'Spesial', 'Classic', 'Modern', 'Natural', 'Organic', 'Mix', 'Plus', 'Super', 'Ultra', 'Mega',
      'Kecil', 'Besar', 'Medium', 'Ekstra', 'Super', 'Lite', 'Zero', 'Full', 'Reguler', 'Special',
    ];

    // Variants for more combinations
    final variants = ['250g', '500g', '1kg', '2kg', '5kg', '10pcs', '20pcs', '50pcs', '100ml', '200ml', '500ml', '1L', 'Sachet', 'Box', 'Pack', 'Botol', 'Kaleng', 'Strip', 'Blister', 'Cup'];

    // Additional categories for more variety
    final additionalCategories = [
      {'name': 'Obat-obatan', 'color': '#F44336', 'icon': 'medical'},
      {'name': 'Alat Rumah Tangga', 'color': '#607D8B', 'icon': 'home'},
      {'name': 'Kosmetik', 'color': '#E91E63', 'icon': 'beauty'},
      {'name': 'Elektronik', 'color': '#2196F3', 'icon': 'device'},
      {'name': 'Fashion', 'color': '#9C27B0', 'icon': 'shirt'},
      {'name': 'Olahraga', 'color': '#4CAF50', 'icon': 'sport'},
      {'name': 'Buku', 'color': '#795548', 'icon': 'book'},
      {'name': 'Mainan', 'color': '#FF9800', 'icon': 'toy'},
      {'name': 'Pertanian', 'color': '#8BC34A', 'icon': 'plant'},
      {'name': 'Perkakas', 'color': '#9E9E9E', 'icon': 'tool'},
    ];

    // Insert additional categories
    for (var cat in additionalCategories) {
      await db.insert('categories', {
        ...cat,
        'parentId': null,
        'sortOrder': 0,
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Re-fetch category list with new categories
    final allCatList = await db.query('categories', columns: ['id', 'name']);
    final allCatMap = {for (var c in allCatList) c['name'] as String: c['id'] as int};

    // Additional suppliers for more variety
    final additionalSuppliers = [
      {'name': 'PT Sehat Selalu', 'contactPerson': 'Dr. Anwar', 'phone': '081111111111', 'email': 'sehat@selalu.com', 'address': 'Jl. Sehat No 1', 'notes': 'Obat & farmasi', 'isActive': 1},
      {'name': 'CV Rumah Tangga Jaya', 'contactPerson': 'Ibu Sari', 'phone': '081222222222', 'email': 'rumah@tangga.com', 'address': 'Jl. Domestic No 2', 'notes': 'Alat rumah tangga', 'isActive': 1},
      {'name': 'PT Beauty Indonesia', 'contactPerson': 'Siti Beauty', 'phone': '081333333333', 'email': 'beauty@indonesia.com', 'address': 'Jl. Cantik No 3', 'notes': 'Kosmetik & skincare', 'isActive': 1},
      {'name': 'Toko Elektronik Prima', 'contactPerson': 'Budi Elektronik', 'phone': '081444444444', 'email': 'elektronik@prima.com', 'address': 'Jl. Tech No 4', 'notes': 'Elektronik & gadget', 'isActive': 1},
      {'name': 'Fashion House Indonesia', 'contactPerson': 'Diana Fashion', 'phone': '081555555555', 'email': 'fashion@house.com', 'address': 'Jl. Style No 5', 'notes': 'Pakaian & aksesoris', 'isActive': 1},
    ];

    for (var sup in additionalSuppliers) {
      await db.insert('suppliers', {
        ...sup,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    // Re-fetch supplier list
    final allSupList = await db.query('suppliers', columns: ['id', 'name']);
    final allSupMap = {for (var s in allSupList) s['name'] as String: s['id'] as int};

    // Update category map
    final updatedCatMap = {...catMap, ...allCatMap};
    final updatedSupMap = {...supMap, ...allSupMap};
    final updatedCatEntries = updatedCatMap.entries.toList();
    final updatedSupEntries = updatedSupMap.entries.toList();

    // Build extended prefixes with new categories
    final extendedPrefixes = {
      ...productPrefixes,
      'Obat-obatan': ['Vitamin', 'Suplemen', 'Obat', 'Sirup', 'Kapsul', 'Tablet', 'Salep', 'Krim', 'Bedak', 'Tetes'],
      'Alat Rumah Tangga': ['Sapu', 'Pel', 'Ember', 'Gayung', 'Panci', 'Wajan', 'Piring', 'Gelas', 'Sendok', 'Garpu'],
      'Kosmetik': ['Lipstick', 'Foundation', 'Mascara', 'Eyeliner', 'Blush', 'Powder', 'Serum', 'Moisturizer', 'Sunscreen', 'Toner'],
      'Elektronik': ['Charger', 'Kabel', 'Headset', 'Speaker', 'Powerbank', 'Lampu', 'Fan', 'Heater', 'Rice Cooker', 'Blender'],
      'Fashion': ['Baju', 'Celana', 'Rok', 'Jaket', 'Sepatu', 'Sandal', 'Tas', 'Topi', 'Scarf', 'Sarung'],
      'Olahraga': ['Bola', 'Raket', 'Matras', 'Dumbbell', 'Resistance', 'Skipping', 'Helm', 'Sarung Tangan', 'Pelampung', 'Sepeda'],
      'Buku': ['Novel', 'Komik', 'Textbook', 'Majalah', 'Kamus', 'Ensiklopedia', 'Biografi', 'Self-Help', 'Resep', 'Pelajaran'],
      'Mainan': ['Boneka', 'Mobil', 'Robot', 'Puzzle', 'Lego', 'Balon', 'Permainan', 'Action Figure', 'Play-Doh', 'Slime'],
      'Pertanian': ['Bibit', 'Pupuk', 'Pestisida', 'Herbisida', 'Sekop', 'Cangkul', 'Selang', 'Sprayer', 'Polybag', 'Media Tanam'],
      'Perkakas': ['Palu', 'Obeng', 'Kunci', 'Gergaji', 'Bor', 'Gerinda', 'Kikir', 'Pahat', 'Martil', 'Tang'],
    };

    // Prepare batch insert for performance
    final int targetProducts = 10000;
    final List<Map<String, dynamic>> productBatch = [];
    final int batchSize = 500; // Insert in batches of 500

    for (int i = 0; i < targetProducts; i++) {
      final idx = i % updatedCatEntries.length;
      final categoryName = updatedCatEntries[idx].key;
      final categoryId = updatedCatEntries[idx].value;
      final supplierIdx = i % updatedSupEntries.length;
      final supplierId = updatedSupEntries[supplierIdx].value;

      final prefixes = extendedPrefixes[categoryName] ?? ['Produk'];
      final prefix = prefixes[i % prefixes.length];
      final suffix = productSuffixes[i % productSuffixes.length];

      // Add variant sometimes
      final useVariant = i % 3 == 0;
      final variant = useVariant ? ' ${variants[(i ~/ 3) % variants.length]}' : '';

      final name = '$prefix $suffix$variant';
      final barcode = '${barcodeCounter++}';

      // Generate realistic prices
      final basePrice = 1000.0 + (i % 100000);
      final purchasePrice = basePrice * (1 + (i % 50) / 100);
      final margin = 1.20 + ((i % 40) / 100);
      final sellingPrice = purchasePrice * margin;

      final stock = 10 + (i % 200);
      final minStock = 5 + (i % 20);

      productBatch.add({
        'barcode': barcode,
        'name': name,
        'category': categoryName,
        'purchasePrice': purchasePrice.roundToDouble(),
        'sellingPrice': sellingPrice.roundToDouble(),
        'stock': stock,
        'minStock': minStock,
        'categoryId': categoryId,
        'supplierId': supplierId,
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Insert batch when full
      if (productBatch.length >= batchSize) {
        final batch = db.batch();
        for (var record in productBatch) {
          batch.insert('products', record);
        }
        await batch.commit(noResult: true);
        productsAdded += productBatch.length;
        debugPrint('Inserted $productsAdded / $targetProducts products...');
        productBatch.clear();
      }
    }

    // Insert remaining products
    if (productBatch.isNotEmpty) {
      final batch = db.batch();
      for (var record in productBatch) {
        batch.insert('products', record);
      }
      await batch.commit(noResult: true);
      productsAdded += productBatch.length;
      productBatch.clear();
    }

    debugPrint('Generated $productsAdded products total');

    // Insert sample transactions
    final userList = await db.query('users', columns: ['id']);
    final userId = userList.isNotEmpty ? userList.first['id'] : 1;
    final outletList = await db.query('outlets', columns: ['id']);
    final outletId = outletList.isNotEmpty ? outletList.first['id'] : 1;
    final productList = await db.query('products', columns: ['id', 'name', 'sellingPrice']);

    // Generate transactions for the last 7 days
    for (var i = 7; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final invoiceNum = 'INV-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}-${1000 + i}';

      // Random 3-8 items per transaction
      final itemCount = 3 + (i % 6);
      double totalAmount = 0;
      List<Map<String, dynamic>> transItems = [];

      for (var j = 0; j < itemCount && j < productList.length; j++) {
        final product = productList[j % productList.length];
        final price = product['sellingPrice'] as double;
        final qty = 1 + (j % 3);
        final subtotal = price * qty;
        totalAmount += subtotal;

        transItems.add({
          'transactionId': 0, // Will be updated
          'productId': product['id'],
          'productName': product['name'],
          'price': price,
          'originalPrice': price,
          'isPriceModified': 0,
          'quantity': qty,
          'subtotal': subtotal,
          'itemDiscount': 0,
          'cost': price * 0.7,
        });
      }

      final discount = totalAmount > 50000 ? totalAmount * 0.05 : 0.0;
      final finalAmount = totalAmount - discount;

      final transId = await db.insert('transactions', {
        'invoiceNumber': invoiceNum,
        'transactionDate': date.toIso8601String(),
        'totalAmount': totalAmount,
        'discount': discount,
        'finalAmount': finalAmount,
        'paymentMethod': i % 3 == 0 ? 'CREDIT' : 'CASH',
        'userId': userId,
        'outletId': outletId,
        'status': 'PAID',
        'customerName': i % 2 == 0 ? 'Pelanggan Umum' : null,
        'notes': i % 4 == 0 ? 'Transaksi cepat' : null,
      });

      // Update items with transaction ID
      for (var item in transItems) {
        item['transactionId'] = transId;
        await db.insert('transactionItems', item);
      }

      // Update stock
      for (var item in transItems) {
        final productId = item['productId'] as int;
        final qty = item['quantity'] as int;
        final currentProduct = await db.query('products', where: 'id = ?', whereArgs: [productId]);
        if (currentProduct.isNotEmpty) {
          final currentStock = currentProduct.first['stock'] as int;
          await db.update('products', {'stock': currentStock - qty}, where: 'id = ?', whereArgs: [productId]);
        }
      }
    }

    // Insert sample discounts
    final discounts = [
      {'name': 'Diskon 5% Pembelian >50rb', 'description': 'Diskon 5% untuk pembelian di atas 50 ribu', 'type': 'percentage', 'value': 5.0, 'minPurchase': 50000.0, 'maxDiscount': 10000.0, 'startDate': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(), 'endDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(), 'isActive': 1},
      {'name': 'Potongan 2000', 'description': 'Potongan harga 2000 untuk pembelian di atas 30 ribu', 'type': 'nominal', 'value': 2000.0, 'minPurchase': 30000.0, 'maxDiscount': null, 'startDate': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'endDate': DateTime.now().add(const Duration(days: 23)).toIso8601String(), 'isActive': 1},
    ];

    for (var disc in discounts) {
      await db.insert('discounts', {
        ...disc,
        'applicableProducts': null,
        'applicableCategories': null,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    debugPrint('Dummy data inserted successfully!');
  }
}
