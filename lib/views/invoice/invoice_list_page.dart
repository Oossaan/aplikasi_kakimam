import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/invoice_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../models/transaction_model.dart';
import '../../config/routes.dart';
import '../../services/export_service.dart';

class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'date_desc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  void _loadInvoices() {
    context.read<InvoiceController>().loadInvoices(
      startDate: _startDate,
      endDate: _endDate,
      status: _selectedStatus,
      sortBy: _sortBy,
      searchQuery: _searchController.text,
    );
  }

  Future<void> _exportInvoices(BuildContext context, List<Transaction> invoices) async {
    if (invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final headers = ['No Invoice', 'Tanggal', 'Outlet/Supplier', 'Total', 'Status'];
    final rows = <List<String>>[];
    for (final inv in invoices) {
      final party = inv.outletName ?? inv.supplierName ?? '-';
      rows.add([
        inv.invoiceNumber,
        dateFormat.format(inv.transactionDate),
        party,
        currency.format(inv.finalAmount),
        inv.statusLabel,
      ]);
    }
    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: 'invoice_list',
      sheetName: 'Invoice',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Export ${invoices.length} invoice berhasil'),
          ]),
          backgroundColor: const Color(0xFF10b981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InvoiceController>();
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
              child: Icon(PhosphorIcons.fileText(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Daftar Invoice'),
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
              onPressed: () => _exportInvoices(context, controller.invoices),
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
            // Search Bar
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                    hintText: 'Cari invoice...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 22),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadInvoices();
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
                  onSubmitted: (_) => _loadInvoices(),
                ),
              ),
            ),
            // Active filters
            if (_selectedStatus != 'all' || _startDate != null || _endDate != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_selectedStatus != 'all')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedStatus.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF667eea),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedStatus = 'all');
                                _loadInvoices();
                              },
                              child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 14),
                            ),
                          ],
                        ),
                      ),
                    if (_startDate != null || _endDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), color: Colors.grey.shade600, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _startDate != null && _endDate != null
                                  ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                                  : _startDate != null
                                      ? 'From ${DateFormat('dd/MM/yy').format(_startDate!)}'
                                      : 'Until ${DateFormat('dd/MM/yy').format(_endDate!)}',
                              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                _loadInvoices();
                              },
                              child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.grey.shade600, size: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Invoice List
            Expanded(
              child: controller.isLoading
                  ? Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)))
                  : controller.invoices.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF667eea),
                          onRefresh: () async => _loadInvoices(),
                          child: ListView.builder(
                            padding: EdgeInsets.all(isMobile ? 8 : 16),
                            itemCount: controller.invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = controller.invoices[index];
                              return _buildInvoiceTile(context, invoice, controller, isMobile);
                            },
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
                PhosphorIcons.fileText(PhosphorIconsStyle.bold),
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak ada invoice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice akan muncul di sini',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceTile(BuildContext context, Transaction invoice, InvoiceController controller, bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    final totalReturned = invoice.items.fold<int>(
      0,
      (sum, item) => sum + item.returnedQuantity,
    );
    final hasReturn = totalReturned > 0;

    Color statusColor;
    String statusBadgeText;
    IconData statusIcon;

    if (hasReturn) {
      statusColor = Colors.orange;
      statusBadgeText = 'Retur';
      statusIcon = PhosphorIcons.arrowUUpLeft(PhosphorIconsStyle.bold);
    } else {
      switch (invoice.status) {
        case TransactionStatus.paid:
          statusColor = const Color(0xFF10b981);
          statusBadgeText = 'Lunas';
          statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.bold);
          break;
        case TransactionStatus.pending:
          statusColor = Colors.orange;
          statusBadgeText = 'Menunggu';
          statusIcon = PhosphorIcons.clock(PhosphorIconsStyle.bold);
          break;
        case TransactionStatus.cancelled:
          statusColor = const Color(0xFFef4444);
          statusBadgeText = 'Dibatalkan';
          statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.bold);
          break;
        case TransactionStatus.refunded:
          statusColor = Colors.purple;
          statusBadgeText = 'Dikembalikan';
          statusIcon = PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold);
          break;
      }
    }

    return Dismissible(
      key: Key('invoice_${invoice.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), color: Colors.white, size: 24),
      ),
      secondaryBackground: invoice.canEdit
          ? Container(
              margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.white, size: 24),
            )
          : null,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _showInvoiceDetails(context, invoice);
          return false;
        } else if (direction == DismissDirection.endToStart && invoice.canEdit) {
          return await _showVoidConfirmation(context, invoice);
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          controller.voidTransaction(invoice.id!, 'Void from list');
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
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
            onTap: () => _showInvoiceDetails(context, invoice),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1f2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              statusBadgeText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(invoice.transactionDate),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      if (invoice.outletName != null) ...[
                        const SizedBox(width: 16),
                        Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            invoice.outletName!,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${invoice.items.length} item',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (hasReturn) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Retur: $totalReturned',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        currencyFormat.format(invoice.finalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF10b981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter Invoice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Status',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['all', 'PAID', 'PENDING', 'CANCELLED', 'REFUNDED']
                    .map((status) => GestureDetector(
                          onTap: () => setSheetState(() => _selectedStatus = status),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedStatus == status ? const Color(0xFF667eea) : const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedStatus == status ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tanggal',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 20),
              const Text(
                'Urutkan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSortChip('Terbaru', 'date_desc', setSheetState),
                  _buildSortChip('Terlama', 'date_asc', setSheetState),
                  _buildSortChip('Total Tertinggi', 'total_desc', setSheetState),
                  _buildSortChip('Total Terendah', 'total_asc', setSheetState),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _selectedStatus = 'all';
                          _startDate = null;
                          _endDate = null;
                          _sortBy = 'date_desc';
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
                        _loadInvoices();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
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

  Widget _buildSortChip(String label, String value, StateSetter setSheetState) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setSheetState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667eea) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context, Transaction invoice) {
    if (invoice.id != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.invoiceDetail,
        arguments: invoice.id,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('ID Invoice tidak ditemukan'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<bool> _showVoidConfirmation(BuildContext context, Transaction invoice) async {
    final settingsController = context.read<SettingsController>();
    if (settingsController.settings.isPinEnabled) {
      final pinController = TextEditingController();
      bool verified = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (pinDialogContext) => Dialog(
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
                  child: Icon(PhosphorIcons.lock(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 28),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verifikasi PIN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Masukkan PIN untuk membatalkan invoice ${invoice.invoiceNumber}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '******',
                    hintStyle: TextStyle(color: Colors.grey.shade300),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(pinDialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(pinDialogContext);
                          final isValid = await settingsController.verifyPin(pinController.text);
                          if (!pinDialogContext.mounted) return;
                          if (isValid) {
                            verified = true;
                            Navigator.pop(pinDialogContext);
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    const Text('PIN salah'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFef4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Verifikasi'),
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
      if (!verified) return false;
    }

    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.bold), color: Colors.orange.shade600, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Void Invoice?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
              ),
              const SizedBox(height: 10),
              Text(
                'Invoice ${invoice.invoiceNumber} akan dibatalkan. Tindakan ini tidak dapat dibatalkan.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Alasan pembatalan...',
                  hintStyle: TextStyle(color: Colors.grey.shade300),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Void', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && reasonController.text.isNotEmpty) {
      context.read<InvoiceController>().voidTransaction(invoice.id!, reasonController.text);
    }
    return false;
  }
}