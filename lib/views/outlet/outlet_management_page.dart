import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/outlet_controller.dart';
import '../../models/outlet_model.dart';
import '../../config/routes.dart';

class OutletManagementPage extends StatefulWidget {
  const OutletManagementPage({super.key});

  @override
  State<OutletManagementPage> createState() => _OutletManagementPageState();
}

class _OutletManagementPageState extends State<OutletManagementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OutletController>().loadOutlets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final outletController = context.watch<OutletController>();
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
              child: Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Manajemen Outlet', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: outletController.isLoading
          ? Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)))
          : RefreshIndicator(
              color: const Color(0xFF667eea),
              onRefresh: () => outletController.loadOutlets(),
              child: outletController.outlets.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 20),
                      itemCount: outletController.outlets.length,
                      itemBuilder: (context, index) {
                        final outlet = outletController.outlets[index];
                        return _buildOutletCard(context, outletController, outlet, isMobile);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOutletDialog(context, outletController, null),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
        label: const Text('Tambah Outlet', style: TextStyle(fontWeight: FontWeight.w600)),
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
              decoration: const BoxDecoration(color: Color(0xFFF5F6FA), shape: BoxShape.circle),
              child: Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), size: 52, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text('Belum ada outlet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text('Tambah outlet untuk memulai', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletCard(
      BuildContext context, OutletController controller, Outlet outlet, bool isMobile) {
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
          onTap: () => _showOutletDialog(context, controller, outlet),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: outlet.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                    color: outlet.isActive ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outlet.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1f2937)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (outlet.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          outlet.address,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (outlet.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(outlet.phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: outlet.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              outlet.isActive ? PhosphorIcons.checkCircle(PhosphorIconsStyle.bold) : PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
                              size: 12,
                              color: outlet.isActive ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              outlet.isActive ? 'Aktif' : 'Nonaktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: outlet.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPopupMenu(context, controller, outlet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, OutletController controller, Outlet outlet) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
        child: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold), color: Colors.grey.shade600, size: 18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'history',
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF667eea).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16)),
            const SizedBox(width: 12),
            const Text('Riwayat Stok', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF667eea).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 16)),
            const SizedBox(width: 12),
            const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: (outlet.isActive ? Colors.orange : Colors.green).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(outlet.isActive ? PhosphorIcons.toggleRight(PhosphorIconsStyle.bold) : PhosphorIcons.power(PhosphorIconsStyle.bold), color: outlet.isActive ? Colors.orange : Colors.green, size: 16)),
            const SizedBox(width: 12),
            Text(outlet.isActive ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(fontWeight: FontWeight.w600, color: outlet.isActive ? Colors.orange : Colors.green)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), color: Colors.red.shade600, size: 16)),
            const SizedBox(width: 12),
            const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
          ]),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'history':
            Navigator.pushNamed(context, AppRoutes.outletStockHistory, arguments: outlet);
            break;
          case 'edit':
            _showOutletDialog(context, controller, outlet);
            break;
          case 'toggle':
            controller.toggleOutletStatus(outlet);
            break;
          case 'delete':
            _showDeleteConfirmation(context, controller, outlet);
            break;
        }
      },
    );
  }

  void _showOutletDialog(BuildContext context, OutletController controller, Outlet? outlet) {
    final isEdit = outlet != null;
    final nameController = TextEditingController(text: outlet?.name ?? '');
    final addressController = TextEditingController(text: outlet?.address ?? '');
    final phoneController = TextEditingController(text: outlet?.phone ?? '');
    bool isActive = outlet?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF667eea).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 26),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Outlet' : 'Tambah Outlet Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nama Outlet *',
                hintText: 'Masukkan nama outlet',
                hintStyle: TextStyle(color: Colors.grey.shade300),
                prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Alamat',
                hintText: 'Masukkan alamat outlet',
                hintStyle: TextStyle(color: Colors.grey.shade300),
                prefixIcon: Container(padding: const EdgeInsets.all(12), child: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 18)),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF667eea), width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIcons.power(PhosphorIconsStyle.bold), color: isActive ? Colors.green : Colors.grey, size: 20),
                      const SizedBox(width: 10),
                      Text('Status Aktif', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    ],
                  ),
                  Switch(
                    value: isActive,
                    activeColor: const Color(0xFF667eea),
                    onChanged: (val) => setState(() => isActive = val),
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
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.grey.shade300)),
                    child: Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              const Text('Nama outlet tidak boleh kosong'),
                            ]),
                            backgroundColor: const Color(0xFFef4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }
                      final newOutlet = Outlet(
                        id: outlet?.id,
                        name: nameController.text.trim(),
                        address: addressController.text.trim(),
                        phone: phoneController.text.trim(),
                        isActive: isActive,
                        createdAt: outlet?.createdAt ?? DateTime.now(),
                      );
                      bool success;
                      if (isEdit) {
                        success = await controller.updateOutlet(newOutlet);
                      } else {
                        success = await controller.addOutlet(newOutlet);
                      }
                      if (success && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text(isEdit ? 'Outlet berhasil diperbarui' : 'Outlet berhasil ditambahkan'),
                            ]),
                            backgroundColor: const Color(0xFF10b981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(isEdit ? 'Simpan' : 'Tambah', style: const TextStyle(fontWeight: FontWeight.w600)),
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

  void _showDeleteConfirmation(BuildContext context, OutletController controller, Outlet outlet) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), color: Colors.red.shade600, size: 32)),
              const SizedBox(height: 22),
              const Text('Hapus Outlet?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937))),
              const SizedBox(height: 10),
              Text('"${outlet.name}" akan dihapus. Tindakan ini tidak dapat dibatalkan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.grey.shade300)),
                      child: Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await controller.deleteOutlet(outlet.id!);
                        if (success && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                const Text('Outlet berhasil dihapus'),
                              ]),
                              backgroundColor: const Color(0xFF10b981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
  }
}