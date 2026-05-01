import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../services/user_controller.dart';

class AdminDrawer extends StatelessWidget {
  /// Route active pour mettre l'item en surbrillance.
  final String currentRoute;

  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final user = UserController.to.user;
    final isSuper = UserController.to.isSuperAdmin;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              name: user?.nom ?? '',
              email: user?.email ?? '',
              isSuper: isSuper,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Item(
                    icon: Icons.dashboard_rounded,
                    label: 'Tableau de bord',
                    route: AppRoutes.adminHome,
                    selected: currentRoute == AppRoutes.adminHome,
                  ),
                  _Item(
                    icon: Icons.store_rounded,
                    label: isSuper ? 'Boutiques' : 'Ma boutique',
                    route: AppRoutes.adminBoutiques,
                    selected: currentRoute == AppRoutes.adminBoutiques,
                  ),
                  _Item(
                    icon: Icons.people_alt_rounded,
                    label: isSuper ? 'Utilisateurs' : 'Mes vendeurs',
                    route: AppRoutes.adminUsers,
                    selected: currentRoute == AppRoutes.adminUsers,
                  ),
                  _Item(
                    icon: Icons.category_rounded,
                    label: 'Catégories',
                    route: AppRoutes.adminCategories,
                    selected: currentRoute == AppRoutes.adminCategories,
                  ),
                  _Item(
                    icon: Icons.inventory_2_rounded,
                    label: 'Produits',
                    route: AppRoutes.adminProduits,
                    selected: currentRoute == AppRoutes.adminProduits,
                  ),
                  _Item(
                    icon: Icons.warehouse_rounded,
                    label: 'Stock',
                    route: AppRoutes.adminStock,
                    selected: currentRoute == AppRoutes.adminStock,
                  ),
                  _Item(
                    icon: Icons.point_of_sale_rounded,
                    label: 'Caisse',
                    route: AppRoutes.adminPos,
                    selected: currentRoute == AppRoutes.adminPos,
                  ),
                  _Item(
                    icon: Icons.receipt_long_rounded,
                    label: 'Ventes',
                    route: AppRoutes.adminVentes,
                    selected: currentRoute == AppRoutes.adminVentes,
                  ),
                  _Item(
                    icon: Icons.bar_chart_rounded,
                    label: 'Rapports',
                    route: AppRoutes.adminRapports,
                    selected: currentRoute == AppRoutes.adminRapports,
                  ),
                  const Divider(),
                  _Item(
                    icon: Icons.settings_rounded,
                    label: 'Paramètres',
                    route: AppRoutes.parametres,
                    selected: currentRoute == AppRoutes.parametres,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Déconnexion',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await UserController.to.signOut();
                Get.offAllNamed(AppRoutes.login);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuper
              ? const [Color(0xFF6A1B9A), Color(0xFF1565C0)]
              : const [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSuper
                        ? const Color(0xFF6A1B9A)
                        : AppColors.primary,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isSuper ? 'SUPER ADMIN' : 'ADMINISTRATEUR',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool selected;

  const _Item({
    required this.icon,
    required this.label,
    required this.route,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? AppColors.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primary : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
      onTap: () {
        Navigator.of(context).pop();
        if (selected) return;
        Get.offNamed(route);
      },
    );
  }
}
