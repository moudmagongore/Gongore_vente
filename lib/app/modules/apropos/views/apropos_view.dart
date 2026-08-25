import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../theme/app_colors.dart';

/// Coordonnées du support, exposées pour réutilisation (page de connexion).
class AproposContact {
  AproposContact._();

  static const String email = 'gongreapp@gmail.com';
  static const List<String> phones = [
    '+224 621 78 56 45',
    '+224 623 28 59 87',
  ];
}

/// Page « À propos » accessible à tous les utilisateurs depuis le drawer.
/// Header immersif (dégradé navy/teal qui occupe l'AppBar + le top de la
/// page, identique à la page de connexion) puis cards d'info/contact sur
/// fond blanc descendantes.
class AproposView extends StatelessWidget {
  const AproposView({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary(context),
      // Le gradient passe sous l'AppBar pour un rendu immersif.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'À propos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // Décor de fond identique à la page login : dégradé + cercles flous.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary(context),
                  AppColors.primaryDark,
                ],
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
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: mq.size.height),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // En-tête (sous l'AppBar) : logo + nom + tagline en blanc
                    SizedBox(height: 24 + mq.padding.top + kToolbarHeight),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        image: const DecorationImage(
                          image: AssetImage(
                              'assets/images/gongoreSplash.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppConstants.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestion de boutique, ventes et clients',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Carte descendante (cards info + contact). Le fond
                    // suit le thème via un check explicite pour éviter
                    // tout effet de cache / contexte hérité.
                    Expanded(
                      child: Builder(builder: (ctx) {
                        final isDark =
                            Theme.of(ctx).brightness == Brightness.dark;
                        return Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.fromLTRB(20, 24, 20, 28),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBg
                                : Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _AboutCard(),
                              const SizedBox(height: 14),
                              const _ContactCard(),
                              const SizedBox(height: 20),
                              const _CopyrightFooter(),
                            ],
                          ),
                        );
                      }),
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

// =============================== À propos =================================

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primary),
              const SizedBox(width: 8),
              Text(
                'À propos',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${AppConstants.appName} accompagne les commerçants au '
            'quotidien : suivi des ventes, gestion du stock, '
            'fournisseurs, clients, règlements, et reporting — '
            'le tout dans une application simple et fiable.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.greyText(context, 800),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================== Contact ==================================

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, color: primary),
              const SizedBox(width: 8),
              Text(
                'Nous contacter',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Une question, une remarque, un besoin ? '
            'Notre équipe support est à votre écoute.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.greyText(context, 700),
            ),
          ),
          const SizedBox(height: 14),
          _ContactTile(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: AproposContact.email,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < AproposContact.phones.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ContactTile(
              icon: Icons.phone_outlined,
              label: i == 0 ? 'Téléphone' : 'Téléphone (alternatif)',
              value: AproposContact.phones[i],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Touchez une coordonnée pour la copier.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.greyText(context, 600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: value));
    if (Get.isSnackbarOpen) Get.closeAllSnackbars();
    Get.snackbar(
      'Copié',
      '$label : $value',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _copy,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyText(context, 600),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_all_rounded,
                  size: 18, color: AppColors.greyText(context, 600)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================== Footer ===================================

class _CopyrightFooter extends StatelessWidget {
  const _CopyrightFooter();

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Center(
      child: Text(
        '© $year ${AppConstants.appName}. Tous droits réservés.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.greyText(context, 600),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
