import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/outlet_controller.dart';
import '../../controllers/supplier_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/report_controller.dart';
import '../../controllers/sales_controller.dart';
import '../../config/routes.dart';
import '../../services/database_service.dart';

import '../../models/product_model.dart';
import '../../models/cart_item_model.dart';
import '../../models/outlet_model.dart';
import '../../models/supplier_model.dart';
import '../../models/sales_model.dart';
import '../../models/payment_detail_model.dart';

class POSPage extends StatefulWidget {
  const POSPage({super.key});

  @override
  State<POSPage> createState() => _POSPageState();
}

class _POSPageState extends State<POSPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final outletController = context.read<OutletController>();
      final supplierController = context.read<SupplierController>();
      final salesController = context.read<SalesController>();
      final posController = context.read<POSController>();
      final authController = context.read<AuthController>();
      final inventoryController = context.read<InventoryController>();

      outletController.loadOutlets().then((_) {
        // Set outlet di POS controller setelah outlets loaded
        if (outletController.selectedOutlet != null) {
          posController.setOutlet(outletController.selectedOutlet);
        }
        // Set user name untuk logging
        posController
            .setCurrentUser(authController.currentUser?.name ?? 'User');
      });
      supplierController.loadSuppliers();
      salesController.loadSales();
      // Load initial products
      inventoryController.loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryController = context.watch<InventoryController>();
    final posController = context.watch<POSController>();
    final outletController = context.watch<OutletController>();
    final supplierController = context.watch<SupplierController>();
    final salesController = context.watch<SalesController>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.width > 600;
    final isWide = size.width > 900;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(PhosphorIcons.cashRegister(PhosphorIconsStyle.bold), size: isTablet ? 24 : 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                posController.isPurchaseMode ? 'Pembelian' : 'Point of Sale',
                style: TextStyle(fontSize: isTablet ? 20 : 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Penjualan/Pembelian Toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleButton(
                    context,
                    'POS',
                    PhosphorIcons.tag(PhosphorIconsStyle.bold),
                    posController.isPurchaseMode == false,
                    () {
                      posController.setPurchaseMode(false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(children: [
                            Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            const Text('Mode Penjualan - Untuk menjual ke pelanggan'),
                          ]),
                          backgroundColor: const Color(0xFF667eea),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                  _buildToggleButton(
                    context,
                    'Beli',
                    PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold),
                    posController.isPurchaseMode == true,
                    () {
                      posController.setPurchaseMode(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(children: [
                            Icon(PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            const Text('Mode Pembelian - Untuk stok ulang barang dari supplier'),
                          ]),
                          backgroundColor: const Color(0xFF10b981),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Outlet Selector Button (for Sales/POS mode) - Opens Modal with Search
          if (!posController.isPurchaseMode && outletController.activeOutlets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showOutletSupplierModal(context, isPurchaseMode: false, showTab: 'outlet'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          posController.selectedOutlet?.name ?? 'Pilih Outlet',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.bold), color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          // Supplier Selector Button (for Purchase mode) - Opens Modal with Search
          if (posController.isPurchaseMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showOutletSupplierModal(context, isPurchaseMode: true, showTab: 'supplier'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.truck(PhosphorIconsStyle.bold), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          posController.selectedSupplier?.name ?? 'Pilih Supplier',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.bold), color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          // Sales Selector Button - Opens Modal with Search (shown in both POS and Buy modes)
          if (salesController.activeSales.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showSalesModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.bold), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          posController.selectedSales?.name ?? 'Pilih Sales',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.bold), color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
          child: _buildResponsiveLayout(context, inventoryController,
              posController, isLandscape, isTablet, isWide)),
    );
  }

  // Responsive Layout - unified method
  Widget _buildResponsiveLayout(
      BuildContext context,
      InventoryController inventoryController,
      POSController posController,
      bool isLandscape,
      bool isTablet,
      bool isWide) {
    // Landscape or Large Tablet: Side by side layout
    if (isLandscape || (isTablet && !isLandscape)) {
      return _buildSplitLayout(
          context, inventoryController, posController, isWide);
    }
    // Phone portrait: Grid with floating cart button
    return _buildCompactLayout(context, inventoryController, posController);
  }

  // Split Layout for Tablet/Landscape
  Widget _buildSplitLayout(
      BuildContext context,
      InventoryController inventoryController,
      POSController posController,
      bool isWide) {
    final crossAxisCount = isWide ? 4 : 3;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: inventoryController.searchProductsDebounced,
          ),
        ),
        // Product Grid & Cart - Side by Side
        Expanded(
          child: Row(
            children: [
              // Product Grid (Left)
              Expanded(
                flex: isWide ? 3 : 2,
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: inventoryController.products.length,
                        itemBuilder: (context, index) {
                          final product = inventoryController.products[index];
                          return _buildProductCard(context, posController, product);
                        },
                      ),
                    ),
                    _buildPaginationControls(inventoryController),
                  ],
                ),
              ),
              // Cart (Right)
              Expanded(
                flex: isWide ? 2 : 3,
              child: _buildCartPanel(context, posController),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Compact Layout for Phone Portrait
  Widget _buildCompactLayout(BuildContext context,
      InventoryController inventoryController, POSController posController) {
    return Stack(
      children: [
        Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                onChanged: inventoryController.searchProductsDebounced,
              ),
            ),
            // Product Grid
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: inventoryController.products.length,
                      itemBuilder: (context, index) {
                        final product = inventoryController.products[index];
                        return _buildProductCardCompact(
                            context, posController, product);
                      },
                    ),
                  ),
                  _buildPaginationControls(inventoryController),
                ],
              ),
            ),
          ],
        ),
        // Floating Cart Button
        if (posController.cart.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _showCartBottomSheet(context, posController),
              icon: Icon(PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold)),
              label: Text('Keranjang (${posController.itemCount})'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(
      BuildContext context, POSController posController, Product product) {
    // Stock status
    final stockColor = product.stock == 0
        ? const Color(0xFFef4444)
        : product.stock < 10
            ? const Color(0xFFf59e0b)
            : const Color(0xFF10b981);
    final stockIcon = product.stock == 0
        ? PhosphorIcons.xCircle(PhosphorIconsStyle.bold)
        : product.stock < 10
            ? PhosphorIcons.warning(PhosphorIconsStyle.bold)
            : PhosphorIcons.checkCircle(PhosphorIconsStyle.bold);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (posController.isPurchaseMode || product.stock > 0) {
              posController.addToCart(product, quantity: 1);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Text('Stok tidak mencukupi'),
                  ]),
                  backgroundColor: const Color(0xFFef4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stock status icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    stockIcon,
                    size: 18,
                    color: stockColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1f2937),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  NumberFormat.currency(
                    locale: 'id',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(
                    posController.isPurchaseMode ? product.purchasePrice : product.sellingPrice,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF10b981),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stok: ${product.stock}',
                  style: TextStyle(
                    color: stockColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Compact Product Card for Phone
  Widget _buildProductCardCompact(
      BuildContext context, POSController posController, Product product) {
    // Stock status
    final stockColor = product.stock == 0
        ? const Color(0xFFef4444)
        : product.stock < 10
            ? const Color(0xFFf59e0b)
            : const Color(0xFF10b981);
    final stockIcon = product.stock == 0
        ? PhosphorIcons.xCircle(PhosphorIconsStyle.bold)
        : product.stock < 10
            ? PhosphorIcons.warning(PhosphorIconsStyle.bold)
            : PhosphorIcons.checkCircle(PhosphorIconsStyle.bold);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (posController.isPurchaseMode || product.stock > 0) {
              posController.addToCart(product, quantity: 1);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Text('Stok tidak mencukupi'),
                  ]),
                  backgroundColor: const Color(0xFFef4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stock status icon
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    stockIcon,
                    size: 14,
                    color: stockColor,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: Text(
                      product.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Color(0xFF1f2937),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(
                    locale: 'id',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(product.sellingPrice),
                  style: const TextStyle(
                    color: Color(0xFF10b981),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Stok: ${product.stock}',
                  style: TextStyle(
                    color: stockColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cart Panel for Landscape/Tablet
  Widget _buildCartPanel(BuildContext context, POSController posController) {
    final authController = context.watch<AuthController>();
    final isAdmin = authController.currentUser?.role == 'admin';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withValues(alpha: 0.1),
                  const Color(0xFF764ba2).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold),
                    size: 18,
                    color: const Color(0xFF667eea),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Keranjang',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1f2937),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${posController.itemCount} item',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cart Items
          Expanded(
            child: posController.cart.isEmpty
                ? _buildEmptyCartState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: posController.cart.length,
                    itemBuilder: (context, index) {
                      final item = posController.cart[index];
                      return _buildCartItemCard(context, posController, index, item, isAdmin);
                    },
                  ),
          ),
          // Cart Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Discount Row (Format A: Diskon % + nominal)
                if (posController.discountAmount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10b981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.tag(PhosphorIconsStyle.bold),
                              size: 14,
                              color: const Color(0xFF10b981),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Diskon',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF10b981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => posController.clearDiscount(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10b981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                                  size: 10,
                                  color: const Color(0xFF10b981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Diskon ${posController.discount.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10b981),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '- ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(posController.discountAmount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10b981),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _showDiscountDialog(context, posController),
                      icon: Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold), size: 14, color: const Color(0xFF667eea)),
                      label: const Text('Tambah Diskon', style: TextStyle(fontSize: 12, color: Color(0xFF667eea))),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
                    Text(
                      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                          .format(posController.total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF10b981)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: posController.cart.isEmpty
                        ? null
                        : () => _showPaymentMethodDialog(context, posController),
                    icon: Icon(PhosphorIcons.money(PhosphorIconsStyle.bold), size: 18),
                    label: const Text('BAYAR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.shoppingCart(PhosphorIconsStyle.light),
              size: 40,
              color: const Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Keranjang kosong',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6b7280)),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih produk untuk ditambahkan',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, POSController posController, int index, CartItem item, bool isAdmin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAdmin
              ? () => _showEditPriceDialog(context, posController, index, item)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (item.isPriceModified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf59e0b).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Edit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFf59e0b))),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.effectivePrice)} x ${item.quantity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: item.isPriceModified ? const Color(0xFFf59e0b) : Colors.grey.shade600,
                    fontWeight: item.isPriceModified ? FontWeight.w500 : FontWeight.normal,
                    decoration: item.isPriceModified ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.isPriceModified) ...[
                  const SizedBox(height: 2),
                  Text(
                    NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.effectivePrice),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFf59e0b)),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.effectivePrice * item.quantity),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                    ),
                    Row(
                      children: [
                        _buildQtyButton(
                          icon: PhosphorIcons.minusCircle(PhosphorIconsStyle.bold),
                          onPressed: item.quantity > 1
                              ? () => posController.updateQuantity(index, item.quantity - 1)
                              : null,
                          color: const Color(0xFF667eea),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('${item.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        _buildQtyButton(
                          icon: PhosphorIcons.plusCircle(PhosphorIconsStyle.bold),
                          onPressed: () => posController.updateQuantity(index, item.quantity + 1),
                          color: const Color(0xFF667eea),
                        ),
                        const SizedBox(width: 8),
                        _buildQtyButton(
                          icon: PhosphorIcons.trash(PhosphorIconsStyle.bold),
                          onPressed: () => posController.removeFromCart(index),
                          color: const Color(0xFFef4444),
                        ),
                      ],
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

  Widget _buildQtyButton({required IconData icon, required VoidCallback? onPressed, required Color color}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: onPressed != null ? color : Colors.grey.shade400),
      ),
    );
  }

  void _showQuantityDialog(
      BuildContext context, POSController posController, Product product) {
    final quantityController = TextEditingController(text: '0');
    int quantity = 0;
    final isPurchaseMode = posController.isPurchaseMode;
    final canAdd = isPurchaseMode || product.stock > 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product name header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1f2937),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                // Stock info
                if (!isPurchaseMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: product.stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          product.stock > 0 ? PhosphorIcons.checkCircle(PhosphorIconsStyle.bold) : PhosphorIcons.warning(PhosphorIconsStyle.bold),
                          size: 14,
                          color: product.stock > 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Stok: ${product.stock}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // Harga Satuan - labeled clearly so user knows it's fixed
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold), size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Harga Satuan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'id',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(
                          posController.isPurchaseMode ? product.purchasePrice : product.sellingPrice,
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1f2937),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Label Jumlah Barang
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Jumlah Barang',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // TextField for quantity
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1f2937)),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey.shade300),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF667eea), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
                    ),
                    suffixText: 'pcs',
                    suffixStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed >= 0) {
                      setDialogState(() => quantity = parsed);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Quick quantity buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [1, 5, 10, 25, 50].map((qty) {
                    return GestureDetector(
                      onTap: () {
                        final newQty = quantity + qty;
                        quantityController.text = newQty.toString();
                        setDialogState(() => quantity = newQty);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '+$qty',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF667eea),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Total Harga - clearly labeled as total price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10b981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Total Harga',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(
                          (posController.isPurchaseMode ? product.purchasePrice : product.sellingPrice) * quantity,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!canAdd || quantity <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    Text(isPurchaseMode ? 'Jumlah harus lebih dari 0' : 'Stok tidak mencukupi'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFef4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          posController.addToCart(product, quantity: quantity);
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('TAMBAH', style: TextStyle(fontWeight: FontWeight.w700)),
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
  }

  // Dialog untuk tambah diskon
  void _showDiscountDialog(BuildContext context, POSController posController) {
    final percentageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.percent(PhosphorIconsStyle.bold),
                  size: 28,
                  color: const Color(0xFF667eea),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tambah Diskon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1f2937),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: percentageController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Diskon',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixText: '%',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5, 10, 15, 20, 25, 50]
                    .map((pct) => Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => percentageController.text = pct.toString(),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Text(
                                  '$pct%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF667eea),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final pct = double.tryParse(percentageController.text);
                        if (pct != null && pct > 0 && pct <= 100) {
                          posController.applyDiscount(pct);
                          Navigator.pop(dialogContext);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('SIMPAN', style: TextStyle(fontWeight: FontWeight.w700)),
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

  // Dialog untuk pilih metode pembayaran
  void _showPaymentMethodDialog(
      BuildContext context, POSController posController) {
    // Use total directly - posController.total already includes discount
    final total = posController.total;
    PaymentType selectedType = posController.paymentMode == 'TEMPO'
        ? PaymentType.tempo
        : PaymentType.cash;
    double amount = total;
    int tempoDays = 7;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF667eea).withValues(alpha: 0.15),
                          const Color(0xFF764ba2).withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.money(PhosphorIconsStyle.bold),
                      size: 28,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    posController.paymentMode == 'TEMPO'
                        ? 'Pembayaran Tempo'
                        : 'Pilih Metode Pembayaran',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1f2937),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Payment type buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PaymentType.values.map((type) {
                      final isSelected = selectedType == type;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedType = type;
                            if (selectedType == PaymentType.cash) {
                              amount = total;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF667eea)
                                : const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type == PaymentType.cash
                                    ? PhosphorIcons.money(PhosphorIconsStyle.bold)
                                    : type == PaymentType.qris
                                        ? PhosphorIcons.qrCode(PhosphorIconsStyle.bold)
                                        : type == PaymentType.transfer
                                            ? PhosphorIcons.bank(PhosphorIconsStyle.bold)
                                            : PhosphorIcons.clock(PhosphorIconsStyle.bold),
                                size: 16,
                                color: isSelected ? Colors.white : const Color(0xFF667eea),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                type.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF667eea),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Total amount
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF667eea).withValues(alpha: 0.08),
                          const Color(0xFF764ba2).withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6b7280))),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(total),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF667eea)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // For cash payment
                  if (selectedType == PaymentType.cash)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Uang Diterima',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixText: 'Rp ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (value) {
                            amount = double.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [total, 20000.0, 50000.0, 100000.0].map((nominal) {
                            return ActionChip(
                              label: Text(nominal == total ? 'Uang Pas' : 'Rp ${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(nominal)}'),
                              backgroundColor: const Color(0xFF667eea).withValues(alpha: 0.1),
                              labelStyle: const TextStyle(color: Color(0xFF667eea), fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                              onPressed: () {
                                amount = nominal;
                                setDialogState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  // For transfer/qris
                  if (selectedType == PaymentType.transfer || selectedType == PaymentType.qris)
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'No. Referensi (Opsional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  // For tempo
                  if (selectedType == PaymentType.tempo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf59e0b).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.clock(PhosphorIconsStyle.bold), size: 16, color: const Color(0xFFf59e0b)),
                              const SizedBox(width: 6),
                              const Text('Pembayaran Tempo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFf59e0b))),
                            ],
                          ),
                          const SizedBox(height: 10),
          Wrap(
                            spacing: 8,
                            children: [7, 14, 30, 60].map((days) {
                              final isSelected = tempoDays == days;
                              return GestureDetector(
                                onTap: () => setDialogState(() => tempoDays = days),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFf59e0b) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFf59e0b)),
                                  ),
                                  child: Text(
                                    '$days hari',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFFf59e0b),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Change display
                  if (selectedType == PaymentType.cash && amount >= total)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10b981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIcons.currencyCircleDollar(PhosphorIconsStyle.bold), size: 16, color: const Color(0xFF10b981)),
                          const SizedBox(width: 8),
                          Text(
                            'Kembalian: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount - total)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF10b981)),
                          ),
                        ],
                      ),
                    ),
                  // Tempo due date
                  if (selectedType == PaymentType.tempo)
                    Text(
                      'Jatuh tempo: ${DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: tempoDays)))}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFf59e0b)),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Validation for cash payment
                            if (selectedType == PaymentType.cash) {
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                        const SizedBox(width: 10),
                                        const Text('Uang diterima harus diisi'),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFFef4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                                return;
                              }
                              if (amount < total) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                        const SizedBox(width: 10),
                                        const Text('Uang diterima tidak boleh kurang dari total'),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFFef4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                                return;
                              }
                            }

                            if (selectedType == PaymentType.tempo) {
                              posController.setPaymentMode('TEMPO');
                              posController.setDueDate(DateTime.now().add(Duration(days: tempoDays)));
                            } else {
                              posController.setPaymentMode('LUNAS');
                              posController.setDueDate(null);
                            }

                            posController.setPaymentMethod(selectedType.code);
                            posController.clearPayments();
                            posController.addPayment(selectedType, total);

                            final invoice = await posController.processTransaction();

                            if (invoice != 'Error' && !invoice.startsWith('Error')) {
                              Navigator.pop(dialogContext);
                              final messenger = ScaffoldMessenger.of(context);
                              await context.read<InventoryController>().loadProducts(refresh: true);

                              // Get transaction ID from database
                              final db = await DatabaseService.database;
                              final txResult = await db.query(
                                'transactions',
                                where: 'invoiceNumber = ?',
                                whereArgs: [invoice],
                              );

                              final reportController = context.read<ReportController>();
                              final now = DateTime.now();
                              reportController.setDateRange(
                                DateTime(now.year, now.month, now.day),
                                now,
                              );

                              final status = selectedType == PaymentType.tempo ? 'Tempo' : 'Lunas';
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(children: [
                                    Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    Text('Transaksi berhasil ($status)'),
                                  ]),
                                  backgroundColor: const Color(0xFF10b981),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );

                              if (txResult.isNotEmpty) {
                                final txId = txResult.first['id'] as int;
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.invoiceDetail,
                                  arguments: txId,
                                );
                              }
                            } else {
                              // Strip 'Error: ' prefix for cleaner user-facing message
                              final errorMsg = invoice.startsWith('Error: ')
                                  ? invoice.substring(7)
                                  : invoice.replaceFirst('Error', '').trim();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(children: [
                                    Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(errorMsg, style: const TextStyle(fontWeight: FontWeight.w500))),
                                  ]),
                                  backgroundColor: const Color(0xFFef4444),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                  margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          child: const Text('PROSES PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.w700)),
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

  // Dialog untuk edit harga item (hanya untuk admin)
  void _showEditPriceDialog(BuildContext context, POSController posController,
      int index, CartItem item) {
    final priceController =
        TextEditingController(text: item.customPrice.toStringAsFixed(0));

    // Discount per item: input nominal (Rp) -> tampilkan % (otomatis) + nominal
    final discountNominalController = TextEditingController(
      text: item.itemDiscountAmount > 0
          ? item.itemDiscountAmount.toStringAsFixed(0)
          : '',
    );

    // Harga modal baru (hanya dipakai di mode beli)
    final purchasePriceController = TextEditingController(
      text: item.product.purchasePrice.toStringAsFixed(0),
    );

    final qtyController = TextEditingController(text: item.quantity.toString());

    final authController = context.read<AuthController>();

    if (authController.currentUser?.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.lock(PhosphorIconsStyle.bold),
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Text('Hanya admin yang dapat mengedit harga'),
          ]),
          backgroundColor: const Color(0xFFf59e0b),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 620, left: 16, right: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
        final basePrice = item.fromPurchaseMode
          ? item.product.purchasePrice
          : item.product.sellingPrice;

        final qty = int.tryParse(qtyController.text) ?? item.quantity;
        final maxQty = item.product.stock;
        final discountNominalParsed =
          double.tryParse(discountNominalController.text) ?? 0.0;
        final maxDiscount = (basePrice * qty);
        final safeDiscountNominal =
          discountNominalParsed.clamp(0, maxDiscount);

        // % = diskon nominal / (basePrice * qty)
        final discountPercent = (maxDiscount > 0 && safeDiscountNominal > 0)
          ? (safeDiscountNominal / maxDiscount) * 100
          : 0.0;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold),
                      size: 28,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Edit Harga & Diskon',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1f2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.product.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Original price
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold),
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text(
                          posController.isPurchaseMode
                              ? 'Harga supplier: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.product.purchasePrice)}'
                              : 'Harga asli: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.product.sellingPrice)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6b7280)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harga Satuan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: posController.isPurchaseMode
                                ? 'Harga Jual Baru'
                                : 'Harga Baru',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixText: 'Rp ',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jumlah',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Jumlah (Qty)',
                            helperText: posController.isPurchaseMode
                                ? null
                                : 'Maksimum: $maxQty',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Discount per product inputs
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10b981).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold),
                                size: 14, color: const Color(0xFF10b981)),
                            const SizedBox(width: 8),
                            const Text(
                              'Diskon per product',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10b981)),
                            ),
                            const Spacer(),
                            Text(
                              '- ${safeDiscountNominal > 0 ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(safeDiscountNominal) : 'Rp 0'}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10b981)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: discountNominalController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Diskon nominal',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixText: 'Rp ',
                            suffixText: '% ${discountPercent.toStringAsFixed(1)}',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onChanged: (_) {
                            // clamp for display; keep raw controller string
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Maks: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(maxDiscount)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Field harga modal baru (hanya mode beli)
                  if (posController.isPurchaseMode) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf59e0b).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.bold),
                                  size: 14, color: const Color(0xFFf59e0b)),
                              const SizedBox(width: 8),
                              const Text(
                                'Update Harga Modal',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFf59e0b)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Harga modal saat ini: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.product.purchasePrice)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: purchasePriceController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Harga Modal Baru',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixText: 'Rp ',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quick price buttons (harga saja)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickPriceButton('Bulatkan', () {
                        final base = posController.isPurchaseMode
                            ? item.product.purchasePrice
                            : item.product.sellingPrice;
                        final rounded = (base / 100).round() * 100;
                        priceController.text = rounded.toString();
                      }),
                      _quickPriceButton('-5000', () {
                        final base = posController.isPurchaseMode
                            ? item.product.purchasePrice
                            : item.product.sellingPrice;
                        final current =
                            double.tryParse(priceController.text) ?? base;
                        priceController.text = (current - 5000).toString();
                      }),
                      _quickPriceButton('+5000', () {
                        final base = posController.isPurchaseMode
                            ? item.product.purchasePrice
                            : item.product.sellingPrice;
                        final current =
                            double.tryParse(priceController.text) ?? base;
                        priceController.text = (current + 5000).toString();
                      }),
                      _quickPriceButton('Reset', () {
                        final base = posController.isPurchaseMode
                            ? item.product.purchasePrice
                            : item.product.sellingPrice;
                        priceController.text = base.toStringAsFixed(0);
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('BATAL',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newPrice =
                              double.tryParse(priceController.text);
                            if (newPrice == null || newPrice <= 0) return;

                            final finalDiscountNominal =
                              safeDiscountNominal;

                            // apply changes into cart
                            posController.updateItemPrice(index, newPrice);

                            // store item discount nominal (amount)
                            posController.updateItemDiscountAmount(
                              index, finalDiscountNominal.toDouble());

                            // Update quantity
                            final parsedQty = int.tryParse(qtyController.text) ?? item.quantity;
                            final maxQty = item.product.stock;
                            final newQty = posController.isPurchaseMode
                                ? parsedQty
                                : parsedQty > maxQty
                                    ? maxQty
                                    : parsedQty;
                            if (newQty > 0) {
                              posController.updateQuantity(index, newQty);
                            }

                            // Jika mode beli: update harga jual & harga modal di database
                            if (posController.isPurchaseMode) {
                              final newPurchasePrice =
                                  double.tryParse(purchasePriceController.text);
                              final pid = item.product.id;
                              if (pid != null && newPurchasePrice != null && newPurchasePrice > 0) {
                                final inventoryController =
                                    context.read<InventoryController>();
                                final updatedProduct = item.product.copyWith(
                                  sellingPrice: newPrice,
                                  purchasePrice: newPurchasePrice,
                                  updatedAt: DateTime.now(),
                                );
                                final ok = await inventoryController.updateProduct(updatedProduct);
                                if (ok) {
                                  posController.syncCartItemProduct(index, updatedProduct);
                                }
                              }
                            } else {
                              // price history (harga jual)
                              final pid = item.product.id;
                              if (pid != null) {
                                posController.logPriceChange(
                                  productId: pid,
                                  productName: item.product.name,
                                  oldPrice: item.product.sellingPrice,
                                  newPrice: newPrice,
                                );
                              }
                            }
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('SIMPAN',
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
        },
      ),
    );
  }

  Widget _quickPriceButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF667eea),
          ),
        ),
      ),
    );
  }

  // Bottom sheet untuk menampilkan cart di mode portrait
  void _showCartBottomSheet(BuildContext context, POSController posController) {
    final authController = context.read<AuthController>();
    final isAdmin = authController.currentUser?.role == 'admin';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withValues(alpha: 0.08),
                      const Color(0xFF764ba2).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold),
                        size: 20,
                        color: const Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Keranjang (${posController.itemCount})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1f2937),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${posController.itemCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(bottomSheetContext),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PhosphorIcons.x(PhosphorIconsStyle.bold),
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cart Items
              Expanded(
                child: posController.cart.isEmpty
                    ? _buildEmptyCartState()
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: posController.cart.length,
                        itemBuilder: (_, index) {
                          final item = posController.cart[index];
                          return _buildCartItemCard(_, posController, index, item, isAdmin);
                        },
                      ),
              ),
              // Summary
              if (posController.cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                          ),
                          Text(
                            NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(posController.total),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF10b981)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(bottomSheetContext);
                            _showPaymentMethodDialog(context, posController);
                          },
                          icon: Icon(PhosphorIcons.money(PhosphorIconsStyle.bold), size: 20),
                          label: const Text('BAYAR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for building toggle buttons
  Widget _buildToggleButton(
    BuildContext context,
    String label,
    PhosphorIconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF667eea) : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF667eea) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modal for selecting Sales
  void _showSalesModal(BuildContext context) {
    final salesController = context.read<SalesController>();
    final posController = context.read<POSController>();
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withValues(alpha: 0.1),
                      const Color(0xFF764ba2).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PhosphorIcons.user(PhosphorIconsStyle.bold),
                        size: 20,
                        color: const Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pilih Sales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1f2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pilih sales untuk penjualan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(modalContext),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 16, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari sales...',
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) {
                    // Filter will be handled by rebuild
                  },
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: salesController.activeSales.length,
                  itemBuilder: (context, index) {
                    final sales = salesController.activeSales[index];
                    return _buildSalesListTile(sales, posController, modalContext);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesListTile(Sales sales, POSController posController, BuildContext modalContext) {
    final isSelected = posController.selectedSales?.id == sales.id;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF667eea).withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            posController.setSales(sales);
            Navigator.pop(modalContext);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF667eea) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.user(PhosphorIconsStyle.bold),
                    color: isSelected ? Colors.white : Colors.blue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sales.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF667eea) : const Color(0xFF1f2937),
                        ),
                      ),
                      if (sales.phone.isNotEmpty)
                        Text(
                          sales.phone,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modal for selecting Outlet or Supplier with search filter
  void _showOutletSupplierModal(BuildContext context, {required bool isPurchaseMode, String showTab = 'outlet'}) {
    final outletController = context.read<OutletController>();
    final supplierController = context.read<SupplierController>();
    final salesController = context.read<SalesController>();
    final posController = context.read<POSController>();
    final searchController = TextEditingController();
    String activeTab = showTab;

    // Determine header based on mode and tab
    String getHeaderTitle() {
      if (isPurchaseMode) return 'Pilih Supplier';
      if (activeTab == 'sales') return 'Pilih Sales';
      return 'Pilih Outlet';
    }

    IconData getHeaderIcon() {
      if (isPurchaseMode) return PhosphorIcons.truck(PhosphorIconsStyle.bold);
      if (activeTab == 'sales') return PhosphorIcons.usersThree(PhosphorIconsStyle.bold);
      return PhosphorIcons.storefront(PhosphorIconsStyle.bold);
    }

    Color getHeaderColor() {
      if (isPurchaseMode) return const Color(0xFF10b981);
      if (activeTab == 'sales') return const Color(0xFFf59e0b);
      return const Color(0xFF667eea);
    }

    Color getHeaderBgColor() {
      if (isPurchaseMode) return const Color(0xFF10b981).withValues(alpha: 0.1);
      if (activeTab == 'sales') return const Color(0xFFf59e0b).withValues(alpha: 0.1);
      return const Color(0xFF667eea).withValues(alpha: 0.1);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      getHeaderBgColor(),
                      const Color(0xFF764ba2).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: getHeaderColor().withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            getHeaderIcon(),
                            size: 20,
                            color: getHeaderColor(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getHeaderTitle(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1f2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPurchaseMode
                                    ? 'Pilih supplier untuk pembelian barang'
                                    : (activeTab == 'sales'
                                        ? 'Pilih sales untuk penjualan'
                                        : 'Pilih outlet untuk penjualan'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(modalContext),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              PhosphorIcons.x(PhosphorIconsStyle.bold),
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Tab buttons for non-purchase mode
                    if (!isPurchaseMode) ...[
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (context, setTabState) => Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                'Outlet',
                                PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                                const Color(0xFF667eea),
                                activeTab == 'outlet',
                                () => setTabState(() => activeTab = 'outlet'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTabButton(
                                'Sales',
                                PhosphorIcons.usersThree(PhosphorIconsStyle.bold),
                                const Color(0xFFf59e0b),
                                activeTab == 'sales',
                                () => setTabState(() => activeTab = 'sales'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // List with Search
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setListState) {
                    final searchQuery = searchController.text.toLowerCase();

                    return Column(
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: isPurchaseMode
                                  ? 'Cari supplier...'
                                  : (activeTab == 'sales' ? 'Cari sales...' : 'Cari outlet...'),
                              prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (value) {
                              setListState(() {});
                            },
                          ),
                        ),
                        // List
                        Expanded(
                          child: isPurchaseMode
                              ? _buildSupplierList(searchQuery, supplierController, posController, setListState)
                              : (activeTab == 'sales'
                                  ? _buildSalesList(searchQuery, salesController, posController, setListState)
                                  : _buildOutletList(searchQuery, outletController, posController, setListState)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build supplier list for modal
  Widget _buildSupplierList(String searchQuery, SupplierController supplierController, POSController posController, StateSetter setListState) {
    final suppliers = supplierController.suppliers.where((s) {
      return s.name.toLowerCase().contains(searchQuery) ||
          (s.phone?.toLowerCase().contains(searchQuery) ?? false) ||
          (s.address?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();

    if (suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.truck(PhosphorIconsStyle.light), size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Supplier tidak ditemukan',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        final isSelected = posController.selectedSupplier?.id == supplier.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF10b981).withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF10b981)
                  : Colors.grey.shade200,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                posController.setSupplier(supplier);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('Supplier ${supplier.name} dipilih'),
                    ]),
                    backgroundColor: const Color(0xFF10b981),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 620, left: 16, right: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10b981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        PhosphorIcons.truck(PhosphorIconsStyle.bold),
                        size: 18,
                        color: const Color(0xFF10b981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1f2937),
                            ),
                          ),
                          if (supplier.phone.isNotEmpty)
                            Text(
                              supplier.phone,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                        size: 20,
                        color: const Color(0xFF10b981),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build outlet list for modal
  Widget _buildOutletList(String searchQuery, OutletController outletController, POSController posController, StateSetter setListState) {
    final outlets = outletController.activeOutlets.where((o) {
      return o.name.toLowerCase().contains(searchQuery) ||
          (o.address?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();

    if (outlets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.storefront(PhosphorIconsStyle.light), size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Outlet tidak ditemukan',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: outlets.length,
      itemBuilder: (context, index) {
        final outlet = outlets[index];
        final isSelected = posController.selectedOutlet?.id == outlet.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF667eea).withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF667eea)
                  : Colors.grey.shade200,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                posController.setOutlet(outlet);
                outletController.selectOutlet(outlet);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('Outlet ${outlet.name} dipilih'),
                    ]),
                    backgroundColor: const Color(0xFF667eea),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 620, left: 16, right: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                        size: 18,
                        color: const Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outlet.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1f2937),
                            ),
                          ),
                          if (outlet.address.isNotEmpty)
                            Text(
                              outlet.address,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                        size: 20,
                        color: const Color(0xFF667eea),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build sales list for modal
  Widget _buildSalesList(String searchQuery, SalesController salesController, POSController posController, StateSetter setListState) {
    final salesList = salesController.activeSales.where((s) {
      return s.name.toLowerCase().contains(searchQuery) ||
          (s.phone?.toLowerCase().contains(searchQuery) ?? false) ||
          (s.address?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();

    if (salesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.light), size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Sales tidak ditemukan',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: salesList.length,
      itemBuilder: (context, index) {
        final sales = salesList[index];
        final isSelected = posController.selectedSales?.id == sales.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFf59e0b).withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFf59e0b)
                  : Colors.grey.shade200,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                posController.setSales(sales);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('Sales ${sales.name} dipilih'),
                    ]),
                    backgroundColor: const Color(0xFFf59e0b),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 620, left: 16, right: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf59e0b).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        PhosphorIcons.usersThree(PhosphorIconsStyle.bold),
                        size: 18,
                        color: const Color(0xFFf59e0b),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sales.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1f2937),
                            ),
                          ),
                          if (sales.phone.isNotEmpty)
                            Text(
                              sales.phone,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                        size: 20,
                        color: const Color(0xFFf59e0b),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls(InventoryController inventoryController) {
    final currentPage = inventoryController.currentPage;
    final totalPages = inventoryController.totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                ? () => inventoryController.goToPage(currentPage - 1)
                : null,
            icon: Icon(
              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: currentPage > 1 ? const Color(0xFF667eea) : Colors.grey.shade300,
            ),
          ),
          Text(
            'Halaman $currentPage dari $totalPages',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF667eea),
            ),
          ),
          IconButton(
            onPressed: currentPage < totalPages
                ? () => inventoryController.goToPage(currentPage + 1)
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
}
