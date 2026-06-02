import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../../services/settings_service.dart';
import '../../services/export_service.dart';

class InvoiceDetailPage extends StatefulWidget {
  final int? invoiceId;

  const InvoiceDetailPage({super.key, this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Transaction? _invoice;
  AppSettings? _settings;
  bool _isLoading = true;

  // Signature
  String? _receiverSignatureName;
  String? _sellerSignatureName;

  // Notes controller
  final _notesController = TextEditingController();

  // Zoom controls
  final TransformationController _transformationController = TransformationController();
  double _currentZoom = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
    _loadSettings();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        // Default: PENERIMA mengikuti OUTLET pada transaksi penjualan,
        // sedangkan PENJUAL/TOKO mengikuti pengaturan aplikasi.
        _sellerSignatureName = settings.storeName;
        _receiverSignatureName = (_invoice?.isSale == true)
            ? (_invoice?.outletName?.isNotEmpty == true
                ? _invoice!.outletName
                : (_invoice?.customerName?.isNotEmpty == true
                    ? _invoice!.customerName
                    : '..........................'))
            : '..........................';

        // update seller default as well (PENJUAL/TOKO selalu dari pengaturan aplikasi)
        _sellerSignatureName = settings.storeName;

        // Jika invoice belum loaded saat settings di-load,
        // nilai receiver akan di-update saat invoice selesai diload.
      });
      if (_invoice != null) {
        _notesController.text = _invoice!.notes ?? '';
      }
    }
  }

  Future<void> _loadInvoice() async {
    if (widget.invoiceId != null) {
      final invoice = await TransactionService.getInvoiceById(widget.invoiceId!);
      if (mounted) {
        setState(() {
          _invoice = invoice;
          _isLoading = false;
        });
        if (_settings != null) {
          _notesController.text = invoice?.notes ?? '';
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  bool get _isOutletTransaction => _invoice?.outletId != null;

  bool get _isTempoPayment =>
      _invoice?.paymentMethod.toLowerCase() == 'tempo' ||
      _invoice?.paymentMethod.toLowerCase() == 'credit' ||
      _invoice?.paymentMethod.toLowerCase() == 'hutang';

  bool _canReturn(TransactionItem item) {
    return (item.quantity - item.returnedQuantity) > 0;
  }

  String _numberToWords(double number) {
    if (number <= 0) return 'nol rupiah';

    final units = [
      '', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan',
      'sepuluh', 'sebelas'
    ];

    String convert(int n) {
      if (n < 12) return units[n];
      if (n < 20) return units[n - 10] + ' belas';
      if (n < 100) return units[n ~/ 10] + ' puluh ' + convert(n % 10);
      if (n < 200) return 'seratus ' + convert(n - 100);
      if (n < 1000) return units[n ~/ 100] + ' ratus ' + convert(n % 100);
      if (n < 2000) return 'seribu ' + convert(n - 1000);
      if (n < 1000000) return convert(n ~/ 1000) + ' ribu ' + convert(n % 1000);
      if (n < 1000000000) return convert(n ~/ 1000000) + ' juta ' + convert(n % 1000000);
      return convert(n ~/ 1000000000) + ' miliar ' + convert(n % 1000000000);
    }

    final intPart = number.floor();
    final result = convert(intPart);
    return result.trim().replaceAll('  ', ' ') + ' rupiah';
  }

  void _showSignatureDialog() {
    final receiverCtrl = TextEditingController(text: _receiverSignatureName);
    final sellerCtrl = TextEditingController(text: _sellerSignatureName);

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIcons.signature(PhosphorIconsStyle.bold),
                    color: const Color(0xFF667eea),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanda Tangan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Atur nama untuk tanda tangan',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: receiverCtrl,
              decoration: _inputDecoration('Nama Penerima'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sellerCtrl,
              decoration: _inputDecoration(_invoice?.isSale == true ? 'Nama Penjual' : 'Nama Pembeli'),
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
                    child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _receiverSignatureName = receiverCtrl.text.isNotEmpty ? receiverCtrl.text : '..........................';
                        _sellerSignatureName = sellerCtrl.text.isNotEmpty ? sellerCtrl.text : '..........................';
                      });
                      Navigator.pop(sheetContext);
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
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      hintText: 'Masukkan nama',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
              child: Icon(PhosphorIcons.fileText(PhosphorIconsStyle.bold), size: 18),
            ),
            const SizedBox(width: 10),
            Text('Invoice ${_invoice?.invoiceNumber ?? ''}'),
          ],
        ),
        backgroundColor: const Color(0xFF1f2937),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.signature(PhosphorIconsStyle.bold)),
            tooltip: 'Atur Tanda Tangan',
            onPressed: _showSignatureDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: const Color(0xFF667eea)))
          : _invoice == null
              ? _buildEmptyState()
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      child: Center(
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: _minZoom,
                          maxScale: _maxZoom,
                          onInteractionUpdate: (details) {
                            setState(() {
                              _currentZoom = _transformationController.value.getMaxScaleOnAxis();
                            });
                          },
                          child: _buildInvoicePreview(isMobile),
                        ),
                      ),
                    ),
                    // Zoom indicator
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zoom out button
                            GestureDetector(
                              onTap: _currentZoom > _minZoom
                                  ? () {
                                      final newZoom = (_currentZoom - 0.25).clamp(_minZoom, _maxZoom);
                                      _transformationController.value = Matrix4.identity()..scale(newZoom);
                                      setState(() => _currentZoom = newZoom);
                                    }
                                  : null,
                              child: Icon(
                                PhosphorIcons.minus(PhosphorIconsStyle.bold),
                                color: _currentZoom > _minZoom ? Colors.white : Colors.grey,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(_currentZoom * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Zoom in button
                            GestureDetector(
                              onTap: _currentZoom < _maxZoom
                                  ? () {
                                      final newZoom = (_currentZoom + 0.25).clamp(_minZoom, _maxZoom);
                                      _transformationController.value = Matrix4.identity()..scale(newZoom);
                                      setState(() => _currentZoom = newZoom);
                                    }
                                  : null,
                              child: Icon(
                                PhosphorIcons.plus(PhosphorIconsStyle.bold),
                                color: _currentZoom < _maxZoom ? Colors.white : Colors.grey,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Reset zoom button
                            GestureDetector(
                              onTap: () {
                                _transformationController.value = Matrix4.identity();
                                setState(() => _currentZoom = 1.0);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'RESET',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                PhosphorIcons.fileText(PhosphorIconsStyle.bold),
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Invoice tidak ditemukan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoice() async {
    if (_invoice == null) return;

    // Print directly using continuous form 4-ply paper size
    try {
      await ExportService.printFormalInvoice(
        _invoice!,
        _settings,
        receiverSignatureName: _receiverSignatureName,
        sellerSignatureName: _sellerSignatureName,
        paperSize: 'continuous_form',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.bold), color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Gagal mencetak invoice: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _paperOption(String value, String title, String subtitle) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.fileText(PhosphorIconsStyle.bold), color: const Color(0xFF667eea), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1f2937))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicePreview(bool isMobile) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 595),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _InvoiceContent(
              invoice: _invoice!,
              settings: _settings,
              receiverSignatureName: _receiverSignatureName,
              sellerSignatureName: _sellerSignatureName,
              notesController: _notesController,
              numberToWords: _numberToWords,
            ),
          ),
          const SizedBox(height: 24),
          if (!_isLoading && _invoice != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showSignatureDialog,
                  icon: Icon(PhosphorIcons.signature(PhosphorIconsStyle.bold), size: 18),
                  label: const Text('Ubah Tanda Tangan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _printInvoice,
                  icon: Icon(PhosphorIcons.printer(PhosphorIconsStyle.bold), size: 18),
                  label: const Text('Cetak Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1f2937),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ========== INVOICE CONTENT ==========

class _InvoiceContent extends StatelessWidget {
  final Transaction invoice;
  final AppSettings? settings;
  final String? receiverSignatureName;
  final String? sellerSignatureName;
  final TextEditingController notesController;
  final String Function(double) numberToWords;

  const _InvoiceContent({
    required this.invoice,
    required this.settings,
    required this.receiverSignatureName,
    required this.sellerSignatureName,
    required this.notesController,
    required this.numberToWords,
  });

  bool get isSale => invoice.isSale;
  bool get isTempo => invoice.paymentMethod.toLowerCase() == 'tempo' ||
      invoice.paymentMethod.toLowerCase() == 'credit' ||
      invoice.paymentMethod.toLowerCase() == 'hutang';

  String get storeName => settings?.storeName.isNotEmpty == true ? settings!.storeName : 'TOKO EMAS Bintang';
  String get storeAddress => settings?.storeAddress.isNotEmpty == true ? settings!.storeAddress : 'Jl. Ahmad Yani No. 10';
  String get storePhone => settings?.storePhone.isNotEmpty == true ? settings!.storePhone : '021-1234567';

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER: Store Info + Invoice Badge =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1f2937)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$storeAddress\nTelp: $storePhone',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1f2937),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'INVOICE',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ===== TRANSACTION INFO =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Customer/Supplier info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSale ? 'KEPADA (PELANGGAN)' : 'KEPADA (SUPPLIER)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSale
                            ? (invoice.customerName ?? invoice.outletName ?? '-')
                            : (invoice.supplierName ?? '-'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSale ? (invoice.outletAddress ?? '-') : (invoice.supplierAddress ?? '-'),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Telp: ${isSale ? (invoice.outletPhone ?? '-') : (invoice.supplierPhone ?? '-')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                      ),
                      if (isSale && invoice.salesName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: 12, color: Color(0xFF667eea)),
                              const SizedBox(width: 4),
                              Text(
                                'Sales: ${invoice.salesName}${invoice.salesPhone != null ? ' - ${invoice.salesPhone}' : ''}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF667eea)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Right: Date, Invoice, Tempo info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _infoRow('No. Faktur', invoice.invoiceNumber),
                      _infoRow('Tgl. Faktur', dateFormat.format(invoice.transactionDate)),
                      if (isTempo && invoice.shipmentDate != null)
                        _infoRow('Jatuh Tempo', dateFormat.format(invoice.shipmentDate!)),
                      if (isTempo)
                        _infoRow('Tempo', '............ hari', valueColor: Colors.orange),
                      _infoRow('Mata Uang', 'IDR (Rupiah)'),
                      _infoRow('Metode Pembayaran', invoice.paymentMethod.toUpperCase()),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ===== ITEMS TABLE =====
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1f2937),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                _HeaderCell('No.', flex: 1, align: TextAlign.center),
                _HeaderCell('NAMA BARANG', flex: 4),
                _HeaderCell('QTY', flex: 1, align: TextAlign.center),
                _HeaderCell('SAT', flex: 1, align: TextAlign.center),
                _HeaderCell('HARGA', flex: 2, align: TextAlign.right),
                _HeaderCell('DISC %', flex: 1, align: TextAlign.center),
                _HeaderCell('DISC Rp', flex: 2, align: TextAlign.right),
                _HeaderCell('NETTO', flex: 2, align: TextAlign.right),
              ],
            ),
          ),

          // Items
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoice.items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final item = invoice.items[index];
                final itemTotal = item.price * item.quantity;
                final discPercent = itemTotal > 0 ? (item.itemDiscount / itemTotal * 100) : 0.0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: index.isOdd ? Colors.grey.shade50 : Colors.white,
                  child: Row(
                    children: [
                      _BodyCell('${index + 1}', flex: 1, align: TextAlign.center),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            if (item.returnedQuantity > 0)
                              Text('Retur: ${item.returnedQuantity}', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
                          ],
                        ),
                      ),
                      _BodyCell('${item.quantity}', flex: 1, align: TextAlign.center),
                      _BodyCell(item.satuan, flex: 1, align: TextAlign.center),
                      _BodyCell(currencyFormat.format(item.price), flex: 2, align: TextAlign.right),
                      _BodyCell(
                        discPercent > 0 ? '${discPercent.toStringAsFixed(1)}%' : '-',
                        flex: 1,
                        align: TextAlign.center,
                        color: discPercent > 0 ? Colors.green.shade700 : null,
                      ),
                      _BodyCell(
                        item.itemDiscount > 0 ? '- ${currencyFormat.format(item.itemDiscount)}' : '-',
                        flex: 2,
                        align: TextAlign.right,
                        color: item.itemDiscount > 0 ? Colors.green.shade700 : null,
                      ),
                      _BodyCell(currencyFormat.format(item.subtotal), flex: 2, align: TextAlign.right, bold: true),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ===== RINCIAN + TERBILANG + CATATAN SECTION =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Rincian
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('RINCIAN'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Jumlah', currencyFormat.format(invoice.totalAmount)),

                          // Diskon keseluruhan ditampilkan dalam % dan nominal Rp
                          Builder(builder: (context) {
                            final subtotalBeforeItemDiscount =
                                invoice.items.fold<double>(0, (sum, it) => sum + (it.price * it.quantity));
                            
                            // Use stored discountPercent if available, otherwise calculate
                            final overallDiscountPercent = invoice.discountPercent > 0
                                ? invoice.discountPercent
                                : (subtotalBeforeItemDiscount > 0
                                    ? (invoice.discount / subtotalBeforeItemDiscount * 100)
                                    : 0.0);

                            if (invoice.discount <= 0) return const SizedBox.shrink();

                            return Column(
                              children: [
                                _summaryRow(
                                  'Diskon %',
                                  '${overallDiscountPercent.toStringAsFixed(1)}%',
                                  valueColor: Colors.green.shade600,
                                ),
                                _summaryRow(
                                  'Diskon',
                                  '- ${currencyFormat.format(invoice.discount)}',
                                  valueColor: Colors.green.shade600,
                                ),
                              ],
                            );
                          }),

                          if (isTempo)
                            _summaryRow('Piutang', currencyFormat.format(invoice.finalAmount), valueColor: Colors.orange.shade700),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
                          _summaryRow('Total', currencyFormat.format(invoice.finalAmount), bold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Right side: Terbilang
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('TERBILANG'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10b981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10b981).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        numberToWords(invoice.finalAmount).toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1f2937)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ===== CATATAN =====
          _sectionTitle('CATATAN'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              invoice.notes?.isNotEmpty == true ? invoice.notes! : '........................................................',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
            ),
          ),

          const SizedBox(height: 32),

          // ===== TANDA TANGAN =====
          Row(
            children: [
              Expanded(child: _signatureBox('PENERIMA', receiverSignatureName)),
              const SizedBox(width: 48),
              Expanded(child: _signatureBox(isSale ? 'PENJUAL / TOKO' : 'PEMBELI / GUDANG', sellerSignatureName)),
            ],
          ),

          const SizedBox(height: 24),

          // ===== DIBUAT OLEH =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Dibuat oleh: ',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  storeName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1f2937)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Column(
              children: [
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Invoice ini sah dan berlaku sebagai bukti transaksi', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: bold ? 16 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  Widget _signatureBox(String title, String? name) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          height: 70,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          alignment: Alignment.center,
          child: Text('Tanda Tangan', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
        ),
        const SizedBox(height: 6),
        Text(name ?? '..........................', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(width: 100, height: 1, color: Colors.grey.shade400),
        const SizedBox(height: 4),
        Text('( ${title.split(' ').first} )', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.5),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;

  const _HeaderCell(this.text, {required this.flex, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), textAlign: align),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  final bool bold;
  final Color? color;

  const _BodyCell(this.text, {required this.flex, this.align = TextAlign.left, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color ?? const Color(0xFF374151)), textAlign: align),
    );
  }
}