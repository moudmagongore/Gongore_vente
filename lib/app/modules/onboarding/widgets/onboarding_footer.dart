import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/onboarding_controller.dart';

/// Bas d'écran : l'indicateur de progression, puis le bouton suivant qui se
/// transforme en CTA pleine largeur sur la dernière page.
class OnboardingFooter extends GetView<OnboardingController> {
  const OnboardingFooter({super.key});

  static const _slotHeight = 66.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Dots(),
          const SizedBox(height: 26),
          SizedBox(
            height: _slotHeight,
            child: Obx(() {
              final isLast = controller.isLast;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: isLast
                    ? const _StartButton(key: ValueKey('start'))
                    : const Align(
                        key: ValueKey('next'),
                        alignment: Alignment.centerRight,
                        child: _NextButton(),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Points de progression : le point actif s'étire en barre.
class _Dots extends GetView<OnboardingController> {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.index.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(OnboardingController.pages.length, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: active ? 1 : 0.34),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      );
    });
  }
}

/// Bouton rond « suivant », cerclé d'un arc de progression qui se remplit
/// au fil des pages.
class _NextButton extends GetView<OnboardingController> {
  const _NextButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final progress =
          (controller.index.value + 1) / OnboardingController.pages.length;

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _ProgressRingPainter(value),
          child: child,
        ),
        child: SizedBox(
          width: 66,
          height: 66,
          child: Center(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.next,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primaryFixed,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;

  const _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - 1.5;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.22);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

/// CTA final pleine largeur.
class _StartButton extends GetView<OnboardingController> {
  const _StartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: controller.finish,
          child: Container(
            height: 58,
            width: double.infinity,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Commencer',
                  style: TextStyle(
                    color: AppColors.primaryFixed,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryFixed,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
