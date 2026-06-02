import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/routes.dart';
import '../../models/stock_model.dart';
import '../../models/supplier_model.dart';
import '../../services/export_service.dart';
import '../../services/stock_service.dart';

class SupplierStockHistoryPage extends StatefulWidget {
  final Supplier supplier;
  
  const SupplierStockHistoryPage({
    super.key,
    required this.supplier,
  });

  @override
  State<SupplierStockHistoryPage> createState() => _SupplierStockHistoryPageState();
}

class _SupplierStockHistoryPageState extends State<SupplierStockHistoryPage> {
  List<StockMovement> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final movements = await StockService.getMovementsBySupplierId(
        widget.supplier.id!,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _movements = movements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportHistory(BuildContext context) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading all stock movements...')),
    );

    // Load ALL movements without pagination limit
    final allMovements = await StockService.getMovementsBySupplierId(
      widget.supplier.id!,
    );

    if (allMovements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final headers = ['Produk', 'Tanggal', 'Stok Sebelum', 'Stok Sesudah', 'Qty', 'Invoice', 'Catatan'];
    final rows = <List<String>>[];
    for (final m in allMovements) {
      rows.add([
        m.productName ?? m.productId.toString(),
        dateFormat.format(m.createdAt),
        m.previousStock.toString(),
        m.newStock.toString(),
        m.quantity.toString(),
        m.invoiceNumber ?? '-',
        m.notes,
      ]);
    }
    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: 'riwayat_stok_${widget.supplier.name.replaceAll(' ', '_')}',
      sheetName: 'Riwayat Stok',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Export ${allMovements.length} data berhasil'),
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(FontAwesomeIcons.truckFast, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Riwayat Stok ${widget.supplier.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
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
              onPressed: () => _exportHistory(context),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _movements.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(isMobile),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.boxOpen,
              size: 48,
              color: const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada stok dari supplier ini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stok masuk akan terlihat di sini',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isMobile) {
    // Group movements by date
    final groupedMovements = <String, List<StockMovement>>{};
    for (var movement in _movements) {
      final dateKey = _formatDateGroup(movement.createdAt);
      groupedMovements.putIfAbsent(dateKey, () => []).add(movement);
    }

    final totalQuantity = _movements.fold<int>(0, (sum, m) => sum + m.quantity);

    return CustomScrollView(
      slivers: [
        // Summary header
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.all(isMobile ? 12 : 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.arrowDown,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Stok Masuk',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalQuantity item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_movements.length} transaksi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Grouped list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final dateKey = groupedMovements.keys.elementAt(index);
              final movements = groupedMovements[dateKey]!;
              return _buildDateGroup(dateKey, movements, isMobile);
            },
            childCount: groupedMovements.length,
          ),
        ),
      ],
    );
  }

  Widget _buildDateGroup(String date, List<StockMovement> movements, bool isMobile) {
    final totalQty = movements.fold<int>(0, (sum, m) => sum + m.quantity);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+$totalQty item',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Movement items
          ...movements.map((m) => _buildMovementCard(m, isMobile)),
        ],
      ),
    );
  }

  Widget _buildMovementCard(StockMovement movement, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              FontAwesomeIcons.arrowDown,
              color: Color(0xFF4CAF50),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.productName ?? 'Produk #${movement.productId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(movement.createdAt)} - Stok: ${movement.previousStock} → ${movement.newStock}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (movement.invoiceNumber != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: movement.referenceId != null
                        ? () => Navigator.pushNamed(
                              context,
                              AppRoutes.invoiceDetail,
                              arguments: movement.referenceId,
                            )
                        : null,
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.fileInvoice,
                            size: 10, color: const Color(0xFF1976D2)),
                        const SizedBox(width: 4),
                        Text(
                          movement.invoiceNumber!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (movement.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    movement.notes,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            '+${movement.quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hari Ini';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Kemarin';
    } else if (now.difference(date).inDays < 7) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
