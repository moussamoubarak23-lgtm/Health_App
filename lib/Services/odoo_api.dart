import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:medical_app/utils/duplicate_guard.dart';

class OdooApi {
  // Adresse du serveur Odoo - À CHANGER : remplacez 192.168.1.197 par l'IP de votre VPS
  static String _odooUrl = 'http://192.168.1.197:8069';
  // Adresse du proxy pour le web - À CHANGER : remplacez 192.168.1.197 par l'IP de votre VPS
  static String _proxyUrl = 'http://192.168.1.197:8000';
  static String get baseUrl => kIsWeb ? _proxyUrl : _odooUrl;

  static const String dbName = String.fromEnvironment(
    'ODOO_DB_NAME',
    defaultValue: 'Test_cabinet',
  );

  static const String _adminLogin = 'sds@gmail.com';
  static const String _adminPassword = 'odoo';

  static bool get canRegisterDoctorsFromClient => true;

  // ─── Cache CSRF token (Odoo 19) ─────────────────────────────────────────────
  static String _csrfToken = '';
  static String _proxyCsrfCookie = '';

  // ─── INITIALISATION ─────────────────────────────────────────────────────────
  static Future<void> initConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _odooUrl = prefs.getString('odoo_server_url') ?? 'http://192.168.1.197:8069';
    _proxyUrl = prefs.getString('proxy_url') ?? 'http://192.168.1.197:8000';
    // Charger le CSRF token sauvegardé (s'il existe)
    _csrfToken = prefs.getString('csrf_token') ?? '';
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
    // Réinitialiser le token CSRF si l'URL change
    _csrfToken = '';
    _proxyCsrfCookie = '';
  }

  // ─── CSRF TOKEN (Odoo 19) ────────────────────────────────────────────────────
  /// Récupère un CSRF token frais depuis le proxy Django.
  /// Sur mobile (non-web), on appelle directement Odoo via /web.
  static Future<void> _refreshCsrfToken() async {
    try {
      if (kIsWeb) {
        // Via le proxy Django : endpoint dédié
        final response = await http.get(
          Uri.parse('$_proxyUrl/api/csrf/'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _csrfToken = data['csrf_token'] ?? '';
          _proxyCsrfCookie = data['session_cookie'] ?? '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('csrf_token', _csrfToken);
        }
      } else {
        // Accès direct Odoo : parser le HTML de /web
        final response = await http.get(
          Uri.parse('$_odooUrl/web'),
          headers: {'Accept': 'text/html'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final match = RegExp(r'''csrf_token["'\s]*:["'\s]*["']([^"']+)["']''')
              .firstMatch(response.body);
          if (match != null) {
            _csrfToken = match.group(1) ?? '';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('csrf_token', _csrfToken);
          }
          // Récupérer le session_id du cookie si présent
          final setCookie = response.headers['set-cookie'] ?? '';
          final sidMatch = RegExp(r'session_id=([^;]+)').firstMatch(setCookie);
          if (sidMatch != null) {
            _proxyCsrfCookie = sidMatch.group(1) ?? '';
          }
        }
      }
    } catch (e) {
      // Silencieux — on continuera sans CSRF (peut marcher selon config Odoo)
      print('[OdooApi] CSRF refresh error: $e');
    }
  }

  static Future<String> _getSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id') ?? '';
  }

  static Future<void> _saveSessionCookie(String cookie) async {
    if (cookie.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      // Extraire uniquement la valeur session_id si c'est un header Set-Cookie complet
      final match = RegExp(r'session_id=([^;]+)').firstMatch(cookie);
      final value = match != null ? match.group(1)! : cookie;
      await prefs.setString('session_id', value);
    }
  }

  // Sécurise la conversion Odoo (false -> "")
  static String _s(dynamic val) {
    if (val == null || val == false) return '';
    return val.toString();
  }

  // ─── HELPER JSON-RPC ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> _callRpc(
      String path,
      Map params, {
        String? cookie,
        bool retryOnDenied = true,
      }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // ── Odoo 19 : injecter le CSRF token ──────────────────────────────────
      if (_csrfToken.isNotEmpty) {
        headers['X-Csrf-Token'] = _csrfToken;
      }

      // ── Cookie de session ──────────────────────────────────────────────────
      // Sur Flutter Web : le navigateur bloque l'envoi manuel du header Cookie
      // (politique CORS). Le proxy Django gère la session via l'IP cliente.
      // Sur mobile : on envoie le cookie normalement.
      if (!kIsWeb) {
        String? effectiveCookie = cookie;
        if (effectiveCookie == null || effectiveCookie.isEmpty) {
          if (_proxyCsrfCookie.isNotEmpty) {
            effectiveCookie = 'session_id=$_proxyCsrfCookie';
          }
        }
        if (effectiveCookie != null && effectiveCookie.isNotEmpty) {
          if (!effectiveCookie.startsWith('session_id=')) {
            effectiveCookie = 'session_id=$effectiveCookie';
          }
          headers['Cookie'] = effectiveCookie;
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': params,
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) return {'error': {'message': 'Réponse vide'}};

      final data = jsonDecode(response.body);

      // ── Extraire le cookie de session de la réponse ────────────────────────
      final cookieHeader =
          response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        if (path.contains('session/authenticate')) {
          data['set-cookie'] = cookieHeader;
        }
        // Mettre à jour le cookie proxy interne
        final sidMatch = RegExp(r'session_id=([^;]+)').firstMatch(cookieHeader);
        if (sidMatch != null) {
          _proxyCsrfCookie = sidMatch.group(1)!;
        }
      }

      // ── Retry automatique si Access Denied (token expiré) ─────────────────
      if (retryOnDenied) {
        final errorName = data['error']?['data']?['name'] ?? '';
        if (errorName == 'odoo.exceptions.AccessDenied' &&
            path.contains('authenticate')) {
          await _refreshCsrfToken();
          return _callRpc(path, params, cookie: cookie, retryOnDenied: false);
        }
      }

      return data;
    } catch (e) {
      return {'error': {'message': 'Erreur réseau : $e'}};
    }
  }

  // ─── LOGIN ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String identifier,
      String password, {
        String role = 'doctor',
      }) async {
    try {
      // ── Odoo 19 : obtenir un CSRF token frais avant toute auth ─────────────
      if (_csrfToken.isEmpty) {
        await _refreshCsrfToken();
      }

      final prefs = await SharedPreferences.getInstance();

      if (role == 'secretary') {
        final adminAuth = await _callRpc('/web/session/authenticate', {
          'db': dbName,
          'login': _adminLogin,
          'password': _adminPassword,
        });
        if (adminAuth == null || adminAuth['result'] == null) {
          return {
            'success': false,
            'error': 'Serveur injoignable ou base de données incorrecte',
          };
        }

        final adminCookie = _s(adminAuth['set-cookie']);

        final searchResult = await _callRpc('/web/dataset/call_kw', {
          'model': 'medical.secretary',
          'method': 'search_read',
          'args': [
            [
              ['secretary_code', '=', password],
              '|',
              '|',
              ['email', '=', identifier],
              ['phone', 'ilike', identifier],
              ['mobile', 'ilike', identifier],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'full_name', 'doctor_id'],
            'limit': 1,
          },
        }, cookie: adminCookie);

        if (searchResult != null &&
            searchResult['result'] != null &&
            (searchResult['result'] as List).isNotEmpty) {
          final secretary = searchResult['result'][0];
          await _saveSessionCookie(adminCookie);
          await prefs.setString('user_role', 'secretary');
          await prefs.setInt('secretary_id', secretary['id'] ?? 0);

          String name = _s(secretary['full_name']);
          await prefs.setString(
            'doctor_name',
            name.isNotEmpty ? name : identifier,
          );

          if (secretary['doctor_id'] is List) {
            await prefs.setInt('uid', secretary['doctor_id'][0]);
          }
          return {'success': true, 'name': name, 'role': 'secretary'};
        }
        return {'success': false, 'error': 'Identifiants secrétaire incorrects'};
      }

      if (role == 'nurse') {
        final adminAuth = await _callRpc('/web/session/authenticate', {
          'db': dbName,
          'login': _adminLogin,
          'password': _adminPassword,
        });
        if (adminAuth == null || adminAuth['result'] == null) {
          return {
            'success': false,
            'error': 'Serveur injoignable ou base de données incorrecte',
          };
        }

        final adminCookie = _s(adminAuth['set-cookie']);
        final searchResult = await _callRpc('/web/dataset/call_kw', {
          'model': 'nurse.nurse',
          'method': 'search_read',
          'args': [
            [
              ['license_number', '=', password],
              '|',
              ['email', '=', identifier],
              ['phone', 'ilike', identifier],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'name', 'create_uid'],
            'limit': 1,
          },
        }, cookie: adminCookie);

        if (searchResult != null &&
            searchResult['result'] != null &&
            (searchResult['result'] as List).isNotEmpty) {
          final nurse = searchResult['result'][0];
          await _saveSessionCookie(adminCookie);
          await prefs.setString('user_role', 'nurse');
          await prefs.setInt('nurse_id', nurse['id'] ?? 0);
          await prefs.setString(
            'doctor_name',
            _s(nurse['name']).isNotEmpty ? _s(nurse['name']) : identifier,
          );
          if (nurse['create_uid'] is List) {
            await prefs.setInt('uid', nurse['create_uid'][0]);
          }
          return {
            'success': true,
            'name': _s(nurse['name']),
            'role': 'nurse',
          };
        }
        return {
          'success': false,
          'error': 'Identifiants infirmier incorrects',
        };
      }

      // ── Rôle médecin ──────────────────────────────────────────────────────
      var auth = await _callRpc('/web/session/authenticate', {
        'db': dbName,
        'login': identifier,
        'password': password,
      });

      if (auth == null || auth['result'] == null) {
        // Tentative de résolution login via admin
        final adminAuth = await _callRpc('/web/session/authenticate', {
          'db': dbName,
          'login': _adminLogin,
          'password': _adminPassword,
        });
        if (adminAuth != null && adminAuth['result'] != null) {
          // Odoo 19 : mobile n'existe plus sur res.users, on cherche par login/email/phone
          // puis on cherche aussi via res.partner.mobile si nécessaire
          var res = await _callRpc('/web/dataset/call_kw', {
            'model': 'res.users',
            'method': 'search_read',
            'args': [
              [
                '|',
                '|',
                ['login', '=', identifier],
                ['email', '=', identifier],
                ['phone', 'ilike', identifier],
              ],
            ],
            'kwargs': {
              'fields': ['login'],
              'limit': 1,
            },
          }, cookie: _s(adminAuth['set-cookie']));

          // Fallback : chercher via res.partner.phone (mobile supprimé en Odoo 19)
          if (res == null || res['result'] == null || (res['result'] as List).isEmpty) {
            final partnerRes = await _callRpc('/web/dataset/call_kw', {
              'model': 'res.partner',
              'method': 'search_read',
              'args': [
                [['phone', 'ilike', identifier]],
              ],
              'kwargs': {
                'fields': ['id'],
                'limit': 1,
              },
            }, cookie: _s(adminAuth['set-cookie']));
            if (partnerRes != null &&
                partnerRes['result'] != null &&
                (partnerRes['result'] as List).isNotEmpty) {
              final partnerId = partnerRes['result'][0]['id'];
              res = await _callRpc('/web/dataset/call_kw', {
                'model': 'res.users',
                'method': 'search_read',
                'args': [
                  [['partner_id', '=', partnerId]],
                ],
                'kwargs': {
                  'fields': ['login'],
                  'limit': 1,
                },
              }, cookie: _s(adminAuth['set-cookie']));
            }
          }

          if (res != null &&
              res['result'] != null &&
              (res['result'] as List).isNotEmpty) {
            auth = await _callRpc('/web/session/authenticate', {
              'db': dbName,
              'login': res['result'][0]['login'],
              'password': password,
            });
          }
        }
      }

      if (auth != null && auth['result'] != null) {
        final res = auth['result'];
        await _saveSessionCookie(_s(auth['set-cookie']));
        await prefs.setInt('uid', res['uid'] ?? 0);
        await prefs.setInt('partner_id', res['partner_id'] ?? 0);
        await prefs.setString(
          'doctor_name',
          _s(res['name']).isNotEmpty ? _s(res['name']) : identifier,
        );
        await prefs.setString(
          'doctor_login',
          _s(res['username']).isNotEmpty ? _s(res['username']) : identifier,
        );
        await prefs.setString('user_role', 'doctor');
        return {'success': true, 'name': res['name'], 'role': 'doctor'};
      }
      return {
        'success': false,
        'error': 'Identifiant ou mot de passe incorrect',
      };
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
    if (cookie.isNotEmpty) {
      await _callRpc('/web/session/destroy', {}, cookie: cookie);
    }
    _csrfToken = '';
    _proxyCsrfCookie = '';
    await prefs.clear();
  }

  // ─── NOTIFICATIONS (RÉEL ODOO) ─────────────────────────────────────────────
  static Future<List<dynamic>> getAppNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;

    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.notification',
      'method': 'search_read',
      'args': [
        [
          ['is_active', '=', true],
        ],
      ],
      'kwargs': {
        'fields': [
          'id',
          'title',
          'content',
          'version',
          'is_critical',
          'url',
          'target_doctor_ids',
        ],
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
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'search_read',
      'args': [
        [
          ['sale_ok', '=', true],
          ['default_code', '=', 'DOC_ID_$uid'],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name', 'list_price'],
      },
    }, cookie: adminCookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createMedicalAct({
    required String name,
    required double price,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);

    final accountData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.account',
      'method': 'search_read',
      'args': [
        [
          ['account_type', '=', 'income'],
        ],
      ],
      'kwargs': {
        'fields': ['id'],
        'limit': 1,
      },
    }, cookie: adminCookie);
    int? accountId =
    (accountData != null && (accountData['result'] as List).isNotEmpty)
        ? accountData['result'][0]['id']
        : null;

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'create',
      'args': [
        {
          'name': name,
          'list_price': price,
          'type': 'service',
          'sale_ok': true,
          'default_code': 'DOC_ID_$uid',
          if (accountId != null) 'property_account_income_id': accountId,
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);
    return data != null && data['result'] != null
        ? {'success': true}
        : {'success': false};
  }

  static Future<Map<String, dynamic>> deleteMedicalAct(int actId) async {
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);
    await _callRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'unlink',
      'args': [
        [actId],
      ],
      'kwargs': {},
    }, cookie: adminCookie);
    return {'success': true};
  }

  // ─── FACTURATION ───────────────────────────────────────────────────────────
  static Future<List<dynamic>> getInvoices({int? patientId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) return [];
    final adminCookie = _s(adminAuth['set-cookie']);

    List domain = [
      ['move_type', '=', 'out_invoice'],
      '|',
      ['invoice_user_id', '=', uid],
      ['create_uid', '=', uid],
    ];
    if (patientId != null) domain.add(['partner_id', '=', patientId]);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.move',
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': [
          'id',
          'name',
          'partner_id',
          'invoice_date',
          'amount_total',
          'payment_state',
          'currency_id',
          'state',
        ],
      },
    }, cookie: adminCookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createInvoice({
    required int patientId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final doctorUid = prefs.getInt('uid') ?? 0;
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName, 'login': _adminLogin, 'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);

    final journalData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.journal', 'method': 'search_read',
      'args': [[['type', '=', 'sale']]],
      'kwargs': {'fields': ['id'], 'limit': 1},
    }, cookie: adminCookie);
    int journalId = journalData?['result'][0]['id'];

    final invoiceLines = lines.map((l) => [0, 0, {
      'product_id': l['product_id'], 'name': l['name'],
      'quantity': 1, 'price_unit': l['price'],
    }]).toList();

    final createData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.move', 'method': 'create',
      'args': [{
        'partner_id': patientId, 'move_type': 'out_invoice',
        'invoice_date': DateTime.now().toString().substring(0, 10),
        'journal_id': journalId, 'invoice_line_ids': invoiceLines,
        'invoice_user_id': doctorUid,
      }],
      'kwargs': {},
    }, cookie: adminCookie);

    if (createData != null && createData['result'] != null) {
      await _callRpc('/web/dataset/call_kw', {
        'model': 'account.move', 'method': 'action_post',
        'args': [[createData['result']]], 'kwargs': {},
      }, cookie: adminCookie);
      return {'success': true, 'id': createData['result']};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> registerPayment(int invoiceId) async {
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName, 'login': _adminLogin, 'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);

    final journalCash = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.journal', 'method': 'search_read',
      'args': [[['type', '=', 'cash']]],
      'kwargs': {'fields': ['id'], 'limit': 1},
    }, cookie: adminCookie);

    if (journalCash == null || (journalCash['result'] as List).isEmpty) {
      return {'success': false, 'error': 'Journal Cash absent'};
    }
    int cashJournalId = journalCash['result'][0]['id'];

    final wizardData = await _callRpc('/web/dataset/call_kw', {
      'model': 'account.payment.register', 'method': 'create',
      'args': [{'journal_id': cashJournalId}],
      'kwargs': {'context': {
        'active_model': 'account.move',
        'active_ids': [invoiceId],
        'active_id': invoiceId,
        'default_journal_id': cashJournalId,
      }},
    }, cookie: adminCookie);

    if (wizardData != null && wizardData['result'] != null) {
      final res = await _callRpc('/web/dataset/call_kw', {
        'model': 'account.payment.register',
        'method': 'action_create_payments',
        'args': [[wizardData['result']]], 'kwargs': {},
      }, cookie: adminCookie);
      if (res != null && res['error'] == null) return {'success': true};
    }
    return {'success': false, 'error': 'Échec du paiement'};
  }

  static Future<Map<String, dynamic>> cancelInvoice(int invoiceId) async {
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName, 'login': _adminLogin, 'password': _adminPassword,
    });
    final adminCookie = _s(adminAuth?['set-cookie']);
    await _callRpc('/web/dataset/call_kw', {
      'model': 'account.move', 'method': 'button_draft',
      'args': [[invoiceId]], 'kwargs': {},
    }, cookie: adminCookie);
    await _callRpc('/web/dataset/call_kw', {
      'model': 'account.move', 'method': 'button_cancel',
      'args': [[invoiceId]], 'kwargs': {},
    }, cookie: adminCookie);
    return {'success': true};
  }

  // ─── DOSSIERS MÉDICAUX ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getMedicalRecords({int? patientId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;

    // ◄ UTILISE AUTH ADMIN
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      print('>>> getMedicalRecords: auth admin failed');
      return [];
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    List domain = [];
    if (patientId != null) {
      // ◄ POUR LES DOSSIERS D'UN PATIENT SPÉCIFIQUE : tous les dossiers du patient
      domain = [
        ['patient_id', '=', patientId],
      ];
    } else {
      // ◄ POUR LA LISTE GÉNÉRALE : seulement ceux du médecin connecté
      domain = [
        ['doctor_id', '=', uid],
      ];
    }

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': [
          'id',
          'name',
          'patient_id',
          'doctor_id',
          'date_consultation',
          'motif',
          'state',
          'diagnostic',
          'prescription',
          'observations',
          'medical_file_number',
        ],
      },
    }, cookie: adminCookie);  // ◄ UTILISE adminCookie
    print('>>> getMedicalRecords: ${data?['result']?.length ?? 0} records trouvés pour patientId=$patientId');
    if (data != null && data['result'] != null && data['result'].isNotEmpty) {
      for (var r in data['result']) {
        print('>>> Record: ${r['name']} - state: ${r['state']} - doctor_id: ${r['doctor_id']}');
      }
    }
    return data?['result'] ?? [];
  }

  static Future<void> markConsultationAsInvoiced(int patientId) async {
    // ◄ UTILISE AUTH ADMIN
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) return;
    final adminCookie = _s(adminAuth['set-cookie']);

    final search = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [
        [
          ['patient_id', '=', patientId],
          ['state', '!=', 'invoiced'],
        ],
      ],
      'kwargs': {
        'fields': ['id'],
        'limit': 1,
        'order': 'date_consultation desc',
      },
    }, cookie: adminCookie);

    if (search != null && (search['result'] as List).isNotEmpty) {
      final consId = search['result'][0]['id'];
      await _callRpc('/web/dataset/call_kw', {
        'model': 'medical.consultation',
        'method': 'write',
        'args': [
          [consId],
          {'state': 'invoiced'},
        ],
        'kwargs': {},
      }, cookie: adminCookie);
    }
  }

  // ─── SALLE D'ATTENTE ────────────────────────────────────────────────────────
  static Future<List<dynamic>> getWaitingRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;

    // Fix A: Utiliser adminCookie pour s'assurer que la session est valide
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      print('>>> getWaitingRoom: admin auth failed');
      return [];
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Fix B: Élargir le domaine de recherche (sans filtre doctor_id)
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [
        [
          [
            'state',
            'in',
            ['draft', 'waiting'],
          ],
          ['date_consultation', '<=', '$todayStr 23:59:59'],
        ],
      ],
      'kwargs': {
        'fields': [
          'id',
          'patient_id',
          'date_consultation',
          'motif',
          'state',
          'medical_file_number',
          'doctor_id',
        ],
        'order': 'date_consultation asc',
      },
    }, cookie: adminCookie);

    // Filtrer côté Dart : garder seulement les consultations du médecin
    // ou celles sans doctor_id assigné
    List<dynamic> results = [];
    if (data?['result'] is List) {
      for (var consultation in data!['result']) {
        final doctorId = consultation['doctor_id'];
        if (doctorId == null ||
            doctorId == false ||
            (doctorId is List && (doctorId.isEmpty || doctorId[0] == uid)) ||
            (doctorId is int && (doctorId == 0 || doctorId == uid))) {
          results.add(consultation);
        }
      }
    }
    return results;
  }

  // ─── PATIENTS ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;

    // ◄ UTILISE AUTH ADMIN COMME LES AUTRES FONCTIONS
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      print('>>> getPatients: auth admin failed');
      return [];
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    // ◄ RÉCUPÈRE LES SECRÉTAIRES ET INFIRMIERS DU MÉDECIN
    final secretariesData = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary',
      'method': 'search_read',
      'args': [
        [
          ['doctor_id', '=', uid],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'user_id'],
      },
    }, cookie: adminCookie);

    // ◄ Les infirmiers n'ont pas de filtre doctor_id dans le modèle Odoo
    // On ne les ajoute pas à allowedUserIds car ils n'ont pas de user_id

    // ◄ CONSTRUIT LA LISTE DES UTILISATEURS AUTORISÉS
    final List<int> allowedUserIds = [uid]; // Le médecin lui-même
    
    // Ajouter les secrétaires
    if (secretariesData?['result'] != null) {
      for (var secretary in secretariesData!['result']) {
        if (secretary['user_id'] != null) {
          final userId = secretary['user_id'] is List ? secretary['user_id'][0] : secretary['user_id'];
          if (userId is int && userId > 0) {
            allowedUserIds.add(userId);
          }
        }
      }
    }
    
    // ◄ Les infirmiers n'ont pas de user_id dans le modèle Odoo, on ne les ajoute pas à allowedUserIds
    // Les infirmiers seront gérés séparément si nécessaire

    print('>>> getPatients: allowedUserIds = $allowedUserIds');

    // ◄ RÉCUPÈRE D'ABORD LES CONSULTATIONS DU MÉDECIN
    final consultationsData = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'search_read',
      'args': [
        [
          ['doctor_id', '=', uid],
        ],
      ],
      'kwargs': {
        'fields': ['patient_id'],
        'limit': 300,
      },
    }, cookie: adminCookie);

    final Set<int> consultationPatientIds = {};
    if (consultationsData != null && consultationsData['result'] is List) {
      for (final row in consultationsData['result']) {
        final patientRef = row['patient_id'];
        if (patientRef is List &&
            patientRef.isNotEmpty &&
            patientRef[0] is int) {
          consultationPatientIds.add(patientRef[0]);
        }
      }
    }

    print('>>> getPatients: consultationPatientIds = $consultationPatientIds');

    // ◄ RÉCUPÈRE LES PATIENTS BASÉS SUR LES CONSULTATIONS DU MÉDECIN
    final primaryData = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.partner',
      'method': 'search_read',
      'args': [
        [
          ['is_patient', '=', true],
          ['id', 'in', consultationPatientIds.toList()],
        ],
      ],
      'kwargs': {
        'fields': [
          'id',
          'name',
          'phone',
          'email',
          'ref',
          'insurance_id',
          'patient_code',
          'height',
          'age',
          'comment',
          'is_patient',
          'create_uid',
          'user_id',
        ],
        'order': 'id desc',
      },
    }, cookie: adminCookie);

    print('>>> getPatients: ${primaryData?['result']?.length ?? 0} patients trouvés au total');

    final mergedPatients = (primaryData?['result'] as List?) ?? [];
    for (var p in mergedPatients) {
      p['medical_file_number'] = _s(p['ref']);
      p['patient_code'] = _s(p['patient_code']);
      if (p['patient_code'].isEmpty && p['comment'] is String && p['comment'].contains('CIN:')) {
        p['patient_code'] =
            p['comment'].split('CIN:')[1].split('\n')[0].trim();
      }
    }
    return mergedPatients;
  }

  static Future<Map<String, dynamic>> createPatient({
    required String name,
    String phone = '',
    String email = '',
    String insuranceId = '',
    String medicalFileNumber = '',
    String patientCode = '',
    double height = 0.0,
    int age = 0,
    String? comment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final doctorUid = prefs.getInt('uid') ?? 0;
    final finalComment = patientCode.isNotEmpty
        ? "CIN: $patientCode\n${comment ?? ''}"
        : (comment ?? '');
    final cookie = await _getSessionCookie();

    // ◄ DEBUG : vérifie le cookie
    print('>>> createPatient cookie: $cookie');

    // ◄ SOLUTION : utilise l'auth admin comme pour les autres fonctions
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Auth admin failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);
    print('>>> createPatient adminCookie: $adminCookie');

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.partner',
      'method': 'create',
      'args': [
        {
          'name': name,
          'phone': phone,
          'email': email,
          'insurance_id': insuranceId,
          'patient_code': patientCode,
          'ref': medicalFileNumber,
          'height': height > 0 ? height : false,  // ◄ CHANGÉ POUR ODOO 19
          'age': age > 0 ? age : false,  // ◄ CHANGÉ POUR ODOO 19
          'is_patient': true,
          'comment': finalComment,
          'user_id': doctorUid,
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);  // ◄ UTILISE adminCookie

    // ◄ AJOUTE CES LIGNES POUR VOIR L'ERREUR
    print('>>> createPatient response: $data');
    if (data != null && data['error'] != null) {
      print('>>> ERREUR: ${data['error']['data']?['message']}');
      print('>>> DETAILS: ${data['error']['data']?['debug']}');
    }

    if (data != null && data['result'] != null) {
      await _logSecretaryActivity("Création patient", details: name);
      // ◄ NE PAS créer automatiquement le dossier ici
      // Le dialog post-création le fera si l'utilisateur sélectionne "Ajouter une consultation"
      return {'success': true, 'id': data['result']};
    }
    return {'success': false, 'error': data?['error']?['data']?['message'] ?? 'Erreur inconnue'};
  }

  static Future<Map<String, dynamic>> updatePatient({
    required int patientId,
    required String name,
    required String phone,
    required String email,
    required String insuranceId,
    required double height,
    required int age,
    String? comment,
    String patientCode = '',
    String medicalFileNumber = '',
  }) async {
    final finalComment = patientCode.isNotEmpty
        ? "CIN: $patientCode\n${comment ?? ''}"
        : (comment ?? '');
    final cookie = await _getSessionCookie();
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Auth admin failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.partner',
      'method': 'write',
      'args': [
        [patientId],
        {
          'name': name,
          'phone': phone,
          'email': email,
          'insurance_id': insuranceId,
          'patient_code': patientCode,
          'ref': medicalFileNumber,
          'height': height,
          'age': age,
          'comment': finalComment,
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);
    final success = data?['result'] == true;
    if (success) {
      await _logSecretaryActivity("Modification patient", details: name);
      return {'success': true};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> deletePatient(int patientId) async {
    try {
      final auth = await _callRpc('/web/session/authenticate', {
        'db': dbName,
        'login': _adminLogin,
        'password': _adminPassword,
      });
      if (auth == null || auth['result'] == null) {
        return {'success': false, 'error': 'Auth admin failed'};
      }
      final cookie = _s(auth['set-cookie']);

      // Dossiers médicaux
      final recs = await _callRpc('/web/dataset/call_kw', {
        'model': 'medical.consultation',
        'method': 'search',
        'args': [
          [
            ['patient_id', '=', patientId],
          ],
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (recs != null &&
          recs['result'] is List &&
          (recs['result'] as List).isNotEmpty) {
        await _callRpc('/web/dataset/call_kw', {
          'model': 'medical.consultation',
          'method': 'unlink',
          'args': [recs['result']],
          'kwargs': {},
        }, cookie: cookie);
      }

      // Calendrier
      final evts = await _callRpc('/web/dataset/call_kw', {
        'model': 'calendar.event',
        'method': 'search',
        'args': [
          [
            [
              'partner_ids',
              'in',
              [patientId],
            ],
          ],
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (evts != null &&
          evts['result'] is List &&
          (evts['result'] as List).isNotEmpty) {
        await _callRpc('/web/dataset/call_kw', {
          'model': 'calendar.event',
          'method': 'unlink',
          'args': [evts['result']],
          'kwargs': {},
        }, cookie: cookie);
      }

      // Factures
      final invs = await _callRpc('/web/dataset/call_kw', {
        'model': 'account.move',
        'method': 'search',
        'args': [
          [
            ['partner_id', '=', patientId],
          ],
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (invs != null &&
          invs['result'] is List &&
          (invs['result'] as List).isNotEmpty) {
        for (var id in invs['result']) {
          await _callRpc('/web/dataset/call_kw', {
            'model': 'account.move',
            'method': 'button_draft',
            'args': [
              [id],
            ],
            'kwargs': {},
          }, cookie: cookie);
          await _callRpc('/web/dataset/call_kw', {
            'model': 'account.move',
            'method': 'unlink',
            'args': [
              [id],
            ],
            'kwargs': {},
          }, cookie: cookie);
        }
      }

      final res = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.partner',
        'method': 'unlink',
        'args': [
          [patientId],
        ],
        'kwargs': {},
      }, cookie: cookie);

      if (res != null && res['result'] == true) {
        await _logSecretaryActivity(
          "Suppression patient",
          details: "ID $patientId",
        );
        return {'success': true};
      }

      // Fallback : archiver
      await _callRpc('/web/dataset/call_kw', {
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [patientId],
          {'active': false},
        ],
        'kwargs': {},
      }, cookie: cookie);

      await _logSecretaryActivity(
        "Archivage patient",
        details: "ID $patientId",
      );
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── SÉCRÉTAIRES ────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSecretaries() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    
    // ◄ UTILISE AUTH ADMIN POUR COHÉRENCE
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return [];
    }
    final adminCookie = _s(adminAuth['set-cookie']);
    
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary',
      'method': 'search_read',
      'args': [
        [
          ['doctor_id', '=', uid],
        ],
      ],
      'kwargs': {
        'fields': [
          'id',
          'first_name',
          'last_name',
          'full_name',
          'gender',
          'birth_date',
          'phone',
          'mobile',
          'email',
          'secretary_code',
          'national_id',
          'address',
          'employee_id',
          'hire_date',
          'office_number',
          'working_hours',
          'active',
          'notes',
        ],
        'limit': 100,
      },
    }, cookie: adminCookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createSecretary(
      Map<String, dynamic> vals,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;
    
    // ◄ UTILISE AUTH ADMIN POUR COHÉRENCE
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Auth admin failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);
    
    vals['doctor_id'] = uid;
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary',
      'method': 'create',
      'args': [vals],
      'kwargs': {},
    }, cookie: adminCookie);  // ◄ UTILISE adminCookie
    
    if (data != null && data['result'] != null) {
      print('>>> createSecretary: created secretary ${data['result']}');
      return {'success': true, 'id': data['result']};
    } else if (data != null && data['error'] != null) {
      print('>>> createSecretary ERROR: ${data['error']['data']?['message']}');
      return {'success': false, 'error': data['error']['data']?['message']};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> updateSecretary(
      int id,
      Map<String, dynamic> vals,
      ) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary',
      'method': 'write',
      'args': [
        [id],
        vals,
      ],
      'kwargs': {},
    }, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<Map<String, dynamic>> deleteSecretary(int id) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.secretary',
      'method': 'unlink',
      'args': [
        [id],
      ],
      'kwargs': {},
    }, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<List<dynamic>> getSecretaryLogs(int secretaryId) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'mail.message',
      'method': 'search_read',
      'args': [
        [
          ['model', '=', 'medical.secretary'],
          ['res_id', '=', secretaryId],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'body', 'date', 'model', 'res_id'],
        'limit': 50,
        'order': 'date desc',
      },
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  // ─── INFIRMIERS ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getNurses() async {
    // ◄ UTILISE AUTH ADMIN POUR COHÉRENCE
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return [];
    }
    final adminCookie = _s(adminAuth['set-cookie']);
    
    // ◄ RÉCUPÈRE TOUS LES INFIRMIERS ACTIFS (pas de filtre doctor_id dans le modèle)
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'nurse.nurse',
      'method': 'search_read',
      'args': [
        [
          ['active', '=', true],
        ],
      ],
      'kwargs': {
        'fields': [
          'id',
          'name',
          'age',
          'gender',
          'phone',
          'email',
          'license_number',
          'license_expiry_date',
          'specialization',
          'department_id',
          'state',
          'active',
          'notes',
          'create_uid', // Ajouté pour information
        ],
        'limit': 100,
      },
    }, cookie: adminCookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> createNurse(
      Map<String, dynamic> vals,
      ) async {
    // ◄ UTILISE AUTH ADMIN POUR COHÉRENCE
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Auth admin failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);
    
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'nurse.nurse',
      'method': 'create',
      'args': [vals],
      'kwargs': {},
    }, cookie: adminCookie);  // ◄ UTILISE adminCookie
    
    if (data != null && data['result'] != null) {
      print('>>> createNurse: created nurse ${data['result']}');
      return {'success': true, 'id': data['result']};
    } else if (data != null && data['error'] != null) {
      print('>>> createNurse ERROR: ${data['error']['data']?['message']}');
      return {'success': false, 'error': data['error']['data']?['message']};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> updateNurse(
      int id,
      Map<String, dynamic> vals,
      ) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'nurse.nurse',
      'method': 'write',
      'args': [
        [id],
        vals,
      ],
      'kwargs': {},
    }, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<Map<String, dynamic>> deleteNurse(int id) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'nurse.nurse',
      'method': 'unlink',
      'args': [
        [id],
      ],
      'kwargs': {},
    }, cookie: cookie);
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<List<dynamic>> getNurseLogs(int nurseId) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'mail.message',
      'method': 'search_read',
      'args': [
        [
          ['model', '=', 'nurse.nurse'],
          ['res_id', '=', nurseId],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'body', 'date', 'model', 'res_id'],
        'limit': 50,
        'order': 'date desc',
      },
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  // ─── GESTION GÉNÉRALE ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addMedicalRecord({
    required int patientId,
    required int doctorId,
    required String datetime,
    required String consultationReason,
    required String diagnostic,
    required String prescription,
    required String observations,
    String status = 'draft',
    String medicalFileNumber = '',
  }) async {
    if (doctorId <= 0) {
      print('>>> addMedicalRecord: invalid doctorId=$doctorId');
      return {'success': false, 'error': 'Médecin introuvable'};
    }
    // ◄ UTILISE AUTH ADMIN POUR COHÉRENCE
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Auth admin failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'create',
      'args': [
        {
          'patient_id': patientId,
          'doctor_id': doctorId,
          'date_consultation': datetime,
          'motif': consultationReason,
          'diagnostic': diagnostic,
          'prescription': prescription,
          'observations': observations,
          'state': status,
          'medical_file_number': medicalFileNumber,
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);  // ◄ UTILISE adminCookie
    print('>>> addMedicalRecord: created record ${data?['result']} for patient $patientId');
    if (data != null && data['error'] != null) {
      print('>>> addMedicalRecord ERROR: ${data['error']['data']?['message']}');
      print('>>> addMedicalRecord DEBUG: ${data['error']['data']?['debug']}');
    }
    return data != null && data['result'] != null
        ? {'success': true, 'id': data['result']}
        : {'success': false, 'error': data?['error']?['data']?['message'] ?? 'Erreur ajout dossier'};
  }

  static Future<Map<String, dynamic>> updateMedicalRecord({
    required int recordId,
    required String motif,
    required String diagnostic,
    required String prescription,
    required String observations,
    required String state,
    String medicalFileNumber = '',
    String? datetime,
  }) async {
    // ◄ UTILISE AUTH ADMIN POUR COHÉRENCE
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Auth admin failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'write',
      'args': [
        [recordId],
        {
          'motif': motif,
          'diagnostic': diagnostic,
          'prescription': prescription,
          'observations': observations,
          'state': state,
          'medical_file_number': medicalFileNumber,
          if (datetime != null) 'date_consultation': datetime,
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);  // ◄ UTILISE adminCookie
    print('>>> updateMedicalRecord: updated record $recordId to state $state');
    return data?['result'] == true ? {'success': true} : {'success': false};
  }

  static Future<Map<String, int>> getDashboardStats() async {
    final results = await Future.wait([getPatients(), getMedicalRecords()]);
    return {'patients': results[0].length, 'records': results[1].length};
  }

  static Future<List<dynamic>> getBpMeasurements({int? patientId}) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'bp.measurement',
      'method': 'search_read',
      'args': [
        patientId != null
            ? [
          ['patient_id', '=', patientId],
        ]
            : [],
      ],
      'kwargs': {
        'fields': [
          'id',
          'patient_id',
          'date_mesure',
          'systolique',
          'diastolique',
          'pouls',
          'appareil',
        ],
        'limit': 50,
        'order': 'date_mesure desc',
      },
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  static Future<List<dynamic>> getBodyMeasurements({int? patientId}) async {
    final cookie = await _getSessionCookie();
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'body.measurement',
      'method': 'search_read',
      'args': [
        patientId != null
            ? [
          ['patient_id', '=', patientId],
        ]
            : [],
      ],
      'kwargs': {
        'fields': [
          'id',
          'patient_id',
          'date',
          'weight',
          'bmi',
          'body_fat',
          'muscle_mass',
          'water',
          'bone_mass',
          'visceral_fat',
          'metabolic_age',
        ],
        'limit': 50,
        'order': 'date desc',
      },
    }, cookie: cookie);
    return data?['result'] ?? [];
  }

  static Future<Map<String, dynamic>> testConnection() async {
    final data = await _callRpc('/jsonrpc', {
      'service': 'common',
      'method': 'version',
      'args': [],
    });
    if (data != null && data['result'] != null) {
      return {
        'success': true,
        'version':
        data['result']['server_version']?.toString() ?? 'Odoo',
      };
    }
    return {'success': false, 'error': 'Erreur'};
  }

  static Future<List<String>> findDoctorRegistrationDuplicateWarnings({
    required String name,
    required String login,
    String phone = '',
  }) async {
    try {
      final auth = await _callRpc('/web/session/authenticate', {
        'db': dbName,
        'login': _adminLogin,
        'password': _adminPassword,
      });
      if (auth == null || auth['result'] == null) return [];
      final cookie = _s(auth['set-cookie']);
      final lt = login.trim().toLowerCase();
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final tail =
      digits.length >= 9 ? digits.substring(digits.length - 9) : digits;
      final trimmedName = name.trim();
      final clauses = <List<dynamic>>[];
      if (lt.isNotEmpty) {
        clauses.add(['login', '=ilike', lt]);
        clauses.add(['email', '=ilike', lt]);
      }
      if (tail.length >= 8) {
        // Odoo 19 : mobile n'est plus sur res.users, on cherche uniquement par phone
        clauses.add(['phone', 'ilike', tail]);
      }
      if (trimmedName.length >= 4) {
        clauses.add(['name', 'ilike', trimmedName]);
      }
      if (clauses.isEmpty) return [];

      final domain = odooOrDomain(clauses);
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.users',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          // Odoo 19 : mobile supprimé de res.users, on récupère partner_id
          'fields': ['id', 'name', 'login', 'email', 'phone', 'partner_id'],
          'limit': 80,
        },
      }, cookie: cookie);

      if (data == null || data['result'] == null) return [];
      final users = data['result'] as List;
      final warnings = <String>{};
      final newPhone = DuplicateGuard.normPhone(phone);

      // Récupérer les mobiles depuis res.partner si nécessaire
      final partnerIds = users
          .where((u) => u['partner_id'] is List)
          .map<int>((u) => u['partner_id'][0] as int)
          .toList();
      final Map<int, String> partnerMobiles = {};
      if (partnerIds.isNotEmpty && newPhone.isNotEmpty) {
        final partnerData = await _callRpc('/web/dataset/call_kw', {
          'model': 'res.partner',
          'method': 'read',
          'args': [partnerIds, ['id', 'phone']],
          'kwargs': {},
        }, cookie: cookie);
        if (partnerData != null && partnerData['result'] is List) {
          for (final p in partnerData['result']) {
            partnerMobiles[p['id']] = _s(p['phone']);
          }
        }
      }

      for (final raw in users) {
        if (raw is! Map) continue;
        final u = Map<String, dynamic>.from(raw);
        final uname = _s(u['name']);
        final ulogin = _s(u['login']).trim().toLowerCase();
        final uemail = _s(u['email']).trim().toLowerCase();

        if (lt.isNotEmpty && (ulogin == lt || (uemail.isNotEmpty && uemail == lt))) {
          warnings.add('Identifiant ou e-mail déjà associé au compte « $uname »');
        }
        if (newPhone.isNotEmpty) {
          final up = DuplicateGuard.normPhone(_s(u['phone']));
          final partnerId = u['partner_id'] is List ? u['partner_id'][0] as int : 0;
          final um = DuplicateGuard.normPhone(partnerMobiles[partnerId] ?? '');
          if ((up.isNotEmpty && up == newPhone) ||
              (um.isNotEmpty && um == newPhone)) {
            warnings.add('Téléphone déjà associé au compte « $uname »');
          }
        }
        if (trimmedName.isNotEmpty &&
            uname.isNotEmpty &&
            DuplicateGuard.nameSimilarity(trimmedName, uname) >=
                DuplicateGuard.nameSimilarityThreshold) {
          warnings.add('Nom très proche du compte existant « $uname »');
        }
      }
      return warnings.toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> registerDoctor({
    required String name,
    required String login,
    required String password,
    String? phone,
  }) async {
    final auth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (auth == null || auth['result'] == null) {
      return {'success': false, 'error': 'Admin auth failed'};
    }
    final adminCookie = _s(auth['set-cookie']);

    // Odoo 19 : plus de groups_id ni mobile sur res.users
    final createData = await _callRpc('/web/dataset/call_kw', {
      'model': 'res.users',
      'method': 'create',
      'args': [
        {
          'name': name,
          'login': login,
          'password': password,
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);

    if (createData == null || createData['result'] == null) {
      return {'success': false};
    }

    final userId = createData['result'];

    // Odoo 19 : assigner le groupe "Role / User" (id=1) via res.groups
    await _callRpc('/web/dataset/call_kw', {
      'model': 'res.groups',
      'method': 'write',
      'args': [
        [1],
        {
          'users': [[4, userId]],
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);

    // Odoo 19 : écrire phone sur res.partner lié (mobile supprimé en v19)
    if (phone != null && phone.isNotEmpty) {
      final userData = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.users',
        'method': 'read',
        'args': [[userId], ['partner_id']],
        'kwargs': {},
      }, cookie: adminCookie);

      if (userData != null &&
          userData['result'] is List &&
          (userData['result'] as List).isNotEmpty) {
        final partnerRef = userData['result'][0]['partner_id'];
        final partnerId = partnerRef is List ? partnerRef[0] : partnerRef;
        await _callRpc('/web/dataset/call_kw', {
          'model': 'res.partner',
          'method': 'write',
          'args': [[partnerId], {'phone': phone}],
          'kwargs': {},
        }, cookie: adminCookie);
      }
    }

    return {'success': true};
  }

  static Future<Map<String, dynamic>> addToWaitingRoom({
    required int patientId,
    String motif = 'Consultation',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('uid') ?? 0;

    // Fix C: Utiliser adminCookie au lieu de _getSessionCookie()
    final adminAuth = await _callRpc('/web/session/authenticate', {
      'db': dbName,
      'login': _adminLogin,
      'password': _adminPassword,
    });
    if (adminAuth == null || adminAuth['result'] == null) {
      return {'success': false, 'error': 'Admin auth failed'};
    }
    final adminCookie = _s(adminAuth['set-cookie']);

    final now = DateTime.now().toString().substring(0, 19);
    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'medical.consultation',
      'method': 'create',
      'args': [
        {
          'patient_id': patientId,
          'doctor_id': uid,
          'date_consultation': now,
          'motif': motif,
          'state': 'waiting',
        },
      ],
      'kwargs': {},
    }, cookie: adminCookie);
    if (data != null && data['result'] != null) {
      await _logSecretaryActivity(
        "Ajout en salle d'attente",
        details: "Patient ID $patientId",
      );
      return {'success': true, 'id': data['result']};
    }
    return {'success': false};
  }

  static Future<void> _logSecretaryActivity(
      String action, {
        String details = '',
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'doctor';
    if (role != 'secretary' && role != 'nurse') return;

    final cookie = await _getSessionCookie();
    final body = details.trim().isEmpty ? action : "$action : $details";
    final int targetId = role == 'nurse'
        ? (prefs.getInt('nurse_id') ?? 0)
        : (prefs.getInt('secretary_id') ?? 0);
    final String targetModel =
    role == 'nurse' ? 'nurse.nurse' : 'medical.secretary';
    if (targetId <= 0) return;

    await _callRpc('/web/dataset/call_kw', {
      'model': 'mail.message',
      'method': 'create',
      'args': [
        {
          'model': targetModel,
          'res_id': targetId,
          'message_type': 'comment',
          'subtype_id': 1,
          'body': body,
        },
      ],
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

    final dateEnd = DateTime.parse(dateStart)
        .add(Duration(minutes: durationMinutes))
        .toString()
        .substring(0, 19);

    final data = await _callRpc('/web/dataset/call_kw', {
      'model': 'calendar.event',
      'method': 'create',
      'args': [
        {
          'name': 'RDV: $name',
          'start': dateStart,
          'stop': dateEnd,
          'duration': durationMinutes / 60.0,
          'description': description,
          'partner_ids': [
            [6, 0, [partnerId, patientId]],
          ],
          'user_id': uid,
        },
      ],
      'kwargs': {},
    }, cookie: cookie);

    if (data != null && data['result'] != null) {
      await addMedicalRecord(
        patientId: patientId,
        doctorId: uid,
        datetime: dateStart,
        consultationReason:
        description.isEmpty ? "Consultation" : description,
        diagnostic: '',
        prescription: '',
        observations: '',
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
        'model': 'medical.secretary',
        'method': 'read',
        'args': [
          [sid],
          ['first_name', 'last_name', 'full_name', 'email', 'phone', 'mobile'],
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (data != null &&
          data['result'] != null &&
          (data['result'] as List).isNotEmpty) {
        final d = data['result'][0];
        return {
          'success': true,
          'data': {
            'name': _s(d['full_name']),
            'email': _s(d['email']),
            'phone': _s(d['phone']),
            'mobile': _s(d['mobile']),
            'login': _s(d['email']),
          },
        };
      }
    } else if (role == 'nurse') {
      final nid = prefs.getInt('nurse_id') ?? 0;
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'nurse.nurse',
        'method': 'read',
        'args': [
          [nid],
          ['name', 'email', 'phone'],
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (data != null &&
          data['result'] != null &&
          (data['result'] as List).isNotEmpty) {
        final d = data['result'][0];
        return {
          'success': true,
          'data': {
            'name': _s(d['name']),
            'email': _s(d['email']),
            'phone': _s(d['phone']),
            'mobile': _s(d['phone']),
            'login': _s(d['email']),
          },
        };
      }
    } else {
      final uid = prefs.getInt('uid') ?? 0;
      final partnerId = prefs.getInt('partner_id') ?? 0;
      // Odoo 19 : mobile n'est plus sur res.users, on lit depuis res.partner
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.users',
        'method': 'read',
        'args': [
          [uid],
          ['name', 'login', 'email', 'phone', 'partner_id'],
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (data != null &&
          data['result'] != null &&
          (data['result'] as List).isNotEmpty) {
        final d = data['result'][0];
        final pId = d['partner_id'] is List ? d['partner_id'][0] : (partnerId > 0 ? partnerId : 0);
        String mobile = '';
        if (pId > 0) {
          final partnerData = await _callRpc('/web/dataset/call_kw', {
            'model': 'res.partner',
            'method': 'read',
            'args': [[pId], ['phone']],
            'kwargs': {},
          }, cookie: cookie);
          if (partnerData != null &&
              partnerData['result'] is List &&
              (partnerData['result'] as List).isNotEmpty) {
            mobile = _s(partnerData['result'][0]['phone']);
          }
        }
        return {
          'success': true,
          'data': {
            'name': _s(d['name']),
            'login': _s(d['login']),
            'email': _s(d['email']),
            'phone': _s(d['phone']),
            'mobile': mobile,
          },
        };
      }
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> vals,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'doctor';
    final cookie = await _getSessionCookie();

    if (role == 'secretary') {
      final sid = prefs.getInt('secretary_id') ?? 0;
      Map<String, dynamic> secVals = {};
      if (vals.containsKey('name')) {
        secVals['first_name'] = vals['name'].split(' ')[0];
        secVals['last_name'] = vals['name'].contains(' ')
            ? vals['name'].substring(vals['name'].indexOf(' ') + 1)
            : '';
      }
      if (vals.containsKey('email')) secVals['email'] = vals['email'];
      if (vals.containsKey('phone')) secVals['phone'] = vals['phone'];
      if (vals.containsKey('mobile')) secVals['mobile'] = vals['mobile'];

      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'medical.secretary',
        'method': 'write',
        'args': [
          [sid],
          secVals,
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (data?['result'] == true) {
        if (vals.containsKey('name')) {
          await prefs.setString('doctor_name', vals['name']);
        }
        return {'success': true};
      }
    } else if (role == 'nurse') {
      final nid = prefs.getInt('nurse_id') ?? 0;
      Map<String, dynamic> nurseVals = {};
      if (vals.containsKey('name')) nurseVals['name'] = vals['name'];
      if (vals.containsKey('email')) nurseVals['email'] = vals['email'];
      if (vals.containsKey('phone')) nurseVals['phone'] = vals['phone'];

      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'nurse.nurse',
        'method': 'write',
        'args': [
          [nid],
          nurseVals,
        ],
        'kwargs': {},
      }, cookie: cookie);
      if (data?['result'] == true) {
        if (vals.containsKey('name')) {
          await prefs.setString('doctor_name', vals['name']);
        }
        return {'success': true};
      }
    } else {
      final uid = prefs.getInt('uid') ?? 0;
      final partnerId = prefs.getInt('partner_id') ?? 0;

      // Odoo 19 : séparer les champs res.users et res.partner
      final userVals = Map<String, dynamic>.from(vals)..remove('mobile');
      final data = await _callRpc('/web/dataset/call_kw', {
        'model': 'res.users',
        'method': 'write',
        'args': [
          [uid],
          userVals,
        ],
        'kwargs': {},
      }, cookie: cookie);

      // Écrire phone sur res.partner si fourni (mobile supprimé en Odoo 19)
      if (vals.containsKey('mobile') && partnerId > 0) {
        await _callRpc('/web/dataset/call_kw', {
          'model': 'res.partner',
          'method': 'write',
          'args': [[partnerId], {'phone': vals['mobile']}],
          'kwargs': {},
        }, cookie: cookie);
      }

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