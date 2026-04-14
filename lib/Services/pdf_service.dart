import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  static Future<pw.Font> _getArabicFont() async {
    return await PdfGoogleFonts.amiriRegular();
  }

  static Future<pw.Font> _getArabicFontBold() async {
    return await PdfGoogleFonts.amiriBold();
  }

  static Future<void> generateAndPrintCertificate({
    required String doctorName,
    required String patientName,
    required String content,
    required DateTime date,
    String cabinetAddress = "",
    String cabinetPhone = "",
    String cabinetEmail = "",
    String cabinetFax = "",
    String? logoPath,
    String specialtyFr = "Médecin Généraliste",
    String experienceFr = "",
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final fontBold = await _getFontBold();

    pw.MemoryImage? logoImage;
    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

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
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 58,
                              height: 58,
                              decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle),
                              child: pw.ClipOval(child: pw.Image(logoImage, fit: pw.BoxFit.cover)),
                            )
                          else
                            pw.Container(
                              width: 58,
                              height: 58,
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                border: pw.Border.all(color: PdfColors.grey300),
                              ),
                            ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  " ${doctorName.toUpperCase()}",
                                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  specialtyFr,
                                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                                ),
                                if (experienceFr.trim().isNotEmpty) ...[
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    experienceFr,
                                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "CERTIFICAT MEDICAL",
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Le: ${DateFormat('dd/MM/yyyy').format(date)}",
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 24),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "CERTIFICAT MEDICAL",
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Paragraph(
                  textAlign: pw.TextAlign.justify,
                  text:
                  "Je soussigné, Dr. $doctorName, certifie avoir examiné ce jour M./Mme/Mlle $patientName.",
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 20),
                pw.Paragraph(
                  textAlign: pw.TextAlign.justify,
                  text: content,
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    children: [
                      pw.Text("Signature et Cachet",
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontStyle: pw.FontStyle.italic)),
                      pw.SizedBox(height: 60),
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                              bottom: pw.BorderSide(width: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    "Adresse : $cabinetAddress",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    "Tel : $cabinetPhone${cabinetFax.isNotEmpty ? '  -  Fax : $cabinetFax' : ''}${cabinetEmail.isNotEmpty ? '  -  Email : $cabinetEmail' : ''}",
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateAndPrintPrescription({
    required String doctorName,
    required String patientName,
    required String content,
    required DateTime date,
    String cabinetAddress = "",
    String cabinetPhone = "",
    String cabinetEmail = "",
    String cabinetFax = "",
    String? logoPath,
    String specialtyFr = "Médecin Généraliste",
    String specialtyAr = "طبيب عام",
    String experienceFr = "",
    String experienceAr = "",
  }) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final fontBold = await _getFontBold();
    final fontAr = await _getArabicFont();
    final fontArBold = await _getArabicFontBold();

    pw.MemoryImage? logoImage;
    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20, vertical: 15),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              if (logoImage != null)
                                pw.Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const pw.BoxDecoration(
                                      shape: pw.BoxShape.circle),
                                  child: pw.ClipOval(
                                    child: pw.Image(logoImage,
                                        fit: pw.BoxFit.cover),
                                  ),
                                )
                              else
                                pw.Container(
                                  width: 60,
                                  height: 60,
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    border: pw.Border.all(
                                        color: PdfColors.grey300),
                                  ),
                                ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    "Dr $doctorName",
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text(
                                    specialtyFr,
                                    style:
                                    const pw.TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            experienceFr,
                            style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey800),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "SUR RENDEZ-VOUS",
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Text(
                              "الدكتور $doctorName",
                              style: pw.TextStyle(
                                fontSize: 17,
                                fontWeight: pw.FontWeight.bold,
                                font: fontArBold,
                              ),
                            ),
                          ),
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Text(
                              specialtyAr,
                              style: pw.TextStyle(
                                  fontSize: 11, font: fontAr),
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Container(
                              width: 120,
                              height: 0.8,
                              color: PdfColors.black),
                          pw.SizedBox(height: 5),
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Text(
                              experienceAr,
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: fontAr,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Padding(
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Text(
                  "${cabinetAddress.split(',').last.trim()}, le : ............. / ............. / 20 .............",
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20, vertical: 5),
                child: pw.Divider(
                    thickness: 1.5, color: PdfColors.black),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Text(
                        "Patient : $patientName",
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    ...List<pw.Widget>.from(
                        _buildPrescriptionLines(content)),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 30),
                child: pw.Row(
                  mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 100,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(
                            color: PdfColors.grey400, width: 0.8),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          "Cachet du\nmédecin",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Signature .................................",
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 50),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20),
                child: pw.Column(
                  children: [
                    pw.Divider(
                        thickness: 1, color: PdfColors.black),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Text(
                        "Adresse : $cabinetAddress  -  Tel : $cabinetPhone${cabinetFax.isNotEmpty ? '  -  Fax : $cabinetFax' : ''}",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static List<pw.Widget> _buildPrescriptionLines(String content) {
    final List<pw.Widget> widgets = [];
    final lines =
    content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final int maxLines = lines.length > 2 ? lines.length : 2;

    for (int i = 0; i < maxLines; i++) {
      final String text = i < lines.length ? lines[i] : "";
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 10, vertical: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                "${i + 1})  ",
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13),
              ),
              pw.Expanded(
                child: pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        style: pw.BorderStyle.dotted,
                        width: 1,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  child: pw.Padding(
                    padding:
                    const pw.EdgeInsets.only(bottom: 3, left: 5),
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static Future<File> generateQrPdfFile({
    required String patientName,
    required String qrData,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError("Génération de fichier local non supportée sur Web.");
    }
    final pdf = pw.Document();
    final font = await _getFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text("CARTE PATIENT",
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(patientName,
                    style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 180,
                  height: 180,
                ),
                pw.SizedBox(height: 15),
                pw.Text("Dossier Médical Portable",
                    style: pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        "${output.path}/carte_qr_${patientName.replaceAll(' ', '_')}.pdf");
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
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text("CARTE PATIENT",
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(patientName,
                    style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 140,
                  height: 140,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Dossier Médical Portable",
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<File> generatePatientReportFile({
    required Map patient,
    required List records,
    required List measurements,
    List bodyMeasurements = const [],
  }) async {
    if (kIsWeb) {
      throw UnsupportedError("Génération de fichier local non supportée sur Web.");
    }
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
                pw.Text("DOSSIER MEDICAL COMPLET",
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text("INFORMATIONS PATIENT",
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Bullet(text: "Nom: ${patient['name']}"),
          pw.Bullet(
              text: "CIN: ${patient['patient_code'] ?? '—'}"),
          pw.Bullet(
              text: "Téléphone: ${patient['phone'] ?? '—'}"),
          pw.Bullet(
              text: "Âge: ${patient['age'] ?? 0} ans"),
          pw.Bullet(
              text:
              "N° Dossier: ${patient['medical_file_number'] ?? '—'}"),
          pw.SizedBox(height: 30),
          pw.Text("HISTORIQUE DES CONSULTATIONS",
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          ...records.map((r) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Date: ${r['date_consultation']}",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold)),
                pw.Text("Motif: ${r['motif']}"),
                if (r['diagnostic'] != null &&
                    r['diagnostic'] != "false")
                  pw.Text("Diagnostic: ${r['diagnostic']}"),
                if (r['prescription'] != null &&
                    r['prescription'] != "false")
                  pw.Text(
                      "Prescription: ${r['prescription']}"),
                pw.SizedBox(height: 5),
              ],
            ),
          )),
          pw.SizedBox(height: 30),
          pw.Text("MESURES DE TENSION",
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Table.fromTextArray(
            headers: ["Date", "Systolique", "Diastolique"],
            data: measurements
                .map((m) => [
              m['date_mesure'].toString().substring(0, 10),
              "${m['systolique']} mmHg",
              "${m['diastolique']} mmHg",
            ])
                .toList(),
          ),
          if (bodyMeasurements.isNotEmpty) ...[
            pw.SizedBox(height: 30),
            pw.Text("MESURES CORPORELLES (BALANCE)",
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Table.fromTextArray(
              headers: ["Date", "Poids", "IMC", "Gras %", "Muscle", "Eau", "Os", "Visceral", "Age M."],
              data: bodyMeasurements
                  .map((m) => [
                m['date'].toString().substring(0, 10),
                "${m['weight']} kg",
                "${m['bmi']}",
                "${m['body_fat']}%",
                "${m['muscle_mass']} kg",
                "${m['water']}%",
                "${m['bone_mass']} kg",
                "${m['visceral_fat']}",
                "${m['metabolic_age']}",
              ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        "${output.path}/rapport_${patient['name'].toString().replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> generateAndPrintPatientReport({
    required Map patient,
    required List records,
    required List measurements,
    List bodyMeasurements = const [],
  }) async {
    final file = await generatePatientReportFile(
        patient: patient,
        records: records,
        measurements: measurements,
        bodyMeasurements: bodyMeasurements);
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async =>
            file.readAsBytesSync());
  }
}