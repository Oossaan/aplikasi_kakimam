import '../models/discount_model.dart';
import 'database_service.dart';

class DiscountService {
  // Get all discounts
  static Future<List<Discount>> getDiscounts({bool activeOnly = false}) async {
    String? where;
    if (activeOnly) {
      where = 'isActive = ?';
    }
    final results = await DatabaseService.query(
      'discounts',
      where: where,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return results.map((map) => Discount.fromMap(map)).toList();
  }

  // Get discount by ID
  static Future<Discount?> getDiscountById(int id) async {
    final results = await DatabaseService.query(
      'discounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Discount.fromMap(results.first);
  }

  // Create discount
  static Future<int> createDiscount(Discount discount) async {
    return await DatabaseService.insert(
        'discounts', discount.toMap()..remove('id'));
  }

  // Update discount
  static Future<int> updateDiscount(Discount discount) async {
    final data = discount.toMap();
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await DatabaseService.update(
      'discounts',
      data,
      where: 'id = ?',
      whereArgs: [discount.id],
    );
  }

  // Delete discount (soft delete)
  static Future<int> deleteDiscount(int id) async {
    return await DatabaseService.update(
      'discounts',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get active discounts for a purchase amount
  static Future<List<Discount>> getActiveDiscounts(
      double purchaseAmount) async {
    final now = DateTime.now().toIso8601String();
    final results = await DatabaseService.query(
      'discounts',
      where:
          'isActive = 1 AND startDate <= ? AND endDate >= ? AND minPurchase <= ?',
      whereArgs: [now, now, purchaseAmount],
      orderBy: 'value DESC',
    );
    return results.map((map) => Discount.fromMap(map)).toList();
  }

  // Get valid discounts for a product
  static Future<List<Discount>> getValidDiscountsForProduct(
      double purchaseAmount, int productId) async {
    final now = DateTime.now().toIso8601String();
    final results = await DatabaseService.rawQuery('''
      SELECT * FROM discounts
      WHERE isActive = 1
        AND startDate <= ?
        AND endDate >= ?
        AND minPurchase <= ?
        AND (
          applicableProducts IS NULL
          OR applicableProducts LIKE '%"?,"%'
          OR applicableProducts LIKE '%"?%'
          OR applicableProducts = '[]'
        )
      ORDER BY value DESC
    ''', [now, now, purchaseAmount, productId, productId]);
    return results.map((map) => Discount.fromMap(map)).toList();
  }

  // Calculate total discount for cart
  static Future<double> calculateCartDiscount(
      double subtotal, List<Discount> discounts) async {
    double totalDiscount = 0;

    for (var discount in discounts) {
      if (discount.isValidFor(subtotal)) {
        totalDiscount += discount.calculateDiscount(subtotal);
      }
    }

    return totalDiscount;
  }

  // Apply discounts to transaction
  static Future<void> applyDiscountsToTransaction(
    int transactionId,
    List<Discount> discounts,
    double subtotal,
  ) async {
    final db = await DatabaseService.database;

    await db.transaction((txn) async {
      for (var discount in discounts) {
        if (discount.isValidFor(subtotal)) {
          final discountAmount = discount.calculateDiscount(subtotal);
          await txn.insert('transactionDiscounts', {
            'transactionId': transactionId,
            'discountId': discount.id,
            'discountName': discount.name,
            'discountType': discount.type == DiscountType.percentage
                ? 'percentage'
                : 'nominal',
            'discountValue': discount.value,
            'discountAmount': discountAmount,
          });
        }
      }
    });
  }

  // Get discounts applied to a transaction
  static Future<List<TransactionDiscount>> getTransactionDiscounts(
      int transactionId) async {
    final results = await DatabaseService.query(
      'transactionDiscounts',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    return results.map((map) => TransactionDiscount.fromMap(map)).toList();
  }

  // Search discounts
  static Future<List<Discount>> searchDiscounts(String query) async {
    final results = await DatabaseService.query(
      'discounts',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((map) => Discount.fromMap(map)).toList();
  }

  // Get expiring soon (within 7 days)
  static Future<List<Discount>> getExpiringDiscounts() async {
    final now = DateTime.now();
    final futureDate = now.add(const Duration(days: 7));

    final results = await DatabaseService.query(
      'discounts',
      where: 'isActive = 1 AND endDate <= ? AND endDate >= ?',
      whereArgs: [
        futureDate.toIso8601String(),
        now.toIso8601String(),
      ],
      orderBy: 'endDate ASC',
    );
    return results.map((map) => Discount.fromMap(map)).toList();
  }
}
