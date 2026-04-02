import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// 🌟 引入刚生成的实体多语言文件
import '../l10n/app_localizations.dart';
import 'package:dio/dio.dart'; // 🌟 新增引入
import 'package:http/http.dart' as http; // 🌟 引入 http 库

class PdfExport {
  static Future<Uint8List> generateAndPrintProposal({
    required AppLocalizations l10n,
    required String companyName,
    required String logoUrl,
    required double pvCapacity,
    required double batteryCapacity,
    required double totalCapex,
    required double npv,
    required double irr,
    required double payback,
    required List<dynamic> fullCashFlowData,
  }) async {
    print("👉 [3. PDF 引擎] 最终传进 PDF 引擎的 Logo 长度: ${logoUrl.length}");
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansSC-VariableFont_wght.ttf'));
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,       // 👈 填补 Helvetica-Bold 的漏洞
        italic: font,     // 👈 填补 Helvetica-Oblique 的漏洞
        boldItalic: font,
      ),
    );

    // 🌟 核心排错法：把错误信息存起来，等下直接印在 PDF 上！
    pw.ImageProvider? logoImage;
    String logoErrorMessage = "";

    if (logoUrl.isNotEmpty) {
      try {
        if (logoUrl.startsWith('http')) {
          final response = await http.get(
            Uri.parse(logoUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'image/png,image/jpeg,image/*;q=0.8',
            },
          ).timeout(const Duration(seconds: 8)); // 增加超时判定

          if (response.statusCode == 200) {
            logoImage = pw.MemoryImage(response.bodyBytes);
          } else {
            logoErrorMessage = "HTTP Err: ${response.statusCode}";
          }
        } else {
          // 🌟 Base64 终极净化：剔除空白，并自动补齐末尾缺失的等号！
          String base64String = logoUrl.contains(',') ? logoUrl.split(',').last : logoUrl;
          base64String = base64String.replaceAll(RegExp(r'\s+'), '');

          int padding = base64String.length % 4;
          if (padding > 0) {
            base64String += '=' * (4 - padding); // 自动补齐，防止 FormatException
          }

          logoImage = pw.MemoryImage(base64Decode(base64String));
        }
      } catch (e) {
        // 抓取异常的第一行，准备印在 PDF 上
        logoErrorMessage = "Err: ${e.toString().split('\n')[0]}";
        print("🔥 Logo 加载异常: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // 🌟 如果图片加载成功，画图片
                      if (logoImage != null) ...[
                        pw.Image(logoImage, height: 32),
                        pw.SizedBox(width: 12),
                      ]
                      // 🌟 如果失败了，把红色的错误代码印在公司名字前面！
                      else if (logoErrorMessage.isNotEmpty) ...[
                        pw.Text(
                          logoErrorMessage,
                          style: pw.TextStyle(color: PdfColors.red, fontSize: 10),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                      ),
                    ],
                  ),
                  pw.Text(
                    l10n.pdfDate(DateTime.now().toString().split(' ')[0]),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 2, color: PdfColors.teal800),
            ],
          );
        },
        // 🌟 页脚：多语言免责与页码
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(l10n.pdfConfidential, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  pw.Text(
                    l10n.pdfPageOf(context.pageNumber.toString(), context.pagesCount.toString()),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          // 1. 报告主标题
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfProposalTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),

          // 2. 核心系统配置
          pw.Text(l10n.pdfSystemConfig, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.SizedBox(height: 10),
          pw.Bullet(text: '${l10n.pdfPvArray}: ${pvCapacity.toStringAsFixed(1)} kWp'),
          pw.Bullet(text: '${l10n.pdfEssBattery}: ${batteryCapacity.toStringAsFixed(1)} kWh'),
          pw.Bullet(text: l10n.pdfGridPolicy),
          pw.SizedBox(height: 8),
          pw.Text(
            '${l10n.pdfTotalCapex}: \$${totalCapex.toStringAsFixed(0)}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
          ),
          pw.SizedBox(height: 20),

          // 3. 高级财务指标 (KPI)
          pw.Text(l10n.pdfFinancialHighlights, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiItem(l10n.pdfNpv, '\$${npv.toStringAsFixed(0)}'),
                _buildKpiItem(l10n.pdfIrr, '${irr.toStringAsFixed(1)}%'),
                _buildKpiItem(l10n.pdfPayback, '${payback.toStringAsFixed(1)} ${l10n.pdfYears}'),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // 4. EMS 策略拆解
          pw.Text(l10n.pdfEmsStrategyTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.teal200, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(l10n.pdfEmsStrategyDesc, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
                _buildRevenueStackItem(l10n.pdfRevDirectSolar, l10n.pdfRevDirectSolarDesc, '\$2,150.00'),
                pw.Divider(color: PdfColors.grey200),
                _buildRevenueStackItem(l10n.pdfRevTou, l10n.pdfRevTouDesc, '\$1,840.00', isHighlight: true),
                pw.Divider(color: PdfColors.grey200),
                _buildRevenueStackItem(l10n.pdfRevPeakShaving, l10n.pdfRevPeakShavingDesc, '\$1,069.16', isHighlight: true),
                pw.Divider(color: PdfColors.grey200),
                _buildRevenueStackItem(l10n.pdfRevBackup, l10n.pdfRevBackupDesc, '\$4,500.00'),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // 5. 现金流表
          pw.Text(l10n.pdfCashFlowTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.SizedBox(height: 10),
          _buildCashFlowTable(fullCashFlowData, l10n),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildKpiItem(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
      ],
    );
  }

  static pw.Widget _buildCashFlowTable(List<dynamic> cashFlow, AppLocalizations l10n) {
    return pw.TableHelper.fromTextArray(
      context: null,
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: [
        l10n.pdfCfYear,
        l10n.pdfCfEnergySavings,
        l10n.pdfCfBackupValue,
        l10n.pdfCfOmBattery,
        l10n.pdfCfDebtService,
        l10n.pdfCfNetCashFlow,
        l10n.pdfCfCumulative,
      ],
      data: List<List<String>>.generate(cashFlow.length, (index) {
        final row = cashFlow[index];
        return [
          '${row['year']}',
          '\$${(row['energy_savings_revenue'] as num).toStringAsFixed(0)}',
          '\$${(row['backup_power_value'] as num).toStringAsFixed(0)}',
          '-\$${(row['opex_and_replacement'] as num).toStringAsFixed(0)}',
          '-\$${(row['debt_service'] as num).toStringAsFixed(0)}',
          '\$${(row['net_cash_flow'] as num).toStringAsFixed(0)}',
          '\$${(row['cumulative_cash_flow'] as num).toStringAsFixed(0)}',
        ];
      }),
    );
  }

  static pw.Widget _buildRevenueStackItem(String title, String desc, String amount, {bool isHighlight = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 10, fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal, color: isHighlight ? PdfColors.teal900 : PdfColors.black),
              ),
              pw.SizedBox(height: 2),
              pw.Text(desc, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.Text(
          amount,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: isHighlight ? PdfColors.teal700 : PdfColors.black),
        ),
      ],
    );
  }
}