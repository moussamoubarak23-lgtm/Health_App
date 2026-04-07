import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndPrintCertificate({
    required String doctorName,
    required String patientName,
    required String content,
    required DateTime date,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
}
