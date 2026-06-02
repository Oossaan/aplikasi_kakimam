import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService {
  static Future<User?> login(String username, String password) async {
    try {
      final db = await DatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );

      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error login: $e');
      return null;
    }
  }

  static Future<bool> register(User user) async {
    try {
      final db = await DatabaseService.database;

      // Check if username exists
      final List<Map<String, dynamic>> existing = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [user.username],
      );

      if (existing.isNotEmpty) {
        return false;
      }

      await db.insert('users', user.toMap());
      return true;
    } catch (e) {
      debugPrint('Error register: $e');
      return false;
    }
  }
}
