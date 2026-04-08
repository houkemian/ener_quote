import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../widgets/legal/legal_iframe_impl_stub.dart'
    if (dart.library.html) '../widgets/legal/legal_iframe_impl_web.dart';

/// In-app legal page: Web loads `web/{htmlFile}` in an iframe; mobile opens production URL.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.htmlFile,
    required this.title,
  });

  final String htmlFile;
  final String title;

  static const String _productionLegalOrigin = 'https://dothings.one';

  Future<void> _openInBrowser() async {
    final uri = Uri.parse('$_productionLegalOrigin/$htmlFile');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
      ),
      backgroundColor: AppColors.background,
      body: kIsWeb
          ? buildLegalHtmlView(htmlFile)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.openInBrowserMessage(title),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _openInBrowser,
                      child: Text(l10n.openInBrowser),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
