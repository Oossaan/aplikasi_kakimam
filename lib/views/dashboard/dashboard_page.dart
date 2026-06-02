import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/report_controller.dart';
import '../../controllers/invoice_controller.dart';
import '../../services/transaction_service.dart';
import '../../services/update_service.dart';
import '../../config/routes.dart';
import 'widgets/tutorial_guide_dialog.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  int _todayTransactionCount = 0;
  bool _isLoadingTransactions = true;
  int _todayReturnCount = 0;
  double _todayReturnAmount = 0;
  bool _isLoadingReturns = true;
  bool _isInitialLoading = true;
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when app resumes (user comes back to dashboard)
    if (state == AppLifecycleState.resumed && _lastLoadTime != null) {
      final elapsed = DateTime.now().difference(_lastLoadTime!);
      // Auto-refresh if last load was more than 30 seconds ago
      if (elapsed.inSeconds > 30) {
        _loadAllData();
      }
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;

    // Record load time for lifecycle monitoring
    _lastLoadTime = DateTime.now();

    // Set date range first
    final reportController = context.read<ReportController>();
    final now = DateTime.now();
    reportController.setDateRange(
      DateTime(now.year, now.month, now.day),
      now,
    );

    // Fire all data loads in parallel for speed
    await Future.wait([
      context.read<InventoryController>().loadProducts(),
      context.read<InventoryController>().loadTotalStats(),
      context.read<InvoiceController>().loadInvoices(),
      _loadTodayTransactions(),
    ]);

    _checkForUpdates();
    _checkFirstTimeTutorial();

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _checkFirstTimeTutorial() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tutorial_shown_v1.txt');
      if (!await file.exists()) {
        if (mounted) {
          await TutorialGuideDialog.show(context);
          await file.writeAsString('done');
        }
      }
    } catch (e) {
      debugPrint('Error checking first time tutorial: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isInitialLoading = true;
    });

    final now = DateTime.now();
    context.read<ReportController>().setDateRange(
      DateTime(now.year, now.month, now.day),
      now,
    );

    await Future.wait([
      context.read<InventoryController>().loadProducts(),
      context.read<InventoryController>().loadTotalStats(),
      _loadTodayTransactions(),
    ]);

    await _checkForUpdates();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('Data diperbarui'),
            ],
          ),
          backgroundColor: const Color(0xFF10b981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await UpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        _showUpdateDialog(updateInfo);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  void _showUpdateDialog(dynamic updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.cloudArrowDown(PhosphorIconsStyle.bold),
                  color: const Color(0xFF667eea),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Update Tersedia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1f2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi ${updateInfo.version}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (updateInfo.releaseNotes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    updateInfo.releaseNotes,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Nanti',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final isWindows = Theme.of(context).platform == TargetPlatform.windows;
                        UpdateService.downloadUpdate(context, updateInfo, isWindows);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIcons.download(PhosphorIconsStyle.bold), size: 18),
                          const SizedBox(width: 8),
                          const Text('Download', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadTodayTransactions() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final summary = await TransactionService.getSalesSummary(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final returnSummary = await TransactionService.getReturnSummary(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      if (mounted) {
        setState(() {
          _todayTransactionCount = (summary['totalTransactions'] as int?) ?? 0;
          _todayReturnCount = (returnSummary['totalReturns'] as int?) ?? 0;
          _todayReturnAmount = (returnSummary['totalReturnAmount'] as double?) ?? 0.0;
          _isLoadingTransactions = false;
          _isLoadingReturns = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _todayTransactionCount = 0;
          _todayReturnCount = 0;
          _todayReturnAmount = 0;
          _isLoadingTransactions = false;
          _isLoadingReturns = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryController = context.watch<InventoryController>();
    final authController = context.watch<AuthController>();
    final reportController = context.watch<ReportController>();
    final invoiceController = context.watch<InvoiceController>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isTablet = size.width > 600;
    final isLandscape = size.width > size.height;

    final statCrossAxisCount = isWide ? 4 : (isTablet ? 2 : 2);
    final actionCrossAxisCount = isWide ? 4 : (isTablet ? 3 : 3);

    return Scaffold(
      drawer: _buildDrawer(context, authController),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(PhosphorIcons.list(PhosphorIconsStyle.bold)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
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
              child: Icon(PhosphorIcons.squaresFour(PhosphorIconsStyle.bold), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.question(PhosphorIconsStyle.bold), color: Colors.white),
            tooltip: 'Panduan Aplikasi',
            onPressed: () => TutorialGuideDialog.show(context),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.bold),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authController.currentUser?.name ?? 'User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1f2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (authController.currentUser?.role ?? '').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF667eea),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(PhosphorIcons.signOut(PhosphorIconsStyle.bold), color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 12),
                    const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                authController.logout();
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    authController.currentUser?.name ?? 'User',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.bold), size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF667eea),
          child: _isInitialLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 60),
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF667eea),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Memuat data dashboard...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1f2937),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isLandscape ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isWide ? 28 : 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667eea).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    PhosphorIcons.handWaving(PhosphorIconsStyle.bold),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Halo, ${authController.currentUser?.name ?? "User"}! 👋',
                                        style: TextStyle(
                                          fontSize: isWide ? 24 : 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Selamat datang di Smart Inventory',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold),
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTanggalIndonesia(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Quick Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ringkasan Hari Ini',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1f2937),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIcons.clock(PhosphorIconsStyle.bold),
                                  size: 14,
                                  color: const Color(0xFF667eea),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Hari ini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF667eea),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: statCrossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: isWide ? 1.3 : (isTablet ? 1.2 : 1.1),
                        children: [
                          _buildStatCard(
                            'Total Produk',
                            '${inventoryController.totalProducts}',
                            PhosphorIcons.package(PhosphorIconsStyle.bold),
                            const Color(0xFF667eea),
                            const Color(0xFF667eea),
                            () {},
                          ),
                          _buildStatCard(
                            'Stok Menipis',
                            '${inventoryController.lowStockProducts}',
                            PhosphorIcons.warning(PhosphorIconsStyle.bold),
                            const Color(0xFFf59e0b),
                            const Color(0xFFf59e0b),
                            () => Navigator.pushNamed(context, AppRoutes.inventory, arguments: {'stockFilter': 'low'}),
                          ),
                          _buildStatCard(
                            'Nilai Inventory',
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(inventoryController.totalInventoryValue),
                            PhosphorIcons.currencyDollar(PhosphorIconsStyle.bold),
                            const Color(0xFF10b981),
                            const Color(0xFF10b981),
                            () => Navigator.pushNamed(context, AppRoutes.stockReport),
                          ),
                          _buildStatCard(
                            'Transaksi',
                            _isLoadingTransactions ? '...' : '$_todayTransactionCount',
                            PhosphorIcons.receipt(PhosphorIconsStyle.bold),
                            const Color(0xFF764ba2),
                            const Color(0xFF764ba2),
                            () => Navigator.pushNamed(context, AppRoutes.invoiceList),
                          ),
                          _buildStatCard(
                            'Profit',
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(reportController.totalProfit),
                            PhosphorIcons.trendUp(PhosphorIconsStyle.bold),
                            const Color(0xFF10b981),
                            const Color(0xFF10b981),
                            () => Navigator.pushNamed(context, AppRoutes.profitReport),
                          ),
                          _buildStatCard(
                            'Piutang',
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(invoiceController.totalUnpaid),
                            PhosphorIcons.file(PhosphorIconsStyle.bold),
                            const Color(0xFFef4444),
                            const Color(0xFFef4444),
                            () => Navigator.pushNamed(context, AppRoutes.receivables),
                          ),
                          _buildStatCard(
                            'Retur',
                            _isLoadingReturns
                                ? '...'
                                : NumberFormat.currency(
                                    locale: 'id',
                                    symbol: 'Rp ',
                                    decimalDigits: 0,
                                  ).format(_todayReturnAmount),
                            PhosphorIcons.arrowUUpLeft(PhosphorIconsStyle.bold),
                            const Color(0xFFf97316),
                            const Color(0xFFf97316),
                            () => Navigator.pushNamed(context, AppRoutes.returns),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Quick Actions
                      const Text(
                        'Aksi Cepat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: actionCrossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: isTablet ? 1.2 : 1.0,
                        children: [
                          _buildActionButton(
                            'Kasir',
                            PhosphorIcons.cashRegister(PhosphorIconsStyle.bold),
                            const Color(0xFF10b981),
                            () => Navigator.pushNamed(context, AppRoutes.pos),
                          ),
                          _buildActionButton(
                            'Tambah Produk',
                            PhosphorIcons.plusCircle(PhosphorIconsStyle.bold),
                            const Color(0xFF667eea),
                            () => Navigator.pushNamed(context, AppRoutes.addProduct),
                          ),
                          _buildActionButton(
                            'Laporan',
                            PhosphorIcons.chartBar(PhosphorIconsStyle.bold),
                            const Color(0xFF764ba2),
                            () => Navigator.pushNamed(context, AppRoutes.salesReport),
                          ),
                          _buildActionButton(
                            'Stok',
                            PhosphorIcons.warehouse(PhosphorIconsStyle.bold),
                            const Color(0xFFf59e0b),
                            () => Navigator.pushNamed(context, AppRoutes.inventory),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, PhosphorIconData icon, Color color, Color bgColor, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade50, width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1f2937),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, PhosphorIconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF374151),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthController authController) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Smart Inventory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.user(PhosphorIconsStyle.bold),
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        authController.currentUser?.name ?? 'User',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (authController.currentUser?.role ?? '').toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  _buildDrawerItem(PhosphorIcons.squaresFour(PhosphorIconsStyle.bold), 'Dashboard', true, () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
                  }),
                  _buildDrawerItem(PhosphorIcons.cashRegister(PhosphorIconsStyle.bold), 'Point of Sale', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.pos);
                  }),
                  _buildDrawerItem(PhosphorIcons.package(PhosphorIconsStyle.bold), 'Inventory', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.inventory);
                  }),
                  const Divider(height: 32),
                  _buildDrawerHeader('MANAJEMEN'),
                  _buildDrawerItem(PhosphorIcons.storefront(PhosphorIconsStyle.bold), 'Outlet', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.outletManagement);
                  }),
                  _buildDrawerItem(PhosphorIcons.truck(PhosphorIconsStyle.bold), 'Supplier', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.supplierManagement);
                  }),
                  _buildDrawerItem(PhosphorIcons.tag(PhosphorIconsStyle.bold), 'Kategori', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.categoryManagement);
                  }),
                  _buildDrawerItem(PhosphorIcons.usersThree(PhosphorIconsStyle.bold), 'Sales', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.salesManagement);
                  }),
                  const Divider(height: 32),
                  _buildDrawerHeader('LAPORAN'),
                  _buildDrawerItem(PhosphorIcons.chartBar(PhosphorIconsStyle.bold), 'Penjualan', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.salesReport);
                  }),
                  _buildDrawerItem(PhosphorIcons.warehouse(PhosphorIconsStyle.bold), 'Stok', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.stockReport);
                  }),
                  const Divider(height: 32),
                  _buildDrawerItem(PhosphorIcons.file(PhosphorIconsStyle.bold), 'Invoice', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.invoiceList);
                  }),
                  _buildDrawerItem(PhosphorIcons.arrowUUpLeft(PhosphorIconsStyle.bold), 'Retur', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.returns);
                  }),
                  _buildDrawerItem(PhosphorIcons.wallet(PhosphorIconsStyle.bold), 'Piutang & Tagihan', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.receivables);
                  }),
                  const Divider(height: 32),
                  _buildDrawerItem(PhosphorIcons.gear(PhosphorIconsStyle.bold), 'Pengaturan', false, () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.settings);
                  }),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        PhosphorIcons.signOut(PhosphorIconsStyle.bold),
                        color: Colors.red.shade400,
                        size: 22,
                      ),
                      title: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        Navigator.pop(context);
                        authController.logout();
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(PhosphorIconData icon, String title, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF667eea).withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF667eea).withValues(alpha: 0.15)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isActive ? const Color(0xFF667eea) : Colors.grey.shade500,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF667eea) : const Color(0xFF374151),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 8, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  String _formatTanggalIndonesia(DateTime date) {
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const bulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${hari[date.weekday - 1]}, ${date.day} ${bulan[date.month - 1]} ${date.year}';
  }
}