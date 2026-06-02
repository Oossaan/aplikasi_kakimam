import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/export_service.dart';
import '../../config/routes.dart';

class ReceivablesPage extends StatefulWidget {
  const ReceivablesPage({super.key});

  @override
  State<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends State<ReceivablesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _unpaidTransactions = [];
  List<Map<String, dynamic>> _paidTransactions = [];
  List<Map<String, dynamic>> _unpaidSupplierHutang = [];
  List<Map<String, dynamic>> _paidSupplierHutang = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.database;

      // Query dan konversi ke mutable map - hanya tampilkan transaksi dengan pembayaran TEMPO
      // Exclude purchase transactions (those with supplierId) from outlet tempo lists
      var unpaid = (await db.query(
        'transactions',
        where: 'paymentMethod = ? AND (payment_status = ? OR payment_status = ?) AND supplierId IS NULL',
        whereArgs: ['TEMPO', 'UNPAID', 'PARTIAL'],
        orderBy: 'transactionDate DESC',
      )).map((e) => Map<String, dynamic>.from(e)).toList();

      var paid = (await db.query(
        'transactions',
        where: 'paymentMethod = ? AND payment_status = ? AND supplierId IS NULL',
        whereArgs: ['TEMPO', 'PAID'],
        orderBy: 'transactionDate DESC',
        limit: 100,
      )).map((e) => Map<String, dynamic>.from(e)).toList();

      // Step 1: Batch query all outlet IDs used in transactions (N+1 fix)
      final allOutletIds = <int>{};
      for (var t in unpaid) {
        if (t['outletId'] != null) allOutletIds.add(t['outletId'] as int);
      }
      for (var t in paid) {
        if (t['outletId'] != null) allOutletIds.add(t['outletId'] as int);
      }

      // Batch fetch outlet names
      final Map<int?, String> outletNames = {};
      if (allOutletIds.isNotEmpty) {
        final placeholders = allOutletIds.map((_) => '?').join(',');
        final outletMaps = await db.query(
          'outlets',
          where: 'id IN ($placeholders)',
          whereArgs: allOutletIds.toList(),
        );
        for (var outlet in outletMaps) {
          outletNames[outlet['id'] as int?] = outlet['name'] as String? ?? '';
        }
      }

      // Assign outlet names to transactions
      for (var i = 0; i < unpaid.length; i++) {
        if (unpaid[i]['outletId'] != null) {
          unpaid[i]['outletName'] = outletNames[unpaid[i]['outletId']];
        }
      }
      for (var i = 0; i < paid.length; i++) {
        if (paid[i]['outletId'] != null) {
          paid[i]['outletName'] = outletNames[paid[i]['outletId']];
        }
      }

      // Load supplier hutang data
      var unpaidHutang = (await db.query(
        'supplierHutang',
        where: 'status = ? OR status = ?',
        whereArgs: ['UNPAID', 'PARTIAL'],
        orderBy: 'dueDate ASC',
      )).map((e) => Map<String, dynamic>.from(e)).toList();

      var paidHutang = (await db.query(
        'supplierHutang',
        where: 'status = ?',
        whereArgs: ['PAID'],
        orderBy: 'dueDate DESC',
        limit: 100,
      )).map((e) => Map<String, dynamic>.from(e)).toList();

