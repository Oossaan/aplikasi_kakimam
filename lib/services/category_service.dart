import '../models/category_model.dart';
import 'database_service.dart';

class CategoryService {
  // Get all categories
  static Future<List<Category>> getCategories({bool activeOnly = false}) async {
    String? where;
    List<Object>? whereArgs;
    if (activeOnly) {
      where = 'isActive = ?';
      whereArgs = [1];
    }
    final results = await DatabaseService.query(
      'categories',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sortOrder ASC, name ASC',
    );

    // Get product counts
    List<Category> categories = [];
    for (var map in results) {
      final cat = Category.fromMap(map);

      // Get product count for this category
      final countResult = await DatabaseService.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE categoryId = ?',
        [cat.id],
      );
      final productCount = countResult.first['count'] as int;

      categories.add(cat.copyWith(productCount: productCount));
    }
    return categories;
  }

  // Get category by ID
  static Future<Category?> getCategoryById(int id) async {
    final results = await DatabaseService.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Category.fromMap(results.first);
  }

  // Create category
  static Future<int> createCategory(Category category) async {
    return await DatabaseService.insert('categories', {
      'name': category.name,
      'description': category.description,
      'color': category.color,
      'icon': category.icon,
      'parentId': category.parentId,
      'sortOrder': category.sortOrder,
      'isActive': category.isActive ? 1 : 0,
      'createdAt': category.createdAt.toIso8601String(),
      'updatedAt': category.updatedAt.toIso8601String(),
    });
  }

  // Update category
  static Future<int> updateCategory(Category category) async {
    return await DatabaseService.update(
      'categories',
      {
        'name': category.name,
        'description': category.description,
        'color': category.color,
        'icon': category.icon,
        'parentId': category.parentId,
        'sortOrder': category.sortOrder,
        'isActive': category.isActive ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // Delete category (soft delete)
  static Future<int> deleteCategory(int id) async {
    return await DatabaseService.update(
      'categories',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get parent categories only (for dropdown)
  static Future<List<Category>> getParentCategories(
      {bool activeOnly = false}) async {
    String? where = 'parentId IS NULL';
    List<Object> whereArgs = [];
    if (activeOnly) {
      where += ' AND isActive = ?';
      whereArgs.add(1);
    }
    final results = await DatabaseService.query(
      'categories',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sortOrder ASC, name ASC',
    );
    return results.map((map) => Category.fromMap(map)).toList();
  }

  // Get subcategories
  static Future<List<Category>> getSubCategories(int parentId) async {
    final results = await DatabaseService.query(
      'categories',
      where: 'parentId = ?',
      whereArgs: [parentId],
      orderBy: 'sortOrder ASC, name ASC',
    );
    return results.map((map) => Category.fromMap(map)).toList();
  }

  // Build tree structure
  static Future<List<Category>> getCategoryTree() async {
    final allCategories = await getCategories();

    // Build tree
    List<Category> buildTree(int? parentId) {
      return allCategories
          .where((cat) => cat.parentId == parentId)
          .map((cat) => cat.copyWith(
                children: buildTree(cat.id),
              ))
          .toList();
    }

    return buildTree(null);
  }

  // Get all descendant IDs (including self)
  static Future<List<int>> getAllDescendantIds(int categoryId) async {
    List<int> ids = [categoryId];

    Future<void> getDescendants(int parentId) async {
      final subCategories = await getSubCategories(parentId);
      for (var cat in subCategories) {
        ids.add(cat.id!);
        await getDescendants(cat.id!);
      }
    }

    await getDescendants(categoryId);
    return ids;
  }

  // Get breadcrumb path
  static Future<List<Category>> getBreadcrumb(int categoryId) async {
    List<Category> breadcrumb = [];

    Future<void> buildPath(int id) async {
      final category = await getCategoryById(id);
      if (category != null) {
        breadcrumb.insert(0, category);
        if (category.parentId != null) {
          await buildPath(category.parentId!);
        }
      }
    }

    await buildPath(categoryId);
    return breadcrumb;
  }

  // Reorder categories
  static Future<void> reorderCategories(List<Category> categories) async {
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      for (int i = 0; i < categories.length; i++) {
        await txn.update(
          'categories',
          {'sortOrder': i},
          where: 'id = ?',
          whereArgs: [categories[i].id],
        );
      }
    });
  }

  // Search categories
  static Future<List<Category>> searchCategories(String query) async {
    final results = await DatabaseService.query(
      'categories',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((map) => Category.fromMap(map)).toList();
  }
}
