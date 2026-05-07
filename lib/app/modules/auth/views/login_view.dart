import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary(context),
      body: Stack(
        children: [
          // ============ Décor de fond : dégradé + cercles flous ============
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary(context), AppColors.primaryDark],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _DecorCircle(
              size: 220,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 60,
            left: -50,
            child: _DecorCircle(
              size: 140,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),

          // ============ Contenu ============
          // SafeArea uniquement en haut (status bar). En bas, on laisse la
          // carte blanche descendre jusqu'au bord de l'écran (sous le home
          // indicator iOS) pour que le blanc soit continu jusqu'en bas.
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: mq.size.height,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ------ En-tête : logo + welcome ------
                    SizedBox(height: 36 + mq.padding.top),
                    _AnimatedLogo(),
                    const SizedBox(height: 22),
                    const Text(
                      'Bienvenue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connectez-vous pour continuer',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ------ Carte du formulaire ------
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          28,
                          24,
                          24 + mq.padding.bottom,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Form(
                          key: controller.formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                _LabeledField(
                                  label: 'Email',
                                  child: TextFormField(
                                    controller: controller.emailCtrl,
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                      hintText: 'votre@email.com',
                                      prefixIcon:
                                          Icon(Icons.mail_outline_rounded),
                                    ),
                                    validator: controller.validateEmail,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Mot de passe',
                                  child: Obx(
                                    () => TextFormField(
                                      controller: controller.passwordCtrl,
                                      obscureText:
                                          controller.obscurePassword.value,
                                      textInputAction:
                                          TextInputAction.done,
                                      onFieldSubmitted: (_) =>
                                          controller.signIn(),
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          onPressed:
                                              controller.toggleObscure,
                                          icon: Icon(
                                            controller
                                                    .obscurePassword.value
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: controller.validatePassword,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: controller.sendPasswordReset,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary(context),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                    ),
                                    child: const Text(
                                      'Mot de passe oublié ?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(
                                  () => SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: controller.isLoading.value
                                          ? null
                                          : controller.signIn,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary(context),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: AppColors.primary(context)
                                            .withValues(alpha: 0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: controller.isLoading.value
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Se connecter',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                Obx(() {
                                  if (!controller.biometricReady.value) {
                                    return const SizedBox.shrink();
                                  }
                                  final label =
                                      controller.biometricLabel.value;
                                  final isFace = label
                                      .toLowerCase()
                                      .contains('face');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: SizedBox(
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            controller.isLoading.value
                                                ? null
                                                : controller
                                                    .signInWithBiometric,
                                        icon: Icon(
                                          isFace
                                              ? Icons.face_rounded
                                              : Icons.fingerprint_rounded,
                                          color: AppColors.primary(context),
                                        ),
                                        label: Text(
                                          'Se connecter avec $label',
                                          style: TextStyle(
                                            color: AppColors.primary(context),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: AppColors.primary(context)
                                                .withValues(alpha: 0.4),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const Spacer(),
                                Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text(
                                    'L\'inscription est réservée à l\'administrateur.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.greyText(context, 700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: const Image(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Petit label en gris au-dessus d'un champ.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.greyText(context, 700),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
