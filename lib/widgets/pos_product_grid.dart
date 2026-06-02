import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';

class POSProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  const POSProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isOutOfStock = product.stock == 0;
        final isLowStock = product.stock > 0 && product.stock <= 10;

        Color stockColor;
        Color stockBg;
        if (isOutOfStock) {
          stockColor = const Color(0xFFef4444);
          stockBg = Colors.red.shade50;
        } else if (isLowStock) {
          stockColor = const Color(0xFFf59e0b);
          stockBg = Colors.orange.shade50;
        } else {
          stockColor = const Color(0xFF10b981);
          stockBg = Colors.green.shade50;
        }

        return Container(
          decoration: BoxDecoration(
            color: isOutOfStock ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isOutOfStock
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: isOutOfStock ? null : () => onProductTap(product),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Product icon/status
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.grey.shade200
                            : stockBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOutOfStock
                            ? PhosphorIcons.warning(PhosphorIconsStyle.bold)
                            : PhosphorIcons.package(PhosphorIconsStyle.bold),
                        color: isOutOfStock ? Colors.grey : stockColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Product name
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isOutOfStock
                            ? Colors.grey.shade400
                            : const Color(0xFF1f2937),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(product.sellingPrice),
                      style: TextStyle(
                        color: isOutOfStock
                            ? Colors.grey.shade400
                            : const Color(0xFF667eea),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Stock badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.grey.shade200 : stockBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isOutOfStock) ...[
                            Icon(
                              PhosphorIcons.cube(PhosphorIconsStyle.bold),
                              size: 9,
                              color: stockColor,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            isOutOfStock
                                ? 'Habis'
                                : 'Stok: ${product.stock}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock ? Colors.grey : stockColor,
                            ),
                          ),
                        ],
                      ),
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
}