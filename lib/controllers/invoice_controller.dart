import 'package:flutter/foundation.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../services/transaction_service.dart';
import '../../services/stock_service.dart';

class InvoiceController extends ChangeNotifier {
  List<Transaction> _invoices = [];
  bool _isLoading = false;
  String? _error;
  double _totalUnpaid = 0;

  List<Transaction> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get totalUnpaid => _totalUnpaid;

Future<void> loadInvoices({
    DateTime? startDate,
    DateTime? endDate,
    String status = 'all',
    String sortBy = 'date_desc',
    String? searchQuery,
    String? paymentMethod,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _invoices = await TransactionService.getInvoices(
        startDate: startDate,
        endDate: endDate,
        status: status == 'all' ? null : status,
        sortBy: sortBy,
        searchQuery: searchQuery,
        paymentMethod: paymentMethod,
      );
      // Calculate total unpaid from transactions with UNPAID or PARTIAL status
      double total = 0;
      for (var invoice in _invoices) {
        final db = await DatabaseService.database;
        final result = await db.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [invoice.id],
        );
        if (result.isNotEmpty) {
          final paymentStatus = result.first['payment_status'] as String?;
          final remaining =
              (result.first['remaining_amount'] as num?)?.toDouble() ?? 0;
          if (paymentStatus == 'UNPAID' || paymentStatus == 'PARTIAL') {
            total += remaining;
          }
        }
      }
      _totalUnpaid = total;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Transaction?> getInvoiceById(int id) async {
    return await TransactionService.getInvoiceById(id);
  }

  Future<void> voidTransaction(int id, String reason) async {
    try {
      // Get invoice first to restore stock
      final invoice = await TransactionService.getInvoiceById(id);
      if (invoice == null) return;

      // Restore stock for each item
      for (var item in invoice.items) {
        await StockService.restoreStock(
          productId: item.productId,
          quantity: item.quantity,
          referenceId: id,
          notes: 'Void invoice ${invoice.invoiceNumber}',
        );
      }

      // Update transaction status
      await TransactionService.voidTransaction(id, reason);
      await loadInvoices();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getSalesSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await TransactionService.getSalesSummary(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
