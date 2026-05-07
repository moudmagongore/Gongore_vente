import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../services/user_controller.dart';
import 'sign_out_dialog.dart';

class VendeurDrawer extends StatelessWidget {
  final String currentRoute;
  const VendeurDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Obx(() {
        final user = UserController.to.user;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(name: user?.nom ?? '', email: user?.email ?? ''),
            SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                    _Item(
                      icon: Icons.home_rounded,
                      label: 'Accueil',
                      route: AppRoutes.vendeurHome,
                      currentRoute: currentRoute,
                    ),
                    _ExpansionGroup(
                      icon: Icons.receipt_long_rounded,
                      title: 'Ventes & règlements',
                      currentRoute: currentRoute,
                      childrenRoutes: const [
                        AppRoutes.vendeurVentes,
                        AppRoutes.adminClients,
                        AppRoutes.adminReglements,
                      ],
                      children: [
                        _Item(
                          icon: Icons.receipt_long_rounded,
                          label: 'Ventes',
                          route: AppRoutes.vendeurVentes,
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
                    _Item(
                      icon: Icons.bar_chart_rounded,
                      label: 'Mes rapports',
                      route: AppRoutes.adminRapports,
                      currentRoute: currentRoute,
                    ),
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
                          Navigator.of(ctx).pop();
                          Get.toNamed(AppRoutes.parametres);
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
                onTap: () => confirmSignOut(ctx),
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
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String email;
  const _Header({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Tap sur le header → ouvre "Mon compte" (édition de son propre profil).
        onTap: () {
          Navigator.of(context).pop();
          final me = UserController.to.user;
          if (me != null) {
            Get.toNamed(AppRoutes.adminUserForm, arguments: me);
          }
        },
        child: Container(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'GESTIONNAIRE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      leading: Icon(icon, color: selected ? AppColors.primary(context) : null),
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
        Navigator.of(context).pop();
        if (selected) return;
        Get.offNamed(route);
      },
    );
  }
}

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
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
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
        childrenPadding: const EdgeInsets.only(left: 12),
        children: children,
      ),
    );
  }
}
