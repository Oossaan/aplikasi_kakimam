import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../config/routes.dart';
import '../../services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeNameController;
  late TextEditingController _storeAddressController;
  late TextEditingController _storePhoneController;
  late TextEditingController _taxController;
  late TextEditingController _lowStockController;
  late TextEditingController _receiptFooterController;
  late TextEditingController _nameController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _bankAccountHolderController;
  late TextEditingController _pinController;
  late TextEditingController _confirmPinController;
  late TextEditingController _loginPasswordForPinController;

  bool _isEditingStore = false;
  bool _isEditingProfile = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _obscureLoginPassword = true;
  bool _isEditingBank = false;
  bool _isEditingPin = false;
  bool _pinEnabled = false;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    final settingsController = context.read<SettingsController>();
    final authController = context.read<AuthController>();

    _storeNameController = TextEditingController(text: settingsController.settings.storeName);
    _storeAddressController = TextEditingController(text: settingsController.settings.storeAddress);
    _storePhoneController = TextEditingController(text: settingsController.settings.storePhone);
    _taxController = TextEditingController(text: settingsController.settings.defaultTax.toString());
    _lowStockController = TextEditingController(text: settingsController.settings.lowStockThreshold.toString());
    _receiptFooterController = TextEditingController(text: settingsController.settings.receiptFooter);
    _nameController = TextEditingController(text: authController.currentUser?.name ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _bankNameController = TextEditingController(text: settingsController.settings.bankName);
    _bankAccountNumberController = TextEditingController(text: settingsController.settings.bankAccountNumber);
    _bankAccountHolderController = TextEditingController(text: settingsController.settings.bankAccountHolder);
    _pinController = TextEditingController();
    _confirmPinController = TextEditingController();
    _loginPasswordForPinController = TextEditingController();
    _pinEnabled = settingsController.settings.isPinEnabled;

    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Error loading version: $e');
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _taxController.dispose();
    _lowStockController.dispose();
    _receiptFooterController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountHolderController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _loginPasswordForPinController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreInfo() async {
    final controller = context.read<SettingsController>();
    final success = await controller.updateStoreInfo(
      storeName: _storeNameController.text.trim(),
      storeAddress: _storeAddressController.text.trim(),
      storePhone: _storePhoneController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _isEditingStore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informasi toko berhasil disimpan'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _savePreferences() async {
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final lowStock = int.tryParse(_lowStockController.text) ?? 10;

    final controller = context.read<SettingsController>();
    final success = await controller.updatePreferences(
      defaultTax: tax,
      lowStockThreshold: lowStock,
      receiptFooter: _receiptFooterController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferensi berhasil disimpan'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_newPasswordController.text.isNotEmpty &&
        _newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password baru tidak cocok'), backgroundColor: Colors.red),
      );
      return;
    }

    final authController = context.read<AuthController>();
    final userId = authController.currentUser?.id;
    if (userId == null) return;

    final controller = context.read<SettingsController>();
    final success = await controller.updateUserProfile(
      userId: userId,
      name: _nameController.text.trim(),
      newPassword: _newPasswordController.text.isNotEmpty ? _newPasswordController.text : null,
    );

    if (success && mounted) {
      setState(() => _isEditingProfile = false);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _currentPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _saveBankInfo() async {
    final controller = context.read<SettingsController>();
    final success = await controller.updateBankInfo(
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim(),
      bankAccountHolder: _bankAccountHolderController.text.trim(),
    );

    if (success && mounted) {
      setState(() => _isEditingBank = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data bank/QRIS berhasil disimpan'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _savePin() async {
    final authController = context.read<AuthController>();
    final userId = authController.currentUser?.id;
    if (userId == null) return;

    if (_loginPasswordForPinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password login harus diisi'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_pinEnabled && (_pinController.text.isEmpty || _pinController.text.length < 4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus minimal 4 digit'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_pinEnabled && _pinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN baru tidak cocok'), backgroundColor: Colors.red),
      );
      return;
    }

    final controller = context.read<SettingsController>();
    final success = await controller.updatePin(
      currentLoginPassword: _loginPasswordForPinController.text,
      newPin: _pinController.text,
      enablePin: _pinEnabled,
      userId: userId,
    );

    if (success && mounted) {
      setState(() {
        _isEditingPin = false;
        _pinController.clear();
        _confirmPinController.clear();
        _loginPasswordForPinController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN berhasil diperbarui'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password login salah'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> verifyPinDialog() async {
    final controller = context.read<SettingsController>();
    if (!controller.settings.isPinEnabled) return true;

    final pinController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIcons.lock(PhosphorIconsStyle.bold), color: const Color(0xFF667eea)),
            SizedBox(width: 10),
            Text('Verifikasi PIN'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan PIN untuk melanjutkan:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PIN',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(PhosphorIcons.key(PhosphorIconsStyle.bold)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(dialogContext);
              final isValid = await controller.verifyPin(pinController.text);
              if (isValid) {
                verified = true;
                navigator.pop();
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text('PIN salah'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('VERIFIKASI'),
          ),
        ],
      ),
    );

    pinController.dispose();
    return verified;
  }

  Future<void> _checkForUpdate() async {
    try {
      final updateInfo = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aplikasi sudah dalam versi terbaru'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memeriksa update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showUpdateDialog(dynamic updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 10),
            Text('Update Tersedia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi terbaru: ${updateInfo.version}'),
            const SizedBox(height: 10),
            Text(updateInfo.releaseNotes ?? 'Tidak ada catatan rilis'),
            const SizedBox(height: 10),
            Text(
              'Tanggal: ${updateInfo.releaseDate?.toString().split(' ')[0] ?? "Tidak diketahui"}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final isWindows = Theme.of(context).platform == TargetPlatform.windows;
              UpdateService.downloadUpdate(context, updateInfo, isWindows);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Update'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthController>().logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: const Color(0xFF667eea).withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF667eea)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1f2937),
            ),
          ),
          iconColor: const Color(0xFF667eea),
          collapsedIconColor: Colors.grey.shade400,
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
          expandedAlignment: Alignment.topLeft,
          children: [
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _customInputDecoration({required String label, required IconData prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9fafb),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = context.watch<SettingsController>();
    final authController = context.watch<AuthController>();
    final settings = settingsController.settings;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(PhosphorIcons.gear(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: settingsController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==== AKUN ====
                    _buildCollapsibleCard(
                      title: 'Akun',
                      icon: PhosphorIcons.user(PhosphorIconsStyle.bold),
                      initiallyExpanded: true,
                      child: Column(
                        children: [
                          if (!_isEditingProfile) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF667eea),
                                child: Text(
                                  (authController.currentUser?.name ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(authController.currentUser?.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(authController.currentUser?.role ?? ''),
                              trailing: TextButton.icon(
                                onPressed: () => setState(() => _isEditingProfile = true),
                                icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 14),
                                label: const Text('Edit'),
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: _customInputDecoration(
                                label: 'Nama',
                                prefixIcon: PhosphorIcons.user(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: _obscureCurrentPassword,
                              decoration: _customInputDecoration(
                                label: 'Password Saat Ini',
                                prefixIcon: PhosphorIcons.lock(PhosphorIconsStyle.bold),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureCurrentPassword ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold) : PhosphorIcons.eye(PhosphorIconsStyle.bold), size: 16),
                                  onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              decoration: _customInputDecoration(
                                label: 'Password Baru (opsional)',
                                prefixIcon: PhosphorIcons.key(PhosphorIconsStyle.bold),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureNewPassword ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold) : PhosphorIcons.eye(PhosphorIconsStyle.bold), size: 16),
                                  onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: _customInputDecoration(
                                label: 'Konfirmasi Password Baru',
                                prefixIcon: PhosphorIcons.key(PhosphorIconsStyle.bold),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold) : PhosphorIcons.eye(PhosphorIconsStyle.bold), size: 16),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _isEditingProfile = false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('BATAL'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667eea),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('SIMPAN'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ==== PENGATURAN TOKO ====
                    _buildCollapsibleCard(
                      title: 'Pengaturan Toko',
                      icon: PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                      child: Column(
                        children: [
                          if (!_isEditingStore) ...[
                            _buildInfoRow('Nama Toko', settings.storeName.isEmpty ? '-' : settings.storeName),
                            const Divider(height: 20),
                            _buildInfoRow('Alamat', settings.storeAddress.isEmpty ? '-' : settings.storeAddress),
                            const Divider(height: 20),
                            _buildInfoRow('Telepon', settings.storePhone.isEmpty ? '-' : settings.storePhone),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  final settings = context.read<SettingsController>().settings;
                                  _storeNameController.text = settings.storeName;
                                  _storeAddressController.text = settings.storeAddress;
                                  _storePhoneController.text = settings.storePhone;
                                  setState(() => _isEditingStore = true);
                                },
                                icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 14),
                                label: const Text('Edit'),
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _storeNameController,
                              decoration: _customInputDecoration(
                                label: 'Nama Toko',
                                prefixIcon: PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _storeAddressController,
                              maxLines: 2,
                              decoration: _customInputDecoration(
                                label: 'Alamat Toko',
                                prefixIcon: PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _storePhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _customInputDecoration(
                                label: 'Telepon',
                                prefixIcon: PhosphorIcons.phone(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _isEditingStore = false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('BATAL'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveStoreInfo,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667eea),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('SIMPAN'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ==== DATA BANK / QRIS ====
                    _buildCollapsibleCard(
                      title: 'Data Bank / QRIS',
                      icon: PhosphorIcons.creditCard(PhosphorIconsStyle.bold),
                      child: Column(
                        children: [
                          if (!_isEditingBank) ...[
                            _buildInfoRow('Nama Bank', settings.bankName.isEmpty ? '-' : settings.bankName),
                            const Divider(height: 20),
                            _buildInfoRow('No. Rekening', settings.bankAccountNumber.isEmpty ? '-' : settings.bankAccountNumber),
                            const Divider(height: 20),
                            _buildInfoRow('Atas Nama', settings.bankAccountHolder.isEmpty ? '-' : settings.bankAccountHolder),
                            const Divider(height: 20),
                            _buildInfoRow('QRIS', settings.qrisImagePath.isEmpty ? 'Tidak ada' : 'Tersedia'),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  final settings = context.read<SettingsController>().settings;
                                  _bankNameController.text = settings.bankName;
                                  _bankAccountNumberController.text = settings.bankAccountNumber;
                                  _bankAccountHolderController.text = settings.bankAccountHolder;
                                  setState(() => _isEditingBank = true);
                                },
                                icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 14),
                                label: const Text('Edit'),
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _bankNameController,
                              decoration: _customInputDecoration(
                                label: 'Nama Bank',
                                prefixIcon: PhosphorIcons.buildings(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bankAccountNumberController,
                              keyboardType: TextInputType.number,
                              decoration: _customInputDecoration(
                                label: 'No. Rekening',
                                prefixIcon: PhosphorIcons.hash(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bankAccountHolderController,
                              decoration: _customInputDecoration(
                                label: 'Atas Nama',
                                prefixIcon: PhosphorIcons.user(PhosphorIconsStyle.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _isEditingBank = false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('BATAL'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveBankInfo,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667eea),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('SIMPAN'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ==== PENGATURAN PIN ====
                    _buildCollapsibleCard(
                      title: 'Pengaturan PIN Keamanan',
                      icon: PhosphorIcons.lock(PhosphorIconsStyle.bold),
                      child: Column(
                        children: [
                          if (!_isEditingPin) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Aktifkan PIN untuk operasi sensitif', style: TextStyle(fontSize: 14)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _pinEnabled ? Colors.green.shade100 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _pinEnabled ? 'AKTIF' : 'TIDAK AKTIF',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _pinEnabled ? Colors.green.shade700 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _pinEnabled,
                                  activeColor: const Color(0xFF667eea),
                                  onChanged: (value) => setState(() {
                                    _pinEnabled = value;
                                    _isEditingPin = true;
                                  }),
                                ),
                              ],
                            ),
                            if (_pinEnabled)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'PIN digunakan untuk menghapus/membatalkan transaksi',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(() => _isEditingPin = true),
                                icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 14),
                                label: const Text('Ubah PIN'),
                              ),
                            ),
                          ] else ...[
                            SwitchListTile(
                              title: const Text('Aktifkan PIN'),
                              subtitle: const Text('Minimal 4 digit'),
                              value: _pinEnabled,
                              activeColor: const Color(0xFF667eea),
                              onChanged: (value) => setState(() => _pinEnabled = value),
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (_pinEnabled) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pinController,
                                obscureText: _obscurePin,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: _customInputDecoration(
                                  label: 'PIN Baru',
                                  prefixIcon: PhosphorIcons.key(PhosphorIconsStyle.bold),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePin ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold) : PhosphorIcons.eye(PhosphorIconsStyle.bold), size: 16),
                                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPinController,
                                obscureText: _obscureConfirmPin,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: _customInputDecoration(
                                  label: 'Konfirmasi PIN Baru',
                                  prefixIcon: PhosphorIcons.key(PhosphorIconsStyle.bold),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirmPin ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold) : PhosphorIcons.eye(PhosphorIconsStyle.bold), size: 16),
                                    onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _loginPasswordForPinController,
                              obscureText: _obscureLoginPassword,
                              decoration: _customInputDecoration(
                                label: 'Password Login (wajib)',
                                prefixIcon: PhosphorIcons.lock(PhosphorIconsStyle.bold),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureLoginPassword ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold) : PhosphorIcons.eye(PhosphorIconsStyle.bold), size: 16),
                                  onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() {
                                      _isEditingPin = false;
                                      _pinController.clear();
                                      _confirmPinController.clear();
                                      _loginPasswordForPinController.clear();
                                      _pinEnabled = settings.isPinEnabled;
                                    }),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('BATAL'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _savePin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667eea),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('SIMPAN'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ==== PREFERENSI APLIKASI ====
                    _buildCollapsibleCard(
                      title: 'Preferensi Aplikasi',
                      icon: PhosphorIcons.sliders(PhosphorIconsStyle.bold),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _taxController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _customInputDecoration(
                              label: 'Pajak Default (%)',
                              prefixIcon: PhosphorIcons.percent(PhosphorIconsStyle.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lowStockController,
                            keyboardType: TextInputType.number,
                            decoration: _customInputDecoration(
                              label: 'Batas Stok Menipis',
                              prefixIcon: PhosphorIcons.warning(PhosphorIconsStyle.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _receiptFooterController,
                            maxLines: 2,
                            decoration: _customInputDecoration(
                              label: 'Footer Struk',
                              prefixIcon: PhosphorIcons.receipt(PhosphorIconsStyle.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _savePreferences,
                              icon: Icon(PhosphorIcons.floppyDisk(PhosphorIconsStyle.bold)),
                              label: const Text('SIMPAN PREFERENSI'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==== FAQ ====\r\n                    _buildCollapsibleCard(\r\n                      title: 'FAQ (Pertanyaan Umum)',\r\n                      icon: PhosphorIcons.chatCircleDots(PhosphorIconsStyle.bold),\r\n                      child: Column(\r\n                        children: [\r\n                          ExpansionTile(\r\n                            title: const Text('Bagaimana cara melakukan pembayaran piutang?'),\r\n                            children: [\r\n                              Padding(\r\n                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),\r\n                                child: const Text(\r\n                                  'Buka menu “Piutang & Tagihan”. Pada tab “Tempo Outlet” pilih invoice yang belum lunas, lalu tekan tombol “BAYAR”. Jika berhasil, status akan berubah menjadi PAID atau PARTIAL sesuai sisa pembayaran.',\r\n                                  style: TextStyle(fontSize: 13, color: Colors.black54),\r\n                                ),\r\n                              ),\r\n                            ],\r\n                          ),\r\n                          ExpansionTile(\r\n                            title: const Text('Apa perbedaan Tempo & Riwayat?'),\r\n                            children: [\r\n                              Padding(\r\n                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),\r\n                                child: const Text(\r\n                                  'Tempo menampilkan data yang belum/masih berjalan (UNPAID/PARTIAL). Riwayat menampilkan data yang sudah selesai (PAID).',\r\n                                  style: TextStyle(fontSize: 13, color: Colors.black54),\r\n                                ),\r\n                              ),\r\n                            ],\r\n                          ),\r\n                          ExpansionTile(\r\n                            title: const Text('Mengapa saya tidak bisa menghapus hutang yang sudah dibayar?'),\r\n                            children: [\r\n                              Padding(\r\n                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),\r\n                                child: const Text(\r\n                                  'Agar integritas data terjaga, hutang dengan status PARTIAL/PAID tidak dapat dihapus. Tindakan yang tersedia adalah sesuai aturan pada status tersebut.',\r\n                                  style: TextStyle(fontSize: 13, color: Colors.black54),\r\n                                ),\r\n                              ),\r\n                            ],\r\n                          ),\r\n                          ExpansionTile(\r\n                            title: const Text('Apa fungsi PIN pada aplikasi ini?'),\r\n                            children: [\r\n                              Padding(\r\n                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),\r\n                                child: const Text(\r\n                                  'PIN digunakan untuk mengamankan operasi sensitif seperti menghapus transaksi. Anda bisa mengaktifkan/ubah PIN di bagian “Pengaturan PIN Keamanan”.',\r\n                                  style: TextStyle(fontSize: 13, color: Colors.black54),\r\n                                ),\r\n                              ),\r\n                            ],\r\n                          ),\r\n                        ],\r\n                      ),\r\n                    ),\r\n\r\n                    // ==== TENTANG APLIKASI ====\r\n                    _buildCollapsibleCard(\r\n                      title: 'Tentang Aplikasi',\r\n                      icon: PhosphorIcons.info(PhosphorIconsStyle.bold),\r\n                      child: Column(\r\n                        children: [\r\n                          _buildInfoRow('Nama Aplikasi', 'Inventory & POS System'),\r\n                          const Divider(height: 20),\r\n                          _buildInfoRow('Versi', _currentVersion),\r\n                          const Divider(height: 20),\r\n                          _buildInfoRow('Pengembang', 'OmegaCoders'),\r\n                          const SizedBox(height: 16),\r\n                          SizedBox(\r\n                            width: double.infinity,\r\n                            child: OutlinedButton.icon(\r\n                              onPressed: _checkForUpdate,\r\n                              icon: Icon(PhosphorIcons.cloudArrowDown(PhosphorIconsStyle.bold)),\r\n                              label: const Text('PERIKSA UPDATE'),\r\n                              style: OutlinedButton.styleFrom(\r\n                                padding: const EdgeInsets.symmetric(vertical: 14),\r\n                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\r\n                              ),\r\n                            ),\r\n                          ),\r\n                        ],\r\n                      ),\r\n                    ),\r\n

                    // ==== LOGOUT ====
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(PhosphorIcons.signOut(PhosphorIconsStyle.bold), size: 18, color: Colors.red.shade600),
                        ),
                        title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                        onTap: _showLogoutConfirmation,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

