import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_colors.dart';
import '../widgets/strakata_editorial_background.dart';

class WebViewPage extends StatefulWidget {
  final String title;
  final String url;
  const WebViewPage({super.key, required this.title, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame != true) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: StrakataEditorialBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.title,
              style: GoogleFonts.libreFranklin(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
            actions: [
              IconButton(
                tooltip: 'Otevřít v prohlížeči',
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser_rounded),
              ),
            ],
          ),
          body: Stack(
            children: [
              if (_failed)
                _ErrorState(onRetryInBrowser: _openInBrowser)
              else
                WebViewWidget(controller: _controller),
              if (_loading && !_failed)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.brand,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetryInBrowser});

  final VoidCallback onRetryInBrowser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Stránku se nepodařilo načíst',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreFranklin(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Otevřete ji v prohlížeči, abyste měli přístup k aktuálnímu znění.',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreFranklin(
                fontSize: 14,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetryInBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Otevřít v prohlížeči'),
            ),
          ],
        ),
      ),
    );
  }
}
