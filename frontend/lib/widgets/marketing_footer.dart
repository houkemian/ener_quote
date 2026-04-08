import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Light SaaS footer: copyright left, legal links right (responsive).
class MarketingFooter extends StatelessWidget {
  const MarketingFooter({super.key});

  Future<String> _loadLegalText(String htmlFile) async {
    final html = await rootBundle.loadString('assets/legal/$htmlFile');
    if (html.trim().isEmpty) {
      throw Exception('Failed to load legal content');
    }
    return _htmlToPlainText(html);
  }

  String _htmlToPlainText(String html) {
    return html
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> _showContactDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.contactUs),
          content: const SelectableText(
            'support@dothings.one',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLegalDialog(
    BuildContext context, {
    required String title,
    required String htmlFile,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 700,
            height: 420,
            child: FutureBuilder<String>(
              future: _loadLegalText(htmlFile),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    l10n.legalLoadFailed,
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  );
                }
                return Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      snapshot.data ?? '',
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const footerBg = Color(0xFFF8FAFC);
    const textMuted = Color(0xFF475569);

    Widget link(String label, VoidCallback onTap) {
      return TextButton(
        onPressed: onTap,
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.hovered)) {
              return AppColors.primary;
            }
            return textMuted;
          }),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          minimumSize: MaterialStateProperty.all(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          mouseCursor: MaterialStateProperty.all(SystemMouseCursors.click),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.hovered)) {
              return AppColors.primary.withOpacity(0.06);
            }
            return null;
          }),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      );
    }

    Widget sep() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
        );

    final linksRow = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        link(l10n.contactUs, () => _showContactDialog(context)),
        sep(),
        link(
          l10n.termsOfServiceTitle,
          () => _showLegalDialog(
            context,
            title: l10n.termsOfServiceTitle,
            htmlFile: 'terms.html',
          ),
        ),
        sep(),
        link(
          l10n.privacyPolicyTitle,
          () => _showLegalDialog(
            context,
            title: l10n.privacyPolicyTitle,
            htmlFile: 'privacy.html',
          ),
        ),
        sep(),
        link(
          l10n.refundPolicyTitle,
          () => _showLegalDialog(
            context,
            title: l10n.refundPolicyTitle,
            htmlFile: 'refund.html',
          ),
        ),
      ],
    );

    return Material(
      color: footerBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.footerCopyright,
                        style: const TextStyle(color: textMuted, fontSize: 13),
                      ),
                    ),
                    linksRow,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.footerCopyright,
                    style: const TextStyle(color: textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  linksRow,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
