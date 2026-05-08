import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medical_app/Services/secure_storage_service.dart';
import 'package:medical_app/theme.dart';

class PrivacyPolicyDialog extends StatefulWidget {
  final VoidCallback onAccept;

  const PrivacyPolicyDialog({
    super.key,
    required this.onAccept,
  });

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  bool _accepted = false;
  bool _checkboxError = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Politique de Confidentialité',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Conformité RGPD'),
                    const SizedBox(height: 8),
                    const Text(
                      'Cette application collecte et traite vos données personnelles conformément au Règlement Général sur la Protection des Données (RGPD).',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    _sectionTitle('Données collectées'),
                    const SizedBox(height: 8),
                    const Text(
                      '• Informations du médecin (nom, email, téléphone)\n• Données des patients (nom, âge, mesures médicales)\n• Données de santé (tension, température, etc.)\n• Gestion des consultations (rendez-vous, dossiers médicaux)\n• Gestion des paiements (factures, reçus, transactions)',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    _sectionTitle('Vos droits'),
                    const SizedBox(height: 8),
                    const Text(
                      '• Droit d\'accès à vos données\n• Droit de rectification\n• Droit à l\'effacement (droit à l\'oubli)\n• Droit à la portabilité\n• Droit d\'opposition',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    _sectionTitle('Sécurité'),
                    const SizedBox(height: 8),
                    const Text(
                      'Vos données sont chiffrées et stockées de manière sécurisée conformément aux normes de sécurité en vigueur.',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    _sectionTitle('Partage des données'),
                    const SizedBox(height: 8),
                    const Text(
                      'Vos données ne sont partagées qu\'avec:\n• Le personnel médical autorisé\n• Nos serveurs sécurisés\n• Les autorités compétentes sur demande légale',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    _sectionTitle('Contact'),
                    const SizedBox(height: 8),
                    const Text(
                      'Pour toute question concernant vos données:\nEmail: contact@smartsds.ma\nTéléphone: +212 6 68 81 64 18',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    // Checkbox
                    CheckboxListTile(
                      value: _accepted,
                      onChanged: (value) {
                        setState(() {
                          _accepted = value ?? false;
                          _checkboxError = false;
                        });
                      },
                      title: Text(
                        'J\'ai lu et j\'accepte la politique de confidentialité',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: _checkboxError ? AppColors.red : AppColors.textPrimary,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            
            // Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_accepted) {
                      await SecureStorageService.saveGdprConsent(true);
                      widget.onAccept();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      setState(() => _checkboxError = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez cocher la case pour continuer'),
                          backgroundColor: AppColors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'D\'accord',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
