import 'package:flutter/material.dart';

// ─── MODÈLE DE TRADUCTIONS ────────────────────────────────────────────────────
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  static final Map<String, Map<String, String>> _translations = {

    // ── GÉNÉRAL ──────────────────────────────────────────────────────────────
    'appName':            {'fr': 'MedicalRecord',        'ar': 'السجل الطبي'},
    'appSubtitle':        {'fr': 'SDS · Cabinet Médical','ar': 'SDS · عيادة طبية'},
    'cancel':             {'fr': 'Annuler',              'ar': 'إلغاء'},
    'save':               {'fr': 'Enregistrer',          'ar': 'حفظ'},
    'edit':               {'fr': 'Modifier',             'ar': 'تعديل'},
    'delete':             {'fr': 'Supprimer',            'ar': 'حذف'},
    'confirm':            {'fr': 'Confirmer',            'ar': 'تأكيد'},
    'close':              {'fr': 'Fermer',               'ar': 'إغلاق'},
    'back':               {'fr': 'Retour',               'ar': 'رجوع'},
    'loading':            {'fr': 'Chargement...',        'ar': 'جارٍ التحميل...'},
    'error':              {'fr': 'Erreur',               'ar': 'خطأ'},
    'success':            {'fr': 'Succès',               'ar': 'نجاح'},
    'language':           {'fr': 'Langue',               'ar': 'اللغة'},
    'french':             {'fr': 'Français',             'ar': 'الفرنسية'},
    'arabic':             {'fr': 'Arabe',                'ar': 'العربية'},
    'seeAll':             {'fr': 'Voir tout',            'ar': 'عرض الكل'},
    'online':             {'fr': 'En ligne',             'ar': 'متصل'},
    'noData':             {'fr': 'Aucune donnée',        'ar': 'لا توجد بيانات'},
    'retry':              {'fr': 'Réessayer',            'ar': 'إعادة المحاولة'},
    'navigation':         {'fr': 'NAVIGATION',           'ar': 'التنقل'},
    'welcome':            {'fr': 'Bienvenue',            'ar': 'مرحباً'},

    // ── SPLASH ───────────────────────────────────────────────────────────────
    'splashInit':         {'fr': 'Initialisation...',                'ar': 'جارٍ التهيئة...'},
    'splashConnecting':   {'fr': 'Connexion au serveur Odoo...',     'ar': 'الاتصال بخادم أودو...'},
    'splashConnected':    {'fr': 'Connecté',                         'ar': 'متصل'},
    'splashError':        {'fr': 'Erreur de connexion',              'ar': 'خطأ في الاتصال'},

    // ── AUTH ─────────────────────────────────────────────────────────────────
    'welcomeBack':        {'fr': 'Bon retour parmi nous !',          'ar': 'مرحباً بعودتك!'},
    'loginSubtitle':      {'fr': 'Connectez-vous à votre espace en tant que Secrétaire ou Médecin', 'ar': 'سجّل دخولك بصفتك سكرتير أو طبيب'},
    'loginBtn':           {'fr': 'Se connecter',                     'ar': 'تسجيل الدخول'},
    'createAccount':      {'fr': 'Créer un compte',          'ar': 'إنشاء حساب طبيب'},
    'identifier':         {'fr': 'Identifiant',                      'ar': 'معرف المستخدم'},
    'identifierHint':     {'fr': 'Adresse e-mail ou numéro de téléphone', 'ar': 'البريد الإلكتروني أو رقم الهاتف'},
    'password':           {'fr': 'Mot de passe',                     'ar': 'كلمة المرور'},
    'confirmPassword':    {'fr': 'Confirmer le mot de passe',        'ar': 'تأكيد كلمة المرور'},
    'fullName':           {'fr': 'Nom complet',                      'ar': 'الاسم الكامل'},
    'fullNameHint':       {'fr': 'Dr. Jean Dupont',                  'ar': 'د. محمد بنعلي'},
    'emailHint':          {'fr': 'dr.dupont@cabinet.com',            'ar': 'dr.mohammed@clinic.ma'},
    'newDoctor':          {'fr': 'Nouveau compte',                  'ar': 'طبيب nouveau'},
    'newDoctorSubtitle':  {'fr': 'Le compte sera enregistré dans notre base de donnée', 'ar': 'سيتم تسجيل الحساب في أودو'},
    'orSeparator':        {'fr': 'ou',                               'ar': 'أو'},
    'loginError':         {'fr': 'Identifiants incorrects',          'ar': 'بيانات الدخول غير صحيحة'},
    'sessionExpired':     {'fr': 'Session expirée, reconnectez-vous','ar': 'انتهت الجلسة، يرجى إعادة تسجيل الدخول'},
    'accountCreated':     {'fr': 'Compte créé avec succès ! Vous pouvez vous connecter.',
                           'ar': 'تم إنشاء الحساب بنجاح! يمكنك تسجيل الدخول الآن.'},
    'allFieldsRequired':  {'fr': 'Tous les champs sont obligatoires','ar': 'جميع الحقول مطلوبة'},
    'passwordMismatch':   {'fr': 'Les mots de passe ne correspondent pas', 'ar': 'كلمta المرور غير متطابقتين'},
    'roleDoctor':         {'fr': 'Médecin',                          'ar': 'طبيب'},
    'roleSecretary':      {'fr': 'Secrétaire',                       'ar': 'سكرتير(ة)'},
    'secIdentifierLabel': {'fr': 'Email ou Téléphone',               'ar': 'البريد الإلكتروني أو الهاتف'},
    'secCodeLabel':       {'fr': 'Code Secrétaire',                  'ar': 'رمز السكرتارية'},

    // ── FEATURES LOGIN ───────────────────────────────────────────────────────
    'feature1':           {'fr': 'Dossiers patients centralisés',    'ar': 'ملفات المرضى مركزية'},
    'feature2':           {'fr': 'Historique des consultations',     'ar': 'سجل الاستشارات'},
    'feature3':           {'fr': 'Prescriptions & diagnostics',      'ar': 'الوصفات والتشخيصات'},
    'feature4':           {'fr': 'Accès sécurisé multi-médecins',    'ar': 'وصol آمن متعدد الأطباء'},
    'systemTitle':        {'fr': 'Système de gestion\nclinique intelligent',
                           'ar': 'نظام إدارة\nالعيادة الذكي'},

    // ── SIDEBAR ──────────────────────────────────────────────────────────────
    'navDashboard':       {'fr': 'Tableau de bord',      'ar': 'لوحة التحكم'},
    'navPatients':        {'fr': 'Patients',             'ar': 'المرضى'},
    'navSecretaries':     {'fr': 'Secrétaires',          'ar': 'السكرتارية'},
    'navRecords':         {'fr': 'Dossiers médicaux',    'ar': 'الملفات الطبية'},
    'navAddRecord':       {'fr': 'Nouvelle Consultation',      'ar': 'ملف جديد'},
    'navInvoices':        {'fr': 'Facturation',          'ar': 'الفواتير'},
    'navSettings':        {'fr': 'Paramètres',           'ar': 'الإعدادات'},
    'logout':             {'fr': 'Déconnexion',          'ar': 'تسجيل الخروج'},
    'logoutConfirmTitle': {'fr': 'Déconnexion',          'ar': 'تسجيل الخروج'},
    'logoutConfirmBody':  {'fr': 'Voulez-vous vraiment vous déconnecter ?',
                           'ar': 'هل تريد فعلاً تسجيل الخروج؟'},
    'logoutBtn':          {'fr': 'Déconnecter',          'ar': 'خروج'},

    // ── DASHBOARD ────────────────────────────────────────────────────────────
    'greetingMorning':    {'fr': 'Bonjour',              'ar': 'صباح الخير'},
    'greetingAfternoon':  {'fr': 'Bon après-midi',       'ar': 'مساء الخير'},
    'greetingEvening':    {'fr': 'Bonsoir',              'ar': 'مساء النور'},
    'dashSubtitle':       {'fr': "Voici un aperçu de votre cabinet aujourd'hui",
                           'ar': 'إليك نظرة عامة على عيادتك اليوم'},
    'totalPatients':      {'fr': 'Total Patients',       'ar': 'إجمالي المرضى'},
    'medicalRecords':     {'fr': 'Dossiers médicaux',    'ar': 'الملفات الطبية'},
    'consultations':      {'fr': 'Consultations',        'ar': 'الاستشارات'},
    'thisMonth':          {'fr': 'Ce mois',              'ar': 'هذا الشهر'},
    'allConsultations':   {'fr': 'Toutes consultations', 'ar': 'جميع الاستشارات'},
    'registered':         {'fr': 'enregistrés',          'ar': 'مسجل'},
    'quickActions':       {'fr': 'Actions rapides',      'ar': 'إجراءات سريعة'},
    'viewPatients':       {'fr': 'Voir les patients',    'ar': 'عرض المرضى'},
    'viewPatientAction':  {'fr': 'Voir le patient',       'ar': 'عرض المريض'},
    'newRecord':          {'fr': 'Nouveau dossier',      'ar': 'ملف جديد'},
    'createNow':          {'fr': 'Créer maintenant',     'ar': 'إنشاء الآن'},
    'allRecords':         {'fr': 'Tous les dossiers',    'ar': 'جميع الملفات'},
    'viewCalendar':       {'fr': 'Voir le Calendrier',   'ar': 'عرض التقويم'},
    'calendarSubtitle':   {'fr': 'Gérer les rendez-vous','ar': 'إدارة المواعيد'},
    'recentActivity':     {'fr': 'Activité récente',     'ar': 'النشاط الأخير'},
    'noRecords':          {'fr': 'Aucun dossier médical','ar': 'لا توجد ملفات طبية'},
    'colPatient':         {'fr': 'Patient',              'ar': 'المريض'},
    'colDate':            {'fr': 'Date',                 'ar': 'التاريخ'},
    'colDiagnostic':      {'fr': 'Diagnostic',           'ar': 'التشخيص'},
    'colStatus':          {'fr': 'Statut',               'ar': 'الحالة'},
    'consulted':          {'fr': 'Consulté',             'ar': 'تمت الاستشارة'},
    'todayOverview':      {'fr': 'Vue du jour',          'ar': 'نظرة اليوم'},
    'todayRecords':       {'fr': 'Consultations du jour','ar': 'استشارات اليوم'},
    'draftsToValidate':   {'fr': 'Brouillons à valider', 'ar': 'مسودات بانتظار التحقق'},
    'validatedRecords':   {'fr': 'Dossiers validés',     'ar': 'ملفات مؤكدة'},
    'recentPatients':     {'fr': 'Patients récents',     'ar': 'المرضى الحديثون'},
    'noRecentPatients':   {'fr': 'Aucun patient récent', 'ar': 'لا يوجد مرضى حديثون'},
    'waitingRoom':        {'fr': "Salle d'attente",      'ar': 'قاعة الانتظار'},
    'serverIp':           {'fr': 'Adresse Serveur',      'ar': 'عنوان الخادم'},
    'patientsWaiting':    {'fr': 'Patients en attente',  'ar': 'المرضى في الانتظار'},
    'todayConsults':      {'fr': "Consultations d'aujourd'hui", 'ar': 'استشارات اليوم'},
    'todayView':          {'fr': 'Vue du Jour',          'ar': 'عرض اليوم'},

    // ── PATIENTS ─────────────────────────────────────────────────────────────
    'patientsTitle':      {'fr': 'Patients',             'ar': 'المرضى'},
    'patientsCount':      {'fr': 'patient(s) enregistré(s)', 'ar': 'مريض مسجل'},
    'searchPatient':      {'fr': 'Rechercher un patient...', 'ar': 'البحث عن مريض...'},
    'noPatientFound':     {'fr': 'Aucun patient trouvé', 'ar': 'لا يوجد مريض'},
    'addInOdoo':          {'fr': 'Ajoutez des patients dans Odoo\navec "Est un patient = Oui"',
                           'ar': 'أضف المرضى في أودو\nمع "هو مريض = نعم"'},
    'patientBadge':       {'fr': 'Patient',              'ar': 'مريض'},
    'tension':            {'fr': 'Tension',              'ar': 'ضغط الدم'},
    'editPatient':        {'fr': 'Modifier le patient',  'ar': 'تعديل بيانات المريض'},
    'phone':              {'fr': 'Téléphone',            'ar': 'الهاتف'},
    'email':              {'fr': 'Email',                'ar': 'البريد الإلكتروني'},
    'insurance':          {'fr': 'N° Assurance',         'ar': 'رقم التأمين'},
    'nationality':        {'fr': 'Nationalité',          'ar': 'الجنسية'},
    'height':             {'fr': 'Taille (cm)',          'ar': 'الطول (سم)'},
    'age':                {'fr': 'Âge',                  'ar': 'العمر'},
    'years':              {'fr': 'ans',                  'ar': 'سنة'},
    'cm':                 {'fr': 'cm',                   'ar': 'سم'},
    'patientUpdated':     {'fr': 'Patient modifié avec succès',  'ar': 'تم تعديل بيانات المريض بنجاح'},
    'patientCreated':     {'fr': 'Patient créé avec succès', 'ar': 'تم إنشاء المريض بنجاح'},
    'newPatientAction':   {'fr': 'Nouveau patient',      'ar': 'مريض جديد'},
    'newPatientTitle':    {'fr': 'Créer un patient',     'ar': 'إنشاء مريض'},
    'patientNameRequired':{'fr': 'Le nom du patient est obligatoire', 'ar': 'اسم المريض إلزامي'},
    'medicalBackground':  {'fr': 'Antécédents',          'ar': 'السوابق المرضية'},
    'allergies':          {'fr': 'Allergies',            'ar': 'الحساسيات'},
    'currentTreatment':   {'fr': 'Traitement en cours',  'ar': 'العلاج الحالي'},
    'medicalNotes':       {'fr': 'Notes médicales',      'ar': 'ملاحظات طبية'},
    'editProfileInfo':    {'fr': 'Compléter la fiche',   'ar': 'إكمال الملف'},
    'profileSaved':       {'fr': 'Fiche patient mise à jour', 'ar': 'تم تحديث ملف المريض'},
    'noInfoYet':          {'fr': 'Aucune information renseignée', 'ar': 'لا توجد معلومات'},
    'viewProfile':        {'fr': 'Profil',               'ar': 'الملف'},
    'patientProfile':     {'fr': 'Fiche patient',        'ar': 'ملف المريض'},
    'recentConsultations':{'fr': 'Consultations récentes','ar': 'الاستشارات الأخيرة'},
    'quickSummary':       {'fr': 'Résumé rapide',        'ar': 'ملخص سريع'},
    'openRecord':         {'fr': 'Ouvrir le dossier',    'ar': 'فتح الملف'},
    'lastConsultation':   {'fr': 'Dernière consultation','ar': 'آخر استشارة'},
    'noHistoryYet':       {'fr': 'Aucun historique pour ce patient', 'ar': 'لا يوجد سجل لهذا المريض'},

    // ── SECRÉTAIRES ──────────────────────────────────────────────────────────
    'secretariesTitle':   {'fr': 'Gestion des Secrétaires', 'ar': 'إدارة السكرتارية'},
    'newSecretary':       {'fr': 'Nouvelle Secrétaire',  'ar': 'سكرتيرة جديدة'},
    'editSecretary':      {'fr': 'Modifier la Secrétaire','ar': 'تعديل بيانات السكرتيرة'},
    'firstName':          {'fr': 'Prénom',               'ar': 'الاسم الشخصي'},
    'lastName':           {'fr': 'Nom',                  'ar': 'الاسم العائلي'},
    'gender':             {'fr': 'Genre',                'ar': 'الجنس'},
    'male':               {'fr': 'Homme',                'ar': 'ذكر'},
    'female':             {'fr': 'Femme',                'ar': 'أنثى'},
    'birthDate':          {'fr': 'Date de naissance',    'ar': 'تاريخ الميلاد'},
    'secretaryCode':      {'fr': 'Code Secrétaire',      'ar': 'رمز السكرتارية'},
    'nationalId':         {'fr': 'CIN',                  'ar': 'رقم البطاقة الوطنية'},
    'address':            {'fr': 'Adresse',               'ar': 'العنوان'},
    'employeeId':         {'fr': 'ID Employé',           'ar': 'رقم الموظف'},
    'hireDate':           {'fr': 'Date d\'embauche',      'ar': 'تاريخ التوظيف'},
    'officeNumber':       {'fr': 'Numéro de bureau',     'ar': 'رقم المكتب'},
    'workingHours':       {'fr': 'Horaires de travail',  'ar': 'ساعات العمل'},
    'activeStatus':       {'fr': 'Actif',                'ar': 'نشط'},
    'notes':              {'fr': 'Notes',                'ar': 'ملاحظات'},
    'secretaryDeleted':   {'fr': 'Secrétaire supprimée', 'ar': 'تم حذف السكرتيرة'},
    'secretaryCreated':   {'fr': 'Secrétaire créée',     'ar': 'تم إنشاء السكرتيرة'},
    'secretaryUpdated':   {'fr': 'Secrétaire mise à jour','ar': 'تم تحديث السكرتيرة'},

    // ── ACCOUNT / PROFILE ────────────────────────────────────────────────────
    'mySecretarySpace':   {'fr': 'Mon Espace Secrétaire', 'ar': 'مساحة السكرتارية الخاصة بي'},
    'myDoctorSpace':      {'fr': 'Mon Compte Médecin',   'ar': 'حساب الطبيب الخاص بي'},
    'managePersonalInfo': {'fr': 'Gérez vos informations personnelles', 'ar': 'إدارة معلوماتك الشخصية'},
    'manageSecuInfo':     {'fr': 'Gérez vos informations et la sécurité de votre accès', 'ar': 'إدارة معلوماتك وأمن وصولك'},
    'personalInfo':       {'fr': 'INFORMATIONS PERSONNELLES', 'ar': 'معلومات شخصية'},
    'accountSecurity':    {'fr': 'SÉCURITÉ DU COMPTE',   'ar': 'أمن الحساب'},
    'changePassword':     {'fr': 'Changer le mot de passe', 'ar': 'تغيير كلمة المرور'},
    'leaveEmpty':         {'fr': 'Laissez vide si vous ne souhaitez pas modifier votre mot de passe actuel.', 'ar': 'اتركه فارغًا إذا كنت لا ترغب في تغيير كلمة مرورك الحالية.'},
    'newPassword':        {'fr': 'Nouveau mot de passe', 'ar': 'كلمة مرور جديدة'},
    'saveChanges':        {'fr': 'Enregistrer les modifications', 'ar': 'حفظ التغييرات'},
    'profileUpdated':     {'fr': 'Profil mis à jour avec succès', 'ar': 'تم تحديث الملف الشخصي بنجاح'},
    'profileUpdateError': {'fr': 'Erreur lors de la mise à jour', 'ar': 'خطأ أثناء التحديث'},
    'verifiedAccount':    {'fr': 'Compte vérifié',       'ar': 'حساب موثق'},
    'doctorAccess':       {'fr': 'Accès Médecin',        'ar': 'وصول الطبيب'},
    'secretaryAccess':    {'fr': 'Accès Secrétaire',     'ar': 'وصول السكرتير'},

    // ── SETTINGS ──────────────────────────────────────────────────────────────
    'identificationPatient': {'fr': 'Identification Patient', 'ar': 'تحديد هوية المريض'},
    'scanPatientSubtitle':  {'fr': 'Scannez le QR Code de la fiche', 'ar': 'امسح رمز QR للملف'},
    'quickId':              {'fr': 'Identification Rapide', 'ar': 'تحديد هوية سريع'},
    'scanPatientDesc':      {'fr': 'Scannez le code QR généré lors de la planification pour ouvrir instantanément la fiche du patient.', 'ar': 'امسح رمز QR الذي تم إنشاؤه أثناء الجدولة لفتح ملف المريض على الفور.'},
    'startScan':            {'fr': 'Démarrer le Scan',      'ar': 'بدء المسح'},
    'stopScan':             {'fr': 'Arrêter le scan',       'ar': 'إيقاف المسح'},
    'actManagement':        {'fr': 'Gestion des Actes',     'ar': 'إدارة الأعمال الطبية'},
    'actSubtitle':          {'fr': 'Configurez vos tarifs et services', 'ar': 'تكوين الأسعار والخدمات'},
    'add':                  {'fr': 'Ajouter',               'ar': 'إضافة'},
    'noActConfigured':      {'fr': 'Aucun acte configuré',  'ar': 'لم يتم تكوين أي عمل طبي'},
    'newMedicalAct':        {'fr': 'Nouvel Acte Médical',   'ar': 'عمل طبي جديد'},
    'actNameLabel':         {'fr': 'Nom de l\'acte (ex: Consultation)', 'ar': 'اسم العمل (مثلاً: استشارة)'},
    'priceLabel':           {'fr': 'Prix (DH)',             'ar': 'الثمن (درهم)'},
    'patientNotFound':      {'fr': 'Patient non trouvé',    'ar': 'المريض غير موجود'},
    'identificationError':  {'fr': 'Erreur d\'identification', 'ar': 'خطأ في تحديد الهوية'},

    // ── TENSION ARTÉRIELLE ───────────────────────────────────────────────────
    'bloodPressure':      {'fr': 'Tension Artérielle',   'ar': 'ضغط الدم'},
    'noMeasure':          {'fr': 'Aucune mesure disponible', 'ar': 'لا توجد قياسات متاحة'},
    'systolic':           {'fr': 'SYS',                  'ar': 'ضغط انقباضي'},
    'diastolic':          {'fr': 'DIA',                  'ar': 'ضغط انبساطي'},
    'pulse':              {'fr': 'Pouls',                'ar': 'النبض'},
    'statusBp':           {'fr': 'Statut',               'ar': 'الحالة'},
    'normal':             {'fr': 'Normal',               'ar': 'طبيعي'},
    'preHta':             {'fr': 'Pré-HTA',              'ar': 'ما قبل ارتفاع ضغط الدم'},
    'hypertension':       {'fr': 'Hypertension',         'ar': 'ارتفاع ضغط الدم'},

    // ── RECORDS ──────────────────────────────────────────────────────────────
    'recordsTitle':       {'fr': 'Tous les dossiers',    'ar': 'جميع الملفات'},
    'recordsCount':       {'fr': 'dossier(s)',           'ar': 'ملف'},
    'noRecordFound':      {'fr': 'Aucun dossier médical','ar': 'لا توجد ملفات طبية'},
    'createFirst':        {'fr': 'Créer le premier dossier', 'ar': 'إنشاء أول ملف'},
    'editRecord':         {'fr': 'Modifier le dossier',  'ar': 'تعديل الملف'},
    'recordUpdated':      {'fr': 'Dossier modifié avec succès', 'ar': 'تم تعديل الملف بنجاح'},
    'statusDraft':        {'fr': 'Brouillon',            'ar': 'مسودة'},
    'statusConfirmed':    {'fr': 'Validé',               'ar': 'مؤكد'},
    'statusWaiting':      {'fr': 'En attente',           'ar': 'في الانتظار'},
    'statusInvoiced':     {'fr': 'Facturé',              'ar': 'مفوتر'},
    'reason':             {'fr': 'Motif',                'ar': 'السبب'},
    'diagnostic':         {'fr': 'Diagnostic',           'ar': 'التشخيص'},
    'prescription':       {'fr': 'Prescription',         'ar': 'الوصفة الطبية'},
    'observations':       {'fr': 'Observations',         'ar': 'الملاحظات'},
    'observationsFollowUp': {'fr': 'Observations & suivi', 'ar': 'الملاحظات والمتابعة'},
    'status':             {'fr': 'Statut',               'ar': 'الحالة'},
    'searchRecord':       {'fr': 'Rechercher un dossier, un patient ou un diagnostic...', 'ar': 'ابحث عن ملف أو مريض أو تشخيص...'},
    'allStatuses':        {'fr': 'Tous les statuts',     'ar': 'كل الحالات'},
    'filteredResults':    {'fr': 'résultat(s) filtré(s)','ar': 'نتيجة مصفاة'},

    // ── ADD RECORD ───────────────────────────────────────────────────────────
    'newConsultation':    {'fr': 'Nouvelle consultation','ar': 'استشارة جديدة'},
    'newConsultSubtitle': {'fr': 'Renseigner les informations de la consultation',
                           'ar': 'أدخل معلومات الاستشارة'},
    'patientInfo':        {'fr': 'Informations patient', 'ar': 'معلومات المريض'},
    'medicalData':        {'fr': 'Données médicales',    'ar': 'البيانات الطبية'},
    'selectPatient':      {'fr': 'Sélectionner un patient', 'ar': 'اختر مريضاً'},
    'consultDate':        {'fr': 'Date de consultation *', 'ar': 'تاريخ الاستشارة *'},
    'modifyDate':         {'fr': 'Modifier',             'ar': 'تغيير'},
    'consultStatus':      {'fr': 'Statut de la consultation', 'ar': 'حالة الاستشارة'},
    'consultReason':      {'fr': 'Motif de consultation', 'ar': 'سبب الاستشارة'},
    'reasonHint':         {'fr': 'Ex: Douleur abdominale, fièvre...', 'ar': 'مثال: ألم بطني، حمى...'},
    'diagnosticHint':     {'fr': 'Saisir le diagnostic du patient...', 'ar': 'أدخل تشخيص المريض...'},
    'prescriptionHint':   {'fr': 'Médicaments, posologie, durée...',  'ar': 'الأدوية، الجرعة، المدة...'},
    'observationsHint':   {'fr': 'Notes, suivi, recommandations...',  'ar': 'ملاحظات، متابعة، توصيات...'},
    'patientRequired':    {'fr': 'Veuillez sélectionner un patient',  'ar': 'الرجاء اختيار مريض'},
    'diagnosticRequired': {'fr': 'Le diagnostic est obligatoire',     'ar': 'التشخيص إلزامي'},
    'saveConsultation':   {'fr': 'Enregistrer la consultation',       'ar': 'حفظ الاستشارة'},
    'recentMeasures':     {'fr': 'Mesures récentes',                  'ar': 'القياسات الأخيرة'},
    'consultCreated':     {'fr': 'Consultation créée avec succès !',  'ar': 'تم إنشاء الاستشارة بنجاح!'},
    'patientRequired2':   {'fr': 'Patient *',                         'ar': 'المريض *'},
    'diagnosticLabel':    {'fr': 'Diagnostic *',                      'ar': 'التشخيص *'},
    'selectedPatient':    {'fr': 'Patient sélectionné',               'ar': 'المريض المختار'},
    'consultationGuide':  {'fr': 'Guide de consultation',             'ar': 'دليل الاستشارة'},
    'consultationGuideHint': {'fr': 'Pensez à renseigner le motif, le diagnostic, le traitement et le suivi recommandé.', 'ar': 'تذكّر إدخال سبب الاستشارة والتشخيص والعلاج والمتابعة الموصى بها.'},

    // ── FACTURATION ──────────────────────────────────────────────────────────
    'invoicesTitle':      {'fr': 'Facturation',          'ar': 'الفواتير'},
    'invoiceNumber':      {'fr': 'N° Facture',           'ar': 'رقم الفاتورة'},
    'amountTotal':        {'fr': 'Montant Total',        'ar': 'المبلغ الإجمالي'},
    'paymentStatus':      {'fr': 'État de paiement',     'ar': 'حالة الدفع'},
    'paid':               {'fr': 'Payé',                 'ar': 'مدفوع'},
    'notPaid':            {'fr': 'Non payé',             'ar': 'غير مدفوع'},
    'partial':            {'fr': 'Partiel',              'ar': 'مدفوع جزئياً'},
    'newInvoice':         {'fr': 'Nouvelle facture',     'ar': 'فاتورة جديدة'},
    'invoiceDate':        {'fr': 'Date facture',         'ar': 'تاريخ الفاتورة'},
    'invoiceSummary':     {'fr': 'Résumé financier',     'ar': 'الملخص المالي'},
    'totalInvoiced':      {'fr': 'Total facturé',        'ar': 'إجمالي المفوتر'},
    'totalPaid':          {'fr': 'Total payé',           'ar': 'إجمالي المدفوع'},
    'remaining':          {'fr': 'Reste à payer',        'ar': 'المبلغ المتبقي'},
    'noInvoices':         {'fr': 'Aucune facture trouvée','ar': 'لا توجد فواتير'},
    'createInvoice':      {'fr': 'Créer une facture',    'ar': 'إنشاء فاتورة'},
    'amount':             {'fr': 'Montant',              'ar': 'المبلغ'},
    'invoiceCreated':     {'fr': 'Facture créée avec succès', 'ar': 'تم إنشاء الفاتورة بنجاح'},

    // ── DATES ────────────────────────────────────────────────────────────────
    'mon': {'fr': 'Lun', 'ar': 'الإثنين'},
    'tue': {'fr': 'Mar', 'ar': 'الثلاثاء'},
    'wed': {'fr': 'Mer', 'ar': 'الأربعاء'},
    'thu': {'fr': 'Jeu', 'ar': 'الخميس'},
    'fri': {'fr': 'Ven', 'ar': 'الجمعة'},
    'sat': {'fr': 'Sam', 'ar': 'السبت'},
    'sun': {'fr': 'Dim', 'ar': 'الأحد'},
    'jan': {'fr': 'Jan', 'ar': 'يناير'},
    'feb': {'fr': 'Fév', 'ar': 'فبراير'},
    'mar': {'fr': 'Mar', 'ar': 'مارس'},
    'apr': {'fr': 'Avr', 'ar': 'أبريل'},
    'may': {'fr': 'Mai', 'ar': 'ماي'},
    'jun': {'fr': 'Jun', 'ar': 'يونيو'},
    'jul': {'fr': 'Jul', 'ar': 'يوليوز'},
    'aug': {'fr': 'Aoû', 'ar': 'غشت'},
    'sep': {'fr': 'Sep', 'ar': 'شتنبر'},
    'oct': {'fr': 'Oct', 'ar': 'أكتوبر'},
    'nov': {'fr': 'Nov', 'ar': 'نونبر'},
    'dec': {'fr': 'Déc', 'ar': 'دجنبر'},
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _translations[key]?[lang] ?? _translations[key]?['fr'] ?? key;
  }

  // Helper pour les jours/mois
  List<String> get days => [
    t('mon'), t('tue'), t('wed'), t('thu'), t('fri'), t('sat'), t('sun')
  ];
  List<String> get months => [
    t('jan'), t('feb'), t('mar'), t('apr'), t('may'), t('jun'),
    t('jul'), t('aug'), t('sep'), t('oct'), t('nov'), t('dec')
  ];

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return t('greetingMorning');
    if (h < 18) return t('greetingAfternoon');
    return t('greetingEvening');
  }
}

// ─── DELEGATE ────────────────────────────────────────────────────────────────
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
