import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../services/user_controller.dart';
import 'sign_out_dialog.dart';

class VendeurDrawer extends StatelessWidget {
  final String currentRoute;
  const VendeurDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final user = UserController.to.user;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(name: user?.nom ?? '', email: user?.email ?? ''),
          const SizedBox(height: 8),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Item(
                    icon: Icons.home_rounded,
                    label: 'Accueil',
                    route: AppRoutes.vendeurHome,
                    selected: currentRoute == AppRoutes.vendeurHome,
                  ),
                  _Item(
                    icon: Icons.receipt_long_rounded,
                    label: 'Vente',
                    route: AppRoutes.vendeurVentes,
                    selected: currentRoute == AppRoutes.vendeurVentes,
                  ),
                  _Item(
                    icon: Icons.contacts_rounded,
                    label: 'Clients',
                    route: AppRoutes.adminClients,
                    selected: currentRoute == AppRoutes.adminClients,
                  ),
                  _Item(
                    icon: Icons.payments_rounded,
                    label: 'Règlements',
                    route: AppRoutes.adminReglements,
                    selected: currentRoute == AppRoutes.adminReglements,
                  ),
                  _Item(
                    icon: Icons.inventory_2_rounded,
                    label: 'Produits',
                    route: AppRoutes.adminProduits,
                    selected: currentRoute == AppRoutes.adminProduits,
                  ),
                  _Item(
                    icon: Icons.category_rounded,
                    label: 'Catégories',
                    route: AppRoutes.adminCategories,
                    selected: currentRoute == AppRoutes.adminCategories,
                  ),
                  _Item(
                    icon: Icons.bar_chart_rounded,
                    label: 'Mes rapports',
                    route: AppRoutes.adminRapports,
                    selected: currentRoute == AppRoutes.adminRapports,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Builder(
            builder: (ctx) => ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Déconnexion',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => confirmSignOut(ctx),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
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
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20 + topInset, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.primary],
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
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
              'VENDEUR',
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
      leading: Icon(icon, color: selected ? AppColors.secondary : null),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.secondary : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.secondary.withValues(alpha: 0.08),
      onTap: () {
        Navigator.of(context).pop();
        if (selected) return;
        Get.offNamed(route);
      },
    );
  }
}
