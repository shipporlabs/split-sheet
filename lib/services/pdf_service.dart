import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config.dart';
import '../models/models.dart';
import '../utils/format.dart';

/// Builds the signed split sheet PDF with a verification QR code.
class PdfService {
  static Future<Uint8List> build(SplitSheet s, {required String networkName}) async {
    pw.ThemeData? theme;
    try {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      theme = null; // Offline: fall back to the built-in Helvetica.
    }
    final mono = pw.Font.courier();
    final amber = PdfColor.fromHex('#B07A12');
    final grey = PdfColor.fromHex('#6B665C');
    final verifyUrl = AppConfig.verifyUrl(s.id);

    pw.Widget cell(String text, {bool bold = false, bool right = false, PdfColor? color}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : null, color: color),
          ),
        );

    pw.Widget proofLine(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 110, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: grey))),
            pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: mono, fontSize: 8))),
          ]),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3EFE7')),
        children: [
          cell('Name', bold: true),
          cell('Role', bold: true),
          cell('Composition', bold: true, right: true),
          cell('Master', bold: true, right: true),
          cell('Signed', bold: true, right: true),
        ],
      ),
      for (var i = 0; i < s.contributors.length; i++)
        pw.TableRow(children: [
          cell(s.contributors[i].stageName.isEmpty
              ? s.contributors[i].name
              : '${s.contributors[i].name} (${s.contributors[i].stageName})'),
          cell(s.contributors[i].rolesLabel),
          cell(fmtPct(s.contributors[i].compositionBps), right: true),
          cell(fmtPct(s.contributors[i].masterBps), right: true),
          cell(s.signatureFor(i) == null ? 'Not signed' : fmtDateTime(s.signatureFor(i)!.signedAt), right: true),
        ]),
    ];

    final doc = pw.Document(title: 'Split sheet - ${s.title}', author: 'Split Sheet');
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('SPLIT SHEET', style: pw.TextStyle(fontSize: 9, color: amber, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                pw.SizedBox(height: 6),
                pw.Text(s.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Session ${fmtDate(s.sessionDate)}${s.studio.isEmpty ? '' : ' - ${s.studio}'}${s.genre.isEmpty ? '' : ' - ${s.genre}'}',
                  style: pw.TextStyle(fontSize: 10, color: grey),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Version ${s.version} - Status: ${s.status.name}${s.executedAt == null ? '' : ' on ${fmtDateTime(s.executedAt!)}'}',
                  style: pw.TextStyle(fontSize: 10, color: grey),
                ),
              ]),
            ),
            pw.Column(children: [
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: verifyUrl, width: 84, height: 84),
              pw.SizedBox(height: 4),
              pw.Text('Scan to verify', style: pw.TextStyle(fontSize: 8, color: grey)),
            ]),
          ]),
          pw.SizedBox(height: 22),
          pw.Text('Parties and shares', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D8D2C4'), width: 0.5),
            columnWidths: {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(1.8),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1.6),
            },
            children: rows,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Composition is the song itself (lyrics and melody). Master is this specific recording.',
            style: pw.TextStyle(fontSize: 8.5, color: grey),
          ),
          pw.SizedBox(height: 22),
          pw.Text('Proof', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          proofLine('Sheet ID', s.id),
          proofLine('Document hash', s.docHash),
          proofLine('Audio file', s.audioName ?? '-'),
          proofLine('Audio fingerprint', s.audioHash ?? '-'),
          proofLine('Creation record', s.createdTxHash ?? '-'),
          proofLine('Network', networkName),
          proofLine('Verify at', verifyUrl),
          pw.SizedBox(height: 14),
          pw.Text('Signatures', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          for (final sig in s.signatures)
            proofLine(
              s.contributors[sig.contributorIndex].displayName,
              '${fmtDateTime(sig.signedAt)}  ${sig.signature}',
            ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F7F3EA')),
            child: pw.Text(
              'This document records the parties\' agreement on ownership shares at the time of signing. '
              'It is not legal advice and does not replace a publishing, label or distribution contract.',
              style: pw.TextStyle(fontSize: 8.5, color: grey),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> share(SplitSheet s, {required String networkName}) async {
    final bytes = await build(s, networkName: networkName);
    final name = slug(s.title).isEmpty ? 'split-sheet' : 'split-sheet-${slug(s.title)}';
    await Printing.sharePdf(bytes: bytes, filename: '$name-v${s.version}.pdf');
  }
}
