// Hide Category from Flutter to avoid conflict with our model
import 'package:flutter/foundation.dart' hide Category;
import '../../models/category_model.dart';
import '../../services/category_service.dart';

class CategoryController extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Category> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  List<Category> get parentCategories =>
      _categories.where((c) => c.parentId == null).toList();

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await CategoryService.getCategories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCategories(String query) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (query.isEmpty) {
        _categories = await CategoryService.getCategories();
      } else {
        _categories = await CategoryService.searchCategories(query);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCategory(Category category) async {
    try {
      await CategoryService.createCategory(category);
      await loadCategories();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await CategoryService.updateCategory(category);
      await loadCategories();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await CategoryService.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleCategoryStatus(Category category) async {
    final updated = category.copyWith(isActive: !category.isActive);
    await updateCategory(updated);
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();

    try {
      await CategoryService.reorderCategories(_categories);
    } catch (e) {
      _error = e.toString();
      await loadCategories();
    }
  }

  List<Category> getSubCategories(int parentId) {
    return _categories.where((c) => c.parentId == parentId).toList();
  }
}
