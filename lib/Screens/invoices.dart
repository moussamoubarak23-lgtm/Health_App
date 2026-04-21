import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/language_provider.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List invoices = [];
  bool loading = true;
  double totalInvoiced = 0.0;
  double totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  // Helper pour éviter le crash Odoo (bool au lieu de String)
  String _s(dynamic val) => (val is String) ? val : '—';

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() => loading = true);
    final inv = await OdooApi.getInvoices();
    double invoiced = 0.0;
    double paid = 0.0;

    for (var i in inv) {
      if (i['state'] != 'cancel') {
        invoiced += (i['amount_total'] as num).toDouble();
        // Odoo utilise 'paid' ou 'in_payment' pour les factures réglées
        if (i['payment_state'] == 'paid' || i['payment_state'] == 'in_payment') {
          paid += (i['amount_total'] as num).toDouble();
        }
      }
    }

    if (mounted) {
      setState(() {
        invoices = inv;
        totalInvoiced = invoiced;
        totalPaid = paid;
        loading = false;
      });
    }
  }

  Future<void> _handleValidate(Map inv) async {
    final patientId = inv['partner_id'] is List ? inv['partner_id'][0] : null;

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 1. Enregistrer le paiement dans Odoo (pour passer le statut à 'Payé')
    final payRes = await OdooApi.registerPayment(inv['id']);

    // 2. Marquer la consultation comme facturée
    if (patientId != null) {
      await OdooApi.markConsultationAsInvoiced(patientId);
    }

    if (mounted) Navigator.pop(context); // Fermer le chargement

    if (payRes['success']) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('paymentRegistered'))));
      _loadInvoices();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context).t('paymentErrorPrefix')} ${payRes['error']}")));
    }
  }

  Future<void> _handleCancel(Map inv) async {
    final res = await OdooApi.cancelInvoice(inv['id']);
    if (res['success']) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('invoiceCancelled'))));
      _loadInvoices();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${res['error']}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = context.watch<LanguageProvider>();
    final isRtl = lang.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          const Sidebar(currentRoute: '/invoices'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.t('invoicesTitle'), style: _titleLg(isRtl)),
                    Text('${invoices.length} ${l10n.t('invoiceCountSuffix')}', style: _mutedStyle(isRtl)),
                  ]),
                  _refreshButton(),
                ]),
                const SizedBox(height: 12),
                AppBreadcrumb(
                  items: [
                    BreadcrumbItem(label: l10n.t('home'), route: '/dashboard'),
                    BreadcrumbItem(label: l10n.t('invoicesLabel')),
                  ],
                ),
                const SizedBox(height: 24),
                _statsCards(l10n, isRtl),
                const SizedBox(height: 24),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : invoices.isEmpty
                          ? _emptyState(l10n, isRtl)
                          : _invoicesList(l10n, isRtl),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _refreshButton() => IconButton.filled(
    onPressed: _loadInvoices,
    icon: const Icon(Icons.refresh_rounded, size: 20),
    style: IconButton.styleFrom(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _statsCards(AppLocalizations l10n, bool isRtl) => Row(children: [
    _statCard(l10n.t('totalInvoiced'), totalInvoiced, Icons.account_balance_wallet_rounded, AppColors.primary, isRtl),
    _statCard(l10n.t('totalPaid'), totalPaid, Icons.check_circle_rounded, AppColors.green, isRtl),
    _statCard(l10n.t('remaining'), totalInvoiced - totalPaid, Icons.pending_actions_rounded, AppColors.red, isRtl),
  ]);

  Widget _statCard(String label, double value, IconData icon, Color color, bool isRtl) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _mutedStyle(isRtl, size: 12)),
          Text('${value.toStringAsFixed(2)} DH', style: _titleSm(isRtl)),
        ]),
      ]),
    ),
  );

  Widget _invoicesList(AppLocalizations l10n, bool isRtl) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      _tableHeader(l10n, isRtl),
      Expanded(
        child: ListView.separated(
          itemCount: invoices.length,
          separatorBuilder: (_, __) => Divider(color: AppColors.divider, height: 1),
          itemBuilder: (_, i) => _invoiceRow(invoices[i], l10n, isRtl),
        ),
      ),
    ]),
  );

  Widget _tableHeader(AppLocalizations l10n, bool isRtl) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Row(children: [
      Expanded(flex: 2, child: _th(l10n.t('invoiceNumber'), isRtl)),
      Expanded(flex: 3, child: _th(l10n.t('colPatient'), isRtl)),
      Expanded(flex: 2, child: _th(l10n.t('invoiceDate'), isRtl)),
      Expanded(flex: 2, child: _th(l10n.t('amountTotal'), isRtl)),
      Expanded(flex: 2, child: _th(l10n.t('colStatus'), isRtl)),
      Expanded(flex: 2, child: _th(l10n.t('colActions'), isRtl)),
    ]),
  );

  Widget _invoiceRow(Map inv, AppLocalizations l10n, bool isRtl) {
    final status = inv['payment_state'];
    final state = inv['state'];
    Color statusColor = AppColors.red;
    String statusLabel = l10n.t('notPaid');

    if (state == 'cancel') {
      statusColor = AppColors.textMuted;
      statusLabel = l10n.t('invoiceCancelled');
    } else if (status == 'paid' || status == 'in_payment') {
      statusColor = AppColors.green;
      statusLabel = l10n.t('paid');
    } else if (status == 'partial') {
      statusColor = AppColors.yellow;
      statusLabel = l10n.t('partial');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(children: [
        Expanded(flex: 2, child: Text(_s(inv['name']), style: _bodyBold(isRtl))),
        Expanded(flex: 3, child: Text(inv['partner_id'] is List ? inv['partner_id'][1].toString() : '—', style: _bodyStyle(isRtl))),
        Expanded(flex: 2, child: Text(_s(inv['invoice_date']), style: _bodyStyle(isRtl))),
        Expanded(flex: 2, child: Text('${(inv['amount_total'] as num).toStringAsFixed(2)} DH', style: _bodyBold(isRtl, color: AppColors.primary))),
        Expanded(flex: 2, child: _statusBadge(statusLabel, statusColor, isRtl)),
        Expanded(flex: 2, child: Row(children: [
          if (state != 'cancel' && status != 'paid' && status != 'in_payment') ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 22),
              tooltip: "Enregistrer le paiement",
              onPressed: () => _handleValidate(inv),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: AppColors.red, size: 22),
              tooltip: "Annuler la facture",
              onPressed: () => _handleCancel(inv),
            ),
          ] else if (state == 'cancel') Text(l10n.t('invoiceCancelled'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
          else const Icon(Icons.verified_rounded, color: AppColors.green, size: 22)
        ])),
      ]),
    );
  }

  Widget _statusBadge(String label, Color color, bool isRtl) => UnconstrainedBox(
    alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: isRtl
        ? GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold)
        : GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _emptyState(AppLocalizations l10n, bool isRtl) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textHint),
      const SizedBox(height: 16),
      Text(l10n.t('noInvoices'), style: _mutedStyle(isRtl, size: 16)),
    ]),
  );

  TextStyle _titleLg(bool r) => r
      ? GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)
      : GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary);

  TextStyle _titleSm(bool r) => r
      ? GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
      : GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  TextStyle _mutedStyle(bool r, {double size = 14}) => r
      ? GoogleFonts.cairo(fontSize: size, color: AppColors.textMuted)
      : GoogleFonts.dmSans(fontSize: size, color: AppColors.textMuted);

  TextStyle _bodyStyle(bool r) => r
      ? GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecond)
      : GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecond);

  TextStyle _bodyBold(bool r, {Color? color}) => r
      ? GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)
      : GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary);

  Widget _th(String label, bool isRtl) => Text(label.toUpperCase(), style: isRtl
      ? GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)
      : GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.0));
}
