import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class AuthController extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _currentUser?.role == 'admin';

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );

      if (maps.isNotEmpty) {
        _currentUser = User.fromMap(maps.first);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Username atau password salah';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
