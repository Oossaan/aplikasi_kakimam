import 'package:flutter/material.dart';
import '../models/sales_model.dart';
import '../services/database_service.dart';

class SalesController extends ChangeNotifier {
  final List<Sales> _sales = [];
  Sales? _selectedSales;
  bool _isLoading = false;

  List<Sales> get sales => _sales;
  Sales? get selectedSales => _selectedSales;
  bool get isLoading => _isLoading;

  List<Sales> get activeSales => _sales.where((s) => s.isActive).toList();

  Future<void> loadSales() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService.database;
      final maps = await db.query('sales', orderBy: 'name ASC');
      _sales.clear();
      _sales.addAll(maps.map((map) => Sales.fromMap(map)).toList());

      // Set default sales if none selected
      if (_selectedSales == null && _sales.isNotEmpty) {
        _selectedSales = _sales.first;
      }
    } catch (e) {
      debugPrint('Error loading sales: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectSales(Sales sales) {
    _selectedSales = sales;
    notifyListeners();
  }

  void selectSalesById(int id) {
    final sales = _sales.firstWhere(
      (s) => s.id == id,
      orElse: () => _sales.first,
    );
    selectSales(sales);
  }

  Future<bool> addSales(Sales sales) async {
    try {
      final db = await DatabaseService.database;
      final map = sales.toMap();
      map.remove('id');
      final id = await db.insert('sales', map);

      final newSales = sales.copyWith(id: id);
      _sales.add(newSales);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding sales: $e');
      return false;
    }
  }

  Future<bool> updateSales(Sales sales) async {
    try {
      final db = await DatabaseService.database;
      await db.update(
        'sales',
        sales.toMap(),
        where: 'id = ?',
        whereArgs: [sales.id],
      );

      final index = _sales.indexWhere((s) => s.id == sales.id);
      if (index != -1) {
        _sales[index] = sales;
      }

      // Update selected sales if it's the one being updated
      if (_selectedSales?.id == sales.id) {
        _selectedSales = sales;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating sales: $e');
      return false;
    }
  }

  Future<bool> deleteSales(int id) async {
    try {
      final db = await DatabaseService.database;
      await db.delete('sales', where: 'id = ?', whereArgs: [id]);

      _sales.removeWhere((s) => s.id == id);

      // If the deleted sales was selected, select another
      if (_selectedSales?.id == id && _sales.isNotEmpty) {
        _selectedSales = _sales.first;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting sales: $e');
      return false;
    }
  }

  Future<bool> toggleSalesStatus(Sales sales) async {
    final updated = sales.copyWith(isActive: !sales.isActive);
    return updateSales(updated);
  }
}
