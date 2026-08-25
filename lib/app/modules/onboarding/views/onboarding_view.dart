import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_background.dart';
import '../widgets/onboarding_footer.dart';
import '../widgets/onboarding_slide.dart';

/// Écran de présentation affiché à la toute première ouverture de l'app.
///
/// Volontairement indépendant du thème clair/sombre : il garde le dégradé de
/// marque du splash pour que l'enchaînement des deux écrans forme une seule
/// séquence d'ouverture.
class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fond sombre en permanence → icônes de la barre d'état en blanc.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: OnboardingBackground(
                pageController: controller.pageController,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: PageView.builder(
                      controller: controller.pageController,
                      onPageChanged: controller.onPageChanged,
                      itemCount: OnboardingController.pages.length,
                      itemBuilder: (context, i) => OnboardingSlide(
                        page: OnboardingController.pages[i],
                        index: i,
                        pageController: controller.pageController,
                      ),
                    ),
                  ),
                  const OnboardingFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo + nom à gauche, « Passer » à droite. Le raccourci disparaît sur la
/// dernière page, où le CTA « Commencer » fait déjà le travail.
class _TopBar extends GetView<OnboardingController> {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 14, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Gongore App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Obx(() {
            final visible = !controller.isLast;
            return IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: TextButton(
                  onPressed: controller.skip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Passer',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
