import '../models/supplier_model.dart';
import 'database_service.dart';

class SupplierService {
  // Get all suppliers
  static Future<List<Supplier>> getSuppliers({bool activeOnly = false}) async {
    String? where;
    if (activeOnly) {
      where = 'isActive = ?';
    }
    final results = await DatabaseService.query(
      'suppliers',
      where: where,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return results.map((map) => Supplier.fromMap(map)).toList();
  }

  // Get supplier by ID
  static Future<Supplier?> getSupplierById(int id) async {
    final results = await DatabaseService.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Supplier.fromMap(results.first);
  }

  // Create supplier
  static Future<int> createSupplier(Supplier supplier) async {
    return await DatabaseService.insert(
        'suppliers', supplier.toMap()..remove('id'));
  }

  // Update supplier
  static Future<int> updateSupplier(Supplier supplier) async {
    final data = supplier.toMap();
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await DatabaseService.update(
      'suppliers',
      data,
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  // Delete supplier (soft delete)
  static Future<int> deleteSupplier(int id) async {
    return await DatabaseService.update(
      'suppliers',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Hard delete supplier
  static Future<int> hardDeleteSupplier(int id) async {
    return await DatabaseService.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Search suppliers
  static Future<List<Supplier>> searchSuppliers(String query) async {
    final results = await DatabaseService.query(
      'suppliers',
      where: 'name LIKE ? OR contactPerson LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((map) => Supplier.fromMap(map)).toList();
  }

  // Get suppliers for a product
  static Future<List<ProductSupplier>> getProductSuppliers(
      int productId) async {
    final results = await DatabaseService.rawQuery('''
      SELECT ps.*, s.name as supplierName
      FROM productSuppliers ps
      JOIN suppliers s ON ps.supplierId = s.id
      WHERE ps.productId = ?
      ORDER BY ps.isPrimary DESC, s.name ASC
    ''', [productId]);
    return results.map((map) => ProductSupplier.fromMap(map)).toList();
  }

  // Add supplier to product
  static Future<int> addProductSupplier(ProductSupplier ps) async {
    return await DatabaseService.insert(
        'productSuppliers', ps.toMap()..remove('id'));
  }

  // Update product supplier
  static Future<int> updateProductSupplier(ProductSupplier ps) async {
    return await DatabaseService.update(
      'productSuppliers',
      ps.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [ps.id],
    );
  }

  // Remove supplier from product
  static Future<int> removeProductSupplier(
      int productId, int supplierId) async {
    return await DatabaseService.delete(
      'productSuppliers',
      where: 'productId = ? AND supplierId = ?',
      whereArgs: [productId, supplierId],
    );
  }

  // Set primary supplier
  static Future<void> setPrimarySupplier(int productId, int supplierId) async {
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      // Reset all to non-primary
      await txn.update(
        'productSuppliers',
        {'isPrimary': 0},
        where: 'productId = ?',
        whereArgs: [productId],
      );
      // Set selected as primary
      await txn.update(
        'productSuppliers',
        {'isPrimary': 1},
        where: 'productId = ? AND supplierId = ?',
        whereArgs: [productId, supplierId],
      );
    });
  }
}
