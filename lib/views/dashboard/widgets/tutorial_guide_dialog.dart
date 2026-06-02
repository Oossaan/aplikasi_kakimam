import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class TutorialGuideDialog extends StatefulWidget {
  const TutorialGuideDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TutorialGuideDialog(),
    );
  }

  @override
  State<TutorialGuideDialog> createState() => _TutorialGuideDialogState();
}

class _TutorialGuideDialogState extends State<TutorialGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Selamat Datang!',
      description: 'Mari pelajari cara menggunakan aplikasi Inventory & POS Smart ini untuk mempermudah bisnis Anda. Panduan ini hanya membutuhkan waktu 1 menit.',
      icon: PhosphorIcons.handWaving(PhosphorIconsStyle.bold),
      color: const Color(0xFF667eea),
    ),
    TutorialStep(
      title: '1. Dashboard Ringkasan',
      description: 'Halaman utama untuk memantau produk, mendeteksi stok yang menipis, menghitung nilai aset gudang, total piutang toko, profit bersih hari ini, serta akses menu dengan cepat.',
      icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.bold),
      color: const Color(0xFF667eea),
    ),
    TutorialStep(
      title: '2. Kasir (POS)',
      description: 'Catat transaksi penjualan kasir secara offline. Dilengkapi tombol penambahan kuantitas cepat, potongan diskon item/faktur, dan berbagai metode pembayaran (Tunai, Transfer, QRIS, Tempo/Utang).',
      icon: PhosphorIcons.cashRegister(PhosphorIconsStyle.bold),
      color: const Color(0xFF10b981),
    ),
    TutorialStep(
      title: '3. Inventory & Produk',
      description: 'Kelola data katalog produk Anda, lakukan penyesuaian stok masuk dan keluar, pantau riwayat mutasi stok, serta ekspor data inventaris ke format Microsoft Excel.',
      icon: PhosphorIcons.package(PhosphorIconsStyle.bold),
      color: const Color(0xFFf59e0b),
    ),
    TutorialStep(
      title: '4. Piutang & Tagihan',
      description: 'Pantau tagihan jatuh tempo penjualan kredit dari outlet pelanggan (piutang) serta catat kewajiban pembayaran belanja Anda ke pihak supplier (hutang).',
      icon: PhosphorIcons.receipt(PhosphorIconsStyle.bold),
      color: const Color(0xFFef4444),
    ),
    TutorialStep(
      title: '5. Pengaturan & PIN',
      description: 'Kustomisasi nama toko, cetak footer nota struk, hubungkan akun rekening/QRIS untuk pembayaran transfer, serta aktifkan PIN keamanan untuk otorisasi pembatalan transaksi.',
      icon: PhosphorIcons.gear(PhosphorIconsStyle.bold),
      color: const Color(0xFF764ba2),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: isMobile ? 480 : 520,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header: Progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Panduan Aplikasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${_currentPage + 1} / ${_steps.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667eea),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Page Content (Slider)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon Badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          color: step.color,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1f2937),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Dot Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (index) {
                final isSelected = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isSelected ? 16 : 6,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (_currentPage > 0) ...[
                  OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Kembali',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _steps.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _steps[_currentPage].color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _steps.length - 1 ? 'Mulai Sekarang' : 'Selanjutnya',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_currentPage == 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Lewati',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
