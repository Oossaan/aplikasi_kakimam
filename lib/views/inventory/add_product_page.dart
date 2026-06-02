import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/supplier_model.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/supplier_controller.dart';

class AddProductPage extends StatefulWidget {
  final Product? product;

  const AddProductPage({super.key, this.product});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  String _selectedCategoryText = 'Umum';
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  bool _isLoading = false;

  // Draft list untuk menyimpan beberapa produk sebelum disimpan
  final List<Product> _draftProducts = [];

  @override
  void initState() {
    super.initState();
    _minStockController.text = '10';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryController>().loadCategories();
      context.read<SupplierController>().loadSuppliers();
    });

    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _barcodeController.text = widget.product!.barcode;
      _purchasePriceController.text = widget.product!.purchasePrice.toString();
      _sellingPriceController.text = widget.product!.sellingPrice.toString();
      _stockController.text = widget.product!.stock.toString();
      _minStockController.text = widget.product!.minStock.toString();
      _selectedCategoryText = widget.product!.category;
      _selectedCategoryId = widget.product!.categoryId;
      _selectedSupplierId = widget.product!.supplierId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryController = context.watch<CategoryController>();
    final supplierController = context.watch<SupplierController>();
    final isEditing = widget.product != null;
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
              child: Icon(
                isEditing
                    ? PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold)
                    : PhosphorIcons.plus(PhosphorIconsStyle.bold),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isEditing ? 'Edit Produk' : 'Tambah Produk',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name Card
                _buildInputCard(
                  children: [
                    _buildInputField(
                      controller: _nameController,
                      label: 'Nama Produk',
                      hint: 'Masukkan nama produk',
                      icon: PhosphorIcons.tag(PhosphorIconsStyle.bold),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama produk harus diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _barcodeController,
                      label: 'Barcode/SKU',
                      hint: 'Masukkan barcode atau SKU',
                      icon: PhosphorIcons.barcode(PhosphorIconsStyle.bold),
                      suffixIcon: IconButton(
                        icon: Icon(
                          PhosphorIcons.magicWand(PhosphorIconsStyle.bold),
                          color: const Color(0xFF667eea),
                        ),
                        onPressed: () {
                          setState(() {
                            _barcodeController.text = 'SKU${DateTime.now().millisecondsSinceEpoch}';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('SKU auto-generated'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10b981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category & Supplier Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCategoryDropdown(categoryController.categories)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSupplierDropdown(supplierController.suppliers)),
                  ],
                ),
                const SizedBox(height: 24),

                // Prices Section
                _buildSectionHeader(PhosphorIcons.currencyDollar(PhosphorIconsStyle.bold), 'Informasi Harga'),
                const SizedBox(height: 12),
                _buildInputCard(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _purchasePriceController,
                            label: 'Harga Beli',
                            hint: '0',
                            icon: PhosphorIcons.arrowDown(PhosphorIconsStyle.bold),
                            isPrice: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Harga beli harus diisi';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            controller: _sellingPriceController,
                            label: 'Harga Jual',
                            hint: '0',
                            icon: PhosphorIcons.arrowUp(PhosphorIconsStyle.bold),
                            isPrice: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Harga jual harus diisi';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stock Section
                _buildSectionHeader(PhosphorIcons.package(PhosphorIconsStyle.bold), 'Informasi Stok'),
                const SizedBox(height: 12),
                _buildInputCard(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _stockController,
                            label: 'Stok Awal',
                            hint: '0',
                            icon: PhosphorIcons.package(PhosphorIconsStyle.bold),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Stok harus diisi';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            controller: _minStockController,
                            label: 'Batas Min. Stok',
                            hint: '10',
                            icon: PhosphorIcons.warning(PhosphorIconsStyle.bold),
                            helperText: 'Akan muncul di alert',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF667eea).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF667eea).withValues(alpha: 0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isEditing
                                    ? PhosphorIcons.check(PhosphorIconsStyle.bold)
                                    : PhosphorIcons.plus(PhosphorIconsStyle.bold),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isEditing ? 'Update Produk' : 'Simpan Produk',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol Tambah ke Daftar & Simpan Semua (hanya untuk mode tambah baru)
                if (!isEditing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addToDraft,
                          icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 18),
                          label: const Text('Tambah Lagi', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _draftProducts.isEmpty ? null : _saveAllProducts,
                          icon: Icon(PhosphorIcons.floppyDisk(PhosphorIconsStyle.bold), size: 18),
                          label: Text(
                            'Simpan Semua (${_draftProducts.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: _draftProducts.isEmpty ? Colors.grey.shade200 : const Color(0xFF10b981)),
                            foregroundColor: _draftProducts.isEmpty ? Colors.grey : const Color(0xFF10b981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Daftar Draft Produk
                if (_draftProducts.isNotEmpty) ...[
                  _buildSectionHeader(PhosphorIcons.listBullets(PhosphorIconsStyle.bold), 'Daftar Produk ($_draftProducts.length)'),
                  const SizedBox(height: 12),
                  _buildDraftList(),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(PhosphorIconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1f2937),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDraftList() {
    return Container(
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
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('Nama Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                const Expanded(flex: 2, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                const Expanded(flex: 1, child: Text('Stok', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                const SizedBox(width: 40),
              ],
            ),
          ),
          // List items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _draftProducts.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final product = _draftProducts[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Rp ${product.sellingPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(product.category, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                    Expanded(flex: 1, child: Text(product.stock.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                    IconButton(
                      icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), color: Colors.red.shade400, size: 18),
                      onPressed: () => _removeFromDraft(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            },
          ),
          // Footer dengan opsi hapus semua
          if (_draftProducts.length > 1)
            TextButton.icon(
              onPressed: _clearAllDraft,
              icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 14, color: Colors.red.shade400),
              label: Text('Hapus Semua Draft', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required PhosphorIconData icon,
    String? suffixText,
    Widget? suffixIcon,
    String? helperText,
    bool isPrice = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade300,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: const Color(0xFF667eea), size: 18),
            ),
            prefixText: isPrice ? 'Rp ' : null,
            prefixStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            suffixText: suffixText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(List<Category> categories) {
    final flatCategories = _flattenCategories(categories);
    final uniqueCategories = <int, Category>{};
    for (var cat in flatCategories) {
      if (cat.id != null) uniqueCategories[cat.id!] = cat;
    }
    final uniqueList = uniqueCategories.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: DropdownButtonFormField<int?>(
            value: _selectedCategoryId,
            decoration: InputDecoration(
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  PhosphorIcons.folder(PhosphorIconsStyle.bold),
                  color: const Color(0xFF667eea),
                  size: 18,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  PhosphorIcons.plus(PhosphorIconsStyle.bold),
                  color: const Color(0xFF667eea),
                  size: 16,
                ),
                onPressed: () => _showAddCategoryDialog(),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tanpa Kategori')),
              ...uniqueList.map((cat) {
                final prefix = cat.parentId != null ? '  ↳ ' : '';
                return DropdownMenuItem<int?>(value: cat.id, child: Text('$prefix${cat.name}'));
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
                if (value != null) {
                  final cat = flatCategories.firstWhere((c) => c.id == value);
                  _selectedCategoryText = cat.name;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierDropdown(List<Supplier> suppliers) {
    final activeSuppliers = suppliers.where((s) => s.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: DropdownButtonFormField<int?>(
            value: _selectedSupplierId,
            decoration: InputDecoration(
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  PhosphorIcons.truck(PhosphorIconsStyle.bold),
                  color: const Color(0xFF667eea),
                  size: 18,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  PhosphorIcons.plus(PhosphorIconsStyle.bold),
                  color: const Color(0xFF667eea),
                  size: 16,
                ),
                onPressed: () => _showAddSupplierDialog(),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tanpa Supplier')),
              ...activeSuppliers.map((supplier) {
                return DropdownMenuItem<int?>(value: supplier.id, child: Text(supplier.name));
              }),
            ],
            onChanged: (value) {
              setState(() => _selectedSupplierId = value);
            },
          ),
        ),
      ],
    );
  }

  List<Category> _flattenCategories(List<Category> categories, [int? parentId, int depth = 0]) {
    List<Category> result = [];
    for (var cat in categories) {
      if (cat.parentId == parentId) {
        result.add(cat);
        result.addAll(_flattenCategories(categories, cat.id, depth + 1));
      }
    }
    return result;
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
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
              child: Icon(
                PhosphorIcons.folder(PhosphorIconsStyle.bold),
                color: const Color(0xFF667eea),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tambah Kategori Baru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nama kategori',
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
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        await context.read<CategoryController>().createCategory(
                          Category(name: nameController.text),
                        );
                        if (mounted) {
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  const Text('Kategori ditambahkan'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10b981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
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
              child: Icon(
                PhosphorIcons.truck(PhosphorIconsStyle.bold),
                color: const Color(0xFF667eea),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tambah Supplier Baru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nama Supplier',
                hintText: 'Masukkan nama supplier',
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
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Telepon',
                hintText: 'Masukkan nomor telepon',
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
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        await context.read<SupplierController>().createSupplier(
                          Supplier(name: nameController.text, phone: phoneController.text),
                        );
                        if (mounted) {
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  const Text('Supplier ditambahkan'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10b981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.product?.id,
        name: _nameController.text,
        barcode: _barcodeController.text,
        category: _selectedCategoryText,
        categoryId: _selectedCategoryId,
        supplierId: _selectedSupplierId,
        purchasePrice: double.parse(_purchasePriceController.text),
        sellingPrice: double.parse(_sellingPriceController.text),
        stock: int.parse(_stockController.text),
        minStock: int.tryParse(_minStockController.text) ?? 10,
      );

      final controller = context.read<InventoryController>();
      bool success;

      if (widget.product != null) {
        success = await controller.updateProduct(product);
      } else {
        success = await controller.addProduct(product);
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(widget.product != null ? 'Produk berhasil diupdate' : 'Produk berhasil ditambahkan'),
                ],
              ),
              backgroundColor: const Color(0xFF10b981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Text('Gagal menyimpan produk'),
                ],
              ),
              backgroundColor: const Color(0xFFef4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Error: ${e.toString()}'),
              ],
            ),
            backgroundColor: const Color(0xFFef4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Tambah produk saat ini ke daftar draft
  void _addToDraft() {
    if (!_formKey.currentState!.validate()) return;

    final product = Product(
      name: _nameController.text,
      barcode: _barcodeController.text,
      category: _selectedCategoryText,
      categoryId: _selectedCategoryId,
      supplierId: _selectedSupplierId,
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
      sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
      stock: int.tryParse(_stockController.text) ?? 0,
      minStock: int.tryParse(_minStockController.text) ?? 10,
    );

    setState(() {
      _draftProducts.add(product);
      // Clear form untuk input produk berikutnya
      _nameController.clear();
      _barcodeController.clear();
      _purchasePriceController.clear();
      _sellingPriceController.clear();
      _stockController.clear();
      _minStockController.text = '10';
      _selectedCategoryText = 'Umum';
      _selectedCategoryId = null;
      _selectedSupplierId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Produk "${product.name}" ditambahkan ke daftar. Total: ${_draftProducts.length} produk'),
          ],
        ),
        backgroundColor: const Color(0xFF10b981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Hapus produk dari daftar draft
  void _removeFromDraft(int index) {
    setState(() {
      _draftProducts.removeAt(index);
    });
  }

  // Simpan semua produk draft
  Future<void> _saveAllProducts() async {
    if (_draftProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('Tidak ada produk untuk disimpan'),
            ],
          ),
          backgroundColor: const Color(0xFFef4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final controller = context.read<InventoryController>();
      final success = await controller.addProducts(_draftProducts);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text('${_draftProducts.length} produk berhasil ditambahkan'),
                ],
              ),
              backgroundColor: const Color(0xFF10b981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Text('Gagal menyimpan produk'),
                ],
              ),
              backgroundColor: const Color(0xFFef4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIcons.warning(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Error: ${e.toString()}'),
              ],
            ),
            backgroundColor: const Color(0xFFef4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Clear semua draft
  void _clearAllDraft() {
    if (_draftProducts.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Draft?'),
        content: Text('Yakin ingin menghapus ${_draftProducts.length} produk dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _draftProducts.clear());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444)),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
