import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown/markdown.dart' as md;

class WebviewPage extends StatefulWidget {
  const WebviewPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final markdown = await rootBundle.loadString(widget.assetPath);
    final htmlBody = md.markdownToHtml(markdown);

    final html = '''
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      body {
        margin: 0;
        padding: 20px 18px 28px;
        background: #F7F8FC;
        color: #1F2937;
        font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
        line-height: 1.7;
      }
      h1, h2, h3 {
        color: #111827;
        margin-top: 22px;
      }
      h1 {
        font-size: 24px;
      }
      h2 {
        font-size: 18px;
      }
      p, li {
        font-size: 15px;
      }
      ul {
        padding-left: 20px;
      }
      .container {
        background: #FFFFFF;
        border-radius: 18px;
        padding: 18px 16px;
        box-shadow: 0 8px 24px rgba(17, 24, 39, 0.06);
      }
    </style>
  </head>
  <body>
    <div class="container">
      $htmlBody
    </div>
  </body>
</html>
''';

    if (!mounted) return;
    setState(() {
      _htmlContent = html;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
      body: _htmlContent == null
          ? const Center(child: CircularProgressIndicator())
          : InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _htmlContent!,
                baseUrl: WebUri('about:blank'),
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
            ),
    );
  }
}
