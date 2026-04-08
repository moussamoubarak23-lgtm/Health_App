import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  static Future<pw.Font> _getFont() async {
    return await PdfGoogleFonts.plusJakartaSansRegular();
  }

  static Future<pw.Font> _getFontBold() async {
    return await PdfGoogleFonts.plusJakartaSansBold();
  }

  static Future<void> generateAndPrintCertificate({
    required String doctorName,
    required String patientName,
    required String content,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final fontBold = await _getFontBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Dr. $doctorName", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Médecin Généraliste"),
                      ],
                    ),
                    pw.Text(DateFormat('dd/MM/yyyy').format(date)),
                  ],
                ),
                pw.SizedBox(height: 50),
                pw.Center(
                  child: pw.Text("CERTIFICAT MEDICAL",
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                ),
                pw.SizedBox(height: 50),
                pw.Paragraph(
                  text: "Je soussigné, Dr. $doctorName, certifie avoir examiné ce jour M./Mme/Mlle $patientName.",
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 20),
                pw.Paragraph(
                  text: content,
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 50),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    children: [
                      pw.Text("Signature et Cachet"),
                      pw.SizedBox(height: 60),
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<File> generateQrPdfFile({
    required String patientName,
    required String qrData,
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text("CARTE PATIENT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(patientName, style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 180,
                  height: 180,
                ),
                pw.SizedBox(height: 15),
                pw.Text("Dossier Médical Portable", style: pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/carte_qr_${patientName.replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> generateAndPrintQrCard({
    required String patientName,
    required String qrData,
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text("CARTE PATIENT", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(patientName, style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 140,
                  height: 140,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Dossier Médical Portable", style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<File> generatePatientReportFile({
    required Map patient,
    required List records,
    required List measurements,
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final fontBold = await _getFontBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("DOSSIER MEDICAL COMPLET", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text("INFORMATIONS PATIENT", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Bullet(text: "Nom: ${patient['name']}"),
          pw.Bullet(text: "CIN: ${patient['patient_code'] ?? '—'}"),
          pw.Bullet(text: "Téléphone: ${patient['phone'] ?? '—'}"),
          pw.Bullet(text: "Âge: ${patient['age'] ?? 0} ans"),
          pw.Bullet(text: "N° Dossier: ${patient['medical_file_number'] ?? '—'}"),
          pw.SizedBox(height: 30),
          pw.Text("HISTORIQUE DES CONSULTATIONS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          ...records.map((r) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Date: ${r['date_consultation']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Motif: ${r['motif']}"),
                if (r['diagnostic'] != null && r['diagnostic'] != "false") pw.Text("Diagnostic: ${r['diagnostic']}"),
                if (r['prescription'] != null && r['prescription'] != "false") pw.Text("Prescription: ${r['prescription']}"),
                pw.SizedBox(height: 5),
              ],
            ),
          )),
          pw.SizedBox(height: 30),
          pw.Text("MESURES DE TENSION", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Table.fromTextArray(
            headers: ["Date", "Systolique", "Diastolique"],
            data: measurements.map((m) => [
              m['date_mesure'].toString().substring(0, 10),
              "${m['systolique']} mmHg",
              "${m['diastolique']} mmHg",
            ]).toList(),
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/rapport_${patient['name'].toString().replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> generateAndPrintPatientReport({
    required Map patient,
    required List records,
    required List measurements,
  }) async {
    final file = await generatePatientReportFile(patient: patient, records: records, measurements: measurements);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => file.readAsBytesSync());
  }
}
