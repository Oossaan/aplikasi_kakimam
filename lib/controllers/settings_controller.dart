import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  String? _errorMessage;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SettingsController() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await SettingsService.getSettings();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal memuat pengaturan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSettings(AppSettings newSettings) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _settingsService.updateSettings(newSettings);
      if (success) {
        _settings = newSettings;
        _errorMessage = null;
      } else {
        _errorMessage = 'Gagal menyimpan pengaturan';
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStoreInfo({
    required String storeName,
    required String storeAddress,
    required String storePhone,
  }) async {
    final newSettings = _settings.copyWith(
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );
    return await updateSettings(newSettings);
  }

  Future<bool> updatePreferences({
    required double defaultTax,
    required int lowStockThreshold,
    required String receiptFooter,
  }) async {
    final newSettings = _settings.copyWith(
      defaultTax: defaultTax,
      lowStockThreshold: lowStockThreshold,
      receiptFooter: receiptFooter,
    );
    return await updateSettings(newSettings);
  }

  Future<bool> updateUserProfile({
    required int userId,
    required String name,
    String? newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _settingsService.updateUserProfile(userId, name, newPassword);
      if (!success) {
        _errorMessage = 'Gagal memperbarui profil';
      } else {
        _errorMessage = null;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> updateBankInfo({
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountHolder,
    String? qrisImagePath,
  }) async {
    final newSettings = _settings.copyWith(
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountHolder: bankAccountHolder,
      qrisImagePath: qrisImagePath ?? _settings.qrisImagePath,
    );
    return await updateSettings(newSettings);
  }

  Future<bool> verifyPin(String pin) async {
    try {
      return await _settingsService.verifyPin(pin);
    } catch (e) {
      return false;
    }
  }

  Future<bool> updatePin({
    required String currentLoginPassword,
    required String newPin,
    required bool enablePin,
    required int userId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _settingsService.updatePin(
        currentLoginPassword: currentLoginPassword,
        newPin: newPin,
        enablePin: enablePin,
        userId: userId,
      );
      if (success) {
        // Reload settings to get updated values
        await loadSettings();
        _errorMessage = null;
      } else {
        _errorMessage = 'Password login salah atau terjadi kesalahan';
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

