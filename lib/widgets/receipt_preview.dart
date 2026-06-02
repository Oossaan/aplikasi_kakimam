import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/transaction_model.dart';

class ReceiptPreview extends StatelessWidget {
  final Transaction transaction;

  const ReceiptPreview({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Store Name - TOKO EMAS Bintang
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.star(PhosphorIconsStyle.bold),
                  color: const Color(0xFFFFD700),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'TOKO EMAS Bintang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFF1f2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Jl. Ahmad Yani No. 10\nTelp: 021-1234567',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Invoice Number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIcons.receipt(PhosphorIconsStyle.bold),
                  size: 14,
                  color: const Color(0xFFB8860B),
                ),
                const SizedBox(width: 6),
                Text(
                  'No. Nota: ${transaction.invoiceNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB8860B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildDividerDotted(),
          const SizedBox(height: 8),

          // Date & Time
          Row(
            children: [
              Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                  size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Icon(PhosphorIcons.clock(PhosphorIconsStyle.bold),
                  size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                DateFormat('HH:mm').format(transaction.transactionDate),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ],
          ),

          if (transaction.outletName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                    size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Outlet: ${transaction.outletName}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          _buildDividerDotted(),
          const SizedBox(height: 8),

          // Header Table
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1f2937),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Nama Barang',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Berat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Harga/Grm',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Subtotal',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Items
          ...transaction.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1f2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.isReturned || item.returnedQuantity > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Retur: ${item.returnedQuantity}',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.berat != null
                            ? '${item.berat!.toStringAsFixed(2)} gr'
                            : '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      if (item.hargaPerGram != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          NumberFormat.currency(
                            locale: 'id',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(item.hargaPerGram),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    NumberFormat.currency(
                      locale: 'id',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(item.price),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    NumberFormat.currency(
                      locale: 'id',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(item.effectiveSubtotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1f2937),
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),

          const SizedBox(height: 8),
          _buildDividerDotted(),
          const SizedBox(height: 8),

          // Totals Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                // Subtotal
                _buildSummaryRow(
                  'Subtotal',
                  NumberFormat.currency(
                    locale: 'id',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(transaction.totalAmount),
                ),

                if (transaction.discount > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Diskon',
                    '- ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction.discount)}',
                    valueColor: const Color(0xFF10b981),
                  ),
                ],

                if (transaction.items.any((i) => i.returnedQuantity > 0)) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Total Retur',
                    '- ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(transaction.totalReturnedAmount)}',
                    valueColor: Colors.orange,
                  ),
                ],

                const SizedBox(height: 8),
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL BAYAR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1f2937),
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(transaction.finalAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB8860B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildDividerDotted(),
          const SizedBox(height: 12),

          // Payment Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          transaction.paymentMethod.toLowerCase() == 'cash'
                              ? PhosphorIcons.money(PhosphorIconsStyle.bold)
                              : PhosphorIcons.creditCard(PhosphorIconsStyle.bold),
                          size: 16,
                          color: const Color(0xFF374151),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Metode Bayar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: transaction.paymentMethod.toLowerCase() == 'cash'
                            ? const Color(0xFF10b981).withValues(alpha: 0.15)
                            : const Color(0xFF6366f1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.paymentMethod.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: transaction.paymentMethod.toLowerCase() == 'cash'
                              ? const Color(0xFF10b981)
                              : const Color(0xFF6366f1),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (transaction.customerName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.user(PhosphorIconsStyle.bold),
                      size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pelanggan: ${transaction.customerName}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // QR Code Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1f2937),
                  const Color(0xFF374151),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // QR placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIcons.qrCode(PhosphorIconsStyle.bold),
                      size: 48,
                      color: const Color(0xFF1f2937),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan untuk verifikasi',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Thank you message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                  color: const Color(0xFF10b981),
                  size: 24,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Terima Kasih',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1f2937),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Barang yang sudah dibeli tidak dapat dikembalikan',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Footer
          Text(
            'www.tokoemasbintang.com',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} TOKO EMAS BINTANG',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildDividerDotted() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashWidth = 4.0;
        final dashSpace = 3.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(dashCount, (_) {
            return Container(
              width: dashWidth,
              height: 1,
              color: Colors.grey.shade300,
            );
          }),
        );
      },
    );
  }
}