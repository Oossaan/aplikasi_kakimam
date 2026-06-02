import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/routes.dart';
import '../../models/sales_model.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/transaction_service.dart';

class SalesHistoryPage extends StatefulWidget {
  final Sales sales;

  const SalesHistoryPage({super.key, required this.sales});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  // Summary
  double _totalRevenue = 0;
  int _totalInvoices = 0;
  int _totalItems = 0;

  // Filter
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterType = 'all'; // 'all', 'sales', 'purchase'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.database;

      String where = 'salesId = ?';
      List<dynamic> args = [widget.sales.id];

      if (_startDate != null && _endDate != null) {
        where += ' AND transactionDate BETWEEN ? AND ?';
        args.addAll([
          _startDate!.toIso8601String(),
          DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)
              .toIso8601String(),
        ]);
      }

      if (_filterType == 'sales') {
        where += " AND transactionType = 'sales'";
      } else if (_filterType == 'purchase') {
        where += " AND transactionType = 'purchase'";
      }

      final maps = await db.query(
        'transactions',
        where: where,
        whereArgs: args,
        orderBy: 'transactionDate DESC',
      );

      final List<Transaction> result = [];
      for (final map in maps) {
        // Fetch items
        final itemMaps = await db.query(
          'transactionItems',
          where: 'transactionId = ?',
          whereArgs: [map['id']],
        );
        final items =
            itemMaps.map((i) => TransactionItem.fromMap(i)).toList();

        // Fetch outlet name
        String? outletName;
        if (map['outletId'] != null) {
          final outletRes = await db.query('outlets',
              columns: ['name'],
              where: 'id = ?',
              whereArgs: [map['outletId']]);
          if (outletRes.isNotEmpty) {
            outletName = outletRes.first['name'] as String?;
          }
        }

        // Fetch supplier name
        String? supplierName;
        if (map['supplierId'] != null) {
          final supRes = await db.query('suppliers',
              columns: ['name'],
              where: 'id = ?',
              whereArgs: [map['supplierId']]);
          if (supRes.isNotEmpty) {
            supplierName = supRes.first['name'] as String?;
          }
        }

        result.add(Transaction.fromMap(
          map,
          items,
          outletName: outletName,
          supplierName: supplierName,
        ));
      }

      // Hitung summary (hanya transaksi aktif / tidak dibatalkan)
      double revenue = 0;
      int itemCount = 0;
      for (final t in result) {
        if (t.status != TransactionStatus.cancelled) {
          revenue += t.finalAmount;
          itemCount += t.items.fold(0, (s, i) => s + i.quantity);
        }
      }

      if (mounted) {
        setState(() {
          _transactions = result;
          _totalRevenue = revenue;
          _totalInvoices = result.length;
          _totalItems = itemCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF667eea)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadHistory();
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filterType = 'all';
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  PhosphorIcons.receipt(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Riwayat ${widget.sales.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
              icon: Icon(PhosphorIcons.fileArrowDown(PhosphorIconsStyle.bold),
                  size: 20),
              tooltip: 'Export CSV',
              onPressed: () => _exportHistory(context),
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold)),
            tooltip: 'Filter',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : RefreshIndicator(
              color: const Color(0xFF667eea),
              onRefresh: _loadHistory,
              child: CustomScrollView(
                slivers: [
                  // Summary card
                  SliverToBoxAdapter(
                    child: _buildSummaryCard(isMobile),
                  ),
                  // Active filter chip
                  if (_startDate != null || _filterType != 'all')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (_startDate != null)
                              Chip(
                                label: Text(
                                  '${DateFormat('dd/MM/yy').format(_startDate!)} – ${DateFormat('dd/MM/yy').format(_endDate!)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                  _loadHistory();
                                },
                                backgroundColor: const Color(0xFF667eea)
                                    .withValues(alpha: 0.1),
                              ),
                            if (_filterType != 'all')
                              Chip(
                                label: Text(
                                  _filterType == 'sales'
                                      ? 'Penjualan'
                                      : 'Pembelian',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () {
                                  setState(() => _filterType = 'all');
                                  _loadHistory();
                                },
                                backgroundColor: const Color(0xFF667eea)
                                    .withValues(alpha: 0.1),
                              ),
                          ],
                        ),
                      ),
                    ),
                  // List
                  _transactions.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildInvoiceCard(
                                _transactions[index], isMobile),
                            childCount: _transactions.length,
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(bool isMobile) {
    final currency =
        NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.user(PhosphorIconsStyle.bold),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sales.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.sales.phone.isNotEmpty)
                      Text(
                        widget.sales.phone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _summaryItem(
                  'Total Invoice', '$_totalInvoices', PhosphorIcons.receipt),
              _summaryDivider(),
              _summaryItem('Total Item', '$_totalItems',
                  PhosphorIcons.shoppingBag),
              _summaryDivider(),
              _summaryItem('Total Nilai', currency.format(_totalRevenue),
                  PhosphorIcons.currencyDollar,
                  small: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData Function(PhosphorIconsStyle) icon,
      {bool small = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon(PhosphorIconsStyle.bold),
              color: Colors.white.withValues(alpha: 0.8), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: small ? 11 : 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildInvoiceCard(Transaction tx, bool isMobile) {
    final currency =
        NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateStr =
        DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(tx.transactionDate);

    final isPurchase = tx.isPurchase;
    final typeColor =
        isPurchase ? const Color(0xFF10b981) : const Color(0xFF667eea);
    final typeLabel = isPurchase ? 'Pembelian' : 'Penjualan';
    final typeIcon = isPurchase
        ? PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold)
        : PhosphorIcons.tag(PhosphorIconsStyle.bold);

    Color statusColor;
    String statusLabel;
    switch (tx.status) {
      case TransactionStatus.cancelled:
        statusColor = const Color(0xFFef4444);
        statusLabel = 'Dibatalkan';
        break;
      case TransactionStatus.refunded:
        statusColor = const Color(0xFFf59e0b);
        statusLabel = 'Diretur';
        break;
      case TransactionStatus.pending:
        statusColor = const Color(0xFFf59e0b);
        statusLabel = 'Tempo';
        break;
      default:
        statusColor = const Color(0xFF10b981);
        statusLabel = 'Lunas';
    }

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.invoiceDetail,
            arguments: tx.id,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 18),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF1f2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (tx.outletName != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                      PhosphorIcons.storefront(
                                          PhosphorIconsStyle.bold),
                                      size: 11,
                                      color: Colors.grey.shade500),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      tx.outletName!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (tx.supplierName != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                      PhosphorIcons.truck(
                                          PhosphorIconsStyle.bold),
                                      size: 11,
                                      color: Colors.grey.shade500),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      tx.supplierName!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${tx.items.length} produk · ${tx.items.fold(0, (s, i) => s + i.quantity)} item',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          Text(
                            currency.format(tx.finalAmount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: tx.status == TransactionStatus.cancelled
                                  ? Colors.grey
                                  : const Color(0xFF1f2937),
                              decoration:
                                  tx.status == TransactionStatus.cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                    size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F6FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.receipt(PhosphorIconsStyle.bold),
              size: 52,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada transaksi',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Transaksi yang melibatkan ${widget.sales.name}\nakan muncul di sini',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          if (_startDate != null || _filterType != 'all') ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearFilter,
              icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 14),
              label: const Text('Hapus filter'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportHistory(BuildContext context) async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency =
        NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final headers = ['No Invoice', 'Tanggal', 'Jenis', 'Outlet/Supplier', 'Total', 'Status'];
    final rows = <List<String>>[];
    for (final t in _transactions) {
      final party = t.outletName ?? t.supplierName ?? '-';
      final type = t.isPurchase ? 'Pembelian' : 'Penjualan';
      rows.add([
        t.invoiceNumber,
        dateFormat.format(t.transactionDate),
        type,
        party,
        currency.format(t.finalAmount),
        t.statusLabel,
      ]);
    }
    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: 'riwayat_sales_${widget.sales.name.replaceAll(' ', '_')}',
      sheetName: 'Riwayat Sales',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Export ${_transactions.length} transaksi berhasil'),
          ]),
          backgroundColor: const Color(0xFF10b981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showFilterSheet() {
    String tempType = _filterType;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter Transaksi',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1f2937)),
              ),
              const SizedBox(height: 16),
              const Text('Jenis Transaksi',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6b7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('Semua', 'all', tempType,
                      (v) => setSheet(() => tempType = v)),
                  _filterChip('Penjualan', 'sales', tempType,
                      (v) => setSheet(() => tempType = v)),
                  _filterChip('Pembelian', 'purchase', tempType,
                      (v) => setSheet(() => tempType = v)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Rentang Tanggal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6b7280))),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickDateRange();
                },
                icon: Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                    size: 16),
                label: Text(
                  _startDate != null
                      ? '${DateFormat('dd/MM/yy').format(_startDate!)} – ${DateFormat('dd/MM/yy').format(_endDate!)}'
                      : 'Pilih rentang tanggal',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearFilter();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Reset',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _filterType = tempType);
                        _loadHistory();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Terapkan',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _filterChip(String label, String value, String current,
      void Function(String) onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF667eea)
              : const Color(0xFF667eea).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF667eea),
          ),
        ),
      ),
    );
  }
}
