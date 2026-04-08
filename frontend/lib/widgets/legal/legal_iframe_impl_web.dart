// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = {};

/// Embeds a static HTML asset from the Flutter `web/` folder (same origin).
Widget buildLegalHtmlView(String htmlFile) {
  final viewType = 'legal_iframe_${htmlFile.hashCode}_$htmlFile';
  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    final src = Uri.base.resolve(htmlFile).toString();
    ui_web.platformViewRegistry.registerViewFactory(viewType, () {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
