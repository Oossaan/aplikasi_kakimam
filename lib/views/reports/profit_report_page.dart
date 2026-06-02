import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../controllers/outlet_controller.dart';
import '../../controllers/sales_controller.dart';
import '../../controllers/category_controller.dart';
import '../../config/routes.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> with WidgetsBindingObserver {
  String? _selectedPaymentMethod;
  String? _selectedStatus;
  String? _selectedOutletId;
  String? _selectedSalesId;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<Transaction> _lastFiltered = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportController>().loadTransactions();
      context.read<SalesController>().loadSales();
      context.read<CategoryController>().loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ReportController>().loadTransactions();
    }
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    return transactions.where((t) {
      // Date range filter
      if (_startDate != null && t.transactionDate.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && t.transactionDate.isAfter(_endDate!)) {
        return false;
      }
      if (_selectedPaymentMethod != null && t.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      if (_selectedStatus != null) {
        switch (_selectedStatus) {
          case 'paid':
            if (t.status != TransactionStatus.paid) return false;
            break;
          case 'pending':
            if (t.status != TransactionStatus.pending) return false;
            break;
          case 'cancelled':
            if (t.status != TransactionStatus.cancelled) return false;
            break;
          case 'refunded':
            if (t.status != TransactionStatus.refunded) return false;
            break;
        }
      }
      if (_selectedOutletId != null && t.outletId?.toString() != _selectedOutletId) {
        return false;
      }
      if (_selectedSalesId != null && t.salesId?.toString() != _selectedSalesId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return t.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }

  Future<void> _exportReport(BuildContext context) async {
    if (_lastFiltered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final headers = ['No Invoice', 'Tanggal', 'Outlet', 'Sales', 'Total', 'Profit', 'Status'];
    final rows = <List<String>>[];
    for (final t in _lastFiltered) {
      final profit = t.totalReturnedAmount > 0 ? t.effectiveProfit : t.profit;
      final amount = t.totalReturnedAmount > 0 ? t.effectiveRevenue : t.finalAmount;
      rows.add([
        t.invoiceNumber,
        dateFormat.format(t.transactionDate),
        t.outletName ?? t.supplierName ?? '-',
        t.salesName ?? '-',
        currency.format(amount),
        currency.format(profit),
        t.statusLabel,
      ]);
    }
    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: 'laporan_penjualan',
      sheetName: 'Laporan Penjualan',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Export ${_lastFiltered.length} transaksi berhasil'),
          ]),
          backgroundColor: const Color(0xFF10b981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();
    final outletController = context.watch<OutletController>();
    final salesController = context.watch<SalesController>();
    final categoryController = context.watch<CategoryController>();
    final filteredTransactions = _getFilteredTransactions(controller.transactions);
    _lastFiltered = filteredTransactions;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 400;

    double filteredSales = filteredTransactions.fold(0, (sum, t) {
      return sum + (t.totalReturnedAmount > 0 ? t.effectiveRevenue : t.finalAmount);
    });
    double filteredProfit = filteredTransactions.fold(0, (sum, t) {
      return sum + (t.totalReturnedAmount > 0 ? t.effectiveProfit : t.profit);
    });
    final marginPercent = filteredSales > 0 ? (filteredProfit / filteredSales * 100) : 0.0;

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
              child: Icon(PhosphorIcons.chartLine(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Laporan Penjualan'),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(PhosphorIcons.fileArrowDown(PhosphorIconsStyle.bold), size: 20),
              tooltip: 'Export CSV',
              onPressed: () => _exportReport(context),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), size: 20),
              onPressed: () => _showFilterDialog(context, controller, outletController, salesController, categoryController),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF667eea),
          onRefresh: () => controller.loadTransactions(),
          child: ListView(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            children: [
              // Active filters display
              if (_startDate != null || _endDate != null || _selectedSalesId != null || _selectedCategory != null || _selectedPaymentMethod != null || _selectedStatus != null || _selectedOutletId != null || _searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_startDate != null || _endDate != null)
                        _buildActiveFilterChip(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                              : (_startDate != null ? 'Dari ${DateFormat('dd/MM/yyyy').format(_startDate!)}' : 'Sampai ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
                          () => setState(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                          color: Colors.orange,
                        ),
                      if (_selectedSalesId != null)
                        _buildActiveFilterChip('Sales', () => setState(() => _selectedSalesId = null), color: Colors.purple),
                      if (_selectedCategory != null)
                        _buildActiveFilterChip('Kategori', () => setState(() => _selectedCategory = null), color: Colors.teal),
                      if (_selectedPaymentMethod != null)
                        _buildActiveFilterChip('Bayar: $_selectedPaymentMethod', () => setState(() => _selectedPaymentMethod = null)),
                      if (_selectedStatus != null)
                        _buildActiveFilterChip('Status: ${_selectedStatus!.toUpperCase()}', () => setState(() => _selectedStatus = null)),
                      if (_selectedOutletId != null)
                        _buildActiveFilterChip('Outlet', () => setState(() => _selectedOutletId = null)),
                      if (_searchQuery.isNotEmpty)
                        _buildActiveFilterChip('"$_searchQuery"', () => setState(() => _searchQuery = '')),
                    ],
                  ),
                ),

              // Summary Cards
              _buildSummarySection(controller, filteredSales, filteredProfit, filteredTransactions.length, isMobile, marginPercent),
              const SizedBox(height: 16),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari invoice...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 22),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 16),

              // Transaction List
              _buildTransactionList(filteredTransactions, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove, {Color? color}) {
    final chipColor = color ?? const Color(0xFF667eea);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: chipColor, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: chipColor, size: 14)),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ReportController controller, double filteredSales, double filteredProfit, int transactionCount, bool isMobile, double marginPercent) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Column(
      children: [
        // Filter Info Card (like Tempo card style)
        if (_startDate != null || _endDate != null || _selectedSalesId != null || _selectedCategory != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withValues(alpha: 0.1),
                  const Color(0xFF764ba2).withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Filter Aktif',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$transactionCount transaksi',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filter details
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_startDate != null || _endDate != null)
                      _buildFilterInfoChip(
                        PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold),
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                            : (_startDate != null ? DateFormat('dd/MM/yy').format(_startDate!) : DateFormat('dd/MM/yy').format(_endDate!)),
                        Colors.orange,
                      ),
                    if (_selectedSalesId != null)
                      _buildFilterInfoChip(
                        PhosphorIcons.user(PhosphorIconsStyle.bold),
                        'Sales',
                        Colors.purple,
                      ),
                    if (_selectedCategory != null)
                      _buildFilterInfoChip(
                        PhosphorIcons.tag(PhosphorIconsStyle.bold),
                        'Kategori',
                        Colors.teal,
                      ),
                  ],
                ),
              ],
            ),
          ),

        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Penjualan',
                currencyFormat.format(filteredSales),
                PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold),
                const Color(0xFF667eea),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Profit',
                currencyFormat.format(filteredProfit),
                PhosphorIcons.trendUp(PhosphorIconsStyle.bold),
                filteredProfit >= 0 ? const Color(0xFF10b981) : const Color(0xFFef4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Transaksi',
                '$transactionCount',
                PhosphorIcons.receipt(PhosphorIconsStyle.bold),
                const Color(0xFF764ba2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Margin',
                '${marginPercent.toStringAsFixed(1)}%',
                PhosphorIcons.percent(PhosphorIconsStyle.bold),
                marginPercent >= 20 ? const Color(0xFF10b981) : (marginPercent >= 10 ? const Color(0xFFf59e0b) : const Color(0xFFef4444)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Pending Profit Card
        if (controller.pendingTransactionCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(PhosphorIcons.clock(PhosphorIconsStyle.bold), color: Colors.orange.shade700, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profit Tertunda', style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(currencyFormat.format(controller.pendingProfit), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                      Text('${controller.pendingTransactionCount} transaksi menunggu', style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Return summary
        if (controller.returnCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold), color: Colors.red.shade700, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Retur', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(currencyFormat.format(controller.totalReturns), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${controller.returnCount} retur', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterInfoChip(PhosphorIconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, PhosphorIconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions, bool isMobile) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F6FA),
                  shape: BoxShape.circle,
                ),
                child: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.bold), size: 48, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
              Text('Belum ada transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Text('Transaksi akan muncul di sini', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Detail Transaksi'),
        const SizedBox(height: 12),
        ...transactions.map((transaction) => _buildTransactionCard(transaction, isMobile)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction, bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final profit = transaction.totalReturnedAmount > 0 ? transaction.effectiveProfit : transaction.profit;
    final profitColor = profit >= 0 ? const Color(0xFF10b981) : const Color(0xFFef4444);
    final amount = transaction.totalReturnedAmount > 0 ? transaction.effectiveRevenue : transaction.finalAmount;

    final salesName = (transaction.salesName != null && transaction.salesName!.trim().isNotEmpty)
        ? transaction.salesName!.trim()
        : (transaction.salesId != null
            ? context.read<SalesController>().sales.firstWhere(
                  (s) => s.id == transaction.salesId,
                  orElse: () => context.read<SalesController>().sales.first,
                ).name
            : null);

    Color statusColor;
    String statusLabel;
    PhosphorIconData statusIcon;

    switch (transaction.status) {
      case TransactionStatus.paid:
        statusColor = const Color(0xFF10b981);
        statusLabel = 'Lunas';
        statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.bold);
        break;
      case TransactionStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Tunda';
        statusIcon = PhosphorIcons.clock(PhosphorIconsStyle.bold);
        break;
      case TransactionStatus.cancelled:
        statusColor = const Color(0xFFef4444);
        statusLabel = 'Batal';
        statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.bold);
        break;
      case TransactionStatus.refunded:
        statusColor = Colors.purple;
        statusLabel = 'Retur';
        statusIcon = PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (transaction.id != null) {
              Navigator.pushNamed(context, AppRoutes.invoiceDetail, arguments: transaction.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(transaction.invoiceNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(dateFormat.format(transaction.transactionDate), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Icon(PhosphorIcons.package(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text('${transaction.items.length} item', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      if (salesName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text('Sales: $salesName', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      if (transaction.paymentMethod.isNotEmpty) ...[

                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(PhosphorIcons.wallet(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(transaction.paymentMethod, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currencyFormat.format(amount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1f2937))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: profitColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Profit: ${currencyFormat.format(profit)}', style: TextStyle(fontSize: 11, color: profitColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, ReportController controller, OutletController outletController, SalesController salesController, CategoryController categoryController) {
    // Filter options loaded directly from database
    List<Map<String, dynamic>> _dbSalesList = [];
    List<Map<String, dynamic>> _dbCategoryList = [];
    List<Map<String, dynamic>> _dbOutletList = [];
    bool _isLoadingDb = true;

    Future<void> _loadDbData() async {
      final db = await DatabaseService.database;

      // Load sales from database
      final salesResult = await db.query('sales', where: 'isActive = ?', whereArgs: [1], orderBy: 'name ASC');
      _dbSalesList = salesResult;

      // Load categories from database
      final categoryResult = await db.query('categories', orderBy: 'name ASC');
      _dbCategoryList = categoryResult;

      // Load outlets from database
      final outletResult = await db.query('outlets', orderBy: 'name ASC');
      _dbOutletList = outletResult;

      _isLoadingDb = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          // Load DB data on first build
          if (_isLoadingDb) {
            _loadDbData().then((_) {
              if (mounted) setModalState(() {});
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 28),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter Laporan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
                  if (_startDate != null || _endDate != null || _selectedSalesId != null || _selectedCategory != null || _selectedPaymentMethod != null || _selectedStatus != null || _selectedOutletId != null)
                    GestureDetector(
                      onTap: () => setModalState(() {
                        _startDate = null;
                        _endDate = null;
                        _selectedSalesId = null;
                        _selectedCategory = null;
                        _selectedPaymentMethod = null;
                        _selectedStatus = null;
                        _selectedOutletId = null;
                        // Also clear controller filters
                        controller.clearFilters();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 4),
                            Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Scrollable filter content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tanggal
                      const Text('Tanggal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    'Dari Tanggal',
                                    _startDate,
                                    () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setModalState(() => _startDate = picked);
                                      }
                                    },
                                    () => setModalState(() => _startDate = null),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateField(
                                    'Sampai Tanggal',
                                    _endDate,
                                    () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setModalState(() => _endDate = picked);
                                      }
                                    },
                                    () => setModalState(() => _endDate = null),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Quick date buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildQuickDateChip('Hari Ini', () {
                                  final now = DateTime.now();
                                  setModalState(() {
                                    _startDate = DateTime(now.year, now.month, now.day);
                                    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                                  });
                                }),
                                _buildQuickDateChip('Kemarin', () {
                                  final now = DateTime.now();
                                  final yesterday = now.subtract(const Duration(days: 1));
                                  setModalState(() {
                                    _startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
                                    _endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
                                  });
                                }),
                                _buildQuickDateChip('Minggu Ini', () {
                                  final now = DateTime.now();
                                  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                                  setModalState(() {
                                    _startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
                                    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                                  });
                                }),
                                _buildQuickDateChip('Bulan Ini', () {
                                  final now = DateTime.now();
                                  setModalState(() {
                                    _startDate = DateTime(now.year, now.month, 1);
                                    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                                  });
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sales
                      const Text('Sales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      if (_isLoadingDb)
                        const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _buildFilterOption('Semua', _selectedSalesId == null, () => setModalState(() => _selectedSalesId = null)),
                            ..._dbSalesList.map(
                              (sales) => _buildFilterOption(sales['name'] as String, _selectedSalesId == sales['id'].toString(), () => setModalState(() => _selectedSalesId = sales['id'].toString())),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Kategori
                      const Text('Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      if (_isLoadingDb)
                        const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _buildFilterOption('Semua', _selectedCategory == null, () => setModalState(() => _selectedCategory = null)),
                            ..._dbCategoryList.map(
                              (cat) => _buildFilterOption(cat['name'] as String, _selectedCategory == cat['id'].toString(), () => setModalState(() => _selectedCategory = cat['id'].toString())),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Payment Method
                      const Text('Metode Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildFilterOption('Semua', _selectedPaymentMethod == null, () => setModalState(() => _selectedPaymentMethod = null)),
                          _buildFilterOption('Cash', _selectedPaymentMethod == 'CASH', () => setModalState(() => _selectedPaymentMethod = 'CASH')),
                          _buildFilterOption('Debit', _selectedPaymentMethod == 'DEBIT', () => setModalState(() => _selectedPaymentMethod = 'DEBIT')),
                          _buildFilterOption('QRIS', _selectedPaymentMethod == 'QRIS', () => setModalState(() => _selectedPaymentMethod = 'QRIS')),
                          _buildFilterOption('Transfer', _selectedPaymentMethod == 'TRANSFER', () => setModalState(() => _selectedPaymentMethod = 'TRANSFER')),
                          _buildFilterOption('Tempo', _selectedPaymentMethod == 'TEMPO', () => setModalState(() => _selectedPaymentMethod = 'TEMPO')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Status
                      const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildFilterOption('Semua', _selectedStatus == null, () => setModalState(() => _selectedStatus = null)),
                          _buildFilterOption('Lunas', _selectedStatus == 'paid', () => setModalState(() => _selectedStatus = 'paid')),
                          _buildFilterOption('Tunda', _selectedStatus == 'pending', () => setModalState(() => _selectedStatus = 'pending')),
                          _buildFilterOption('Batal', _selectedStatus == 'cancelled', () => setModalState(() => _selectedStatus = 'cancelled')),
                          _buildFilterOption('Retur', _selectedStatus == 'refunded', () => setModalState(() => _selectedStatus = 'refunded')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Outlet
                      const Text('Outlet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      if (_isLoadingDb)
                        const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _buildFilterOption('Semua', _selectedOutletId == null, () => setModalState(() => _selectedOutletId = null)),
                            ..._dbOutletList.map(
                              (outlet) => _buildFilterOption(outlet['name'] as String, _selectedOutletId == outlet['id'].toString(), () => setModalState(() => _selectedOutletId = outlet['id'].toString())),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Apply button
              Container(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Sync filters with ReportController to reload data from DB
                      final newStart = _startDate ?? controller.startDate;
                      final newEnd = _endDate ?? controller.endDate;

                      // Update ReportController filters
                      if (_startDate != null || _endDate != null ||
                          _selectedSalesId != null || _selectedCategory != null || _selectedOutletId != null) {
                        // If date changed, set date range first
                        if (newStart != controller.startDate || newEnd != controller.endDate) {
                          controller.setDateRange(newStart, newEnd);
                        }
                        // Then apply filters
                        controller.setFilters(
                          salesId: _selectedSalesId,
                          categoryId: _selectedCategory,
                          outletId: _selectedOutletId,
                        );
                      }

                      setState(() {});
                      Navigator.pop(bottomSheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDateField(String label, DateTime? value, VoidCallback onTap, VoidCallback onClear) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? DateFormat('dd/MM/yyyy').format(value) : label,
                style: TextStyle(fontSize: 12, color: value != null ? Colors.grey.shade800 : Colors.grey.shade400),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF667eea))),
      ),
    );
  }

  Widget _buildFilterOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667eea) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }
}