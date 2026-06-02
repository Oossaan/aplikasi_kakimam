import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/sales_controller.dart';
import '../../models/sales_model.dart';
import '../../config/routes.dart';

class SalesManagementPage extends StatefulWidget {
  const SalesManagementPage({super.key});

  @override
  State<SalesManagementPage> createState() => _SalesManagementPageState();
}

class _SalesManagementPageState extends State<SalesManagementPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesController>().loadSales();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SalesController>();
    final isMobile = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Manajemen Sales', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
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
                    hintText: 'Cari sales...',
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
                              controller.loadSales();
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
                  onChanged: (query) {
                    if (query.isEmpty) {
                      controller.loadSales();
                    } else {
                      final filtered = controller.sales.where((s) =>
                        s.name.toLowerCase().contains(query.toLowerCase()) ||
                        s.phone.contains(query)
                      ).toList();
                      // We need to show filtered results - for now just reload
                    }
                  },
                ),
              ),
            ),

            // Sales List
            Expanded(
              child: controller.isLoading
                  ? Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)))
                  : controller.sales.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF667eea),
                          onRefresh: () => controller.loadSales(),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
                            itemCount: controller.sales.length,
                            itemBuilder: (context, index) {
                              final sales = controller.sales[index];
                              return _buildSalesTile(context, sales, controller, isMobile);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSalesDialog(context),
        backgroundColor: const Color(0xFF667eea),
        child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: Colors.white),
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
                PhosphorIcons.usersThree(PhosphorIconsStyle.bold),
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah sales baru untuk memulai',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTile(BuildContext context, Sales sales, SalesController controller, bool isMobile) {
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
          onTap: () => _showSalesDialog(context, sales: sales),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sales.isActive ? Colors.blue.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIcons.user(PhosphorIconsStyle.bold),
                    color: sales.isActive ? Colors.blue : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sales.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1f2937)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sales.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(PhosphorIcons.phone(PhosphorIconsStyle.bold), size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              sales.phone,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                      if (sales.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.bold), size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                sales.address,
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
                _buildSalesPopupMenu(context, sales, controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesPopupMenu(BuildContext context, Sales sales, SalesController controller) {
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
        PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF10b981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.bold), color: const Color(0xFF10b981), size: 16)),
              const SizedBox(width: 12),
              const Text('Riwayat Penjualan', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF667eea).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16)),
              const SizedBox(width: 12),
              const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: (sales.isActive ? Colors.orange : Colors.green).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(sales.isActive ? PhosphorIcons.toggleRight(PhosphorIconsStyle.bold) : PhosphorIcons.power(PhosphorIconsStyle.bold), color: sales.isActive ? Colors.orange : Colors.green, size: 16)),
              const SizedBox(width: 12),
              Text(sales.isActive ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(fontWeight: FontWeight.w600, color: sales.isActive ? Colors.orange : Colors.green)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), color: Colors.red.shade600, size: 16)),
              const SizedBox(width: 12),
              const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'history':
            Navigator.pushNamed(
              context,
              AppRoutes.salesHistory,
              arguments: sales,
            );
            break;
          case 'edit':
            _showSalesDialog(context, sales: sales);
            break;
          case 'toggle':
            controller.toggleSalesStatus(sales);
            break;
          case 'delete':
            _showDeleteConfirmation(context, sales);
            break;
        }
      },
    );
  }

  void _showSalesDialog(BuildContext context, {Sales? sales}) {
    final isEditing = sales != null;
    final nameController = TextEditingController(text: sales?.name ?? '');
    final phoneController = TextEditingController(text: sales?.phone ?? '');
    final addressController = TextEditingController(text: sales?.address ?? '');
    final formKey = GlobalKey<FormState>();

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
                PhosphorIcons.user(PhosphorIconsStyle.bold),
                color: const Color(0xFF667eea),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Sales' : 'Tambah Sales Baru',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Sales *',
                      hintText: 'Masukkan nama sales',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Nama sales wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telepon',
                      hintText: 'Nomor telepon',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.phone(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Alamat',
                      hintText: 'Alamat lengkap',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
                    ),
                  ),
                ],
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
                    child: Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final ctrl = context.read<SalesController>();
                        if (isEditing) {
                          ctrl.updateSales(sales.copyWith(
                            name: nameController.text,
                            phone: phoneController.text,
                            address: addressController.text,
                          ));
                        } else {
                          ctrl.addSales(Sales(
                            name: nameController.text,
                            phone: phoneController.text,
                            address: addressController.text,
                          ));
                        }
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text(isEditing ? 'Sales diperbarui' : 'Sales ditambahkan'),
                            ]),
                            backgroundColor: const Color(0xFF10b981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
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

  Future<void> _showDeleteConfirmation(BuildContext context, Sales sales) async {
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
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), color: Colors.red.shade600, size: 32),
              ),
              const SizedBox(height: 22),
              const Text('Hapus Sales?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
              const SizedBox(height: 10),
              Text(
                '"${sales.name}" akan dihapus. Tindakan ini tidak dapat dibatalkan.',
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
      context.read<SalesController>().deleteSales(sales.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('${sales.name} dihapus'),
          ]),
          backgroundColor: const Color(0xFFef4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
