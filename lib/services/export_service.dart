import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../models/product_model.dart';
import 'database_service.dart';
import 'settings_service.dart';

class ExportService {
  /// Cross-platform file save and share - Windows Downloads + auto open
  static Future<void> saveAndShareFile({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      String filePath;
      
      if (Platform.isWindows) {
        // Windows: Save to Downloads
        final userProfile = Platform.environment['USERPROFILE']!;
        final downloadsPath = '$userProfile/Downloads';
        filePath = '$downloadsPath/$filename';
        final directory = Directory(downloadsPath);
        await directory.create(recursive: true);
        // Open Downloads after save
        Process.run('explorer.exe', [downloadsPath]);
      } else {
        // Mobile/Desktop temp
        final directory = await getTemporaryDirectory();
        filePath = '${directory.path}/$filename';
      }
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      developer.log('File saved: $filePath');
      
      if (Platform.isAndroid || Platform.isIOS) {
        await Share.shareXFiles([XFile(filePath)], text: 'Inventory Export - $filename');
      }
      
    } catch (e) {
      developer.log('Export error: $e');
    }
  }

  static Future<Uint8List?> exportToExcel(List<Map<String, dynamic>> data, String sheetName, List<String> headers) async {
    final excel = Excel.createExcel();

    final headerStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: '#667eea',
      fontColorHex: '#FFFFFF',
      bold: true,
    );

    // For small datasets, use single sheet
    if (data.length <= _chunkSize) {
      _writeMapSheet(excel, sheetName, headers, data, headerStyle);
    } else {
      // Chunk large datasets into multiple sheets
      final totalChunks = (data.length / _chunkSize).ceil();
      for (int chunk = 0; chunk < totalChunks; chunk++) {
        final start = chunk * _chunkSize;
        final end = (start + _chunkSize < data.length) ? start + _chunkSize : data.length;
        final chunkData = data.sublist(start, end);
        final chunkSheetName = '$sheetName ${chunk + 1}';
        _writeMapSheet(excel, chunkSheetName, headers, chunkData, headerStyle);

        if (chunk < totalChunks - 1) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }

    final fileBytes = excel.save()!;
    return Uint8List.fromList(fileBytes);
  }

  static void _writeMapSheet(Excel excel, String sheetName, List<String> headers, List<Map<String, dynamic>> data, CellStyle headerStyle) {
    final sheet = excel[sheetName];

    // Headers
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = headers[col];
      cell.cellStyle = headerStyle;
    }

