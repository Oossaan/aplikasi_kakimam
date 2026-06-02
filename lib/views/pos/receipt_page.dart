import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/export_service.dart';

class ReceiptPage extends StatefulWidget {
  final int? invoiceId;
  final String? invoiceNumber;
  final Transaction? transaction;
  final String? outletName;

  const ReceiptPage({
    super.key,
    this.invoiceId,
    this.invoiceNumber,
    this.transaction,
    this.outletName,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  Transaction? _transaction;
  bool _isLoading = true;
  String? _outletName;
  AppSettings? _appSettings;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
    _loadAppSettings();
  }

  Future<void> _loadAppSettings() async {
    try {
      _appSettings = await SettingsService.getSettings();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  Future<void> _loadTransaction() async {
    if (widget.transaction != null) {
      setState(() {
        _transaction = widget.transaction;
        _outletName = widget.outletName;
        _isLoading = false;
      });
      return;
    }

    if (widget.invoiceId != null) {
      await _loadByInvoiceId(widget.invoiceId!);
      return;
    }

    if (widget.invoiceNumber != null) {
      await _loadByInvoiceNumber(widget.invoiceNumber!);
      return;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadByInvoiceId(int invoiceId) async {
    try {
      final db = await DatabaseService.database;
      final txResult = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (txResult.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      await _processTransactionData(txResult.first);
    } catch (e) {
      debugPrint('Error loading transaction by ID: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadByInvoiceNumber(String invoiceNumber) async {
    try {
      final db = await DatabaseService.database;
      final txResult = await db.query(
        'transactions',
        where: 'invoiceNumber = ?',
        whereArgs: [invoiceNumber],
      );

      if (txResult.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      await _processTransactionData(txResult.first);
    } catch (e) {
      debugPrint('Error loading transaction by invoice number: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processTransactionData(Map<String, dynamic> txData) async {
    final db = await DatabaseService.database;

    final outletId = txData['outletId'];
    String? outletName;
    if (outletId != null) {
      final outletResult = await db.query(
        'outlets',
        where: 'id = ?',
        whereArgs: [outletId],
      );
      if (outletResult.isNotEmpty) {
        outletName = outletResult.first['name'] as String?;
      }
    }

    String? salesName;
    String? salesPhone;
    final salesId = txData['salesId'];
    if (salesId != null) {
      final salesResult = await db.query(
        'sales',
        columns: ['name', 'phone'],
        where: 'id = ?',
        whereArgs: [salesId],
      );
      if (salesResult.isNotEmpty) {
        salesName = salesResult.first['name'] as String?;
        salesPhone = salesResult.first['phone'] as String?;
      }
    }

    final transactionId = txData['id'] as int;
    final itemsResult = await db.query(
      'transactionItems',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );

    final items = itemsResult.map((item) => TransactionItem(
      id: item['id'] as int?,
      productId: (item['productId'] as int?) ?? 0,
      productName: item['productName'] as String,
      price: (item['price'] as num).toDouble(),
      quantity: item['quantity'] as int,
      subtotal: (item['subtotal'] as num).toDouble(),
      cost: (item['cost'] as num?)?.toDouble() ?? 0,
      returnedQuantity: item['returnedQuantity'] as int? ?? 0,
    )).toList();

    setState(() {
      _transaction = Transaction(
        id: txData['id'] as int?,
        invoiceNumber: txData['invoiceNumber'] as String,
        transactionDate: DateTime.parse(txData['transactionDate'] as String),
        totalAmount: (txData['totalAmount'] as num).toDouble(),
        discount: (txData['discount'] as num?)?.toDouble() ?? 0,
        finalAmount: (txData['finalAmount'] as num).toDouble(),
        paymentMethod: txData['paymentMethod'] as String? ?? 'Cash',
        outletId: txData['outletId'] as int?,
        outletName: outletName,
        salesName: salesName,
        salesPhone: salesPhone,
        items: items,
      );
      _outletName = outletName ?? widget.outletName;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isLandscape = size.width > size.height;

    // Responsive values
    final horizontalPadding = isTablet ? (isLandscape ? 48.0 : 32.0) : 16.0;
    final receiptMaxWidth = isTablet ? 480.0 : double.infinity;
    final successCardPadding = isTablet ? 32.0 : 20.0;
    final receiptCardPadding = isTablet ? 28.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(isTablet),
      body: _isLoading
          ? _buildLoadingState()
          : _transaction == null
              ? _buildErrorState()
              : _buildContent(
                  horizontalPadding,
                  receiptMaxWidth,
                  successCardPadding,
                  receiptCardPadding,
                  isTablet,
                ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isTablet) {
    return AppBar(
      leading: IconButton(
        icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              PhosphorIcons.receipt(PhosphorIconsStyle.bold),
              size: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(width: isTablet ? 14 : 10),
          Flexible(
            child: Text(
              'Struk Pembayaran',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 20 : 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF667eea),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: Icon(PhosphorIcons.fileXls(PhosphorIconsStyle.bold)),
          onPressed: _transaction != null ? () async {
            await ExportService.printReceipt(_transaction!, _appSettings);
          } : null,
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF667eea)),
          SizedBox(height: 16),
          Text('Memuat struk...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warningCircle(PhosphorIconsStyle.bold),
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Transaksi tidak ditemukan',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
              label: const Text('Kembali ke POS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    double horizontalPadding,
    double receiptMaxWidth,
    double successCardPadding,
    double receiptCardPadding,
    bool isTablet,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: receiptMaxWidth),
          child: Column(
            children: [
              // Success Card
              _buildSuccessCard(successCardPadding, isTablet),
              const SizedBox(height: 20),

              // Receipt Card
              _buildReceiptCard(receiptCardPadding, isTablet),
              const SizedBox(height: 24),

              // Action Buttons
              _buildActionButtons(isTablet),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessCard(double padding, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10b981).withValues(alpha: 0.12),
            const Color(0xFF667eea).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10b981).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF10b981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
              size: isTablet ? 56 : 48,
              color: const Color(0xFF10b981),
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            'Transaksi Berhasil!',
            style: TextStyle(
              fontSize: isTablet ? 26 : 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _transaction!.invoiceNumber,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(double padding, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Store icon
          Container(
            padding: EdgeInsets.all(isTablet ? 18 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.storefront(PhosphorIconsStyle.bold),
              size: isTablet ? 32 : 28,
              color: const Color(0xFF667eea),
            ),
          ),
          SizedBox(height: isTablet ? 16 : 12),

          // Outlet Name
          if (_outletName != null) ...[
            Text(
              _outletName!,
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1f2937),
              ),
            ),
            SizedBox(height: isTablet ? 6 : 4),
          ],

          // Sales Name
          if (_transaction?.salesName != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: 14, color: const Color(0xFF667eea)),
                  const SizedBox(width: 4),
                  Text(
                    'Sales: ${_transaction!.salesName}${_transaction!.salesPhone != null ? ' - ${_transaction!.salesPhone}' : ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF667eea)),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 6 : 4),
          ],

          // Store name
          Text(
            _appSettings?.storeName.isNotEmpty == true ? _appSettings!.storeName : 'SMART INVENTORY',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1f2937),
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 6 : 4),
          Text(
            _appSettings?.storeAddress.isNotEmpty == true ? _appSettings!.storeAddress : 'Jl. Example No. 123, Jakarta' + (_appSettings?.storePhone.isNotEmpty == true ? '\\nTelp: ${_appSettings!.storePhone}' : ''),
            style: TextStyle(
              fontSize: isTablet ? 13 : 11,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isTablet ? 20 : 16),
          _buildDividerDotted(),
          SizedBox(height: isTablet ? 16 : 12),

          // Invoice Info
          _buildInfoRow('No. Invoice', _transaction!.invoiceNumber, isBold: true, isTablet: isTablet),
          SizedBox(height: isTablet ? 6 : 4),
          _buildInfoRow(
            'Tanggal',
            DateFormat('dd/MM/yyyy HH:mm').format(_transaction!.transactionDate),
            isTablet: isTablet,
          ),
          SizedBox(height: isTablet ? 6 : 4),
          _buildInfoRow('Pembayaran', _transaction!.paymentMethod.toUpperCase(), isTablet: isTablet),

          SizedBox(height: isTablet ? 16 : 12),
          _buildDividerDotted(),
          SizedBox(height: isTablet ? 16 : 12),

          // Header
          _buildItemsHeader(isTablet),
          SizedBox(height: isTablet ? 12 : 8),

          // Items
          ..._transaction!.items.map((item) => _buildItemRow(item, isTablet)).toList(),

          SizedBox(height: isTablet ? 16 : 12),
          _buildDividerDotted(),
          SizedBox(height: isTablet ? 16 : 12),

          // Summary
          _buildInfoRow(
            'Subtotal',
            NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_transaction!.totalAmount),
            isTablet: isTablet,
          ),
          if (_transaction!.discount > 0) ...[
            SizedBox(height: isTablet ? 6 : 4),
            _buildInfoRow(
              'Diskon',
              '- ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_transaction!.discount)}',
              valueColor: const Color(0xFF10b981),
              isTablet: isTablet,
            ),
          ],
          if (_transaction!.items.any((i) => i.returnedQuantity > 0)) ...[
            SizedBox(height: isTablet ? 6 : 4),
            _buildInfoRow(
              'Retur',
              '- ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_getReturnAmount())}',
              valueColor: Colors.orange,
              isTablet: isTablet,
            ),
          ],

          SizedBox(height: isTablet ? 16 : 12),
          _buildTotalRow(isTablet),

          SizedBox(height: isTablet ? 20 : 16),

          // Thank You
          _buildThankYouSection(isTablet),
        ],
      ),
    );
  }

  Widget _buildItemsHeader(bool isTablet) {
    final fontSize = isTablet ? 11.0 : 9.0;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            'PRODUK',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6b7280),
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'QTY',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6b7280),
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'SUBTOTAL',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6b7280),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(TransactionItem item, bool isTablet) {
    final fontSizeName = isTablet ? 14.0 : 12.0;
    final fontSizeSubtotal = isTablet ? 14.0 : 12.0;
    final verticalPadding = isTablet ? 8.0 : 6.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(
                          fontSize: fontSizeName,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1f2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.returnedQuantity > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          '-${item.returnedQuantity}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSizeName,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item.subtotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSizeSubtotal,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1f2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 14, vertical: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withValues(alpha: 0.1),
            const Color(0xFF764ba2).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TOTAL',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isTablet ? 17 : 15,
              color: const Color(0xFF1f2937),
              letterSpacing: 1,
            ),
          ),
          Text(
            NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_transaction!.finalAmount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isTablet ? 20 : 18,
              color: const Color(0xFF667eea),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYouSection(bool isTablet) {
    final footer = _appSettings?.receiptFooter ?? 'Terima kasih';
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withValues(alpha: 0.06),
            const Color(0xFF764ba2).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            PhosphorIcons.heart(PhosphorIconsStyle.bold),
            size: isTablet ? 32 : 28,
            color: Colors.pink.shade400,
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Text(
            footer.split(' ').first.toUpperCase(),
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1f2937),
            ),
          ),
          if (footer.split(' ').length > 1) ...[
            SizedBox(height: isTablet ? 6 : 4),
            Text(
              footer.split(' ').sublist(1).join(' '),
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            'Barang yang sudah dibeli tidak dapat dikembalikan',
            style: TextStyle(
              fontSize: isTablet ? 11 : 10,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold), size: isTablet ? 20 : 18),
            label: Text(
              'Kembali ke POS',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: isTablet ? 15 : 14),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: isTablet ? 20 : 18),
            label: Text(
              'Transaksi Baru',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: isTablet ? 15 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isBold = false, bool isTablet = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? (isBold ? const Color(0xFF1f2937) : const Color(0xFF374151)),
          ),
        ),
      ],
    );
  }

  Widget _buildDividerDotted() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
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

  double _getReturnAmount() {
    double total = 0;
    for (final item in _transaction!.items) {
      if (item.returnedQuantity > 0) {
        total += item.price * item.returnedQuantity;
      }
    }
    return total;
  }
}
