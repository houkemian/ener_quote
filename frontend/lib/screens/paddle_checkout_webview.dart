import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaddleCheckoutWebView extends StatefulWidget {
  final String checkoutUrl;

  const PaddleCheckoutWebView({
    super.key,
    required this.checkoutUrl,
  });

  @override
  State<PaddleCheckoutWebView> createState() => _PaddleCheckoutWebViewState();
}

class _PaddleCheckoutWebViewState extends State<PaddleCheckoutWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('https://api.dothings.one') && url.contains('_ptxn=')) {
              final uri = Uri.tryParse(url);
              final ptxn = uri?.queryParameters['_ptxn'];
              Navigator.of(context).pop(ptxn);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _openFreshCheckout();
  }

  Future<void> _openFreshCheckout() async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();
    await _controller.clearCache();
    await _controller.clearLocalStorage();
    await _controller.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.lock, size: 18),
            SizedBox(width: 8),
            Text('Secure Checkout'),
          ],
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
