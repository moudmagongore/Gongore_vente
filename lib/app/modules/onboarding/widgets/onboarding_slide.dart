import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import 'page_offset.dart';

/// Une page de l'onboarding : l'illustration orbitale, le titre et le
/// sous-titre.
///
/// Illustration et textes ne se déplacent pas à la même vitesse que la page
/// elle-même (`-delta * facteur`, facteurs différents) : c'est ce décalage
/// qui donne l'effet de profondeur pendant le swipe.
class OnboardingSlide extends StatelessWidget {
  final OnboardingPage page;
  final int index;
  final PageController pageController;

  const OnboardingSlide({
    super.key,
    required this.page,
    required this.index,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        // 0 quand la page est centrée, ±1 quand elle est complètement
        // sortie à gauche / à droite.
        final delta = (index - pageOffsetOf(pageController)).clamp(-1.0, 1.0);
        final distance = delta.abs();

        // Les voisines s'effacent avant d'être totalement sorties (facteur
        // 1.4) : on ne voit jamais deux pages à moitié visibles.
        final opacity = (1 - distance * 1.4).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final illustrationSize = math.min(
              math.min(constraints.maxHeight * 0.42, constraints.maxWidth * 0.7),
              264.0,
            );

            return Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(-delta * 80, 0),
                      child: Transform.rotate(
                        angle: delta * 0.10,
                        child: Transform.scale(
                          scale: 1 - distance * 0.16,
                          child: _OrbitIllustration(
                            page: page,
                            size: illustrationSize,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.07),
                    Transform.translate(
                      offset: Offset(-delta * 26, 0),
                      child: Column(
                        children: [
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 15.5,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Icône centrale posée sur deux anneaux concentriques, entourée de trois
/// pastilles qui gravitent lentement autour. Les pastilles sont
/// contre-tournées de l'angle de l'orbite pour rester droites.
class _OrbitIllustration extends StatefulWidget {
  final OnboardingPage page;
  final double size;

  const _OrbitIllustration({required this.page, required this.size});

  @override
  State<_OrbitIllustration> createState() => _OrbitIllustrationState();
}

class _OrbitIllustrationState extends State<_OrbitIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final orbitRadius = size * 0.46;
    final chipSize = size * 0.18;

    return AnimatedBuilder(
      animation: _orbit,
      builder: (context, _) {
        final angle = _orbit.value * 2 * math.pi;
        // Respiration très légère du disque central, calée sur le même
        // cycle que l'orbite pour n'avoir qu'un seul ticker.
        final breath = 1 + math.sin(angle) * 0.02;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(size, alpha: 0.12),
              _ring(size * 0.76, alpha: 0.16, fillAlpha: 0.04),
              Transform.scale(
                scale: breath,
                child: Container(
                  width: size * 0.52,
                  height: size * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0.10),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.page.icon,
                    size: size * 0.24,
                    color: Colors.white,
                  ),
                ),
              ),
              for (var i = 0; i < widget.page.orbit.length; i++)
                _chip(
                  icon: widget.page.orbit[i],
                  angle: angle + i * 2 * math.pi / widget.page.orbit.length,
                  radius: orbitRadius,
                  size: chipSize,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double diameter, {required double alpha, double fillAlpha = 0}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: fillAlpha),
        border: Border.all(color: Colors.white.withValues(alpha: alpha)),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required double angle,
    required double radius,
    required double size,
  }) {
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
