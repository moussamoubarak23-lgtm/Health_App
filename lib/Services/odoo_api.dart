import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class OdooApi {
  static String _odooUrl = 'http://192.168.1.89:8069';
  static String _proxyUrl = 'http://localhost:8000';
  static String get baseUrl => kIsWeb ? _proxyUrl : _odooUrl;

  static const String dbName = String.fromEnvironment(
    'ODOO_DB_NAME',
    defaultValue: 'Dossier_medical',
  );

  static const String _adminLogin = 'admin';
  static const String _adminPassword = 'admin';

  static bool get canRegisterDoctorsFromClient => true;

  // ─── INITIALISATION ─────────────────────────────────────────────────────────
  static Future<void> initConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _odooUrl = prefs.getString('odoo_server_url') ?? 'http://192.168.1.89:8069';
    _proxyUrl = prefs.getString('proxy_url') ?? 'http://localhost:8000';
  }

  static Future<void> setServerUrl(String newUrl, {bool isProxy = false}) async {
    String cleaned = newUrl.trim();
    if (!cleaned.startsWith('http')) cleaned = 'http://$cleaned';
    if (cleaned.endsWith('/')) cleaned = cleaned.substring(0, cleaned.length - 1);
    final prefs = await SharedPreferences.getInstance();
    if (isProxy || kIsWeb) {
      _proxyUrl = cleaned;
      await prefs.setString('proxy_url', cleaned);
    } else {
      _odooUrl = cleaned;
      await prefs.setString('odoo_server_url', cleaned);
    }
  }

  static Future<String> _getSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id') ?? '';
  }

  static Future<void> _saveSessionCookie(String cookie) async {
    if (cookie.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_id', cookie);
    }
  }

  // Sécurise la conversion Odoo (false -> "")
  static String _s(dynamic val) {
    if (val == null || val == false) return '';
    return val.toString();
  }

  // ─── HELPER JSON-RPC ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> _callRpc(String path, Map params, {String? cookie}) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (!kIsWeb && cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params, 'id': DateTime.now().millisecondsSinceEpoch}),
      ).timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) return {'error': {'message': 'Réponse vide'}};

      final data = jsonDecode(response.body);

      if (!kIsWeb && path.contains('session/authenticate')) {
        final cookieHeader = response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
        if (cookieHeader != null) data['set-cookie'] = cookieHeader;
      }
      return data;
    } catch (e) {
      return {'error': {'message': 'Erreur réseau : $e'}};
    }
  }

  // ─── LOGIN ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String identifier, String password, {String role = 'doctor'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (role == 'secretary') {
        final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
        if (adminAuth == null || adminAuth['result'] == null) {
          return {'success': false, 'error': 'Serveur injoignable ou base de données incorrecte'};
        }

        final adminCookie = _s(adminAuth['set-cookie']);
        
        final searchResult = await _callRpc('/web/dataset/call_kw', {
          'model': 'medical.secretary',
          'method': 'search_read',
          'args': [[
            ['secretary_code', '=', password],
            '|', '|',
            ['email', '=', identifier],
            ['phone', 'ilike', identifier],
            ['mobile', 'ilike', identifier]
          ]],
          'kwargs': {'fields': ['id', 'full_name', 'doctor_id'], 'limit': 1},
        }, cookie: adminCookie);

        if (searchResult != null && searchResult['result'] != null && (searchResult['result'] as List).isNotEmpty) {
          final secretary = searchResult['result'][0];
          await _saveSessionCookie(adminCookie);
          await prefs.setString('user_role', 'secretary');
          await prefs.setInt('secretary_id', secretary['id'] ?? 0);

          String name = _s(secretary['full_name']);
          await prefs.setString('doctor_name', name.isNotEmpty ? name : identifier);

          if (secretary['doctor_id'] is List) {
             await prefs.setInt('uid', secretary['doctor_id'][0]);
          }
          return {'success': true, 'name': name, 'role': 'secretary'};
        }
        return {'success': false, 'error': 'Identifiants secrétaire incorrects'};
      }

      var auth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': identifier, 'password': password});

      if (auth == null || auth['result'] == null) {
        final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
        if (adminAuth != null && adminAuth['result'] != null) {
          final res = await _callRpc('/web/dataset/call_kw', {
            'model': 'res.users', 'method': 'search_read',
            'args': [['|', '|', '|', ['login', '=', identifier], ['email', '=', identifier], ['phone', 'ilike', identifier], ['mobile', 'ilike', identifier]]],
            'kwargs': {'fields': ['login'], 'limit': 1},
          }, cookie: _s(adminAuth['set-cookie']));

          if (res != null && res['result'] != null && (res['result'] as List).isNotEmpty) {
            auth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': res['result'][0]['login'], 'password': password});
          }
        }
      }

      if (auth != null && auth['result'] != null) {
        final res = auth['result'];
        await _saveSessionCookie(_s(auth['set-cookie']));
        await prefs.setInt('uid', res['uid'] ?? 0);
        await prefs.setInt('partner_id', res['partner_id'] ?? 0);
        await prefs.setString('doctor_name', _s(res['name']).isNotEmpty ? _s(res['name']) : identifier);
        await prefs.setString('doctor_login', _s(res['username']).isNotEmpty ? _s(res['username']) : identifier);
        await prefs.setString('user_role', 'doctor');
        return {'success': true, 'name': res['name'], 'role': 'doctor'};
      }
      return {'success': false, 'error': 'Identifiant ou mot de passe incorrect'};
    } catch (e) {
      return {'success': false, 'error': 'Erreur technique: $e'};
    }
  }

  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'doctor';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = await _getSessionCookie();
    if (cookie.isNotEmpty) await _callRpc('/web/session/destroy', {}, cookie: cookie);
    await prefs.clear();
  }

  // ─── NOTIFICATIONS (RÉEL ODOO) ─────────────────────────────────────────────
  static Future<List<dynamic>> getAppNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;

    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName, 'login': _adminLogin, 'password': _adminPassword
    });
    final adminCookie = _s(adminAuth?['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.notification',
      'method': 'search_read',
      'args': [[['is_active', '=', true]]],
      'kwargs': {
        'fields': ['id', 'title', 'content', 'version', 'is_critical', 'url', 'target_doctor_ids'],
        'order': 'create_date desc',
      },
    }, cookie: adminCookie);

    if (data == null || data['result'] == null) return [];
    List results = data['result'] as List;

    return results.where((n) {
      List targets = n['target_doctor_ids'] ?? [];
      return targets.isEmpty || targets.contains(uid);
    }).toList();
  }

  // ─── ACTES MÉDICAUX ──────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMedicalActs() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    final adminCookie = _s(adminAuth?['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'search_read',
      'args': [[['sale_ok', '=', true], ['default_code', '=', 'DOC_ID_$uid']]],
      'kwargs': {'fields': ['id', 'name', 'list_price']},
    }, cookie: adminCookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createMedicalAct({required String name, required double price}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    final adminCookie = _s(adminAuth?['set-cookie']);

    final accountData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.account', 'method': 'search_read', 'args': [[['account_type', '=', 'income']]], 'kwargs': {'fields': ['id'], 'limit': 1},
    }, cookie: adminCookie);
    int? accountId = (accountData != null && (accountData['result'] as List).isNotEmpty) ? accountData['result'][0]['id'] : null;

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'create',
      'args': [{'name': name, 'list_price': price, 'type': 'service', 'sale_ok': true, 'default_code': 'DOC_ID_$uid', if (accountId != null) 'property_account_income_id': accountId}],
      'kwargs': {},
    }, cookie: adminCookie);
    return data != null && data['result'] != null ? {'success': true} : {'success': false};
  }

  static Future<Map<String, dynamic>> deleteMedicalAct(int actId) async {
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    final adminCookie = _s(adminAuth?['set-cookie']);
    await _callRpc('/web/dataset/call_kw', {'model': 'product.product', 'method': 'unlink', 'args': [[actId]], 'kwargs': {}}, cookie: adminCookie);
    return {'success': true};
  }

  // ─── FACTURATION ───────────────────────────────────────────────────────────
  static Future<List<dynamic>> getInvoices({int? patientId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    if (adminAuth == null || adminAuth['result'] == null) return [];
    final adminCookie = _s(adminAuth['set-cookie']);

    List domain = [['move_type', '=', 'out_invoice'], '|', ['invoice_user_id', '=', uid], ['create_uid', '=', uid]];
    if (patientId != null) domain.add(['partner_id', '=', patientId]);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.move', 'method': 'search_read', 'args': [domain],
      'kwargs': {'fields': ['id', 'name', 'partner_id', 'invoice_date', 'amount_total', 'payment_state', 'currency_id', 'state']},
    }, cookie: adminCookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createInvoice({required int patientId, required List<Map<String, dynamic>> lines}) async {
    final prefs = await SharedPreferences.getInstance();
    final doctorUid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    final adminCookie = _s(adminAuth?['set-cookie']);

    final journalData = await _callRpc('/web/dataset/call_kw', {'model': 'account.journal', 'method': 'search_read', 'args': [[['type', '=', 'sale']]], 'kwargs': {'fields': ['id'], 'limit': 1}}, cookie: adminCookie);
    int journalId = journalData?['result'][0]['id'];

    final invoiceLines = lines.map((l) => [0, 0, {'product_id': l['product_id'], 'name': l['name'], 'quantity': 1, 'price_unit': l['price']}]).toList();

    final createData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.move', 'method': 'create',
      'args': [{
        'partner_id': patientId, 'move_type': 'out_invoice', 'invoice_date': DateTime.now().toString().substring(0, 10),
        'journal_id': journalId, 'invoice_line_ids': invoiceLines, 'invoice_user_id': doctorUid
      }],
      'kwargs': {},
    }, cookie: adminCookie);

    if (createData != null && createData['result'] != null) {
      await _callRpc('/web/dataset/call_kw', {'model': 'account.move', 'method': 'action_post', 'args': [[createData['result']]], 'kwargs': {}}, cookie: adminCookie);
      return {'success': true, 'id': createData['result']};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> registerPayment(int invoiceId) async {
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    final adminCookie = _s(adminAuth?['set-cookie']);

    final journalCash = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.journal', 'method': 'search_read', 'args': [[['type', '=', 'cash']]], 'kwargs': {'fields': ['id'], 'limit': 1},
    }, cookie: adminCookie);

    if (journalCash == null || (journalCash['result'] as List).isEmpty) return {'success': false, 'error': 'Journal Cash absent'};
    int cashJournalId = journalCash['result'][0]['id'];

    final wizardData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.payment.register',
      'method': 'create',
      'args': [{'journal_id': cashJournalId}],
      'kwargs': {'context': {'active_model': 'account.move', 'active_ids': [invoiceId], 'active_id': invoiceId, 'default_journal_id': cashJournalId}},
    }, cookie: adminCookie);

    if (wizardData != null && wizardData['result'] != null) {
      final res = await _callRpc('/web/dataset/call_kw', {'model': 'account.payment.register', 'method': 'action_create_payments', 'args': [[wizardData['result']]], 'kwargs': {}}, cookie: adminCookie);
      if (res != null && res['error'] == null) return {'success': true};
    }
    return {'success': false, 'error': 'Échec du paiement'};
  }

  static Future<Map<String, dynamic>> cancelInvoice(int invoiceId) async {
    final adminAuth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    final adminCookie = _s(adminAuth?['set-cookie']);
    await _callRpc('/web/dataset/call_kw', {'model': 'account.move', 'method': 'button_draft', 'args': [[invoiceId]], 'kwargs': {}}, cookie: adminCookie);
    await _callRpc('/web/dataset/call_kw', {'model': 'account.move', 'method': 'button_cancel', 'args': [[invoiceId]], 'kwargs': {}}, cookie: adminCookie);
    return {'success': true};
  }

  // ─── DOSSIERS MÉDICAUX ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getMedicalRecords({int? patientId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final cookie = await _getSessionCookie();
    List domain = [['doctor_id', '=', uid]];
    if (patientId != null) domain.add(['patient_id', '=', patientId]);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation', 'method': 'search_read', 'args': [domain],
      'kwargs': {'fields': ['id', 'name', 'patient_id', 'doctor_id', 'date_consultation', 'motif', 'state', 'diagnostic', 'prescription', 'observations', 'medical_file_number']},
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  static Future<void> markConsultationAsInvoiced(int patientId) async {
    final cookie = await _getSessionCookie();
    final search = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [[['patient_id', '=', patientId], ['state', '!=', 'invoiced']]],
      'kwargs': {'fields': ['id'], 'limit': 1, 'order': 'date_consultation desc'},
    }, cookie: cookie);

    if (search != null && (search['result'] as List).isNotEmpty) {
      final consId = search['result'][0]['id'];
      await _callRpc('/web/dataset/call_kw', {'model': 'medical.consultation', 'method': 'write', 'args': [[consId], {'state': 'invoiced'}], 'kwargs': {}}, cookie: cookie);
    }
  }

  // ─── SALLE D'ATTENTE ────────────────────────────────────────────────────────
  static Future<List<dynamic>> getWaitingRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final cookie = await _getSessionCookie();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [[
        ['state', 'in', ['draft', 'waiting']],
        ['doctor_id', '=', uid],
        ['date_consultation', '<=', '$todayStr 23:59:59']
      ]],
      'kwargs': {'fields': ['id', 'patient_id', 'date_consultation', 'motif', 'state', 'medical_file_number'], 'order': 'date_consultation asc'}
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  // ─── PATIENTS ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final cookie = await _getSessionCookie();
    final primaryData = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.partner', 'method': 'search_read',
      'args': [[
        ['is_patient', '=', true],
        '|',
        ['create_uid', '=', uid],
        ['user_id', '=', uid]
      ]],
      'kwargs': {
        'fields': ['id', 'name', 'ref', 'phone', 'email', 'insurance_id', 'height', 'age', 'comment', 'user_id'],
        'limit': 100
      }
    }, cookie: cookie);

    final consultationsData = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [[['doctor_id', '=', uid]]],
      'kwargs': {'fields': ['patient_id'], 'limit': 300},
    }, cookie: cookie);

    final Set<int> consultationPatientIds = {};
    if (consultationsData != null && consultationsData['result'] is List) {
      for (final row in consultationsData['result']) {
        final patientRef = row['patient_id'];
        if (patientRef is List && patientRef.isNotEmpty && patientRef[0] is int) {
          consultationPatientIds.add(patientRef[0]);
        }
      }
    }

    List<dynamic> consultationPatients = [];
    if (consultationPatientIds.isNotEmpty) {
      final extraData = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.partner',
        'method': 'search_read',
        'args': [[
          ['is_patient', '=', true],
          ['id', 'in', consultationPatientIds.toList()]
        ]],
        'kwargs': {
          'fields': ['id', 'name', 'ref', 'phone', 'email', 'insurance_id', 'height', 'age', 'comment', 'user_id'],
          'limit': 300
        }
      }, cookie: cookie);
      consultationPatients = (extraData?['result'] as List?) ?? [];
    }

    final Map<int, dynamic> byId = {};
    for (final p in (primaryData?['result'] as List?) ?? []) {
      if (p['id'] is int) byId[p['id']] = p;
    }
    for (final p in consultationPatients) {
      if (p['id'] is int) byId[p['id']] = p;
    }

    final mergedPatients = byId.values.toList();
    for (var p in mergedPatients) {
        p['medical_file_number'] = _s(p['ref']);
        p['patient_code'] = '';
        if (p['comment'] is String && p['comment'].contains('CIN:')) {
          p['patient_code'] = p['comment'].split('CIN:')[1].split('\n')[0].trim();
        }
      }
    return mergedPatients;
  }

  static Future<Map<String, dynamic>> createPatient({
    required String name, String phone = '', String email = '', String insuranceId = '',
    String medicalFileNumber = '', String patientCode = '',
    double height = 0.0, int age = 0, String? comment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final doctorUid = prefs.getInt('uid') ?? 0;
    final finalComment = patientCode.isNotEmpty ? "CIN: $patientCode\n${comment ?? ''}" : (comment ?? '');
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.partner', 'method': 'create',
      'args': [{
        'name': name,
        'phone': phone,
        'email': email,
        'insurance_id': insuranceId,
        'ref': medicalFileNumber,
        'height': height,
        'age': age,
        'is_patient': true,
        'comment': finalComment,
        'user_id': doctorUid,
      }],
      'kwargs': {},
    }, cookie: cookie);

    if (data != null && data['result'] != null) {
      await _logSecretaryActivity("Création patient", details: name);
      return {'success': true, 'id': data['result']};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> updatePatient({
    required int patientId, required String name, required String phone, required String email,
    required String insuranceId, required double height, required int age, String? comment,
    String patientCode = '', String medicalFileNumber = '',
  }) async {
    final finalComment = patientCode.isNotEmpty ? "CIN: $patientCode\n${comment ?? ''}" : (comment ?? '');
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.partner', 'method': 'write',
      'args': [[patientId], {
        'name': name, 'phone': phone, 'email': email, 'insurance_id': insuranceId,
        'ref': medicalFileNumber, 'height': height, 'age': age, 'comment': finalComment
      }],
      'kwargs': {},
    }, cookie: cookie);
    final success = data?['result'] == true;
    if (success) {
      await _logSecretaryActivity("Modification patient", details: name);
      return {'success': true};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> deletePatient(int patientId) async {
    try {
      final auth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
      if (auth == null || auth['result'] == null) return {'success': false, 'error': 'Auth admin failed'};
      final cookie = _s(auth['set-cookie']);

      // Dossiers médicaux
      final recs = await _callRpc('/web/dataset/call_kw', {
        'model': 'medical.consultation', 'method': 'search', 'args': [[['patient_id', '=', patientId]]], 'kwargs': {},
      }, cookie: cookie);
      if (recs != null && recs['result'] is List && (recs['result'] as List).isNotEmpty) {
        await _callRpc('/web/dataset/call_kw', {'model': 'medical.consultation', 'method': 'unlink', 'args': [recs['result']], 'kwargs': {}}, cookie: cookie);
      }

      // Calendrier
      final evts = await _callRpc('/web/dataset/call_kw', {
        'model': 'calendar.event', 'method': 'search', 'args': [[['partner_ids', 'in', [patientId]]]], 'kwargs': {},
      }, cookie: cookie);
      if (evts != null && evts['result'] is List && (evts['result'] as List).isNotEmpty) {
        await _callRpc('/web/dataset/call_kw', {'model': 'calendar.event', 'method': 'unlink', 'args': [evts['result']], 'kwargs': {}}, cookie: cookie);
      }

      // Factures (Moves)
      final invs = await _callRpc('/web/dataset/call_kw', {
        'model': 'account.move', 'method': 'search', 'args': [[['partner_id', '=', patientId]]], 'kwargs': {},
      }, cookie: cookie);
      if (invs != null && invs['result'] is List && (invs['result'] as List).isNotEmpty) {
        for (var id in invs['result']) {
          await _callRpc('/web/dataset/call_kw', {'model': 'account.move', 'method': 'button_draft', 'args': [[id]], 'kwargs': {}}, cookie: cookie);
          await _callRpc('/web/dataset/call_kw', {'model': 'account.move', 'method': 'unlink', 'args': [[id]], 'kwargs': {}}, cookie: cookie);
        }
      }

      final res = await _callRpc('/web/dataset/call_kw', {'model': 'res.partner', 'method': 'unlink', 'args': [[patientId]], 'kwargs': {}}, cookie: cookie);

      if (res != null && res['result'] == true) {
        await _logSecretaryActivity("Suppression patient", details: "ID $patientId");
        return {'success': true};
      }

      await _callRpc('/web/dataset/call_kw', {
        'model': 'res.partner', 'method': 'write', 'args': [[patientId], {'active': false}], 'kwargs': {},
      }, cookie: cookie);

      await _logSecretaryActivity("Archivage patient", details: "ID $patientId");
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── SÉCRÉTAIRES ────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSecretaries() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary', 'method': 'search_read',
      'args': [[['doctor_id', '=', uid]]],
      'kwargs': {'fields': ['id', 'first_name', 'last_name', 'full_name', 'gender', 'birth_date', 'phone', 'mobile', 'email', 'secretary_code', 'national_id', 'address', 'employee_id', 'hire_date', 'office_number', 'working_hours', 'active', 'notes'], 'limit': 100}
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createSecretary(Map<String, dynamic> vals) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final cookie = await _getSessionCookie();
    vals['doctor_id'] = uid;
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary', 'method': 'create',
      'args': [vals], 'kwargs': {},
    }, cookie: cookie);
    return data != null && data['result'] != null ? {'success': true, 'id': data['result']} : {'success': false};
  }

  static Future<Map<String, dynamic>> updateSecretary(int id, Map<String, dynamic> vals) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary', 'method': 'write',
      'args': [[id], vals],
      'kwargs': {},
    }, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<Map<String, dynamic>> deleteSecretary(int id) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary', 'method': 'unlink',
      'args': [[id]], 'kwargs': {},
    }, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<List<dynamic>> getSecretaryLogs(int secretaryId) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'mail.message',
      'method': 'search_read',
      'args': [[
        ['model', '=', 'medical.secretary'],
        ['res_id', '=', secretaryId]
      ]],
      'kwargs': {'fields': ['id', 'body', 'date', 'model', 'res_id'], 'limit': 50, 'order': 'date desc'}
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  // ─── GESTION GÉNÉRALE ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addMedicalRecord({required int patientId, required int doctorId, required String datetime, required String consultationReason, required String diagnostic, required String prescription, required String observations, String status = 'draft', String medicalFileNumber = ''}) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {'model': 'medical.consultation', 'method': 'create', 'args': [{
      'patient_id': patientId, 'doctor_id': doctorId, 'date_consultation': datetime, 'motif': consultationReason,
      'diagnostic': diagnostic, 'prescription': prescription, 'observations': observations, 'state': status,
      'medical_file_number': medicalFileNumber
    }], 'kwargs': {}}, cookie: cookie);
    return data != null && data['result'] != null ? {'success': true, 'id': data['result']} : {'success': false};
  }

  static Future<Map<String, dynamic>> updateMedicalRecord({required int recordId, required String motif, required String diagnostic, required String prescription, required String observations, required String state, String medicalFileNumber = '', String? datetime}) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {'model': 'medical.consultation', 'method': 'write', 'args': [[recordId], {
      'motif': motif, 'diagnostic': diagnostic, 'prescription': prescription, 'observations': observations, 'state': state,
      'medical_file_number': medicalFileNumber,
      if (datetime != null) 'date_consultation': datetime,
    }], 'kwargs': {}}, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<Map<String, int>> getDashboardStats() async {
    final results = await Future.wait([getPatients(), getMedicalRecords()]);
    return {'patients': results[0].length, 'records': results[1].length};
  }

  static Future<List<dynamic>> getBpMeasurements({int? patientId}) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {'model': 'bp.measurement', 'method': 'search_read', 'args': [patientId != null ? [['patient_id', '=', patientId]] : []], 'kwargs': {'fields': ['id', 'patient_id', 'date_mesure', 'systolique', 'diastolique', 'pouls', 'appareil'], 'limit': 50, 'order': 'date_mesure desc'}}, cookie: cookie);
    return data?['result'] ?? [];
  }

  static Future<List<dynamic>> getBodyMeasurements({int? patientId}) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'body.measurement',
      'method': 'search_read',
      'args': [patientId != null ? [['patient_id', '=', patientId]] : []],
      'kwargs': {
        'fields': ['id', 'patient_id', 'date', 'weight', 'bmi', 'body_fat', 'muscle_mass', 'water', 'bone_mass', 'visceral_fat', 'metabolic_age'],
        'limit': 50,
        'order': 'date desc'
      }
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> testConnection() async {
    final data = await _callRpc('/jsonrpc', {'service': 'common', 'method': 'version', 'args': []});
    if (data != null && data['result'] != null) return {'success': true, 'version': data['result']['server_version']?.toString() ?? 'Odoo'};
    return {'success': false, 'error': 'Erreur'};
  }

  static Future<Map<String, dynamic>> registerDoctor({required String name, required String login, required String password, String? phone}) async {
    final auth = await _callRpc('/web/session/authenticate', {'db': dbName, 'login': _adminLogin, 'password': _adminPassword});
    if (auth == null || auth['result'] == null) return {'success': false, 'error': 'Admin auth failed'};
    final createData = await _callRpc('/web/dataset/call_kw', {'model': 'res.users', 'method': 'create', 'args': [{'name': name, 'login': login, 'password': password, 'phone': phone, 'mobile': phone, 'groups_id': [[4, 1], [4, 2]]}], 'kwargs': {}}, cookie: _s(auth['set-cookie']));
    return createData != null && createData['result'] != null ? {'success': true} : {'success': false};
  }

  static Future<Map<String, dynamic>> addToWaitingRoom({required int patientId, String motif = 'Consultation'}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final cookie = await _getSessionCookie();
    final now = DateTime.now().toString().substring(0, 19);
    final data = await _callRpc('/web/dataset/call_kw', {'model': 'medical.consultation', 'method': 'create', 'args': [{'patient_id': patientId, 'doctor_id': uid, 'date_consultation': now, 'motif': motif, 'state': 'waiting'}], 'kwargs': {}}, cookie: cookie);
    if (data != null && data['result'] != null) {
      await _logSecretaryActivity("Ajout en salle d'attente", details: "Patient ID $patientId");
      return {'success': true, 'id': data['result']};
    }
    return {'success': false};
  }

  static Future<void> _logSecretaryActivity(String action, {String details = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'doctor';
    if (role != 'secretary') return;

    final secretaryId = prefs.getInt('secretary_id') ?? 0;
    if (secretaryId <= 0) return;

    final cookie = await _getSessionCookie();
    final body = details.trim().isEmpty ? action : "$action : $details";

    await _callRpc('/web/dataset/call_kw', {
      'model': 'mail.message',
      'method': 'create',
      'args': [{
        'model': 'medical.secretary',
        'res_id': secretaryId,
        'message_type': 'comment',
        'subtype_id': 1,
        'body': body,
      }],
      'kwargs': {},
    }, cookie: cookie);
  }

  static Future<Map<String, dynamic>> createCalendarAppointment({
    required int patientId,
    required String name,
    required String dateStart,
    required int durationMinutes,
    String description = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final partnerId = prefs.getInt('partner_id') ?? 0;
    final cookie = await _getSessionCookie();

    final dateEnd = DateTime.parse(dateStart).add(Duration(minutes: durationMinutes)).toString().substring(0, 19);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'calendar.event',
      'method': 'create',
      'args': [{
        'name': 'RDV: $name',
        'start': dateStart,
        'stop': dateEnd,
        'duration': durationMinutes / 60.0,
        'description': description,
        'partner_ids': [[6, 0, [partnerId, patientId]]],
        'user_id': uid,
      }],
      'kwargs': {},
    }, cookie: cookie);

    if (data != null && data['result'] != null) {
      await addMedicalRecord(
        patientId: patientId,
        doctorId: uid,
        datetime: dateStart,
        consultationReason: description.isEmpty ? "Consultation" : description,
        diagnostic: '', prescription: '', observations: '',
        status: 'waiting',
      );
      return {'success': true, 'id': data['result']};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'doctor';
    final cookie = await _getSessionCookie();

    if (role == 'secretary') {
      final sid = prefs.getInt('secretary_id') ?? 0;
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'medical.secretary', 'method': 'read',
        'args': [[sid], ['first_name', 'last_name', 'full_name', 'email', 'phone', 'mobile']],
        'kwargs': {},
      }, cookie: cookie);
      if (data != null && data['result'] != null && (data['result'] as List).isNotEmpty) {
        final d = data['result'][0];
        return {'success': true, 'data': {
          'name': _s(d['full_name']),
          'email': _s(d['email']),
          'phone': _s(d['phone']),
          'mobile': _s(d['mobile']),
          'login': _s(d['email'])
        }};
      }
    } else {
      final uid = prefs.getInt('uid') ?? 0;
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.users', 'method': 'read',
        'args': [[uid], ['name', 'login', 'email', 'phone', 'mobile']],
        'kwargs': {},
      }, cookie: cookie);
      if (data != null && data['result'] != null && (data['result'] as List).isNotEmpty) {
        final d = data['result'][0];
        return {'success': true, 'data': {
          'name': _s(d['name']),
          'login': _s(d['login']),
          'email': _s(d['email']),
          'phone': _s(d['phone']),
          'mobile': _s(d['mobile']),
        }};
      }
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> vals) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'doctor';
    final cookie = await _getSessionCookie();

    if (role == 'secretary') {
      final sid = prefs.getInt('secretary_id') ?? 0;
      Map<String, dynamic> secVals = {};
      if (vals.containsKey('name')) {
         secVals['first_name'] = vals['name'].split(' ')[0];
         secVals['last_name'] = vals['name'].contains(' ') ? vals['name'].substring(vals['name'].indexOf(' ') + 1) : '';
      }
      if (vals.containsKey('email')) secVals['email'] = vals['email'];
      if (vals.containsKey('phone')) secVals['phone'] = vals['phone'];
      if (vals.containsKey('mobile')) secVals['mobile'] = vals['mobile'];

      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'medical.secretary', 'method': 'write',
        'args': [[sid], secVals],
        'kwargs': {},
      }, cookie: cookie);
      if (data?['result'] == true) {
        if (vals.containsKey('name')) await prefs.setString('doctor_name', vals['name']);
        return {'success': true};
      }
    } else {
      final uid = prefs.getInt('uid') ?? 0;
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.users', 'method': 'write',
        'args': [[uid], vals],
        'kwargs': {},
      }, cookie: cookie);
      if (data?['result'] == true) {
        if (vals.containsKey('name')) {
          await prefs.setString('doctor_name', _s(vals['name']));
        }
        return {'success': true};
      }
    }
    return {'success': false};
  }
}
