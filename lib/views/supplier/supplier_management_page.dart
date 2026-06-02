import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/supplier_controller.dart';
import '../../models/supplier_model.dart';
import '../../config/routes.dart';

class SupplierManagementPage extends StatefulWidget {
  const SupplierManagementPage({super.key});

  @override
  State<SupplierManagementPage> createState() => _SupplierManagementPageState();
}

class _SupplierManagementPageState extends State<SupplierManagementPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierController>().loadSuppliers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupplierController>();
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
              child: Icon(PhosphorIcons.truck(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Manajemen Supplier', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    hintText: 'Cari supplier...',
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
                              controller.loadSuppliers();
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
                      controller.loadSuppliers();
                    } else {
                      controller.searchSuppliers(query);
                    }
                  },
                ),
              ),
            ),

            // Supplier List
            Expanded(
              child: controller.isLoading
                  ? Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)))
                  : controller.suppliers.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF667eea),
                          onRefresh: () => controller.loadSuppliers(),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
                            itemCount: controller.suppliers.length,
                            itemBuilder: (context, index) {
                              final supplier = controller.suppliers[index];
                              return _buildSupplierTile(context, supplier, controller, isMobile);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSupplierDialog(context),
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
                PhosphorIcons.truck(PhosphorIconsStyle.bold),
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada supplier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah supplier baru untuk memulai',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierTile(BuildContext context, Supplier supplier, SupplierController controller, bool isMobile) {
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
          onTap: () => _showSupplierDialog(context, supplier: supplier),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: supplier.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIcons.truck(PhosphorIconsStyle.bold),
                    color: supplier.isActive ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1f2937)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (supplier.contactPerson.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          supplier.contactPerson,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      if (supplier.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          supplier.phone,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildSupplierPopupMenu(context, supplier, controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierPopupMenu(BuildContext context, Supplier supplier, SupplierController controller) {
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
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF667eea).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16)),
              const SizedBox(width: 12),
              const Text('Riwayat Stok', style: TextStyle(fontWeight: FontWeight.w600)),
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
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: (supplier.isActive ? Colors.orange : Colors.green).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(supplier.isActive ? PhosphorIcons.toggleRight(PhosphorIconsStyle.bold) : PhosphorIcons.power(PhosphorIconsStyle.bold), color: supplier.isActive ? Colors.orange : Colors.green, size: 16)),
              const SizedBox(width: 12),
              Text(supplier.isActive ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(fontWeight: FontWeight.w600, color: supplier.isActive ? Colors.orange : Colors.green)),
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
            Navigator.pushNamed(context, AppRoutes.supplierStockHistory, arguments: supplier);
            break;
          case 'edit':
            _showSupplierDialog(context, supplier: supplier);
            break;
          case 'toggle':
            controller.toggleSupplierStatus(supplier);
            break;
          case 'delete':
            _showDeleteConfirmation(context, supplier);
            break;
        }
      },
    );
  }

  void _showSupplierDialog(BuildContext context, {Supplier? supplier}) {
    final isEditing = supplier != null;
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final contactController = TextEditingController(text: supplier?.contactPerson ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final addressController = TextEditingController(text: supplier?.address ?? '');
    final notesController = TextEditingController(text: supplier?.notes ?? '');
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
                PhosphorIcons.truck(PhosphorIconsStyle.bold),
                color: const Color(0xFF667eea),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Supplier' : 'Tambah Supplier Baru',
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
                      labelText: 'Nama Supplier *',
                      hintText: 'Masukkan nama supplier',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.truck(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Nama supplier wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: 'Nama Kontak',
                      hintText: 'Nama kontak person',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
                    ),
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
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Email supplier',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.envelope(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'Catatan tambahan',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.note(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
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
                        final ctrl = context.read<SupplierController>();
                        if (isEditing) {
                          ctrl.updateSupplier(supplier.copyWith(
                            name: nameController.text,
                            contactPerson: contactController.text,
                            phone: phoneController.text,
                            email: emailController.text,
                            address: addressController.text,
                            notes: notesController.text,
                          ));
                        } else {
                          ctrl.createSupplier(Supplier(
                            name: nameController.text,
                            contactPerson: contactController.text,
                            phone: phoneController.text,
                            email: emailController.text,
                            address: addressController.text,
                            notes: notesController.text,
                          ));
                        }
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text(isEditing ? 'Supplier diperbarui' : 'Supplier ditambahkan'),
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

  Future<void> _showDeleteConfirmation(BuildContext context, Supplier supplier) async {
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
              const Text('Hapus Supplier?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
              const SizedBox(height: 10),
              Text(
                '"${supplier.name}" akan dihapus. Tindakan ini tidak dapat dibatalkan.',
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
      context.read<SupplierController>().deleteSupplier(supplier.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('${supplier.name} dihapus'),
          ]),
          backgroundColor: const Color(0xFFef4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}