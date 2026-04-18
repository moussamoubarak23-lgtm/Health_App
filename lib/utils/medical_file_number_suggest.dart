/// Proposition du prochain numéro de dossier médical (`ref` / `medical_file_number`)
/// à partir des patients déjà chargés (suffixe numérique final ou entier pur).
class MedicalFileNumberSuggest {
  MedicalFileNumberSuggest._();

  /// Analyse les numéros existants, retient celui avec le plus grand suffixe numérique
  /// final et propose la même forme avec [suffixe + 1] (zéros conservés si possible).
  /// Si aucun numéro exploitable : `AAAA-001` (année courante).
  static String suggestNext(Iterable<dynamic> patients) {
    var bestNum = -1;
    var template = '';

    for (final raw in patients) {
      if (raw is! Map) continue;
      final s = (raw['medical_file_number'] ?? raw['ref'] ?? '').toString().trim();
      if (s.isEmpty || s == 'false' || s == '—') continue;
      final m = RegExp(r'^(.*?)(\d+)$').firstMatch(s);
      if (m == null) continue;
      final n = int.tryParse(m.group(2)!);
      if (n == null) continue;
      if (n > bestNum) {
        bestNum = n;
        template = s;
      }
    }

    if (bestNum < 0 || template.isEmpty) {
      final y = DateTime.now().year;
      return '$y-001';
    }

    final m = RegExp(r'^(.*?)(\d+)$').firstMatch(template);
    if (m == null) {
      final y = DateTime.now().year;
      return '$y-001';
    }
    final prefix = m.group(1)!;
    final oldSuffix = m.group(2)!;
    final next = bestNum + 1;
    final w = oldSuffix.length > next.toString().length ? oldSuffix.length : next.toString().length;
    return '$prefix${next.toString().padLeft(w, '0')}';
  }
}
