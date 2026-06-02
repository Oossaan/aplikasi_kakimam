import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/product_model.dart';
import '../../services/export_service.dart';

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final filteredProducts = _filter == 'all'
        ? controller.getFilteredProducts(controller.products)
        : _filter == 'low'
            ? controller.lowStockList
            : controller.outOfStockList;

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
              child: Icon(PhosphorIcons.package(PhosphorIconsStyle.bold), size: isMobile ? 16 : 18),
            ),
            const SizedBox(width: 10),
            const Text('Laporan Stok'),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          SizedBox(
            height: 40,
            child: Center(
              child: Icon(
                PhosphorIcons.chartBar(PhosphorIconsStyle.bold),
                size: 20,
              ),
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.fileArrowUp(PhosphorIconsStyle.bold), size: 20),
            tooltip: 'Export CSV',
            onPressed: () => _exportToCSV(context, controller),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Wrap(
                spacing: isMobile ? 8 : 12,
                runSpacing: isMobile ? 8 : 12,
                children: [
                  _buildFilterChip('Semua', 'all', Colors.blue, isMobile),
                  _buildFilterChip('Stok Menipis', 'low', Colors.orange, isMobile),
                  _buildFilterChip('Habis', 'out', Colors.red, isMobile),
                  _buildCategoryFilterChip(controller),
                ],
              ),
            ),

            // Summary Cards
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Produk',
                          '${controller.totalProducts}',
                          Icons.inbox_rounded,
                          const Color(0xFF667eea),
                          isMobile,
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Stok Menipis',
                          '${controller.lowStockProducts}',
                          Icons.warning_amber_rounded,
                          Colors.orange,
                          isMobile,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  _buildSummaryCard(
                    'Total Nilai Stok',
                    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(controller.totalInventoryValue),
                    PhosphorIcons.currencyDollar(PhosphorIconsStyle.bold),
                    const Color(0xFF10b981),
                    isMobile,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // Table Header
            if (filteredProducts.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
                margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 11 : 12)),
                    ),
                    Expanded(
                      child: Text('Stok', style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 11 : 12), textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('Harga', style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 11 : 12), textAlign: TextAlign.right),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 11 : 12), textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),

            // Product List
            Expanded(
              child: filteredProducts.isEmpty
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
                            child: Icon(
                              PhosphorIcons.package(PhosphorIconsStyle.bold),
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'all' ? 'Tidak ada produk' : _filter == 'low' ? 'Tidak ada produk stok menipis' : 'Semua tercukupi',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF667eea),
                      onRefresh: () => controller.loadProducts(refresh: true),
                      child: ListView.builder(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) => _buildProductRow(filteredProducts[index], isMobile),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(InventoryController controller) {
    // Placeholder: category filter UI (only if controller has category info).
    // For now, show chip that informs user that category filter isn't implemented.
    return _buildDisabledChip('Kategori: belum ada filter', Colors.grey.shade400, isMobile: MediaQuery.of(context).size.width < 400);

  }

  Widget _buildDisabledChip(String label, Color color, {required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 12 : 13,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color, bool isMobile) {

    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 12 : 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isMobile, {bool fullWidth = false}) {
    final content = Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isMobile ? 18 : 22),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isMobile ? 14 : 16,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (fullWidth) return content;
    return content;
  }

  Widget _buildProductRow(Product product, bool isMobile) {
    final totalValue = product.stock * product.purchasePrice;
    final isLow = product.isLowStock;
    final isOut = product.isOutOfStock;

    Color stockColor;
    if (isOut) {
      stockColor = Colors.red;
    } else if (isLow) {
      stockColor = Colors.orange;
    } else {
      stockColor = const Color(0xFF10b981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isOut
            ? Border.all(color: Colors.red.shade200, width: 1)
            : isLow
                ? Border.all(color: Colors.orange.shade200, width: 1)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.category,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 4 : 6),
              decoration: BoxDecoration(
                color: stockColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${product.stock}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: stockColor,
                  fontSize: isMobile ? 12 : 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(product.sellingPrice),
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(totalValue),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1f2937)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV(BuildContext context, InventoryController controller) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading all products for export...')),
    );

    // Load ALL products without pagination
    final allProducts = await controller.loadAllProductsForExport();
    if (allProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to export')),
      );
      return;
    }

    final headers = ['Nama Produk', 'Kategori', 'Stok', 'Min Stok', 'Harga Beli (HPP)', 'Harga Jual', 'Total Nilai'];
    final rows = allProducts.map((p) => [
      p.name,
      p.category,
      p.stock.toString(),
      p.minStock.toString(),
      p.purchasePrice.toStringAsFixed(0),
      p.sellingPrice.toStringAsFixed(0),
      (p.stock * p.purchasePrice).toStringAsFixed(0),
    ]).toList();

    await ExportService.exportToExcelGeneric(
      headers: headers,
      rows: rows,
      filenameBase: 'stock_report',
      sheetName: 'Stock Report',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock report exported (${allProducts.length} products)')),
      );
    }
  }
}