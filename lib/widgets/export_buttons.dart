import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../utils/const_colors.dart';

class ExportButtons extends StatelessWidget {
  final VoidCallback? onExcel;
  final VoidCallback? onPrint;
  final String title;

  const ExportButtons({
    super.key,
    this.onExcel,
    this.onPrint,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onExcel,
            icon: Icon(PhosphorIcons.fileXls(PhosphorIconsStyle.bold)),
            label: Text('Excel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: ConstColors.green400, width: 2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onPrint,
            icon: Icon(PhosphorIcons.printer(PhosphorIconsStyle.bold)),
            label: Text('Print'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ConstColors.green600,
            ),
          ),
        ),
      ],
    );
  }
}

