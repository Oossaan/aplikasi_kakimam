import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/supplier_controller.dart';
import '../../controllers/outlet_controller.dart';
import '../../config/routes.dart';
import '../../models/product_model.dart';
import '../../models/stock_model.dart';
import '../../services/export_service.dart';


class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with WidgetsBindingObserver {
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialLoadDone && mounted) {
        _initialLoadDone = true;
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Avoid calling notifyListeners() during build phase.
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('stockFilter')) {
      final stockFilter = args['stockFilter'] as String?;
      if (stockFilter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<InventoryController>().setStockFilter(stockFilter);
        });
      }
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadData() {
    if (mounted) {
      context.read<InventoryController>().loadProducts();
      context.read<InventoryController>().loadStockMovements();
      context.read<SupplierController>().loadSuppliers();
      context.read<OutletController>().loadOutlets();
    }
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _refreshProducts() async {
    await context.read<InventoryController>().loadProducts();
    await context.read<InventoryController>().loadStockMovements();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isTablet = size.width > 600;
    final isMobile = size.width < 400;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
                child: Icon(PhosphorIcons.package(PhosphorIconsStyle.bold), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Inventory',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF667eea),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: [
              Tab(icon: Icon(PhosphorIcons.package(PhosphorIconsStyle.bold), size: 18), text: 'Produk'),
              Tab(icon: Icon(PhosphorIcons.arrowDown(PhosphorIconsStyle.bold), size: 18), text: 'Masuk'),
              Tab(icon: Icon(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold), size: 18), text: 'Keluar'),
              Tab(icon: Icon(PhosphorIcons.clock(PhosphorIconsStyle.bold), size: 18), text: 'Riwayat'),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.addProduct),
                tooltip: 'Tambah Produk',
                icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 20),
              ),
            ),
            IconButton(
              icon: Icon(PhosphorIcons.fileXls(PhosphorIconsStyle.bold), size: 20),
              onPressed: () async {
                if (!mounted) return;
                final controller = context.read<InventoryController>();
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loading all products for export...')),
                );
                // Load ALL products without pagination
                final allProducts = await controller.loadAllProductsForExport();
                if (allProducts.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No products to export')),
                    );
                  }
                  return;
                }
                await ExportService.exportInventoryToExcel(allProducts);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Inventory exported to Excel (${allProducts.length} products)')),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(PhosphorIcons.printer(PhosphorIconsStyle.bold), size: 20),
              onPressed: () async {
                if (!mounted) return;
                final controller = context.read<InventoryController>();
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loading all products for print...')),
                );
                // Load ALL products without pagination
                final allProducts = await controller.loadAllProductsForExport();
                if (allProducts.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No products to print')),
                    );
                  }
                  return;
                }
                await ExportService.printInventory(allProducts);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Inventory printed/saved (${allProducts.length} products)')),
                  );
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Stats + Search (Products tab only)
              Builder(
                builder: (context) {
                  final tabIndex = DefaultTabController.of(context).index;
                  if (tabIndex != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      children: [
                        // Stats
                        _buildStatsRow(controller, isWide, isTablet, isMobile),
                        const SizedBox(height: 16),
                        // Search
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
                            decoration: InputDecoration(
                              hintText: 'Cari produk...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 22),
                              ),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18),
                                  onPressed: () => _showFilterDialog(context),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (value) => controller.searchProductsDebounced(value),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    controller.isLoading
                        ? Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)))
                        : controller.getFilteredProducts(controller.products).isEmpty
                            ? _buildEmptyState()
                            : Column(
                                children: [
                                  Expanded(
                                    child: RefreshIndicator(
                                      color: const Color(0xFF667eea),
                                      onRefresh: _refreshProducts,
                                      child: ListView.builder(
                                        padding: EdgeInsets.all(isMobile ? 8 : 16),
                                        itemCount: controller.getFilteredProducts(controller.products).length,
                                        itemBuilder: (context, index) {
                                          final product = controller.getFilteredProducts(controller.products)[index];
                                          return _buildProductCard(context, controller, product, isMobile);
                                        },
                                      ),
                                    ),
                                  ),
                                  _buildPaginationControls(controller),
                                ],
                              ),
                    _buildStockInTab(context, controller, isMobile),
                    _buildStockOutTab(context, controller, isMobile),
                    _buildHistoryTab(context, controller, isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls(InventoryController controller) {
    final currentPage = controller.currentPage;
    final totalPages = controller.totalPages;
    final isMobile = MediaQuery.of(context).size.width < 400;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: currentPage > 1
                ? () => context.read<InventoryController>().goToPage(currentPage - 1)
                : null,
            icon: Icon(
              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: currentPage > 1 ? const Color(0xFF667eea) : Colors.grey.shade300,
            ),
          ),
          Text(
            'Halaman $currentPage dari $totalPages',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 13 : 15,
              color: const Color(0xFF667eea),
            ),
          ),
          IconButton(
            onPressed: currentPage < totalPages
                ? () => context.read<InventoryController>().goToPage(currentPage + 1)
                : null,
            icon: Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              color: currentPage < totalPages ? const Color(0xFF667eea) : Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(InventoryController controller, bool isWide, bool isTablet, bool isMobile) {
    final stats = [
      _StatData('Total Produk', '${controller.totalProducts}', PhosphorIcons.package(PhosphorIconsStyle.bold), const Color(0xFF667eea)),
      _StatData('Stok Menipis', '${controller.lowStockProducts}', PhosphorIcons.warning(PhosphorIconsStyle.bold), const Color(0xFFf59e0b)),
      _StatData('Nilai Inventory', _formatCurrency(controller.totalInventoryValue), PhosphorIcons.currencyDollar(PhosphorIconsStyle.bold), const Color(0xFF10b981)),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatItem(stats[0], isMobile)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem(stats[1], isMobile)),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatItem(stats[2], isMobile),
        ],
      );
    }

    if (isWide) {
      return Row(
        children: stats.map((s) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildStatItem(s, false),
        ))).toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: _buildStatItem(stats[0], false)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatItem(stats[1], false)),
        if (isTablet) ...[
          const SizedBox(width: 10),
          Expanded(child: _buildStatItem(stats[2], false)),
        ],
      ],
    );
  }

  Widget _buildStatItem(_StatData data, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: data.color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.color, size: isMobile ? 20 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 17,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                PhosphorIcons.package(PhosphorIconsStyle.bold),
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah produk baru untuk memulai',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.addProduct),
              icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
              label: const Text('Tambah Produk'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                shadowColor: const Color(0xFF667eea).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, InventoryController controller, Product product, bool isMobile) {
    final isLowStock = product.isLowStock;
    final stockColor = isLowStock ? const Color(0xFFef4444) : const Color(0xFF10b981);
    final stockBg = isLowStock ? Colors.red.shade50 : Colors.green.shade50;

    return Container(
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
          onTap: () => _showProductDetails(context, product),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                // Status icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: stockBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLowStock
                        ? PhosphorIcons.warning(PhosphorIconsStyle.bold)
                        : PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                    color: stockColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1f2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF667eea),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SKU: ${product.barcode}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Price & Stock
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(product.sellingPrice),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Stok: ${product.stock}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Menu
                _buildPopupMenu(context, controller, product),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, InventoryController controller, Product product) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold), color: Colors.grey.shade600, size: 18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        _buildPopupItem('edit', PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), 'Edit', const Color(0xFF667eea)),
        _buildPopupItem('add_stock', PhosphorIcons.plus(PhosphorIconsStyle.bold), 'Tambah Stok', const Color(0xFF10b981)),
        _buildPopupItem('reduce_stock', PhosphorIcons.minus(PhosphorIconsStyle.bold), 'Kurangi Stok', const Color(0xFFf59e0b)),
        const PopupMenuDivider(),
        _buildPopupItem('retur', PhosphorIcons.arrowUUpLeft(PhosphorIconsStyle.bold), 'Retur', const Color(0xFFFF9800)),
        _buildPopupItem('barang_rusak', PhosphorIcons.warning(PhosphorIconsStyle.bold), 'Barang Rusak', const Color(0xFFef4444)),
        const PopupMenuDivider(),
        _buildPopupItem('delete', PhosphorIcons.trash(PhosphorIconsStyle.bold), 'Hapus', const Color(0xFFef4444), isDestructive: true),
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            Navigator.pushNamed(context, AppRoutes.addProduct, arguments: product);
            break;
          case 'add_stock':
          case 'reduce_stock':
            Navigator.pushNamed(context, AppRoutes.stockAdjustment);
            break;
          case 'retur':
          case 'barang_rusak':
            Navigator.pushNamed(context, AppRoutes.supplierReturn);
            break;
          case 'delete':
            _showDeleteConfirmation(context, controller, product);
            break;
        }
      },
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, PhosphorIconData icon, String label, Color color, {bool isDestructive = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDestructive ? color : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, InventoryController controller, Product product) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.trash(PhosphorIconsStyle.bold),
                  color: Colors.red.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Hapus Produk?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1f2937),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '"${product.name}" akan dihapus dari inventory. Tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && context.mounted) {
      final success = await controller.deleteProduct(product.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? PhosphorIcons.checkCircle(PhosphorIconsStyle.bold) : PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(success ? 'Produk berhasil dihapus' : 'Gagal menghapus produk'),
              ],
            ),
            backgroundColor: success ? const Color(0xFF10b981) : const Color(0xFFef4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildStockInTab(BuildContext context, InventoryController controller, bool isMobile) {
    final groups = controller.stockInGroups;

    if (controller.isLoadingMovements) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)));
    }

    if (groups.isEmpty) {
      return _buildEmptyTab(PhosphorIcons.arrowDown(PhosphorIconsStyle.bold), 'Belum ada stok masuk', 'Stok masuk dari supplier akan muncul di sini');
    }

    return RefreshIndicator(
      color: const Color(0xFF667eea),
      onRefresh: _refreshProducts,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: groups.length,
        itemBuilder: (context, index) => _buildStockInGroupCard(groups[index], isMobile),
      ),
    );
  }

  Widget _buildStockOutTab(BuildContext context, InventoryController controller, bool isMobile) {
    final groups = controller.stockOutGroups;

    if (controller.isLoadingMovements) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)));
    }

    if (groups.isEmpty) {
      return _buildEmptyTab(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold), 'Belum ada stok keluar', 'Stok keluar dari penjualan akan muncul di sini');
    }

    return RefreshIndicator(
      color: const Color(0xFF667eea),
      onRefresh: _refreshProducts,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: groups.length,
        itemBuilder: (context, index) => _buildStockOutGroupCard(groups[index], isMobile),
      ),
    );
  }

  /// Build a grouped stock-in card (by supplier)
  Widget _buildStockInGroupCard(StockHistoryGroup group, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to invoice detail for purchase transaction
            if (group.referenceId != null) {
              Navigator.pushNamed(context, AppRoutes.invoiceDetail, arguments: group.referenceId);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.arrowDown(PhosphorIconsStyle.bold), color: const Color(0xFF10b981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                group.referenceLabel,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1f2937)),
                              ),
                              const SizedBox(width: 8),
                              Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 14),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(group.createdAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${group.totalQuantity}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF10b981)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${group.products.length} item',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF667eea)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (group.products.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Show aggregated product items
                  ...group.products.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'x${item.totalQuantity}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10b981)),
                        ),
                      ],
                    ),
                  )),
                  if (group.products.length > 3)
                    Text(
                      '+${group.products.length - 3} more',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a grouped stock-out card (by invoice/transaction)
  Widget _buildStockOutGroupCard(StockHistoryGroup group, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to invoice detail for transaction type
            if (group.referenceType == 'transaction' && group.referenceId != null) {
              Navigator.pushNamed(context, AppRoutes.invoiceDetail, arguments: group.referenceId);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold), color: const Color(0xFFef4444), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                group.referenceLabel,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1f2937)),
                              ),
                              const SizedBox(width: 8),
                              Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 14),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(group.createdAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '-${group.totalQuantity}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFFef4444)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${group.products.length} item',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF667eea)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (group.products.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Show aggregated product items
                  ...group.products.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'x${item.totalQuantity}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFef4444)),
                        ),
                      ],
                    ),
                  )),
                  if (group.products.length > 3)
                    Text(
                      '+${group.products.length - 3} more',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, InventoryController controller, bool isMobile) {
    if (controller.isLoading) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)));
    }

    if (controller.stockHistory.isEmpty) {
      return _buildEmptyTab(PhosphorIcons.clock(PhosphorIconsStyle.bold), 'Belum ada riwayat stok', 'Riwayat penyesuaian stok akan muncul di sini');
    }

    return RefreshIndicator(
      color: const Color(0xFF667eea),
      onRefresh: _refreshProducts,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: controller.stockHistory.length,
        itemBuilder: (context, index) => _buildStockMovementItem(controller.stockHistory[index], isMobile),
      ),
    );
  }

  Widget _buildEmptyTab(PhosphorIconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockMovementItem(StockMovement movement, bool isMobile, {bool? isIn}) {
    final isMovementIn = isIn ?? movement.isPositive;
    final color = isMovementIn ? const Color(0xFF10b981) : const Color(0xFFef4444);
    final bgColor = isMovementIn ? Colors.green.shade50 : Colors.red.shade50;
    final icon = isMovementIn
        ? PhosphorIcons.arrowDown(PhosphorIconsStyle.bold)
        : PhosphorIcons.arrowUp(PhosphorIconsStyle.bold);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: movement.referenceId != null
              ? () => Navigator.pushNamed(context, AppRoutes.invoiceDetail, arguments: movement.referenceId)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              movement.typeLabel,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1f2937)),
                            ),
                          ),
                          if (movement.referenceId != null)
                            Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 14),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movement.notes.isNotEmpty ? movement.notes : (movement.referenceType ?? '-'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isMovementIn ? '+' : '-'}${movement.quantity}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(movement.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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

  void _showFilterDialog(BuildContext context) {
    final inventoryController = context.read<InventoryController>();

    String tempStockFilter = inventoryController.stockFilter; // all, low, out

    Widget filterTile({
      required String title,
      required String subtitle,
      required PhosphorIconData icon,
      required String value,
      required Color color,
    }) {
      final selected = tempStockFilter == value;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => tempStockFilter = value);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color.withValues(alpha: 0.35) : Colors.grey.shade200,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: selected ? color : Colors.grey.shade600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : const Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? color : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: color, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                'Filter Produk',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
              ),
              const SizedBox(height: 24),

              // Stock filter
              Column(
                children: [
                  filterTile(
                    title: 'Semua',
                    subtitle: 'Tampilkan semua produk aktif',
                    icon: PhosphorIcons.package(PhosphorIconsStyle.bold),
                    value: 'all',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  filterTile(
                    title: 'Stok Menipis',
                    subtitle: 'Stok <= min stok, stok > 0',
                    icon: PhosphorIcons.warning(PhosphorIconsStyle.bold),
                    value: 'low',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  filterTile(
                    title: 'Habis',
                    subtitle: 'Stok <= 0',
                    icon: PhosphorIcons.skull(PhosphorIconsStyle.bold),
                    value: 'out',
                    color: Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        inventoryController.setStockFilter(tempStockFilter);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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




  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(PhosphorIcons.package(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
                      const SizedBox(height: 4),
                      Text(product.category, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildDetailRow('Harga Beli', _formatCurrency(product.purchasePrice)),
            _buildDetailRow('Harga Jual', _formatCurrency(product.sellingPrice)),
            _buildDetailRow('Stok', '${product.stock}', showBadge: true, isLowStock: product.isLowStock),
            _buildDetailRow('Min. Stok', '${product.minStock}'),
            _buildDetailRow('Barcode/SKU', product.barcode),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.addProduct, arguments: product);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  shadowColor: const Color(0xFF667eea).withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), size: 18),
                    const SizedBox(width: 10),
                    const Text('Edit Produk', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool showBadge = false, bool isLowStock = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          if (showBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isLowStock ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isLowStock ? Colors.red : Colors.green),
              ),
            )
          else
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1f2937))),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }
}

class _StatData {
  final String title;
  final String value;
  final PhosphorIconData icon;
  final Color color;

  _StatData(this.title, this.value, this.icon, this.color);
}
