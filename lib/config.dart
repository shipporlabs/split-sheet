import 'package:flutter/foundation.dart';

class AppConfig {
  /// Where the web build is hosted. Used in QR codes and PDFs printed from the mobile app.
  /// Change this to your deployed URL (for example a Firebase Hosting or Vercel address).
  static const publicBaseUrl = 'https://usesplitsheet.web.app';

  static String get baseUrl {
    if (!kIsWeb) return publicBaseUrl;
    var s = Uri.base.removeFragment().replace(query: '').toString();
    if (s.endsWith('?')) s = s.substring(0, s.length - 1);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  static String verifyUrl(String sheetId) => '$baseUrl/#/verify/$sheetId';
  static String joinUrl(String code) => '$baseUrl/#/join/$code';
}
