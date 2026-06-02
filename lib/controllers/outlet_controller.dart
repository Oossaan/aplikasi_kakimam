import 'package:flutter/material.dart';
import '../models/outlet_model.dart';
import '../services/database_service.dart';

class OutletController extends ChangeNotifier {
  final List<Outlet> _outlets = [];
  Outlet? _selectedOutlet;
  bool _isLoading = false;

  List<Outlet> get outlets => _outlets;
  Outlet? get selectedOutlet => _selectedOutlet;
  bool get isLoading => _isLoading;

  List<Outlet> get activeOutlets => _outlets.where((o) => o.isActive).toList();

  Future<void> loadOutlets() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService.database;
      final maps = await db.query('outlets', orderBy: 'name ASC');
      _outlets.clear();
      _outlets.addAll(maps.map((map) => Outlet.fromMap(map)).toList());

      // Set default outlet if none selected
      if (_selectedOutlet == null && _outlets.isNotEmpty) {
        _selectedOutlet = _outlets.first;
      }
    } catch (e) {
      debugPrint('Error loading outlets: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectOutlet(Outlet outlet) {
    _selectedOutlet = outlet;
    notifyListeners();
  }

  void selectOutletById(int id) {
    final outlet = _outlets.firstWhere(
      (o) => o.id == id,
      orElse: () => _outlets.first,
    );
    selectOutlet(outlet);
  }

  Future<bool> addOutlet(Outlet outlet) async {
    try {
      final db = await DatabaseService.database;
      final map = outlet.toMap();
      map.remove('id');
      final id = await db.insert('outlets', map);

      final newOutlet = outlet.copyWith(id: id);
      _outlets.add(newOutlet);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding outlet: $e');
      return false;
    }
  }

  Future<bool> updateOutlet(Outlet outlet) async {
    try {
      final db = await DatabaseService.database;
      await db.update(
        'outlets',
        outlet.toMap(),
        where: 'id = ?',
        whereArgs: [outlet.id],
      );

      final index = _outlets.indexWhere((o) => o.id == outlet.id);
      if (index != -1) {
        _outlets[index] = outlet;
      }

      // Update selected outlet if it's the one being updated
      if (_selectedOutlet?.id == outlet.id) {
        _selectedOutlet = outlet;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating outlet: $e');
      return false;
    }
  }

  Future<bool> deleteOutlet(int id) async {
    try {
      final db = await DatabaseService.database;
      await db.delete('outlets', where: 'id = ?', whereArgs: [id]);

      _outlets.removeWhere((o) => o.id == id);

      // If the deleted outlet was selected, select another
      if (_selectedOutlet?.id == id && _outlets.isNotEmpty) {
        _selectedOutlet = _outlets.first;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting outlet: $e');
      return false;
    }
  }

  Future<bool> toggleOutletStatus(Outlet outlet) async {
    final updated = outlet.copyWith(isActive: !outlet.isActive);
    return updateOutlet(updated);
  }
}
