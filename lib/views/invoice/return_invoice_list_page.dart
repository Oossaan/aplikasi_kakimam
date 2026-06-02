import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/routes.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';

class ReturnInvoiceListPage extends StatefulWidget {
  const ReturnInvoiceListPage({super.key});

  @override
  State<ReturnInvoiceListPage> createState() => _ReturnInvoiceListPageState();
}

class _ReturnInvoiceListPageState extends State<ReturnInvoiceListPage> {
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  List<Transaction> _returns = [];
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
      final returns = await TransactionService.getInvoices(
        startDate: _startDate,
        endDate: _endDate,
        status: 'REFUNDED',
        searchQuery: _searchController.text.isEmpty ? null : _searchController.text,
      );

      double total = 0;
      for (var ret in returns) {
        total += ret.finalAmount.abs();
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final isMobile = MediaQuery.of(context).size.width < 400;

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
              child: Icon(PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold), size: 18),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Retur',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(_totalReturnAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_returns.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                    hintText: 'Cari invoice retur...',
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
            const SizedBox(height: 16),

            // Return List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _returns.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: Colors.orange,
                          onRefresh: _loadReturns,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                            itemCount: _returns.length,
                            itemBuilder: (context, index) => _buildReturnCard(_returns[index], isMobile),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold),
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak ada retur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Riwayat retur akan muncul di sini',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnCard(Transaction ret, bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

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
            if (ret.id != null) {
              Navigator.pushNamed(
                context,
                AppRoutes.invoiceDetail,
                arguments: ret.id,
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold),
                    color: Colors.orange.shade600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ret.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1f2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            dateFormat.format(ret.transactionDate),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      if (ret.notes != null && ret.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(PhosphorIcons.note(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ret.notes!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  currencyFormat.format(ret.finalAmount.abs()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), color: Colors.orange, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter Tanggal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), color: Colors.grey.shade500, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _startDate != null ? DateFormat('dd/MM/yy').format(_startDate!) : 'Mulai',
                              style: TextStyle(color: _startDate != null ? Colors.grey.shade700 : Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), color: Colors.grey.shade500, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : 'Selesai',
                              style: TextStyle(color: _endDate != null ? Colors.grey.shade700 : Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _loadReturns();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}