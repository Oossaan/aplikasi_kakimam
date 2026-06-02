import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'database_service.dart';

class InventoryService {
  static Future<List<Product>> getAllProducts() async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query('products');
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  static Future<Product?> getProductById(int id) async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Product.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product: $e');
      return null;
    }
  }

  static Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      if (maps.isNotEmpty) {
        return Product.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product by barcode: $e');
      return null;
    }
  }

  static Future<bool> addProduct(Product product) async {
    try {
      final db = await DatabaseService.database;
      await db.insert('products', product.toMap());
      return true;
    } catch (e) {
      debugPrint('Error adding product: $e');
      return false;
    }
  }

  static Future<bool> updateProduct(Product product) async {
    try {
      final db = await DatabaseService.database;
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(int id) async {
    try {
      final db = await DatabaseService.database;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  static Future<bool> updateStock(int productId, int quantity) async {
    try {
      final db = await DatabaseService.database;
      final product = await getProductById(productId);

      if (product == null) return false;

      final newStock = product.stock + quantity;
      if (newStock < 0) return false;

      await db.update(
        'products',
        {
          'stock': newStock,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating stock: $e');
      return false;
    }
  }

  static Future<List<Product>> searchProducts(String query) async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ? OR category LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  static Future<List<Product>> getLowStockProducts() async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'stock < ?',
        whereArgs: [10],
      );
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting low stock products: $e');
      return [];
    }
  }
}
