import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/models/boutique_model.dart';
import '../../data/repositories/boutique_repository.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../services/subscription_guard.dart';
import '../services/user_controller.dart';
import '../services/user_manual_pdf_service.dart';
import 'drawer_open_guard.dart';
import 'sign_out_dialog.dart';

class AdminDrawer extends StatelessWidget {
  /// Route active pour mettre l'item en surbrillance.
  final String currentRoute;

  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // DrawerOpenGuard : ignore les taps tant que le drawer n'a pas fini de
      // s'ouvrir. Sans ça, un tap qui arrive pendant le slide-in atterrit sur
      // le contenu du drawer et déclenche un item au hasard (voir le widget).
      child: DrawerOpenGuard(
        child: Obx(() {
        // Obx au top : tout le drawer se redessine si l'utilisateur change
        // (ex. admin coche/décoche `alsoGestionnaire` sur son propre profil).
        final user = UserController.to.user;
        final isSuper = UserController.to.isSuperAdmin;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              name: user?.nom ?? '',
              email: user?.email ?? '',
              isSuper: isSuper,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                // ClampingScrollPhysics pour désactiver le bouncing iOS qui
                // laissait voir le fond du drawer au-dessus du header lors
                // d'un overscroll vers le haut.
                physics: const ClampingScrollPhysics(),
                children: [
                    _Item(
                      icon: Icons.dashboard_rounded,
                      label: 'Tableau de bord',
                      route: AppRoutes.adminHome,
                      currentRoute: currentRoute,
                    ),
                    _Item(
                      icon: Icons.store_rounded,
                      label: isSuper ? 'Boutiques' : 'Ma boutique',
                      route: AppRoutes.adminBoutiques,
                      currentRoute: currentRoute,
                    ),
                    _Item(
                      icon: Icons.people_alt_rounded,
                      label: isSuper ? 'Utilisateurs' : 'Mes gestionnaires',
                      route: AppRoutes.adminUsers,
                      currentRoute: currentRoute,
                    ),
                    _ExpansionGroup(
                      icon: Icons.inventory_2_outlined,
                      title: 'Catalogue',
                      currentRoute: currentRoute,
                      childrenRoutes: const [
                        AppRoutes.adminProduits,
                        AppRoutes.adminCategories,
                        AppRoutes.adminStock,
                      ],
                      children: [
                        _Item(
                          icon: Icons.inventory_2_rounded,
                          label: 'Produits',
                          route: AppRoutes.adminProduits,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.category_rounded,
                          label: 'Catégories',
                          route: AppRoutes.adminCategories,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.warehouse_rounded,
                          label: 'Stock',
                          route: AppRoutes.adminStock,
                          currentRoute: currentRoute,
                        ),
                      ],
                    ),
                    _ExpansionGroup(
                      icon: Icons.local_shipping_outlined,
                      title: 'Achats',
                      currentRoute: currentRoute,
                      childrenRoutes: const [
                        AppRoutes.adminFournisseurs,
                        AppRoutes.adminAppros,
                        AppRoutes.adminReglementsFournisseurs,
                      ],
                      children: [
                        _Item(
                          icon: Icons.local_shipping_rounded,
                          label: 'Fournisseurs',
                          route: AppRoutes.adminFournisseurs,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.move_to_inbox_rounded,
                          label: 'Approvisionnements',
                          route: AppRoutes.adminAppros,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Règlements fournisseurs',
                          route: AppRoutes.adminReglementsFournisseurs,
                          currentRoute: currentRoute,
                        ),
                      ],
                    ),
                    _ExpansionGroup(
                      icon: Icons.receipt_long_rounded,
                      title: 'Ventes & règlements',
                      currentRoute: currentRoute,
                      childrenRoutes: const [
                        AppRoutes.adminVentes,
                        AppRoutes.adminClients,
                        AppRoutes.adminReglements,
                      ],
                      children: [
                        _Item(
                          icon: Icons.receipt_long_rounded,
                          label: 'Ventes',
                          route: AppRoutes.adminVentes,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.contacts_rounded,
                          label: 'Clients',
                          route: AppRoutes.adminClients,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.payments_rounded,
                          label: 'Règlements clients',
                          route: AppRoutes.adminReglements,
                          currentRoute: currentRoute,
                        ),
                      ],
                    ),
                    _ExpansionGroup(
                      icon: Icons.savings_outlined,
                      title: 'Dépenses',
                      currentRoute: currentRoute,
                      childrenRoutes: const [
                        AppRoutes.adminDepenses,
                        AppRoutes.adminNaturesDepense,
                      ],
                      children: [
                        _Item(
                          icon: Icons.receipt_long_rounded,
                          label: 'Dépenses',
                          route: AppRoutes.adminDepenses,
                          currentRoute: currentRoute,
                        ),
                        _Item(
                          icon: Icons.tune_rounded,
                          label: 'Natures de dépense',
                          route: AppRoutes.adminNaturesDepense,
                          currentRoute: currentRoute,
                        ),
                      ],
                    ),
                    _Item(
                      icon: Icons.bar_chart_rounded,
                      label: 'Rapports',
                      route: AppRoutes.adminRapports,
                      currentRoute: currentRoute,
                    ),
                    // Abonnements :
                    //   • super-admin → vue globale gestion paiements + tarifs
                    //     (route principale, on remplace la stack)
                    //   • admin de boutique → vue lecture seule (sous-page,
                    //     on push pour conserver un bouton retour vers le
                    //     dashboard)
                    if (isSuper)
                      _Item(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Abonnements',
                        route: AppRoutes.adminAbonnements,
                        currentRoute: currentRoute,
                      )
                    else
                      Builder(
                        builder: (ctx) => ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          leading:
                              const Icon(Icons.workspace_premium_rounded),
                          title: const Text(
                            'Mon abonnement',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(ctx).pop();
                            Get.toNamed(AppRoutes.monAbonnement);
                          },
                        ),
                      ),
                    // Mon compte : visible pour tous les rôles.
                    // Style aligné sur les autres `_Item` (shape plate,
                    // typographie identique).
                    Builder(
                      builder: (ctx) => ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        leading:
                            const Icon(Icons.account_circle_outlined),
                        title: const Text(
                          'Mon compte',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(ctx).pop();
                          final me = UserController.to.user;
                          if (me != null) {
                            Get.toNamed(AppRoutes.adminUserForm,
                                arguments: me);
                          }
                        },
                      ),
                    ),
                    // Paramètres : push (toNamed) plutôt que replace pour
                    // garder la route précédente dans la pile et afficher
                    // automatiquement un bouton retour dans l'AppBar.
                    Builder(
                      builder: (ctx) => ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        leading: const Icon(Icons.settings_rounded),
                        title: const Text(
                          'Paramètres',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(ctx).pop();
                          Get.toNamed(AppRoutes.parametres);
                        },
                      ),
                    ),
                    Builder(
                      builder: (ctx) => ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text(
                          'Manuel utilisateur',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(ctx).pop();
                          UserManualPdfService.openAndPreview();
                        },
                      ),
                    ),
                    Builder(
                      builder: (ctx) => ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text(
                          'À propos',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(ctx).pop();
                          Get.toNamed(AppRoutes.apropos);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1),
            Builder(
              builder: (ctx) => ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  confirmSignOut(ctx);
                },
              ),
            ),
            // Marge basse uniquement sur Android (iOS gère son home indicator).
            SizedBox(
              height: Platform.isAndroid
                  ? MediaQuery.of(context).padding.bottom + 8
                  : 8,
            ),
          ],
        );
        }),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final bool isSuper;

  const _Header({
    required this.name,
    required this.email,
    required this.isSuper,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // Header volontairement NON cliquable : il couvrait tout le coin
    // haut-gauche (là où se trouve le bouton hamburger) et se déclenchait par
    // erreur à l'ouverture du drawer, surtout sur tablette — le drawer se
    // refermait aussitôt en poussant « Mon compte ».
    // « Mon compte » reste accessible via l'item dédié de la liste ci-dessus.
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20 + topInset, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary(context), AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            // Sans `Clip.none`, l'étoile (positionnée en débord -2px)
            // serait rognée par le Stack qui clip ses enfants par défaut.
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary(context),
                  ),
                ),
              ),
              if (isSuper)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          // Badge rôle : on affiche aussi GESTIONNAIRE en dessous si
          // l'admin a activé le cumul des rôles (alsoGestionnaire = true).
          Builder(
            builder: (_) {
              final user = UserController.to.user;
              final showCumul = !isSuper && (user?.alsoGestionnaire ?? false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoleBadge(
                    label: isSuper ? 'SUPER ADMIN' : 'ADMINISTRATEUR',
                  ),
                  if (showCumul) ...[
                    const SizedBox(height: 6),
                    const _RoleBadge(label: 'GESTIONNAIRE'),
                  ],
                ],
              );
            },
          ),
          // Switcher de boutique : visible uniquement pour un admin ayant
          // accès à plusieurs boutiques. Permet de basculer la boutique
          // active utilisée pour scoper toutes les requêtes.
          Obx(() {
            final user = UserController.to.user;
            if (user == null || !user.hasMultipleBoutiques) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _BoutiqueSwitcher(),
            );
          }),
        ],
      ),
    );
  }
}

