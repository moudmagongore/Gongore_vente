import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../modules/apropos/views/apropos_view.dart' show AproposContact;
import '../../theme/app_colors.dart';
import '../constants/app_constants.dart';

/// Numéros du support Gongore App sous forme de puces cliquables (tel:).
/// Utilisé partout où l'utilisateur doit joindre l'éditeur — notamment le
/// bandeau d'abonnement bientôt expiré, où il n'a plus qu'un délai court
/// pour régulariser.
///
/// Volontairement limité au téléphone : la régularisation d'un abonnement
/// se règle par appel, pas par mail. L'email reste disponible sur la page
/// « À propos » et l'écran de connexion.
///
/// La source des coordonnées reste [AproposContact] : un seul endroit à
/// mettre à jour.
class SupportContactBlock extends StatelessWidget {
  /// Couleur d'accent des puces. Par défaut la couleur primaire ; le
  /// bandeau d'abonnement passe sa couleur d'alerte (orange / rouge).
  final Color? accent;

  /// Texte d'introduction. `null` masque la ligne.
  final String? intro;

  const SupportContactBlock({
    super.key,
    this.accent,
    this.intro = 'Besoin d\'aide ? Contactez ${AppConstants.appName}',
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (intro != null) ...[
          Text(
            intro!,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.greyText(context, 700),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AproposContact.phones
              .map(
                (p) => _ContactChip(
                  icon: Icons.phone_outlined,
                  label: p,
                  color: color,
                  // tel: exige un numéro sans espaces.
                  uri: Uri(scheme: 'tel', path: p.replaceAll(' ', '')),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Uri uri;

  const _ContactChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.uri,
  });

  Future<void> _open() async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar(
        'Action impossible',
        'Aucune application disponible pour ouvrir « $label ».',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
