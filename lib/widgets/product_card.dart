import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.isLowStock;
    final stockColor = isLowStock ? const Color(0xFFef4444) : const Color(0xFF10b981);
    final stockBg = isLowStock ? Colors.red.shade50 : Colors.green.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(product.sellingPrice),
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

                // Action Menu
                if (onEdit != null || onDelete != null) _buildPopupMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
          color: Colors.grey.shade600,
          size: 18,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold),
                    color: const Color(0xFF667eea),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PhosphorIcons.trash(PhosphorIconsStyle.bold),
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Hapus',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                ),
              ],
            ),
          ),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          onEdit?.call();
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
    );
  }
}