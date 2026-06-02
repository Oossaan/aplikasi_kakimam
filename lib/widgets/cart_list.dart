import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/cart_item_model.dart';

class CartList extends StatelessWidget {
  final List<CartItem> cart;
  final Function(int) onRemove;
  final Function(int, int) onQuantityChanged;
  final bool isPurchaseMode;

  const CartList({
    super.key,
    required this.cart,
    required this.onRemove,
    required this.onQuantityChanged,
    this.isPurchaseMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold),
                  size: 48,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Keranjang kosong',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih produk untuk menambahkan',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: cart.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = cart[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1f2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          PhosphorIcons.trash(PhosphorIconsStyle.bold),
                          color: Colors.red.shade600,
                          size: 18,
                        ),
                        onPressed: () => onRemove(index),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          NumberFormat.currency(
                            locale: 'id',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(isPurchaseMode ? item.product.purchasePrice : item.product.sellingPrice),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.subtotal)}',
                          style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQtyButton(
                            PhosphorIcons.minus(PhosphorIconsStyle.bold),
                            () {
                              if (item.quantity > 1) {
                                onQuantityChanged(index, item.quantity - 1);
                              }
                            },
                            item.quantity > 1,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1f2937),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          _buildQtyButton(
                            PhosphorIcons.plus(PhosphorIconsStyle.bold),
                            () => onQuantityChanged(index, item.quantity + 1),
                            true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQtyButton(PhosphorIconData icon, VoidCallback onPressed, bool enabled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? const Color(0xFF667eea) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}