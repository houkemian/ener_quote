import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// 🌟 引入刚生成的实体多语言文件
import '../l10n/app_localizations.dart';
import 'package:http/http.dart' as http; // 🌟 引入 http 库

class PdfExport {
  static const double _revDirectSolar = 2150.00;
  static const double _revTou = 1840.00;
  static const double _revPeakShaving = 1069.16;
  static const double _revBackup = 4500.00;

  static Future<Uint8List> generateAndPrintProposal({
    required AppLocalizations l10n,
    required String companyName,
    required String logoUrl,
    required bool isProUser,
    required double pvCapacity,
    required double batteryCapacity,
    required double totalCapex,
    required double npv,
    required double irr,
    required double payback,
    required List<dynamic> fullCashFlowData,
  }) async {
    final effectiveCompanyName = isProUser ? companyName : "EnerQuote System";
    final effectiveLogoUrl = isProUser ? logoUrl : "";
    print("👉 [3. PDF 引擎] 最终传进 PDF 引擎的 Logo 长度: ${effectiveLogoUrl.length}");
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

    if (effectiveLogoUrl.isNotEmpty) {
      try {
        if (effectiveLogoUrl.startsWith('http')) {
          final response = await http.get(
            Uri.parse(effectiveLogoUrl),
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
          String base64String = effectiveLogoUrl.contains(',') ? effectiveLogoUrl.split(',').last : effectiveLogoUrl;
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
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          // FREE 用户：每一页都覆盖全局浅色对角水印
          buildBackground: (context) =>
              isProUser ? pw.SizedBox() : _buildFreeWatermark(),
        ),
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
                        effectiveCompanyName,
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
        // 🌟 页脚：按订阅等级切换品牌与声明
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isProUser ? l10n.pdfConfidential : "EnerQuote System",
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                  pw.Text(
                    l10n.pdfPageOf(context.pageNumber.toString(), context.pagesCount.toString()),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => isProUser
            ? _buildProSections(
                l10n: l10n,
                pvCapacity: pvCapacity,
                batteryCapacity: batteryCapacity,
                totalCapex: totalCapex,
                npv: npv,
                irr: irr,
                payback: payback,
                fullCashFlowData: fullCashFlowData,
              )
            : _buildFreeSections(
                l10n: l10n,
                pvCapacity: pvCapacity,
                batteryCapacity: batteryCapacity,
                totalCapex: totalCapex,
              ),
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

  // SaaS 付费墙：FREE 版只展示基础物理方案，并用占位内容提示升级。
  static List<pw.Widget> _buildFreeSections({
    required AppLocalizations l10n,
    required double pvCapacity,
    required double batteryCapacity,
    required double totalCapex,
  }) {
    return [
      pw.SizedBox(height: 20),
      pw.Text(l10n.pdfProposalTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      _buildSystemConfigurationSection(
        l10n: l10n,
        pvCapacity: pvCapacity,
        batteryCapacity: batteryCapacity,
        totalCapex: totalCapex,
      ),
      pw.SizedBox(height: 20),
      _buildFinancialPaywallPlaceholder(),
      pw.SizedBox(height: 20),
      _buildEmsBlurPlaceholder(_year1EstimatedSavings()),
    ];
  }

  // PRO 版完整渲染所有财务与现金流内容。
  static List<pw.Widget> _buildProSections({
    required AppLocalizations l10n,
    required double pvCapacity,
    required double batteryCapacity,
    required double totalCapex,
    required double npv,
    required double irr,
    required double payback,
    required List<dynamic> fullCashFlowData,
  }) {
    return [
      pw.SizedBox(height: 20),
      pw.Text(l10n.pdfProposalTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      _buildSystemConfigurationSection(
        l10n: l10n,
        pvCapacity: pvCapacity,
        batteryCapacity: batteryCapacity,
        totalCapex: totalCapex,
      ),
      pw.SizedBox(height: 20),
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
            _buildRevenueStackItem(l10n.pdfRevDirectSolar, l10n.pdfRevDirectSolarDesc, '\$${_revDirectSolar.toStringAsFixed(2)}'),
            pw.Divider(color: PdfColors.grey200),
            _buildRevenueStackItem(l10n.pdfRevTou, l10n.pdfRevTouDesc, '\$${_revTou.toStringAsFixed(2)}', isHighlight: true),
            pw.Divider(color: PdfColors.grey200),
            _buildRevenueStackItem(l10n.pdfRevPeakShaving, l10n.pdfRevPeakShavingDesc, '\$${_revPeakShaving.toStringAsFixed(2)}', isHighlight: true),
            pw.Divider(color: PdfColors.grey200),
            _buildRevenueStackItem(l10n.pdfRevBackup, l10n.pdfRevBackupDesc, '\$${_revBackup.toStringAsFixed(2)}'),
          ],
        ),
      ),
      pw.SizedBox(height: 30),
      pw.Text(l10n.pdfCashFlowTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
      pw.SizedBox(height: 10),
      _buildCashFlowTable(fullCashFlowData, l10n),
    ];
  }

  static pw.Widget _buildSystemConfigurationSection({
    required AppLocalizations l10n,
    required double pvCapacity,
    required double batteryCapacity,
    required double totalCapex,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  static pw.Widget _buildFinancialPaywallPlaceholder() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber700, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text(
        "🔒 Upgrade to PRO to unlock Payback Period & IRR analysis",
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.amber900,
        ),
      ),
    );
  }

  static pw.Widget _buildEmsBlurPlaceholder(double totalSavings) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text(
        "Estimated Year 1 Total Savings: \$${totalSavings.toStringAsFixed(2)}",
        style: pw.TextStyle(
          fontSize: 12,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  static double _year1EstimatedSavings() {
    return _revDirectSolar + _revTou + _revPeakShaving + _revBackup;
  }

  static pw.Widget _buildFreeWatermark() {
    return pw.Center(
      child: pw.Transform.rotate(
        angle: -0.6,
        child: pw.Text(
          "Generated by EnerQuote - Upgrade to PRO for detailed financials",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 38,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey300,
          ),
        ),
      ),
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