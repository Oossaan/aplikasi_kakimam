import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/return_model.dart';
import '../../services/transaction_service.dart';
import '../../services/export_service.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  ReturnType? _selectedReturnType;
  bool _isLoading = true;
  List<Return> _returns = [];
  double _totalReturnAmount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReturns();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReturns() async {
    setState(() => _isLoading = true);
    try {
      final returns = await TransactionService.getReturns(
        returnType: _selectedReturnType,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchController.text.isEmpty ? null : _searchController.text,
      );

      double total = 0;
      for (var ret in returns) {
        total += ret.subtotal;
      }

      if (mounted) {
        setState(() {
          _returns = returns;
          _totalReturnAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading returns: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportReturns(BuildContext context) async {
    if (_returns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final headers = ['Produk', 'Tanggal', 'Tipe', 'Qty', 'Total', 'Referensi', 'Catatan'];
    final rows = <List<String>>[];
    for (final ret in _returns) {
      rows.add([
        ret.productName,
        dateFormat.format(ret.createdAt),
        ret.returnType.name,
        ret.quantity.toString(),
        currency.format(ret.subtotal),
        ret.referenceNumber ?? '-',
        ret.notes ?? '-',
      ]);
    }
    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: 'laporan_retur',
      sheetName: 'Retur',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Export ${_returns.length} retur berhasil'),
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
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 400;

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
              child: Icon(PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold), size: isMobile ? 16 : 18),
            ),
            const SizedBox(width: 10),
            const Text('Daftar Retur'),
          ],
        ),
        backgroundColor: Colors.orange,
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
              onPressed: () => _exportReturns(context),
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
              onPressed: () => _showFilterDialog(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary Card
            Container(
              margin: EdgeInsets.all(isMobile ? 12 : 16),
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold), color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Total Retur',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(_totalReturnAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_returns.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips
            if (_selectedReturnType != null || _startDate != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedReturnType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_selectedReturnType!.name, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _selectedReturnType = null);
                                  _loadReturns();
                                },
                                child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.orange, size: 14),
                              ),
                            ],
                          ),
                        ),
                      if (_startDate != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(DateFormat('dd/MM/yy').format(_startDate!), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                  _loadReturns();
                                },
                                child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.orange, size: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            SizedBox(height: isMobile ? 8 : 12),

            // Return Type Tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
              child: Row(
                children: [
                  Expanded(child: _buildTypeTab('Semua', null, isMobile)),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(child: _buildTypeTab('Penjualan', ReturnType.sales, isMobile)),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(child: _buildTypeTab('Supplier', ReturnType.supplier, isMobile)),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(child: _buildTypeTab('Outlet', ReturnType.outlet, isMobile)),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari produk atau invoice...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
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
                  onSubmitted: (_) => _loadReturns(),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),

            // Return List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _returns.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5F6FA),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold), size: 48, color: Colors.grey.shade400),
                              ),
                              const SizedBox(height: 16),
                              Text('Tidak ada retur', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: Colors.orange,
                          onRefresh: _loadReturns,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                            itemCount: _returns.length,
                            itemBuilder: (context, index) {
                              final ret = _returns[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
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
                                    child: Padding(
                                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(isMobile ? 10 : 12),
                                            decoration: BoxDecoration(
                                              color: _getTypeColor(ret.returnType).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getTypeIcon(ret.returnType),
                                              color: _getTypeColor(ret.returnType),
                                              size: isMobile ? 18 : 20,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ret.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 12, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      dateFormat.format(ret.createdAt),
                                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                                if (ret.referenceNumber != null && ret.referenceNumber!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(PhosphorIcons.hash(PhosphorIconsStyle.bold), size: 12, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Ref: ${ret.referenceNumber}',
                                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                if (ret.notes != null && ret.notes!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    ret.notes!,
                                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                currencyFormat.format(ret.subtotal),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.orange,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getTypeColor(ret.returnType).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'x${ret.quantity}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: _getTypeColor(ret.returnType),
                                                  ),
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
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String label, ReturnType? type, bool isMobile) {
    final isSelected = _selectedReturnType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedReturnType = type);
        _loadReturns();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: isMobile ? 11 : 12,
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(ReturnType type) {
    switch (type) {
      case ReturnType.sales:
        return Colors.orange;
      case ReturnType.supplier:
        return Colors.blue;
      case ReturnType.outlet:
        return Colors.green;
      case ReturnType.adjustment:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(ReturnType type) {
    switch (type) {
      case ReturnType.sales:
        return PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold);
      case ReturnType.supplier:
        return PhosphorIcons.truck(PhosphorIconsStyle.bold);
      case ReturnType.outlet:
        return PhosphorIcons.storefront(PhosphorIconsStyle.bold);
      case ReturnType.adjustment:
        return PhosphorIcons.sliders(PhosphorIconsStyle.bold);
    }
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), color: Colors.orange, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Filter Tanggal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), size: 16),
                      label: Text(_startDate != null ? DateFormat('dd/MM/yy').format(_startDate!) : 'Mulai'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => _startDate = picked);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), size: 16),
                      label: Text(_endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : 'Selesai'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => _endDate = picked);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _loadReturns();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Terapkan'),
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
}