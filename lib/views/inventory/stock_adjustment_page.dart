import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/supplier_controller.dart';
import '../../controllers/outlet_controller.dart';
import '../../config/routes.dart';
import '../../models/product_model.dart';
import '../../models/supplier_model.dart';

class StockAdjustmentPage extends StatefulWidget {
  final bool isSupplierReturn;

  const StockAdjustmentPage({super.key, this.isSupplierReturn = false});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();
  String _adjustmentType = 'in';
  bool _isLoading = false;

  final Map<int, _SelectedProduct> _selectedProducts = {};
  Supplier? _selectedSupplier;
  final Set<int> _expandedProducts = {};

  String _generateReferenceCode() {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyyMMdd');
    final timeFormat = DateFormat('HHmmss');
    return 'FK-${dateFormat.format(now)}-${timeFormat.format(now)}';
  }

  @override
  void initState() {
    super.initState();
    _referenceController.text = _generateReferenceCode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierController>().loadSuppliers();
      context.read<OutletController>().loadOutlets();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();
    final supplierController = context.watch<SupplierController>();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isWide = size.width >= 900;

    final hasSelectedProducts = _selectedProducts.isNotEmpty;
    final selectedCount = _selectedProducts.length;
    final totalItems = _selectedProducts.values.fold<int>(0, (sum, p) => sum + p.quantity);

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
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.isSupplierReturn
                    ? PhosphorIcons.arrowUUpLeft(PhosphorIconsStyle.bold)
                    : PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
                size: isMobile ? 16 : 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.isSupplierReturn ? 'Retur ke Supplier' : 'Penyesuaian Stok',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 15 : 17),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!widget.isSupplierReturn)
            Container(
              margin: EdgeInsets.only(right: isMobile ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.supplierReturn),
                icon: Icon(PhosphorIcons.arrowSquareOut(PhosphorIconsStyle.bold), color: Colors.white, size: isMobile ? 14 : 16),
                label: Text('Retur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isMobile ? 11 : 13)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isWide ? _buildWideLayout(controller, supplierController, hasSelectedProducts, selectedCount, totalItems) : _buildMobileLayout(controller, supplierController, isMobile, hasSelectedProducts, selectedCount, totalItems),
      ),
    );
  }

  // Wide layout for tablet/desktop - side by side
  Widget _buildWideLayout(InventoryController controller, SupplierController supplierController, bool hasSelectedProducts, int selectedCount, int totalItems) {
    return Row(
      children: [
        // Left panel - Settings
        Container(
          width: 340,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildSettingsPanel(supplierController, hasSelectedProducts, selectedCount, totalItems),
        ),
        // Right panel - Product list + Submit
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _buildProductList(controller),
              ),
              if (hasSelectedProducts)
                _buildBottomSubmit(hasSelectedProducts, selectedCount),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel(SupplierController supplierController, bool hasSelectedProducts, int selectedCount, int totalItems) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isSupplierReturn) ...[
            _buildSectionTitle('Kode Referensi'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _referenceController.text,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _referenceController.text = _generateReferenceCode();
                      });
                      _showSnackBar('Kode berhasil di-generate', const Color(0xFF10b981));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (widget.isSupplierReturn) ...[
            _buildSectionTitle('Pilih Supplier'),
            const SizedBox(height: 12),
            _buildSupplierDropdown(supplierController.suppliers),
            const SizedBox(height: 20),
          ],

          if (!widget.isSupplierReturn) ...[
            _buildSectionTitle('Tipe Pergerakan Stok'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _adjustmentType = 'in'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _adjustmentType == 'in' ? const Color(0xFF10b981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.arrowDown(PhosphorIconsStyle.bold), color: _adjustmentType == 'in' ? Colors.white : Colors.grey.shade400, size: 18),
                            const SizedBox(width: 8),
                            Text('Stok Masuk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _adjustmentType == 'in' ? Colors.white : Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _adjustmentType = 'out'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _adjustmentType == 'out' ? const Color(0xFFef4444) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold), color: _adjustmentType == 'out' ? Colors.white : Colors.grey.shade400, size: 18),
                            const SizedBox(width: 8),
                            Text('Stok Keluar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _adjustmentType == 'out' ? Colors.white : Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Mobile/compact layout
  Widget _buildMobileLayout(InventoryController controller, SupplierController supplierController, bool isMobile, bool hasSelectedProducts, int selectedCount, int totalItems) {
    return Column(
      children: [
        // Fixed top section
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isSupplierReturn) ...[
                _buildSectionTitle('Kode Referensi'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_referenceController.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _referenceController.text = _generateReferenceCode());
                          _showSnackBar('Kode berhasil di-generate', const Color(0xFF10b981));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (widget.isSupplierReturn) ...[
                _buildSectionTitle('Pilih Supplier'),
                const SizedBox(height: 10),
                _buildSupplierDropdown(supplierController.suppliers),
                const SizedBox(height: 14),
              ],

              if (!widget.isSupplierReturn) ...[
                _buildSectionTitle('Tipe Pergerakan Stok'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _adjustmentType = 'in'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _adjustmentType == 'in' ? const Color(0xFF10b981) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.arrowDown(PhosphorIconsStyle.bold), color: _adjustmentType == 'in' ? Colors.white : Colors.grey.shade400, size: 14),
                                const SizedBox(width: 6),
                                Text('Masuk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _adjustmentType == 'in' ? Colors.white : Colors.grey.shade400)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _adjustmentType = 'out'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _adjustmentType == 'out' ? const Color(0xFFef4444) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold), color: _adjustmentType == 'out' ? Colors.white : Colors.grey.shade400, size: 14),
                                const SizedBox(width: 6),
                                Text('Keluar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _adjustmentType == 'out' ? Colors.white : Colors.grey.shade400)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Selected Products Summary
        if (hasSelectedProducts)
          Container(
            margin: EdgeInsets.all(isMobile ? 12 : 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFF667eea).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$selectedCount produk dipilih', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Total: $totalItems item', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedProducts.clear()),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),

        // Product list
        Expanded(child: _buildProductList(controller)),

        // Bottom Submit
        if (hasSelectedProducts) _buildBottomSubmit(hasSelectedProducts, selectedCount),
      ],
    );
  }

  Widget _buildProductList(InventoryController controller) {
    if (controller.isLoading) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)));
    }
    if (controller.products.isEmpty) {
      return _buildEmptyProductState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.products.length,
      itemBuilder: (context, index) {
        final product = controller.products[index];
        final isSelected = _selectedProducts.containsKey(product.id);
        final isExpanded = _expandedProducts.contains(product.id);
        return _buildProductListItem(product, isSelected, isExpanded);
      },
    );
  }

  Widget _buildBottomSubmit(bool hasSelectedProducts, int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isSupplierReturn)
            _buildSectionTitle('Catatan Retur')
          else
            _buildSectionTitle('Catatan'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.isSupplierReturn ? 'Alasan retur...' : 'Catatan (opsional)...',
              hintStyle: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.w400),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _submitAdjustments(),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isSupplierReturn ? Colors.orange : const Color(0xFF667eea),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.isSupplierReturn ? PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.bold) : PhosphorIcons.check(PhosphorIconsStyle.bold), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.isSupplierReturn ? 'Kirim Retur ($selectedCount produk)' : 'Simpan Semua ($selectedCount produk)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF667eea), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
      ],
    );
  }

  Widget _buildSupplierDropdown(List<Supplier> suppliers) {
    final activeSuppliers = suppliers.where((s) => s.isActive).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonFormField<Supplier?>(
        value: _selectedSupplier,
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(PhosphorIcons.truck(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18),
          ),
          suffixIcon: _selectedSupplier != null
              ? GestureDetector(
                  onTap: () => setState(() => _selectedSupplier = null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 16),
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        hint: Text('Pilih Supplier', style: TextStyle(color: Colors.grey.shade500)),
        items: activeSuppliers.map((supplier) {
          return DropdownMenuItem<Supplier>(value: supplier, child: Text(supplier.name, style: const TextStyle(fontSize: 14)));
        }).toList(),
        onChanged: (value) => setState(() => _selectedSupplier = value),
      ),
    );
  }

  Widget _buildEmptyProductState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFF5F6FA), shape: BoxShape.circle),
            child: Icon(PhosphorIcons.package(PhosphorIconsStyle.bold), size: 44, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text('Belum ada produk', style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildProductListItem(Product product, bool isSelected, bool isExpanded) {
    final isLowStock = product.isLowStock;
    final stockColor = isLowStock ? const Color(0xFFef4444) : const Color(0xFF10b981);
    final stockBg = isLowStock ? Colors.red.shade50 : Colors.green.shade50;
    final selectedData = _selectedProducts[product.id!];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF667eea).withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  if (_expandedProducts.contains(product.id)) {
                    _expandedProducts.remove(product.id!);
                  } else {
                    _expandedProducts.add(product.id!);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleProductSelection(product),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF667eea) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade300, width: 2),
                        ),
                        child: isSelected ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: Colors.white, size: 14) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        isLowStock ? PhosphorIcons.warning(PhosphorIconsStyle.bold) : PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                        color: stockColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20)),
                                child: Text('Stok: ${product.stock}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: stockColor)),
                              ),
                              const SizedBox(width: 8),
                              Text('Min: ${product.minStock}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (selectedData != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF667eea), borderRadius: BorderRadius.circular(20)),
                        child: Text('x${selectedData.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    const SizedBox(width: 8),
                    Icon(isExpanded ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold) : PhosphorIcons.caretDown(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 18),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _buildQuantityInput(product, selectedData),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantityInput(Product product, _SelectedProduct? initialData) {
    final qtyController = TextEditingController(text: initialData?.quantity.toString() ?? '');
    final notesController = TextEditingController(text: initialData?.notes ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isSupplierReturn) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.arrowUUpLeft(PhosphorIconsStyle.bold), color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text('Retur ke Supplier (Stok Keluar)', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text('Jumlah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final current = int.tryParse(qtyController.text) ?? 0;
                  if (current > 0) qtyController.text = (current - 1).toString();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(PhosphorIcons.minus(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final current = int.tryParse(qtyController.text) ?? 0;
                  qtyController.text = (current + 1).toString();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final qty = int.tryParse(qtyController.text);
                  if (qty != null && qty > 0) {
                    setState(() {
                      _selectedProducts[product.id!] = _SelectedProduct(product: product, quantity: qty, notes: notesController.text);
                      _expandedProducts.remove(product.id!);
                    });
                  } else {
                    _showSnackBar('Jumlah harus lebih dari 0', const Color(0xFFef4444));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Pilih', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesController,
            maxLines: 1,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Catatan (opsional)',
              hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleProductSelection(Product product) {
    setState(() {
      if (_selectedProducts.containsKey(product.id)) {
        _selectedProducts.remove(product.id!);
      } else {
        _selectedProducts[product.id!] = _SelectedProduct(product: product, quantity: 1);
        _expandedProducts.add(product.id!);
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submitAdjustments() async {
    if (widget.isSupplierReturn && _selectedSupplier == null) {
      _showSnackBar('Silakan pilih supplier terlebih dahulu', const Color(0xFFef4444));
      return;
    }

    setState(() => _isLoading = true);

    final ctrl = context.read<InventoryController>();
    int successCount = 0;
    int failCount = 0;

    for (var entry in _selectedProducts.entries) {
      final data = entry.value;
      bool result;

      if (widget.isSupplierReturn) {
        result = await ctrl.adjustStock(data.product.id!, -data.quantity, notes: _notesController.text.isNotEmpty ? _notesController.text : data.notes);
      } else if (_adjustmentType == 'in') {
        result = await ctrl.receiveItems(productId: data.product.id!, quantity: data.quantity, notes: _notesController.text.isNotEmpty ? _notesController.text : data.notes);
      } else {
        result = await ctrl.adjustStock(data.product.id!, -data.quantity, notes: _notesController.text.isNotEmpty ? _notesController.text : data.notes);
      }

      if (result) {
        successCount++;
      } else {
        failCount++;
      }
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (failCount == 0) {
        _showSnackBar(
          widget.isSupplierReturn ? 'Retur berhasil dikirim ($successCount produk)' : 'Berhasil menyimpan ($successCount produk)',
          const Color(0xFF10b981),
        );
        Navigator.pop(context);
      } else {
        _showSnackBar('$successCount berhasil, $failCount gagal', const Color(0xFFef4444));
      }
    }
  }
}

class _SelectedProduct {
  final Product product;
  int quantity;
  final String notes;

  _SelectedProduct({required this.product, this.quantity = 1, this.notes = ''});
}