      if (mounted) {
        setState(() {
          _unpaidTransactions = unpaid;
          _paidTransactions = paid;
          _unpaidSupplierHutang = unpaidHutang;
          _paidSupplierHutang = paidHutang;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterTransactions(List<Map<String, dynamic>> transactions) {
    if (_searchQuery.isEmpty) return transactions;
    final query = _searchQuery.toLowerCase();
    return transactions.where((t) {
      final invoice = (t['invoiceNumber'] ?? '').toString().toLowerCase();
      final customer = (t['customerName'] ?? '').toString().toLowerCase();
      final outlet = (t['outletName'] ?? '').toString().toLowerCase();
      return invoice.contains(query) || customer.contains(query) || outlet.contains(query);
    }).toList();
  }

  double _calculateTotalPiutang(List<Map<String, dynamic>> transactions) {
    return transactions.fold(0.0, (sum, t) {
      final remaining = (t['remaining_amount'] as num?)?.toDouble() ?? 0;
      return sum + remaining;
    });
  }

  double _calculateTotalSupplierHutang(List<Map<String, dynamic>> hutangList) {
    return hutangList.fold(0.0, (sum, h) {
      final remaining = (h['remainingAmount'] as num?)?.toDouble() ?? 0;
      return sum + remaining;
    });
  }

  List<Map<String, dynamic>> _filterSupplierHutang(List<Map<String, dynamic>> hutangList) {
    if (_searchQuery.isEmpty) return hutangList;
    final query = _searchQuery.toLowerCase();
    return hutangList.where((h) {
      final invoice = (h['invoiceNumber'] ?? '').toString().toLowerCase();
      final supplier = (h['supplierName'] ?? '').toString().toLowerCase();
      return invoice.contains(query) || supplier.contains(query);
    }).toList();
  }

  Future<void> _exportCurrentTab(BuildContext context) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    List<List<String>> rows;
    List<String> headers;
    String filename;
    String sheetName;

    if (_selectedTabIndex == 0 || _selectedTabIndex == 1) {
      final data = _selectedTabIndex == 0 ? _unpaidTransactions : _paidTransactions;
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data')));
        return;
      }
      filename = _selectedTabIndex == 0 ? 'piutang_outlet' : 'riwayat_piutang_outlet';
      sheetName = _selectedTabIndex == 0 ? 'Piutang Outlet' : 'Riwayat Piutang Outlet';
      headers = ['No Invoice', 'Tanggal', 'Outlet', 'Total', 'Sisa', 'Status'];
      rows = [];
      for (final t in data) {
        rows.add([
          t['invoiceNumber'] ?? '',
          dateFormat.format(DateTime.parse(t['transactionDate'] as String)),
          t['outletName'] ?? '-',
          currency.format((t['finalAmount'] as num).toDouble()),
          currency.format((t['remaining_amount'] as num?)?.toDouble() ?? 0),
          t['payment_status'] ?? '-',
        ]);
      }
    } else {
      final data = _selectedTabIndex == 2 ? _unpaidSupplierHutang : _paidSupplierHutang;
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data')));
        return;
      }
      filename = _selectedTabIndex == 2 ? 'hutang_supplier' : 'riwayat_hutang_supplier';
      sheetName = _selectedTabIndex == 2 ? 'Hutang Supplier' : 'Riwayat Hutang Supplier';
      headers = ['No Invoice', 'Supplier', 'Jatuh Tempo', 'Total', 'Sisa', 'Status'];
      rows = [];
      for (final h in data) {
        final dueDate = h['dueDate'] != null ? dateFormat.format(DateTime.parse(h['dueDate'] as String)) : '-';
        rows.add([
          h['invoiceNumber'] ?? '',
          h['supplierName'] ?? '-',
          dueDate,
          currency.format((h['totalAmount'] as num).toDouble()),
          currency.format((h['remainingAmount'] as num?)?.toDouble() ?? 0),
          h['status'] ?? '-',
        ]);
      }
    }

    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: filename,
      sheetName: sheetName,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Text('Export berhasil'),
          ]),
          backgroundColor: const Color(0xFF10b981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildCustomTabBar() {
    final tabs = [
      {
        'label': 'Tempo\nOutlet',
        'icon': PhosphorIcons.clock(PhosphorIconsStyle.bold),
        'count': _unpaidTransactions.length,
        'color': const Color(0xFFef4444),
      },
      {
        'label': 'Riwayat\nOutlet',
        'icon': PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
        'count': _paidTransactions.length,
        'color': const Color(0xFF10b981),
      },
      {
        'label': 'Tempo\nSupplier',
        'icon': PhosphorIcons.truck(PhosphorIconsStyle.bold),
        'count': _unpaidSupplierHutang.length,
        'color': const Color(0xFFf59e0b),
      },
      {
        'label': 'Riwayat\nSupplier',
        'icon': PhosphorIcons.archive(PhosphorIconsStyle.bold),
        'count': _paidSupplierHutang.length,
        'color': const Color(0xFF6366f1),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final tab = tabs[index];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF667eea), width: 2)
                      : Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF667eea).withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          tab['icon'] as PhosphorIconData,
                          size: 22,
                          color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade600,
                        ),
                        if ((tab['count'] as int) > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: tab['color'] as Color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(minWidth: 16),
                              child: Text(
                                '${tab['count']}',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade600,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isAdmin = authController.currentUser?.role == 'admin';

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
              child: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Piutang & Tagihan'),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(PhosphorIcons.fileArrowDown(PhosphorIconsStyle.bold), size: 20),
              tooltip: 'Export CSV',
              onPressed: () => _exportCurrentTab(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Tab Bar
            _buildCustomTabBar(),
            const SizedBox(height: 8),

            // Summary Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedTabIndex < 2 ? PhosphorIcons.wallet(PhosphorIconsStyle.bold) : PhosphorIcons.truck(PhosphorIconsStyle.bold),
                              size: 16,
                              color: const Color(0xFF667eea),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedTabIndex < 2 ? 'Total Piutang Outlet' : 'Total Hutang Supplier',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF6b7280)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _selectedTabIndex < 2
                                ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_calculateTotalPiutang(_unpaidTransactions))
                                : NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_calculateTotalSupplierHutang(_unpaidSupplierHutang)),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF667eea)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTabIndex < 2
                              ? '${_unpaidTransactions.length} transaksi'
                              : '${_unpaidSupplierHutang.length} hutang',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _selectedTabIndex < 2 ? PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold) : PhosphorIcons.package(PhosphorIconsStyle.bold),
                      size: 28,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
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
                  decoration: InputDecoration(
                    hintText: _selectedTabIndex < 2 ? 'Cari invoice atau customer...' : 'Cari invoice atau supplier...',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 22),
                    ),
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
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransactionList(_filterTransactions(_unpaidTransactions), isAdmin, true, false),
                        _buildTransactionList(_filterTransactions(_paidTransactions), isAdmin, false, false),
                        _buildSupplierHutangList(_filterSupplierHutang(_unpaidSupplierHutang), isAdmin, true),
                        _buildSupplierHutangList(_filterSupplierHutang(_paidSupplierHutang), isAdmin, false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions, bool isAdmin, bool isUnpaid, bool isOutlet) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), size: 48, color: Colors.green.shade300),
            ),
            const SizedBox(height: 16),
            Text(isUnpaid ? 'Tidak ada piutang' : 'Tidak ada riwayat', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) => _buildTransactionCard(transactions[index], isAdmin, isUnpaid, isOutlet),
      ),
    );
  }

  Widget _buildSupplierHutangList(List<Map<String, dynamic>> hutangList, bool isAdmin, bool isUnpaid) {
    if (hutangList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), size: 48, color: Colors.green.shade300),
            ),
            const SizedBox(height: 16),
            Text(isUnpaid ? 'Tidak ada hutang supplier' : 'Tidak ada riwayat', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: hutangList.length,
        itemBuilder: (context, index) => _buildSupplierHutangCard(hutangList[index], isAdmin, isUnpaid),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction, bool isAdmin, bool isUnpaid, bool isOutlet) {
    final invoiceNumber = transaction['invoiceNumber'] as String;
    final finalAmount = (transaction['finalAmount'] as num).toDouble();
    final remainingAmount = (transaction['remaining_amount'] as num?)?.toDouble() ?? 0;
    final customerName = transaction['customerName'] as String? ?? '-';
    final outletName = transaction['outletName'] as String?;
    final transactionDate = DateTime.parse(transaction['transactionDate'] as String);
    final paymentMethod = transaction['paymentMethod'] as String;
    final paymentStatus = transaction['payment_status'] as String? ?? 'PAID';

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
            final transactionId = transaction['id'] as int?;
            if (transactionId != null) {
              Navigator.pushNamed(
                context,
                AppRoutes.invoiceDetail,
                arguments: transactionId,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnpaid ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(paymentStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isUnpaid ? Colors.orange.shade700 : Colors.green.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (outletName != null && outletName.isNotEmpty)
                  Row(children: [
                    Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(outletName, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                  ]),
                Row(children: [
                  Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(customerName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(DateFormat('dd/MM/yyyy').format(transactionDate), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                  Icon(PhosphorIcons.wallet(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(paymentMethod, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Color(0xFF6b7280))),
                      Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(finalAmount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1f2937))),
                    ]),
                    if (isUnpaid)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Sisa', style: TextStyle(fontSize: 12, color: Colors.orange)),
                        Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(remainingAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.orange.shade700)),
                      ]),
                  ],
                ),
                if (isUnpaid && isAdmin) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editPiutangOutletPayment(transaction),
                          icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 14),
                          label: const Text('BAYAR'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deletePiutangOutlet(transaction),
                          icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 14),
                          label: const Text('HAPUS'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isUnpaid && isAdmin) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _deletePiutangOutlet(transaction),
                      icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 14),
                      label: const Text('HAPUS'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierHutangCard(Map<String, dynamic> hutang, bool isAdmin, bool isUnpaid) {
    final invoiceNumber = hutang['invoiceNumber'] as String;
    final totalAmount = (hutang['totalAmount'] as num).toDouble();
    final remainingAmount = (hutang['remainingAmount'] as num?)?.toDouble() ?? 0;
    final supplierName = hutang['supplierName'] as String? ?? '-';
    final dueDate = hutang['dueDate'] != null ? DateTime.parse(hutang['dueDate'] as String) : DateTime.now();
    final status = hutang['status'] as String? ?? 'UNPAID';

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
          onTap: () => _showSupplierHutangDetail(hutang),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnpaid ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isUnpaid ? Colors.orange.shade700 : Colors.green.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(PhosphorIcons.truck(PhosphorIconsStyle.bold), size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(supplierName, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('Jatuh tempo: ${DateFormat('dd/MM/yyyy').format(dueDate)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Color(0xFF6b7280))),
                      Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(totalAmount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1f2937))),
                    ]),
                    if (isUnpaid)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Sisa', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(remainingAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red.shade700)),
                      ]),
                  ],
                ),
                if (isUnpaid && isAdmin) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showSupplierHutangPaymentDialog(hutang),
                          icon: Icon(PhosphorIcons.money(PhosphorIconsStyle.bold), size: 14),
                          label: const Text('BAYAR'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editSupplierHutangDueDate(hutang),
                          icon: Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 14),
                          label: const Text('EDIT'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteSupplierHutang(hutang),
                          icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 14),
                          label: const Text('HAPUS'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupplierHutangDetail(Map<String, dynamic> hutang) {
    final dueDate = hutang['dueDate'] != null ? DateTime.parse(hutang['dueDate'] as String) : DateTime.now();
    final createdAt = hutang['createdAt'] != null ? DateTime.parse(hutang['createdAt'] as String) : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(hutang['invoiceNumber'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [Icon(PhosphorIcons.truck(PhosphorIconsStyle.bold), size: 14, color: Colors.blue), const SizedBox(width: 4), Text(hutang['supplierName'] as String, style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500))]),
              Text('Tanggal: ${DateFormat('dd/MM/yyyy').format(createdAt)}'),
              Text('Jatuh Tempo: ${DateFormat('dd/MM/yyyy').format(dueDate)}'),
              Text('Status: ${hutang['status'] ?? 'UNPAID'}'),
              if ((hutang['notes'] as String?) != null && (hutang['notes'] as String).isNotEmpty)
                Text('Catatan: ${hutang['notes']}'),
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(hutang['totalAmount']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Dibayar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(hutang['paidAmount'] ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Sisa:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(hutang['remainingAmount']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSupplierHutangPaymentDialog(Map<String, dynamic> hutang) async {
    final amountController = TextEditingController(
      text: ((hutang['remainingAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFeef2ff),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      PhosphorIcons.wallet(PhosphorIconsStyle.bold),
                      size: 32,
                      color: const Color(0xFF4f46e5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pembayaran Hutang Supplier',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masukkan nominal pembayaran untuk melunasi atau mencicil hutang supplier.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile('Invoice', hutang['invoiceNumber'] ?? '-'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoTile('Supplier', hutang['supplierName'] ?? '-'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  'Sisa Hutang',
                  currency.format((hutang['remainingAmount'] as num?)?.toDouble() ?? 0),
                  valueColor: Colors.red,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah Pembayaran',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    prefixIcon: Icon(
                      PhosphorIcons.currencyCircleDollar(PhosphorIconsStyle.bold),
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('BATAL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) return;

                          final remaining = (hutang['remainingAmount'] as num?)?.toDouble() ?? 0;
                          final paid = (hutang['paidAmount'] as num?)?.toDouble() ?? 0;
                          final newRemaining = remaining - amount;
                          final newPaid = paid + amount;
                          final isPaid = newRemaining <= 0;

                          final db = await DatabaseService.database;
                          await db.update(
                            'supplierHutang',
                            {
                              'remainingAmount': newRemaining < 0 ? 0 : newRemaining,
                              'paidAmount': newPaid,
                              'status': isPaid ? 'PAID' : 'PARTIAL',
                              'updatedAt': DateTime.now().toIso8601String(),
                            },
                            where: 'id = ?',
                            whereArgs: [hutang['id']],
                          );

                          if (dialogContext.mounted) {
                            final messenger = ScaffoldMessenger.of(dialogContext);
                            Navigator.pop(dialogContext);
                            _loadTransactions();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isPaid ? 'Hutang lunas!' : 'Pembayaran diterima'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('BAYAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    amountController.dispose();
  }

  // Kept for future use: transaction detail modal
  // ignore: unused_element
  void _showTransactionDetail(Map<String, dynamic> transaction) {
    final outletName = transaction['outletName'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(transaction['invoiceNumber'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (outletName != null && outletName.isNotEmpty)
                Row(children: [Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), size: 14, color: Colors.blue), const SizedBox(width: 4), Text(outletName, style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500))]),
              Text('Customer: ${transaction['customerName'] ?? '-'}'),
              Text('Tanggal: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(transaction['transactionDate'] as String))}'),
              Text('Metode: ${transaction['paymentMethod']}'),
              Text('Status: ${transaction['payment_status'] ?? 'PAID'}'),
              const Divider(height: 24),
              const Text('Rincian Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getTransactionItems(transaction['id'] as int),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Tidak ada item'));
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return ListTile(
                          dense: true,
                          title: Text(item['productName'] as String),
                          subtitle: Text('${item['quantity']} x ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item['price'])}'),
                          trailing: Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format((item['price'] as num) * (item['quantity'] as int)), style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction['finalAmount']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              _buildRemainingRow(transaction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingRow(Map<String, dynamic> transaction) {
    final remaining = (transaction['remaining_amount'] as num?)?.toDouble() ?? 0;
    if (remaining <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Sisa:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
        Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction['remaining_amount']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
      ]),
    );
  }

  Future<List<Map<String, dynamic>>> _getTransactionItems(int transactionId) async {
    debugPrint('Loading items for transaction: $transactionId');
    final db = await DatabaseService.database;
    final items = await db.query('transactionItems', where: 'transactionId = ?', whereArgs: [transactionId]);
    debugPrint('Found ${items.length} items');
    return items;
  }

  // Kept for future use: payment dialog modal
  // ignore: unused_element
  void _showPaymentDialog(Map<String, dynamic> transaction) {
    final amountController = TextEditingController(text: ((transaction['remaining_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pembayaran Piutang',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Invoice: ${transaction['invoiceNumber']}'),
              Text('Sisa: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction['remaining_amount'])}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Pembayaran',
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) return;

                        final remaining = (transaction['remaining_amount'] as num?)?.toDouble() ?? 0;
                        final newRemaining = remaining - amount;
                        final isPaid = newRemaining <= 0;

                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(context);

                        final db = await DatabaseService.database;
                        await db.update(
                          'transactions',
                          {'remaining_amount': newRemaining < 0 ? 0 : newRemaining, 'payment_status': isPaid ? 'PAID' : 'PARTIAL'},
                          where: 'id = ?',
                          whereArgs: [transaction['id']],
                        );

                        await db.insert('payment_details', {
                          'transaction_id': transaction['id'],
                          'payment_type': 'PAYMENT',
                          'amount': amount,
                          'created_at': DateTime.now().toIso8601String(),
                        });

                        navigator.pop();
                        if (mounted) {
                          _loadTransactions();
                          messenger.showSnackBar(SnackBar(content: Text(isPaid ? 'Piutang lunas!' : 'Pembayaran diterima'), backgroundColor: Colors.green));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('BAYAR'),
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

  // ===== PIN VERIFICATION =====
  Future<bool> _showPinVerificationDialog() async {
    final pinController = TextEditingController();
    bool isVerified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0ECFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    PhosphorIcons.lock(PhosphorIconsStyle.bold),
                    size: 32,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verifikasi PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan PIN 6 digit Anda untuk melanjutkan.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF5F7FF),
                  hintText: '••••••',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (value) {},
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final settingsService = SettingsService();
                        final verified = await settingsService.verifyPin(pinController.text);
                        if (verified) {
                          isVerified = true;
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        } else {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('PIN tidak valid!'), backgroundColor: Colors.red),
                            );
                            pinController.clear();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('KONFIRMASI'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    pinController.dispose();
    return isVerified;
  }

  // ===== DELETE WITH REASON =====
  Future<String?> _showDeleteReasonDialog() async {
    final reasonController = TextEditingController();
    String? reason;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    PhosphorIcons.trash(PhosphorIconsStyle.bold),
                    size: 32,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Alasan Penghapusan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tulis alasan singkat mengapa entri ini harus dihapus.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Contoh: Salah input, duplicate data, dll...',
                  filled: true,
                  fillColor: const Color(0xFFF7F7F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        reason = null;
                        Navigator.pop(dialogContext);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Alasan harus diisi!'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        reason = reasonController.text.trim();
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('HAPUS'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    reasonController.dispose();
    return reason;
  }

  // ===== DELETE PIUTANG OUTLET (TRANSACTION) =====
  Future<void> _deletePiutangOutlet(Map<String, dynamic> transaction) async {
    final deletedBy = context.read<AuthController>().currentUser?.name ?? 'Unknown';

    // Step 1: Verify PIN
    final pinVerified = await _showPinVerificationDialog();
    if (!pinVerified) return;
    if (!mounted) return;

    // Step 2: Get delete reason
    final reason = await _showDeleteReasonDialog();
    if (reason == null) return;
    if (!mounted) return;

    // Step 3: Delete the transaction
    try {
      final db = await DatabaseService.database;

      // Log the deletion with reason
      await db.insert('deletion_log', {
        'table_name': 'transactions',
        'record_id': transaction['id'],
        'invoice_number': transaction['invoiceNumber'],
        'deleted_by': deletedBy,
        'reason': reason,
        'deleted_at': DateTime.now().toIso8601String(),
      });

      // Delete the transaction
      await db.delete('transactions', where: 'id = ?', whereArgs: [transaction['id']]);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        _loadTransactions();
        messenger.showSnackBar(
          const SnackBar(content: Text('Piutang berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===== DELETE HUTANG SUPPLIER =====
  Future<void> _deleteSupplierHutang(Map<String, dynamic> hutang) async {
    final deletedBy = context.read<AuthController>().currentUser?.name ?? 'Unknown';
    final status = hutang['status'] as String? ?? 'UNPAID';

    // Check if already paid/partial - cannot delete
    if (status == 'PARTIAL' || status == 'PAID') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        PhosphorIcons.warning(PhosphorIconsStyle.bold),
                        color: const Color(0xFFF97316),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tidak Dapat Dihapus',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hutang ini sudah memiliki pembayaran ($status). Tidak dapat dihapus untuk menjaga integritas data.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('TUTUP'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return;
    }

    // Step 1: Verify PIN
    final pinVerified = await _showPinVerificationDialog();
    if (!pinVerified) return;
    if (!mounted) return;

    // Step 2: Get delete reason
    final reason = await _showDeleteReasonDialog();
    if (reason == null) return;
    if (!mounted) return;

    // Step 3: Delete the hutang
    try {
      final db = await DatabaseService.database;

      // Log the deletion with reason
      await db.insert('deletion_log', {
        'table_name': 'supplierHutang',
        'record_id': hutang['id'],
        'invoice_number': hutang['invoiceNumber'],
        'deleted_by': deletedBy,
        'reason': reason,
        'deleted_at': DateTime.now().toIso8601String(),
      });

      // Delete the hutang
      await db.delete('supplierHutang', where: 'id = ?', whereArgs: [hutang['id']]);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        _loadTransactions();
        messenger.showSnackBar(
          const SnackBar(content: Text('Hutang supplier berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===== EDIT DUE DATE FOR SUPPLIER HUTANG =====
  Future<void> _editSupplierHutangDueDate(Map<String, dynamic> hutang) async {
    // Step 1: Verify PIN
    final pinVerified = await _showPinVerificationDialog();
    if (!pinVerified) return;
    if (!mounted) return;

    // Step 2: Show date picker
    final currentDueDate = hutang['dueDate'] != null
        ? DateTime.parse(hutang['dueDate'] as String)
        : DateTime.now();

    DateTime selectedDate = currentDueDate;

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0ECFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold),
                    color: const Color(0xFF2563EB),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Jatuh Tempo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih tanggal jatuh tempo baru yang sesuai untuk hutang supplier.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildInfoTile('Invoice', hutang['invoiceNumber'] ?? '-')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfoTile('Supplier', hutang['supplierName'] ?? '-')),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoTile('Jatuh Tempo Saat Ini', DateFormat('dd/MM/yyyy').format(currentDueDate)),
              const SizedBox(height: 16),
              const Text('Pilih tanggal baru:', style: TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) => InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), color: Colors.blue.shade700),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final db = await DatabaseService.database;
                          await db.update(
                            'supplierHutang',
                            {
                              'dueDate': selectedDate.toIso8601String(),
                              'updatedAt': DateTime.now().toIso8601String(),
                            },
                            where: 'id = ?',
                            whereArgs: [hutang['id']],
                          );

                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            _loadTransactions();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Jatuh tempo diupdate ke ${DateFormat('dd/MM/yyyy').format(selectedDate)}'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Gagal update: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('SIMPAN'),
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

  // ===== EDIT PAYMENT FOR PIUTANG OUTLET =====
  Future<void> _editPiutangOutletPayment(Map<String, dynamic> transaction) async {
    // Step 1: Verify PIN
    final pinVerified = await _showPinVerificationDialog();
    if (!pinVerified) return;
    if (!mounted) return;

    // Step 2: Show payment edit dialog
    final amountController = TextEditingController(
      text: ((transaction['remaining_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F9F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    PhosphorIcons.money(PhosphorIconsStyle.bold),
                    size: 32,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Pembayaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sesuaikan pembayaran piutang pada invoice ini dengan mudah.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildInfoTile('Invoice', transaction['invoiceNumber'] ?? '-'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildInfoTile('Total', NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction['finalAmount']))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfoTile('Sisa', NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction['remaining_amount']), valueColor: Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah Pembayaran',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  prefixIcon: Icon(PhosphorIcons.currencyCircleDollar(PhosphorIconsStyle.bold), size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) return;

                        try {
                          final db = await DatabaseService.database;
                          final remaining = (transaction['remaining_amount'] as num?)?.toDouble() ?? 0;
                          final newRemaining = remaining - amount;
                          final isPaid = newRemaining <= 0;

                          await db.update(
                            'transactions',
                            {
                              'remaining_amount': newRemaining < 0 ? 0 : newRemaining,
                              'payment_status': isPaid ? 'PAID' : 'PARTIAL',
                            },
                            where: 'id = ?',
                            whereArgs: [transaction['id']],
                          );

                          await db.insert('payment_details', {
                            'transaction_id': transaction['id'],
                            'payment_type': 'PAYMENT',
                            'amount': amount,
                            'created_at': DateTime.now().toIso8601String(),
                          });

                          // Update invoice status fields so invoice detail can show it as LUNAS
                          await db.update(
                            'transactions',
                            {
                              'remaining_amount': newRemaining < 0 ? 0 : newRemaining,
                              'payment_status': isPaid ? 'PAID' : 'PARTIAL',
                              // ensure due/tempo date exists so InvoiceDetail can render it
                              'shipmentDate': transaction['shipmentDate'] ?? transaction['dueDate'] ?? transaction['due_date'],
                            },
                            where: 'id = ?',
                            whereArgs: [transaction['id']],
                          );

                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            _loadTransactions();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isPaid ? 'Piutang lunas!' : 'Pembayaran diterima'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('BAYAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    amountController.dispose();
  }

  Widget _buildInfoTile(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }
}