/// Bandeau cliquable affichant la boutique active de l'admin multi-boutique.
/// Au clic, ouvre une bottom sheet listant toutes les boutiques accessibles
/// pour permettre le switch. Après switch, la stack est réinitialisée
/// (`Get.offAllNamed(adminHome)`) pour que tous les contrôleurs ré-init
/// leurs streams avec le nouveau scope.
class _BoutiqueSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeId = UserController.to.currentBoutiqueId.value;
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _openSwitchSheet(context);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<BoutiqueModel?>(
                  // FutureBuilder se ré-exécute quand `activeId` change car
                  // l'Obx parent rebuild et recrée un nouveau Future.
                  future: activeId == null
                      ? Future.value(null)
                      : BoutiqueRepository().getById(activeId),
                  builder: (context, snap) {
                    final name = snap.data?.nom ??
                        (snap.connectionState == ConnectionState.waiting
                            ? '...'
                            : 'Boutique');
                    return Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    });
  }

  void _openSwitchSheet(BuildContext context) {
    final ids = UserController.to.accessibleBoutiqueIds;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Changer de boutique',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greyText(ctx, 800),
                  ),
                ),
              ),
              FutureBuilder<List<BoutiqueModel?>>(
                future: Future.wait(
                  ids.map((id) => BoutiqueRepository().getById(id)),
                ),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final boutiques =
                      snap.data!.whereType<BoutiqueModel>().toList();
                  return Obx(() {
                    final activeId =
                        UserController.to.currentBoutiqueId.value;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: boutiques.map((b) {
                        final isActive = b.id == activeId;
                        return ListTile(
                          leading: Icon(
                            Icons.store_rounded,
                            color: isActive
                                ? AppColors.primary(context)
                                : null,
                          ),
                          title: Text(
                            b.nom,
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? AppColors.primary(context)
                                  : null,
                            ),
                          ),
                          trailing: isActive
                              ? Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary(context),
                                )
                              : null,
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            if (isActive) {
                              Navigator.of(ctx).pop();
                              return;
                            }
                            // Vérifie l'abonnement de la boutique cible
                            // AVANT de basculer. Si pas d'abonnement actif
                            // ou expiré au-delà de la grâce, on bloque
                            // avec un message et on n'effectue pas le
                            // switch (l'admin reste sur sa boutique
                            // précédente).
                            final blockMsg =
                                await SubscriptionGuard.checkBoutiqueAccess(
                                    b.id);
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            if (blockMsg != null) {
                              Get.snackbar(
                                'Switch impossible',
                                blockMsg,
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red.shade50,
                                colorText: Colors.red.shade900,
                                icon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.red.shade900,
                                ),
                                duration: const Duration(seconds: 5),
                                isDismissible: true,
                                margin: const EdgeInsets.all(12),
                              );
                              return;
                            }
                            UserController.to.setCurrentBoutique(b.id);
                            // Repart sur le tableau de bord pour que
                            // tous les contrôleurs ré-init leurs streams
                            // avec la nouvelle boutique active.
                            Get.offAllNamed(AppRoutes.adminHome);
                          },
                        );
                      }).toList(),
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _Item({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentRoute == route;
    return ListTile(
      // Pas d'arrondi pour la surbrillance du drawer : on veut un highlight
      // qui occupe toute la largeur sans coin arrondi.
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      leading: Icon(
        icon,
        color: selected ? AppColors.primary(context) : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: selected ? AppColors.primary(context) : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.primary(context).withValues(alpha: 0.08),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        if (selected) return;
        Get.offNamed(route);
      },
    );
  }
}

/// Groupe d'items réunis dans un ExpansionTile. S'ouvre par défaut quand
/// la route active fait partie du groupe pour faire ressortir l'item courant.
class _ExpansionGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final String currentRoute;
  final List<String> childrenRoutes;
  final List<Widget> children;

  const _ExpansionGroup({
    required this.icon,
    required this.title,
    required this.currentRoute,
    required this.childrenRoutes,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final containsCurrent = childrenRoutes.contains(currentRoute);
    return Theme(
      // ExpansionTile met une bordure top/bottom qui jure avec le reste
      // du drawer : on la neutralise.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // Pas d'arrondi sur la zone d'expansion (full-width flat).
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        collapsedShape:
            const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        leading: Icon(
          icon,
          color: containsCurrent ? AppColors.primary(context) : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: containsCurrent ? AppColors.primary(context) : null,
            fontWeight:
                containsCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        initiallyExpanded: containsCurrent,
        // Le déplié/replié d'une section est un clic comme un autre.
        onExpansionChanged: (_) => HapticFeedback.selectionClick(),
        childrenPadding: const EdgeInsets.only(left: 12),
        children: children,
      ),
    );
  }
}
