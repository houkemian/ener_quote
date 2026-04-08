import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../l10n/app_localizations.dart'; // 👈 新增这行
import '../theme/app_colors.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;

  const PdfPreviewScreen({super.key, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pdfPreviewTitle,
          style: const TextStyle(fontSize: 16, color: AppColors.onSurface),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        color: AppColors.background,
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.onSurface.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PdfPreview(
              build: (format) => pdfBytes,
              allowSharing: true,
              allowPrinting: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName:
                  'PV_ESS_Proposal_${DateTime.now().millisecondsSinceEpoch}.pdf',
            ),
          ),
        ),
      ),
    );
  }
}