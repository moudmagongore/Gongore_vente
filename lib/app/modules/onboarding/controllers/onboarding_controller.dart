import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/onboarding_service.dart';
import '../../../routes/app_routes.dart';

/// Contenu d'une page d'onboarding : l'icône centrale, les trois icônes
/// satellites qui gravitent autour, les textes et le dégradé de fond.
class OnboardingPage {
  final IconData icon;
  final List<IconData> orbit;
  final String title;
  final String subtitle;

  /// Dégradé haut → bas du fond. Interpolé d'une page à l'autre pendant
  /// le scroll, d'où la contrainte : toujours exactement 2 couleurs.
  final List<Color> gradient;

  const OnboardingPage({
    required this.icon,
    required this.orbit,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}

class OnboardingController extends GetxController {
  /// La première page reprend le dégradé du splash pour que l'enchaînement
  /// splash → onboarding soit continu, sans rupture visuelle.
  static const pages = <OnboardingPage>[
    OnboardingPage(
      icon: Icons.storefront_rounded,
      orbit: [
        Icons.inventory_2_rounded,
        Icons.point_of_sale_rounded,
        Icons.groups_rounded,
      ],
      title: 'Votre boutique\ndans la poche',
      subtitle:
          'Produits, ventes, stock et clients : pilotez toute votre activité '
          'depuis votre téléphone, où que vous soyez.',
      gradient: [Color(0xFF34A0A7), Color(0xFF194565)],
    ),
    OnboardingPage(
      icon: Icons.point_of_sale_rounded,
      orbit: [
        Icons.receipt_long_rounded,
        Icons.picture_as_pdf_rounded,
        Icons.share_rounded,
      ],
      title: 'Vendez\nen quelques gestes',
      subtitle:
          'Enregistrez une vente en quelques secondes, générez le reçu en PDF '
          'et partagez-le aussitôt à votre client.',
      gradient: [Color(0xFF00ACC1), Color(0xFF123A5A)],
    ),
    OnboardingPage(
      icon: Icons.inventory_2_rounded,
      orbit: [
        Icons.local_shipping_rounded,
        Icons.swap_vert_rounded,
        Icons.notifications_active_rounded,
      ],
      title: 'Un stock\ntoujours juste',
      subtitle:
          'Approvisionnements, entrées et sorties : chaque mouvement est '
          'enregistré automatiquement, sans calcul manuel.',
      gradient: [Color(0xFF2BB3A3), Color(0xFF14405F)],
    ),
    OnboardingPage(
      icon: Icons.insights_rounded,
      orbit: [
        Icons.groups_rounded,
        Icons.account_balance_wallet_rounded,
        Icons.bar_chart_rounded,
      ],
      title: 'Décidez avec\ndes chiffres clairs',
      subtitle:
          'Suivez les règlements de vos clients et de vos fournisseurs, et '
          'consultez vos rapports en un coup d\'œil.',
      gradient: [Color(0xFF2E86C1), Color(0xFF152C48)],
    ),
  ];

  late final PageController pageController;

  /// Index de la page affichée (entier, mis à jour à chaque swipe terminé).
  /// Sert aux éléments d'UI qui basculent d'un état à l'autre — indicateur,
  /// bouton « Passer », CTA final. Le parallaxe, lui, s'appuie directement
  /// sur [pageController] pour suivre le doigt en continu.
  final index = 0.obs;

  int get lastIndex => pages.length - 1;
  bool get isLast => index.value == lastIndex;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  void onPageChanged(int i) {
    index.value = i;
    HapticFeedback.selectionClick();
  }

  void next() {
    if (isLast) {
      finish();
      return;
    }
    pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void skip() => finish();

  /// Marque l'onboarding comme vu puis enchaîne sur le login. L'écran n'est
  /// atteint que depuis le splash et uniquement quand aucune session n'est
  /// ouverte : la destination est donc toujours le login.
  Future<void> finish() async {
    await OnboardingService.markSeen();
    Get.offAllNamed(AppRoutes.login);
  }
}
