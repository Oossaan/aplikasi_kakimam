import 'package:flutter/material.dart';
import '../../services/settings_service.dart';

/// Dialog untuk verifikasi PIN sebelum edit harga atau diskon
class PINVerificationDialog extends StatefulWidget {
  final bool isPinEnabled;
  final Function(bool success) onVerified;
  final String title;
  final String message;

  const PINVerificationDialog({
    Key? key,
    required this.isPinEnabled,
    required this.onVerified,
    this.title = 'Verifikasi PIN',
    this.message = 'Masukkan PIN untuk melanjutkan',
  }) : super(key: key);

  @override
  State<PINVerificationDialog> createState() => _PINVerificationDialogState();
}

class _PINVerificationDialogState extends State<PINVerificationDialog> {
  late TextEditingController _pinController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'PIN tidak boleh kosong';
      });
      return;
    }

    if (!widget.isPinEnabled) {
      setState(() {
        _errorMessage = 'PIN belum diaktifkan di pengaturan';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settingsService = SettingsService();
      final isValid = await settingsService.verifyPin(_pinController.text);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (isValid) {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onVerified(true);
          }
        } else {
          setState(() {
            _errorMessage = 'PIN salah';
            _pinController.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: !_showPin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'PIN',
              hintText: 'Masukkan PIN',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPin ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _showPin = !_showPin;
                  });
                },
              ),
              errorText: _errorMessage,
              counterText: '',
            ),
            onSubmitted: (_) {
              if (!_isLoading) {
                _verifyPin();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verifikasi'),
        ),
      ],
    );
  }
}

/// Dialog untuk edit harga dengan PIN verification
class EditPriceDialog extends StatefulWidget {
  final double currentPrice;
  final bool isPinEnabled;
  final Function(double newPrice) onConfirm;
  final String productName;

  const EditPriceDialog({
    Key? key,
    required this.currentPrice,
    required this.isPinEnabled,
    required this.onConfirm,
    required this.productName,
  }) : super(key: key);

  @override
  State<EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<EditPriceDialog> {
  late TextEditingController _priceController;
  bool _pinVerified = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentPrice.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _showPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PINVerificationDialog(
        isPinEnabled: widget.isPinEnabled,
        onVerified: (success) {
          if (success) {
            setState(() {
              _pinVerified = true;
            });
          }
        },
      ),
    );
  }

  void _handleConfirm() {
    if (widget.isPinEnabled && !_pinVerified) {
      _showPinDialog();
      return;
    }

    final newPrice = double.tryParse(_priceController.text);
    if (newPrice == null || newPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga tidak valid')),
      );
      return;
    }

    Navigator.of(context).pop();
    widget.onConfirm(newPrice);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Harga'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Produk: ${widget.productName}'),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Harga Baru',
              hintText: '0',
              border: OutlineInputBorder(),
              prefixText: 'Rp ',
            ),
          ),
          if (widget.isPinEnabled && !_pinVerified)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diperlukan PIN untuk mengubah harga',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Dialog untuk edit diskon per item
class EditItemDiscountDialog extends StatefulWidget {
  final double itemSubtotal;
  final double currentDiscountNominal;
  final bool isPinEnabled;
  final Function(double discountNominal, double discountPercent) onConfirm;
  final String productName;

  const EditItemDiscountDialog({
    Key? key,
    required this.itemSubtotal,
    required this.currentDiscountNominal,
    required this.isPinEnabled,
    required this.onConfirm,
    required this.productName,
  }) : super(key: key);

  @override
  State<EditItemDiscountDialog> createState() => _EditItemDiscountDialogState();
}

class _EditItemDiscountDialogState extends State<EditItemDiscountDialog> {
  late TextEditingController _nominalController;
  late TextEditingController _percentController;
  bool _pinVerified = false;
  String _inputMode = 'nominal'; // 'nominal' or 'percent'

