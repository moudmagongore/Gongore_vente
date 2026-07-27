import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import 'page_offset.dart';

/// Fond de l'onboarding : un dégradé de marque qui se transforme au fil du
/// scroll, surmonté de halos lumineux en dérive lente.
///
/// Les halos sont de simples [RadialGradient] qui s'éteignent sur les bords
/// plutôt que des cercles floutés : même rendu diffus, sans le coût d'un
/// BackdropFilter répété à chaque frame.
class OnboardingBackground extends StatefulWidget {
  final PageController pageController;

  const OnboardingBackground({super.key, required this.pageController});

  @override
  State<OnboardingBackground> createState() => _OnboardingBackgroundState();
}

class _OnboardingBackgroundState extends State<OnboardingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  /// Couleurs du dégradé pour la position continue [offset] : on interpole
  /// entre la page entière la plus proche et la suivante.
  List<Color> _gradientAt(double offset) {
    const pages = OnboardingController.pages;
    final from = offset.floor().clamp(0, pages.length - 1);
    final to = (from + 1).clamp(0, pages.length - 1);
    final t = (offset - from).clamp(0.0, 1.0);

    return [
      Color.lerp(pages[from].gradient[0], pages[to].gradient[0], t)!,
      Color.lerp(pages[from].gradient[1], pages[to].gradient[1], t)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.pageController, _drift]),
      builder: (context, _) {
        final offset = pageOffsetOf(widget.pageController);
        final colors = _gradientAt(offset);
        final t = _drift.value * 2 * math.pi;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return Stack(
                children: [
                  // Halo principal en haut à droite. Il dérive aussi
                  // horizontalement avec le scroll (`-offset * 40`) pour
                  // renforcer la sensation de profondeur au swipe.
                  _halo(
                    left: w * 0.55 + math.sin(t) * 26 - offset * 40,
                    top: h * 0.02 + math.cos(t) * 20,
                    size: w * 0.95,
                    alpha: 0.16,
                  ),
                  _halo(
                    left: -w * 0.28 + math.cos(t * 0.8) * 30 - offset * 24,
                    top: h * 0.34 + math.sin(t * 0.8) * 26,
                    size: w * 0.85,
                    alpha: 0.10,
                  ),
                  _halo(
                    left: w * 0.30 + math.sin(t * 1.3 + 1) * 22 - offset * 60,
                    top: h * 0.66 + math.cos(t * 1.3) * 18,
                    size: w * 0.75,
                    alpha: 0.08,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _halo({
    required double left,
    required double top,
    required double size,
    required double alpha,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: alpha),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
