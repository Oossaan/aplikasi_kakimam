import 'package:flutter/foundation.dart';
import '../../models/supplier_model.dart';
import '../../services/supplier_service.dart';

class SupplierController extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String? _error;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Supplier> get activeSuppliers =>
      _suppliers.where((s) => s.isActive).toList();

  Future<void> loadSuppliers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _suppliers = await SupplierService.getSuppliers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSuppliers(String query) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (query.isEmpty) {
        _suppliers = await SupplierService.getSuppliers();
      } else {
        _suppliers = await SupplierService.searchSuppliers(query);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSupplier(Supplier supplier) async {
    try {
      await SupplierService.createSupplier(supplier);
      await loadSuppliers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateSupplier(Supplier supplier) async {
    try {
      await SupplierService.updateSupplier(supplier);
      await loadSuppliers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      await SupplierService.deleteSupplier(id);
      await loadSuppliers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleSupplierStatus(Supplier supplier) async {
    final updated = supplier.copyWith(isActive: !supplier.isActive);
    await updateSupplier(updated);
  }
}
