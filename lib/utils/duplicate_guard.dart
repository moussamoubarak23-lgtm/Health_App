import 'package:flutter/material.dart';

/// Détection locale de doublons (normalisation + similarité de chaînes).
class DuplicateGuard {
  DuplicateGuard._();

  static const double nameSimilarityThreshold = 0.88;

  static String normName(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Dernières 9 décimales si assez longues (tolère indicatifs pays / espaces).
  static String normPhone(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 9) return d.substring(d.length - 9);
    return d;
  }

  static String normId(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'\s'), '').replaceAll('-', '');

  static int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    var row = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      var prev = row[0];
      row[0] = i;
      for (var j = 1; j <= n; j++) {
        final tmp = row[j];
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        row[j] = [row[j - 1] + 1, row[j] + 1, prev + cost].reduce((x, y) => x < y ? x : y);
        prev = tmp;
      }
    }
    return row[n];
  }

  /// 1.0 = identique, 0 = très différent.
  static double nameSimilarity(String a, String b) {
    final x = normName(a);
    final y = normName(b);
    if (x.isEmpty || y.isEmpty) return 0;
    if (x == y) return 1;
    final d = _lev(x, y);
    final maxL = x.length > y.length ? x.length : y.length;
    return 1.0 - d / maxL;
  }

  static String _secFullName(Map p) {
    final fn = (p['first_name'] ?? '').toString().trim();
    final ln = (p['last_name'] ?? '').toString().trim();
    final full = (p['full_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    return '$fn $ln'.trim();
  }

  /// Retourne des phrases courtes pour une boîte de dialogue (création ou modification patient).
  /// [excludePatientId] : ignorer la fiche en cours lors d’une modification.
  static List<String> patientWarnings(
    Iterable<dynamic> patients, {
    required String fullName,
    required String phone,
    required String cin,
    required String dossier,
    int? excludePatientId,
  }) {
    final out = <String>[];
    final np = normPhone(phone);
    final nc = normId(cin);
    final nd = dossier.trim().toLowerCase();
    final nn = normName(fullName);

    for (final raw in patients) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final pid = p['id'];
      if (excludePatientId != null && pid == excludePatientId) continue;

      final label = (p['name'] ?? '').toString().trim();
      if (label.isEmpty) continue;

      if (nd.isNotEmpty) {
        final ref = (p['medical_file_number'] ?? p['ref'] ?? '').toString().trim().toLowerCase();
        if (ref.isNotEmpty && ref == nd) {
          out.add('N° dossier identique à la fiche « $label »');
        }
      }
      if (nc.isNotEmpty) {
        final existingCin = normId((p['patient_code'] ?? '').toString());
        if (existingCin.isNotEmpty && existingCin == nc) {
          out.add('CIN / pièce d\'identité identique à « $label »');
        }
      }
      if (np.isNotEmpty) {
        final ph = normPhone((p['phone'] ?? '').toString());
        if (ph.isNotEmpty && ph == np) {
          out.add('Téléphone identique à « $label »');
        }
      }
      if (nn.isNotEmpty && nameSimilarity(fullName, label) >= nameSimilarityThreshold) {
        out.add('Nom très proche de « $label » (${(nameSimilarity(fullName, label) * 100).round()} % de ressemblance)');
      }
    }
    return _dedupe(out);
  }

  static List<String> secretaryWarnings(
    Iterable<dynamic> secretaries, {
    required String firstName,
    required String lastName,
    required String phone,
    required String mobile,
    required String email,
    required String code,
    required String nationalId,
    int? excludeId,
  }) {
    final out = <String>[];
    final np = normPhone(phone);
    final nm = normPhone(mobile);
    final em = email.trim().toLowerCase();
    final codeN = normId(code);
    final nid = normId(nationalId);
    final newFull = normName('$firstName $lastName');

    for (final raw in secretaries) {
      if (raw is! Map) continue;
      final s = Map<String, dynamic>.from(raw);
      if (excludeId != null && s['id'] == excludeId) continue;

      final label = _secFullName(s);
      if (codeN.isNotEmpty) {
        final c0 = normId((s['secretary_code'] ?? '').toString());
        if (c0.isNotEmpty && c0 == codeN) {
          out.add('Code secrétaire identique à « $label »');
        }
      }
      if (nid.isNotEmpty) {
        final n0 = normId((s['national_id'] ?? '').toString());
        if (n0.isNotEmpty && n0 == nid) {
          out.add('CIN / identifiant identique à « $label »');
        }
      }
      if (em.isNotEmpty) {
        final e0 = (s['email'] ?? '').toString().trim().toLowerCase();
        if (e0.isNotEmpty && e0 == em) {
          out.add('E-mail identique à « $label »');
        }
      }
      final p0 = normPhone((s['phone'] ?? '').toString());
      final m0 = normPhone((s['mobile'] ?? '').toString());
      final incoming = <String>{};
      if (np.isNotEmpty) incoming.add(np);
      if (nm.isNotEmpty && nm != np) incoming.add(nm);
      if (incoming.isNotEmpty) {
        final secPhones = {p0, m0}.where((e) => e.isNotEmpty);
        for (final inc in incoming) {
          if (secPhones.any((sp) => sp == inc)) {
            out.add('Téléphone proche ou identique à « $label »');
            break;
          }
        }
      }
      if (newFull.isNotEmpty && label.isNotEmpty && nameSimilarity(newFull, label) >= nameSimilarityThreshold) {
        out.add('Nom très proche de « $label »');
      }
    }
    return _dedupe(out);
  }

  static List<String> nurseWarnings(
    Iterable<dynamic> nurses, {
    required String name,
    required String phone,
    required String email,
    required String license,
    int? excludeId,
  }) {
    final out = <String>[];
    final np = normPhone(phone);
    final em = email.trim().toLowerCase();
    final lic = normId(license);

    for (final raw in nurses) {
      if (raw is! Map) continue;
      final n = Map<String, dynamic>.from(raw);
      if (excludeId != null && n['id'] == excludeId) continue;

      final label = (n['name'] ?? '').toString().trim();
      if (lic.isNotEmpty) {
        final l0 = normId((n['license_number'] ?? '').toString());
        if (l0.isNotEmpty && l0 == lic) {
          out.add('N° de licence identique à « $label »');
        }
      }
      if (em.isNotEmpty) {
        final e0 = (n['email'] ?? '').toString().trim().toLowerCase();
        if (e0.isNotEmpty && e0 == em) {
          out.add('E-mail identique à « $label »');
        }
      }
      if (np.isNotEmpty) {
        final p0 = normPhone((n['phone'] ?? '').toString());
        if (p0.isNotEmpty && p0 == np) {
          out.add('Téléphone identique à « $label »');
        }
      }
      if (label.isNotEmpty && name.isNotEmpty && nameSimilarity(name, label) >= nameSimilarityThreshold) {
        out.add('Nom très proche de « $label »');
      }
    }
    return _dedupe(out);
  }

  static List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    return items.where(seen.add).toList();
  }
}

List<dynamic> odooOrDomain(List<List<dynamic>> clauses) {
  if (clauses.isEmpty) return [];
  if (clauses.length == 1) return clauses.first;
  var d = clauses[0];
  for (var i = 1; i < clauses.length; i++) {
    d = ['|', d, clauses[i]];
  }
  return d;
}

/// [true] = l'utilisateur confirme malgré les alertes (création ou enregistrement).
Future<bool> showDuplicateProceedDialog(
  BuildContext context, {
  required String title,
  required List<String> warnings,
  String confirmLabel = 'Créer quand même',
}) async {
  if (warnings.isEmpty) return true;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Des fiches existantes présentent des champs similaires. Vérifiez qu\'il ne s\'agit pas d\'un doublon.',
              ),
              const SizedBox(height: 12),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(w)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Modifier'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}