    // Data
    for (int row = 0; row < data.length; row++) {
      for (int col = 0; col < headers.length; col++) {
        final key = headers[col];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
        cell.value = data[row][key] ?? '';
      }
    }
  }

  /// Chunk size per sheet for large exports (prevents memory issues with 10k+ records)
  static const int _chunkSize = 8000;

  /// Generic Excel export for tabular data (replaces CSV exports)
  /// Handles 10,000+ records by chunking into multiple sheets
  static Future<void> exportToExcelGeneric({
    required List<String> headers,
    required List<List<String>> rows,
    required String filenameBase,
    String sheetName = 'Data',
  }) async {
    final now = DateTime.now();
    final filename = '${filenameBase}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(now)}.xlsx';

    final excel = Excel.createExcel();

    // For small datasets, use single sheet
    if (rows.length <= _chunkSize) {
      _writeSheet(excel, sheetName, headers, rows);
    } else {
      // Chunk large datasets into multiple sheets
      final totalChunks = (rows.length / _chunkSize).ceil();
      for (int chunk = 0; chunk < totalChunks; chunk++) {
        final start = chunk * _chunkSize;
        final end = (start + _chunkSize < rows.length) ? start + _chunkSize : rows.length;
        final chunkRows = rows.sublist(start, end);
        final chunkSheetName = '$sheetName ${chunk + 1}';
        _writeSheet(excel, chunkSheetName, headers, chunkRows);

        // Allow UI to breathe between chunks for very large datasets
        if (chunk < totalChunks - 1) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }

    final fileBytes = excel.save()!;
    await saveAndShareFile(
      filename: filename,
      bytes: Uint8List.fromList(fileBytes),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Write data to a single sheet (used by both single-sheet and chunked exports)
  static void _writeSheet(Excel excel, String sheetName, List<String> headers, List<List<String>> rows) {
    final sheet = excel[sheetName];

    // Header row with styling
    final headerStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: '#667eea',
      fontColorHex: '#FFFFFF',
      bold: true,
    );

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = headers[col];
      cell.cellStyle = headerStyle;
    }

    // Data rows - write directly without per-cell style to reduce memory overhead
    for (int row = 0; row < rows.length; row++) {
      for (int col = 0; col < rows[row].length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
        cell.value = rows[row][col];
      }
    }
  }

  static Future<void> exportInventoryToExcel(List<Product> products) async {
    final now = DateTime.now();
    final filename = 'inventory_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(now)}.xlsx';
    final headers = ['ID', 'Nama', 'Kategori', 'Barcode', 'HPP', 'Harga Jual', 'Stok', 'Min Stok'];
    final data = products.map((p) => {
      'ID': p.id ?? '',
      'Nama': p.name,
      'Kategori': p.category,
      'Barcode': p.barcode,
      'HPP': p.purchasePrice,
      'Harga Jual': p.sellingPrice,
      'Stok': p.stock,
      'Min Stok': p.minStock,
    }).toList();

    final bytes = await exportToExcel(data, 'Inventory', headers);
    if (bytes != null) {
      await saveAndShareFile(
        filename: filename,
        bytes: bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  }

  static Future<void> printInventory(List<Product> products) async {
    final now = DateTime.now();
    final filename = 'inventory_print_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(now)}.xlsx';
    final headers = ['ID', 'Nama', 'Kategori', 'Barcode', 'HPP', 'Harga Jual', 'Stok', 'Min Stok'];
    final data = products.map((p) => {
      'ID': p.id ?? '',
      'Nama': p.name,
      'Kategori': p.category,
      'Barcode': p.barcode,
      'HPP': p.purchasePrice,
      'Harga Jual': p.sellingPrice,
      'Stok': p.stock,
      'Min Stok': p.minStock,
    }).toList();

    final bytes = await exportToExcel(data, 'Inventory Print', headers);
    if (bytes != null) {
      await saveAndShareFile(
        filename: filename,
        bytes: bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  }

  static Future<void> exportCSV(String csvContent, String filenameBase) async {
    final now = DateTime.now();
    final filename = '${filenameBase}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(now)}.csv';
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    await saveAndShareFile(
      filename: filename,
      bytes: bytes,
      mimeType: 'text/csv',
    );
  }

  static Future<pw.Document> generateReceiptPdf(Transaction transaction, AppSettings? settings) async {
    final pdf = pw.Document();
    final storeName = settings?.storeName ?? 'TOKO EMAS Bintang';
    final storeAddress = settings?.storeAddress ?? 'Jl. Ahmad Yani No. 10';
    final storePhone = settings?.storePhone ?? '021-1234567';

    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Calculate return amount if any
    double returnAmount = 0;
    for (var item in transaction.items) {
      if (item.returnedQuantity > 0) {
        returnAmount += item.price * item.returnedQuantity;
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        margin: pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Store Header
                pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  storeAddress,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
                if (storePhone.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Telp: $storePhone',
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ],

                pw.SizedBox(height: 10),

                // Invoice Number Box
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'No. Nota: ${transaction.invoiceNumber}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                pw.SizedBox(height: 8),
                _buildDashedLine(),
                pw.SizedBox(height: 6),

                // Date & Outlet Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(dateFormat.format(transaction.transactionDate), style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(transaction.paymentMethod.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                if (transaction.outletName != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Outlet: ${transaction.outletName}', style: const pw.TextStyle(fontSize: 9)),
                ],

                pw.SizedBox(height: 6),
                _buildDashedLine(),
                pw.SizedBox(height: 6),

                // Items Header - Nama Barang | Berat | Harga/Grm | Subtotal
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey800,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text('Nama Barang', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                      pw.Expanded(
                        child: pw.Text('Berat', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('Harga/Grm', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('Subtotal', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),

                // Items
                ...transaction.items.map((item) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                              maxLines: 2,
                            ),
                            if (item.returnedQuantity > 0)
                              pw.Text(
                                'Retur: ${item.returnedQuantity}',
                                style: pw.TextStyle(fontSize: 7, color: PdfColors.orange),
                              ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          item.berat != null ? '${item.berat!.toStringAsFixed(2)} gr' : '-',
                          style: pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          item.hargaPerGram != null ? currencyFormat.format(item.hargaPerGram) : '-',
                          style: pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          currencyFormat.format(item.effectiveSubtotal),
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                )),

                pw.SizedBox(height: 6),
                _buildDashedLine(),
                pw.SizedBox(height: 6),

                // Summary Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.amber100, width: 0.5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(currencyFormat.format(transaction.totalAmount), style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      if (transaction.discount > 0) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Diskon', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                            pw.Text('- ${currencyFormat.format(transaction.discount)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                          ],
                        ),
                      ],
                      if (returnAmount > 0) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Retur', style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                            pw.Text('- ${currencyFormat.format(returnAmount)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Divider(thickness: 0.5),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL BAYAR', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                          pw.Text(
                            currencyFormat.format(transaction.finalAmount),
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),
                _buildDashedLine(),
                pw.SizedBox(height: 8),

                // Payment Method Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Metode Bayar', style: const pw.TextStyle(fontSize: 10)),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: transaction.paymentMethod.toLowerCase() == 'cash' ? PdfColors.green50 : PdfColors.indigo50,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          transaction.paymentMethod.toUpperCase(),
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: transaction.paymentMethod.toLowerCase() == 'cash' ? PdfColors.green800 : PdfColors.indigo800),
                        ),
                      ),
                    ],
                  ),
                ),

                if (transaction.customerName != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text('Pelanggan: ', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(transaction.customerName!, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      ],
                    ),
                  ),
                ],

                pw.SizedBox(height: 12),

                // QR Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey800,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Center(
                          child: pw.Text('QR', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Scan untuk verifikasi', style: pw.TextStyle(fontSize: 7, color: PdfColors.white)),
                      pw.SizedBox(height: 2),
                      pw.Text(transaction.invoiceNumber, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // Thank You Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('Terima Kasih', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Barang yang sudah dibeli tidak dapat dikembalikan', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),
                pw.Text('www.tokoemasbintang.com', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.SizedBox(height: 2),
                pw.Text('© ${DateTime.now().year} $storeName', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildDashedLine() {
    return pw.Row(
      children: List.generate(
        40,
        (index) => pw.Expanded(
          child: pw.Container(
            height: 1,
            margin: const pw.EdgeInsets.only(right: 2),
            color: PdfColors.grey300,
          ),
        ),
      ),
    );
  }

  static Future<void> printReceipt(Transaction transaction, AppSettings? settings) async {
    final pdf = await generateReceiptPdf(transaction, settings);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<List<Map<String, dynamic>>> getTransactionData(int? transactionId) async {
    final db = await DatabaseService.database;
    if (transactionId == null) return [];

    final items = await db.query('transactionItems', where: 'transactionId = ?', whereArgs: [transactionId]);
    return items;
  }

  // ============ FORMAL INVOICE PDF WITH PAPER SIZE SUPPORT ============
  static Future<void> printFormalInvoice(

    Transaction transaction,
    AppSettings? settings, {
    String? receiverSignatureName,
    String? sellerSignatureName,
    String paperSize = 'letter', // 'letter', 'a4', '76mm', '8inch'
  }) async {

    final pdf = await generateFormalInvoicePdf(
      transaction,
      settings,
      receiverSignatureName: receiverSignatureName,
      sellerSignatureName: sellerSignatureName,
      paperSize: paperSize,
    );

    // Use printing's preview screen (works on Android/Windows when available).
    // This replaces `layoutPdf` which may skip the preview depending on platform/driver.
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      format: paperSize == 'a4'
          ? PdfPageFormat(595.28, 841.89)
          : paperSize == '76mm'
              ? PdfPageFormat(76 * PdfPageFormat.mm, 600 * PdfPageFormat.mm)
              : paperSize == '8inch'
                  ? PdfPageFormat(203.0, 600 * PdfPageFormat.mm)
                  : const PdfPageFormat(684.0, 792.0),
    );
  }


  // ============ FORMAL INVOICE PDF WITH PAPER SIZE SUPPORT ============
  static Future<pw.Document> generateFormalInvoicePdf(
    Transaction transaction,
    AppSettings? settings, {
    String? receiverSignatureName,
    String? sellerSignatureName,
    String paperSize = 'letter',
  }) async {
    final pdf = pw.Document();
    final storeName = settings?.storeName ?? 'TOKO EMAS Bintang';
    final storeAddress = settings?.storeAddress ?? 'Jl. Ahmad Yani No. 10';
    final storePhone = settings?.storePhone ?? '021-1234567';

    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');

    final isSale = transaction.isSale;
    final isTempo = transaction.paymentMethod.toLowerCase() == 'tempo' ||
        transaction.paymentMethod.toLowerCase() == 'credit' ||
        transaction.paymentMethod.toLowerCase() == 'hutang';

    // Select page format based on paper size
    PdfPageFormat pageFormat;
    double contentPadding;
    bool isWideFormat;
    bool isA4;

    switch (paperSize) {
      case 'a4':
        pageFormat = const PdfPageFormat(595.28, 841.89); // A4 in points (portrait)
        contentPadding = 40.0;
        isWideFormat = true;
        isA4 = true;
        break;
      case '76mm':
        pageFormat = PdfPageFormat(76 * PdfPageFormat.mm, 600 * PdfPageFormat.mm);
        contentPadding = 6.0;
        isWideFormat = false;
        isA4 = false;
        break;
      case 'continuous_form':
        // 4-ply carbon transfer continuous form: 9.5" x 11" = 684 x 792 points
        // Optimized margins for dot matrix printer with pin-feed paper
        pageFormat = const PdfPageFormat(684.0, 792.0);
        contentPadding = 24.0;
        isWideFormat = true;
        isA4 = false;
        break;
      case '8inch':
        pageFormat = PdfPageFormat(203.0, 600 * PdfPageFormat.mm);
        contentPadding = 10.0;
        isWideFormat = true;
        isA4 = false;
        break;
      case 'letter':
      default:
        // 9.5" x 11" in inches = 684 x 792 points
        pageFormat = const PdfPageFormat(684.0, 792.0);
        contentPadding = 36.0;
        isWideFormat = true;
        isA4 = false;
        break;
    }

    final bool showTerbilang = isA4 || paperSize == 'letter' || paperSize == 'continuous_form';

    // For continuous forms and letter/A4, use multi-page to handle overflow properly
    final bool useContinuousLayout = paperSize == '8inch' || paperSize == '76mm';
    final bool useCarbon4PlyLayout = paperSize == 'continuous_form';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(contentPadding),
        build: (pw.Context context) {
          if (useCarbon4PlyLayout) {
            return [_buildCarbon4PlyInvoice(
              transaction, storeName, storeAddress, storePhone,
              currencyFormat, dateFormat, isSale, isTempo,
              receiverSignatureName, sellerSignatureName,
            )];
          } else if (useContinuousLayout) {
            return [_buildContinuousInvoice(
              transaction, storeName, storeAddress, storePhone,
              currencyFormat, dateFormat, isSale, isTempo,
              receiverSignatureName, sellerSignatureName,
              contentPadding, isWideFormat, showTerbilang,
            )];
          } else {
            return [_buildA4Invoice(
              transaction, storeName, storeAddress, storePhone,
              currencyFormat, dateFormat, isSale, isTempo,
              receiverSignatureName, sellerSignatureName,
              contentPadding, showTerbilang,
            )];
          }
        },
      ),
    );

    return pdf;
  }

  // ============ A4 / LETTER INVOICE LAYOUT ============
  static pw.Widget _buildA4Invoice(
    Transaction transaction,
    String storeName,
    String storeAddress,
    String storePhone,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    bool isSale,
    bool isTempo,
    String? receiverSignatureName,
    String? sellerSignatureName,
    double contentPadding,
    bool showTerbilang,
  ) {
    // No extra padding here - it's handled by MultiPage/Page margin
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ===== HEADER =====
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(storeName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('$storeAddress\nTelp: $storePhone', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey800,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Text('INVOICE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.SizedBox(height: 2),
                  pw.Text(transaction.invoiceNumber, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 16),

        // ===== TRANSACTION INFO =====
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(isSale ? 'KEPADA (PELANGGAN)' : 'KEPADA (SUPPLIER)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 6),
                    pw.Text(isSale ? (transaction.customerName ?? transaction.outletName ?? '-') : (transaction.supplierName ?? '-'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(isSale ? (transaction.outletAddress ?? '-') : (transaction.supplierAddress ?? '-'), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Telp: ${isSale ? (transaction.outletPhone ?? '-') : (transaction.supplierPhone ?? '-')}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _pdfInfoRow('No. Faktur', transaction.invoiceNumber),
                    _pdfInfoRow('Tgl. Faktur', dateFormat.format(transaction.transactionDate)),
                    if (isTempo && transaction.shipmentDate != null)
                      _pdfInfoRow('Jatuh Tempo', dateFormat.format(transaction.shipmentDate!)),
                    _pdfInfoRow('Tempo', '............ hari', valueColor: PdfColors.orange800),
                    _pdfInfoRow('Mata Uang', 'IDR (Rupiah)'),
                    _pdfInfoRow('Pembayaran', transaction.paymentMethod.toUpperCase()),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // ===== ITEMS TABLE (A4/Letter: Full detail columns) =====
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.5),
          ),
          child: pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: const pw.BoxDecoration(color: PdfColors.grey800),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 30, child: pw.Text('No.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 4, child: pw.Text('NAMA BARANG', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.SizedBox(width: 40, child: pw.Text('QTY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                    pw.SizedBox(width: 40, child: pw.Text('SAT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('HARGA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
                    pw.SizedBox(width: 45, child: pw.Text('DISC%', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                    pw.SizedBox(width: 55, child: pw.Text('DISC Rp', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('NETTO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              // Items
              ...transaction.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final itemTotal = item.price * item.quantity;
                final discPercent = itemTotal > 0 ? (item.itemDiscount / itemTotal * 100) : 0.0;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: index.isOdd ? PdfColors.grey50 : PdfColors.white,
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(width: 30, child: pw.Text('${index + 1}', style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            if (item.returnedQuantity > 0)
                              pw.Text('Retur: ${item.returnedQuantity}', style: pw.TextStyle(fontSize: 8, color: PdfColors.orange700)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 40, child: pw.Text('${item.quantity}', style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.SizedBox(width: 40, child: pw.Text(item.satuan, style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(currencyFormat.format(item.price), style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.SizedBox(
                        width: 45,
                        child: pw.Text(
                          discPercent > 0 ? discPercent.toStringAsFixed(1) + '%' : '-',
                          style: pw.TextStyle(fontSize: 9, color: discPercent > 0 ? PdfColors.green700 : null),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(
                        width: 55,
                        child: pw.Text(
                          item.itemDiscount > 0 ? '- ${currencyFormat.format(item.itemDiscount)}' : '-',
                          style: pw.TextStyle(fontSize: 9, color: item.itemDiscount > 0 ? PdfColors.green700 : null),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(flex: 2, child: pw.Text(currencyFormat.format(item.subtotal), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // ===== RINCIAN + TERBILANG (A4/Letter layout) =====
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Rincian (left)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RINCIAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Jumlah', style: pw.TextStyle(fontSize: 10)),
                            pw.Text(currencyFormat.format(transaction.totalAmount), style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        if (transaction.discount > 0)
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Diskon', style: pw.TextStyle(fontSize: 10)),
                              pw.Text('- ${currencyFormat.format(transaction.discount)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                            ],
                          ),
                        if (isTempo)
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Piutang', style: pw.TextStyle(fontSize: 10)),
                              pw.Text(currencyFormat.format(transaction.finalAmount), style: pw.TextStyle(fontSize: 10, color: PdfColors.orange800)),
                            ],
                          ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text(currencyFormat.format(transaction.finalAmount), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 24),

            // Terbilang (right)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TERBILANG', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green200),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      _numberToWords(transaction.finalAmount).toUpperCase(),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),

        // ===== CATATAN =====
        pw.Text('CATATAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            border: pw.Border.all(color: PdfColors.amber200),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            transaction.notes?.isNotEmpty == true ? transaction.notes! : '........................................................',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),

        pw.SizedBox(height: 24),

        // ===== SIGNATURE =====
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text('PENERIMA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 6),
                  pw.Container(height: 60, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400))),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    (receiverSignatureName != null && receiverSignatureName.isNotEmpty)
                        ? receiverSignatureName
                        : (isSale
                            ? (transaction.outletName ?? transaction.customerName ?? '..........................')
                            : (transaction.supplierName ?? '..........................')),
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(width: 100, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Text('( Penerima )', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ),
            pw.SizedBox(width: 48),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(isSale ? 'PENJUAL / TOKO' : 'PEMBELI / GUDANG', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 6),
                  pw.Container(height: 60, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400))),
                  pw.SizedBox(height: 4),
                  pw.Text(sellerSignatureName ?? storeName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Container(width: 100, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Text('( ${isSale ? "Penjual/Toko" : "Pembeli/Gudang"} )', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 16),

        // ===== DIBUAT OLEH =====
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Dibuat oleh: $storeName', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),
        ),

        pw.SizedBox(height: 16),

        // Footer
        pw.Center(
          child: pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text('Invoice ini sah dan berlaku sebagai bukti transaksi', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ),
      ],
    );
  }

// ============ 4-PLY CARBON TRANSFER CONTINUOUS FORM LAYOUT ============
// Layout untuk kertas continuous form 4-ply (9.5" x 11")
// 1 salinan invoice - pure plain text tanpa border/badge/kotak
  static pw.Widget _buildCarbon4PlyInvoice(
    Transaction transaction,
    String storeName,
    String storeAddress,
    String storePhone,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    bool isSale,
    bool isTempo,
    String? receiverSignatureName,
    String? sellerSignatureName,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ========== SINGLE COPY - PURE PLAIN TEXT ==========
        _buildPlainInvoiceContent(
          transaction: transaction,
          storeName: storeName,
          storeAddress: storeAddress,
          storePhone: storePhone,
          currencyFormat: currencyFormat,
          dateFormat: dateFormat,
          isSale: isSale,
          isTempo: isTempo,
          receiverSignatureName: receiverSignatureName,
          sellerSignatureName: sellerSignatureName,
        ),
      ],
    );
  }

  // Pure plain text invoice - no borders, no badges, no boxes
  static pw.Widget _buildPlainInvoiceContent({
    required Transaction transaction,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required NumberFormat currencyFormat,
    required DateFormat dateFormat,
    required bool isSale,
    required bool isTempo,
    String? receiverSignatureName,
    String? sellerSignatureName,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header - pure text, no box
        pw.Text(storeName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('$storeAddress  |  Telp: $storePhone', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text('INVOICE: ${transaction.invoiceNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),

        pw.SizedBox(height: 6),

        // Customer/Supplier info - pure text
        pw.Text(isSale ? 'KEPADA (PELANGGAN)' : 'KEPADA (SUPPLIER)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(isSale ? (transaction.customerName ?? transaction.outletName ?? '-') : (transaction.supplierName ?? '-'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text(isSale ? (transaction.outletAddress ?? '-') : (transaction.supplierAddress ?? '-'), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text('Telp: ${isSale ? (transaction.outletPhone ?? '-') : (transaction.supplierPhone ?? '-')}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        if (isSale && transaction.salesName != null && transaction.salesName!.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'Sales: ${transaction.salesName}${transaction.salesPhone != null && transaction.salesPhone!.isNotEmpty ? ' - ${transaction.salesPhone}' : ''}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue600),
          ),
        ],


        pw.SizedBox(height: 4),

        // Date info - inline text
        pw.Text('No. Faktur: ${transaction.invoiceNumber}   |   Tgl. Faktur: ${dateFormat.format(transaction.transactionDate)}   |   Pembayaran: ${transaction.paymentMethod.toUpperCase()}', style: pw.TextStyle(fontSize: 9)),
        if (isTempo && transaction.shipmentDate != null)
          pw.Text('Jatuh Tempo: ${dateFormat.format(transaction.shipmentDate!)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.orange800)),

        pw.SizedBox(height: 6),

        // Items header - pure text row
        pw.Row(
          children: [
            pw.SizedBox(width: 20, child: pw.Text('No.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
            pw.Expanded(flex: 4, child: pw.Text('NAMA BARANG', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 28, child: pw.Text('QTY', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
            pw.SizedBox(width: 28, child: pw.Text('SAT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
            pw.Expanded(flex: 2, child: pw.Text('HARGA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
            pw.Expanded(flex: 2, child: pw.Text('SUBTOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          ],
        ),

        // Separator line
        pw.Divider(height: 1, thickness: 0.5),

        // Items rows - plain text, alternating background only
        ...transaction.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.Container(
            color: index.isOdd ? PdfColors.grey50 : PdfColors.white,
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 20, child: pw.Text('${index + 1}', style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.productName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      if (item.berat != null)
                        pw.Text('${item.berat!.toStringAsFixed(2)} gr', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      if (item.returnedQuantity > 0)
                        pw.Text('Retur: ${item.returnedQuantity}', style: pw.TextStyle(fontSize: 8, color: PdfColors.orange700)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 28, child: pw.Text('${item.quantity}', style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                pw.SizedBox(width: 28, child: pw.Text(item.satuan.isNotEmpty ? item.satuan : '-', style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),

                pw.Expanded(flex: 2, child: pw.Text(currencyFormat.format(item.price), style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 2, child: pw.Text(currencyFormat.format(item.subtotal), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
              ],
            ),
          );
        }),

        // Separator line
        pw.Divider(height: 1, thickness: 0.5),

        pw.SizedBox(height: 4),

        // Summary - inline text, no box
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TERBILANG:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_numberToWords(transaction.finalAmount).toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Jumlah', style: pw.TextStyle(fontSize: 10)),
                      pw.Text(currencyFormat.format(transaction.totalAmount), style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  if (transaction.discount > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Diskon', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                        pw.Text('- ${currencyFormat.format(transaction.discount)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                      ],
                    ),
                  pw.Divider(thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text(currencyFormat.format(transaction.finalAmount), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (isTempo && transaction.shipmentDate != null) ...[
                    pw.SizedBox(height: 3),
                    pw.Text('Jatuh Tempo: ${dateFormat.format(transaction.shipmentDate!)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                  ],
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 4),

        // Notes - plain text
        pw.Text('CATATAN: ${transaction.notes?.isNotEmpty == true ? transaction.notes! : '................................................................'}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),

        pw.SizedBox(height: 8),

        // Signature - plain text boxes only (no surrounding border box)
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 36, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400))),
                  pw.SizedBox(height: 3),
                  pw.Text('Penerima', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(receiverSignatureName ?? '..........................', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(width: 32),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 36, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400))),
                  pw.SizedBox(height: 3),
                  pw.Text(isSale ? 'Penjual / Toko' : 'Pembeli / Gudang', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(
                    (sellerSignatureName != null && sellerSignatureName.isNotEmpty)
                        ? sellerSignatureName
                        : storeName,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 6),

        // Footer - plain text
        pw.Text('Dibuat oleh: $storeName  |  Invoice ini sah dan berlaku sebagai bukti transaksi', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    );
  }

// ============ CONTINUOUS FORM INVOICE LAYOUT ============
  static pw.Widget _buildContinuousInvoice(

    Transaction transaction,
    String storeName,
    String storeAddress,
    String storePhone,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    bool isSale,
    bool isTempo,
    String? receiverSignatureName,
    String? sellerSignatureName,
    double contentPadding,
    bool isWideFormat,
    bool showTerbilang,
  ) {
    // For continuous form, use compact single-column layout
    // Note: No extra padding - handled by MultiPage margin
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header Store Info
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(storeName, style: pw.TextStyle(fontSize: isWideFormat ? 16 : 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('$storeAddress - Telp: $storePhone', style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6)),
            ],
          ),
        ),

        pw.SizedBox(height: 4),

        // Invoice Badge + Info Row
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey800,
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('INVOICE', style: pw.TextStyle(fontSize: isWideFormat ? 14 : 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text(transaction.invoiceNumber, style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7, color: PdfColors.white)),
            ],
          ),
        ),

        pw.SizedBox(height: 4),

        // Transaction Info
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(isSale ? 'KEPADA (PELANGGAN)' : 'KEPADA (SUPPLIER)', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 6, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          isSale ? (transaction.customerName ?? transaction.outletName ?? '-') : (transaction.supplierName ?? '-'),
                          style: pw.TextStyle(fontSize: isWideFormat ? 10 : 8, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(isSale ? (transaction.outletAddress ?? '-') : (transaction.supplierAddress ?? '-'), style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6)),
                        pw.Text('Telp: ${isSale ? (transaction.outletPhone ?? '-') : (transaction.supplierPhone ?? '-')}', style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6)),
                        if (isSale && (transaction.salesName != null) && transaction.salesName!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Sales: ${transaction.salesName}${transaction.salesPhone != null && transaction.salesPhone!.isNotEmpty ? ' - ${transaction.salesPhone}' : ''}',
                            style: pw.TextStyle(fontSize: isWideFormat ? 7 : 6, color: PdfColors.blue600),
                          ),
                        ],

                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _pdfInfoRow('No. Faktur', transaction.invoiceNumber, fontSize: isWideFormat ? 8 : 6),
                        _pdfInfoRow('Tgl. Faktur', dateFormat.format(transaction.transactionDate), fontSize: isWideFormat ? 8 : 6),
                        if (isTempo && transaction.shipmentDate != null)
                          _pdfInfoRow('Jatuh Tempo', dateFormat.format(transaction.shipmentDate!), fontSize: isWideFormat ? 8 : 6),
                        _pdfInfoRow('Pembayaran', transaction.paymentMethod.toUpperCase(), fontSize: isWideFormat ? 8 : 6),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 4),

        // Items Table Header
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: isWideFormat ? 4 : 3, horizontal: isWideFormat ? 6 : 4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey800),
          child: pw.Row(
            children: [
              pw.Expanded(flex: isWideFormat ? 4 : 3, child: pw.Text('NAMA BARANG', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
              pw.Expanded(child: pw.Text('QTY', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
              pw.Expanded(flex: isWideFormat ? 2 : 2, child: pw.Text('HARGA', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
              pw.Expanded(flex: isWideFormat ? 2 : 2, child: pw.Text('SUBTOTAL', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
            ],
          ),
        ),

        // Items
        ...transaction.items.map((item) => pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: isWideFormat ? 6 : 4, vertical: isWideFormat ? 4 : 3),
          decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: PdfColors.grey300), right: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: isWideFormat ? 4 : 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.productName, style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7, fontWeight: pw.FontWeight.bold)),
                    if (item.berat != null)
                      pw.Text('${item.berat!.toStringAsFixed(2)} gr', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Text('${item.quantity}', style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7), textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: isWideFormat ? 2 : 2,
                child: pw.Text(currencyFormat.format(item.price), style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7), textAlign: pw.TextAlign.right),
              ),
              pw.Expanded(
                flex: isWideFormat ? 2 : 2,
                child: pw.Text(currencyFormat.format(item.subtotal), style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        )),

        // Bottom border for items
        pw.Container(height: 1, color: PdfColors.black),

        pw.SizedBox(height: 4),

        // Summary
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Jumlah:', style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7)),
                  pw.Text(currencyFormat.format(transaction.totalAmount), style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7)),
                ],
              ),
              if (transaction.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Diskon:', style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7)),
                    pw.Text('- ${currencyFormat.format(transaction.discount)}', style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7, color: PdfColors.green)),
                  ],
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: isWideFormat ? 12 : 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(currencyFormat.format(transaction.finalAmount), style: pw.TextStyle(fontSize: isWideFormat ? 12 : 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (isTempo) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Tempo:', style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7, fontWeight: pw.FontWeight.bold)),
                      pw.Text(dateFormat.format(transaction.shipmentDate ?? DateTime.now()), style: pw.TextStyle(fontSize: isWideFormat ? 9 : 7, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        pw.SizedBox(height: 4),

        // Terbilang (if enabled)
        if (showTerbilang) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Text(
              'TERBILANG: ${_numberToWords(transaction.finalAmount).toUpperCase()}',
              style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
        ],

        // Notes
        if (transaction.notes?.isNotEmpty == true) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Text('CATATAN: ${transaction.notes}', style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6)),
          ),
          pw.SizedBox(height: 4),
        ],

        // Signature
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: isWideFormat ? 40 : 30, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black))),
                  pw.SizedBox(height: 4),
                  pw.Text('Penerima', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5)),
                  pw.Text(receiverSignatureName ?? '..........................', style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(width: isWideFormat ? 20 : 12),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: isWideFormat ? 40 : 30, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black))),
                  pw.SizedBox(height: 4),
                  pw.Text(isSale ? 'Penjual / Toko' : 'Pembeli / Gudang', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5)),
                  pw.Text(
                    (sellerSignatureName != null && sellerSignatureName.isNotEmpty)
                        ? sellerSignatureName
                        : storeName,
                    style: pw.TextStyle(fontSize: isWideFormat ? 8 : 6, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 4),

        // Footer
        pw.Center(
          child: pw.Text('Invoice ini sah dan berlaku sebagai bukti transaksi', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5, color: PdfColors.grey600)),
        ),

        // Cut mark for 3-ply paper
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5, style: pw.BorderStyle.dashed),
            ),
            child: pw.Text('= = = POTONG DI SINI = = =', style: pw.TextStyle(fontSize: isWideFormat ? 7 : 5, color: PdfColors.grey400)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _pdfInfoRow(String label, String value, {double fontSize = 8, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  static String _numberToWords(double number) {
    if (number <= 0) return 'nol rupiah';
    final units = ['', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan', 'sepuluh', 'sebelas'];
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
    return convert(intPart).trim().replaceAll('  ', ' ') + ' rupiah';
  }
}