  @override
  void initState() {
    super.initState();
    _nominalController = TextEditingController(
      text: widget.currentDiscountNominal.toStringAsFixed(0),
    );
    _percentController = TextEditingController(
      text: widget.itemSubtotal > 0
          ? ((widget.currentDiscountNominal / widget.itemSubtotal) * 100)
              .toStringAsFixed(2)
          : '0',
    );
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  void _updateFromNominal(String value) {
    final nominal = double.tryParse(value) ?? 0;
    if (widget.itemSubtotal > 0) {
      final percent = (nominal / widget.itemSubtotal) * 100;
      _percentController.text = percent.toStringAsFixed(2);
    }
  }

  void _updateFromPercent(String value) {
    final percent = double.tryParse(value) ?? 0;
    final nominal = widget.itemSubtotal * (percent / 100);
    _nominalController.text = nominal.toStringAsFixed(0);
  }

  void _showPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PINVerificationDialog(
        isPinEnabled: widget.isPinEnabled,
        onVerified: (success) {
          if (success) {
            setState(() {
              _pinVerified = true;
            });
          }
        },
      ),
    );
  }

  void _handleConfirm() {
    if (widget.isPinEnabled && !_pinVerified) {
      _showPinDialog();
      return;
    }

    final nominalDiscount = double.tryParse(_nominalController.text) ?? 0;
    final percentDiscount = double.tryParse(_percentController.text) ?? 0;

    if (nominalDiscount < 0 || percentDiscount < 0 || percentDiscount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diskon tidak valid')),
      );
      return;
    }

    Navigator.of(context).pop();
    widget.onConfirm(nominalDiscount, percentDiscount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Diskon Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produk: ${widget.productName}'),
            const SizedBox(height: 8),
            Text(
              'Subtotal: Rp ${widget.itemSubtotal.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Nominal Input
            TextField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              onChanged: _updateFromNominal,
              decoration: InputDecoration(
                labelText: 'Diskon (Rp)',
                hintText: '0',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 12),
            // Percent Input
            TextField(
              controller: _percentController,
              keyboardType: TextInputType.number,
              onChanged: _updateFromPercent,
              decoration: InputDecoration(
                labelText: 'Diskon (%)',
                hintText: '0',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            if (widget.isPinEnabled && !_pinVerified)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Diperlukan PIN untuk mengubah diskon',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Dialog untuk edit diskon keseluruhan
class EditOverallDiscountDialog extends StatefulWidget {
  final double subtotal;
  final double currentDiscountNominal;
  final bool isPinEnabled;
  final Function(double discountNominal, double discountPercent) onConfirm;

  const EditOverallDiscountDialog({
    Key? key,
    required this.subtotal,
    required this.currentDiscountNominal,
    required this.isPinEnabled,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<EditOverallDiscountDialog> createState() =>
      _EditOverallDiscountDialogState();
}

class _EditOverallDiscountDialogState extends State<EditOverallDiscountDialog> {
  late TextEditingController _nominalController;
  late TextEditingController _percentController;
  bool _pinVerified = false;

  @override
  void initState() {
    super.initState();
    _nominalController = TextEditingController(
      text: widget.currentDiscountNominal.toStringAsFixed(0),
    );
    _percentController = TextEditingController(
      text: widget.subtotal > 0
          ? ((widget.currentDiscountNominal / widget.subtotal) * 100)
              .toStringAsFixed(2)
          : '0',
    );
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  void _updateFromNominal(String value) {
    final nominal = double.tryParse(value) ?? 0;
    if (widget.subtotal > 0) {
      final percent = (nominal / widget.subtotal) * 100;
      _percentController.text = percent.toStringAsFixed(2);
    }
  }

  void _updateFromPercent(String value) {
    final percent = double.tryParse(value) ?? 0;
    final nominal = widget.subtotal * (percent / 100);
    _nominalController.text = nominal.toStringAsFixed(0);
  }

  void _showPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PINVerificationDialog(
        isPinEnabled: widget.isPinEnabled,
        onVerified: (success) {
          if (success) {
            setState(() {
              _pinVerified = true;
            });
          }
        },
      ),
    );
  }

  void _handleConfirm() {
    if (widget.isPinEnabled && !_pinVerified) {
      _showPinDialog();
      return;
    }

    final nominalDiscount = double.tryParse(_nominalController.text) ?? 0;
    final percentDiscount = double.tryParse(_percentController.text) ?? 0;

    if (nominalDiscount < 0 || percentDiscount < 0 || percentDiscount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diskon tidak valid')),
      );
      return;
    }

    Navigator.of(context).pop();
    widget.onConfirm(nominalDiscount, percentDiscount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Diskon Keseluruhan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtotal: Rp ${widget.subtotal.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Nominal Input
            TextField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              onChanged: _updateFromNominal,
              decoration: InputDecoration(
                labelText: 'Diskon (Rp)',
                hintText: '0',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 12),
            // Percent Input
            TextField(
              controller: _percentController,
              keyboardType: TextInputType.number,
              onChanged: _updateFromPercent,
              decoration: InputDecoration(
                labelText: 'Diskon (%)',
                hintText: '0',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            if (widget.isPinEnabled && !_pinVerified)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Diperlukan PIN untuk mengubah diskon',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
