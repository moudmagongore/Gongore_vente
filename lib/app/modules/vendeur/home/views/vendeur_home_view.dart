import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/vendeur_home_controller.dart';

class VendeurHomeView extends GetView<VendeurHomeController> {
  const VendeurHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Column(
              children: [
                const Text('Espace vendeur', style: TextStyle(fontSize: 14)),
                if (controller.boutique.value != null)
                  Text(
                    controller.boutique.value!.nom,
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            )),
      ),
      drawer: const VendeurDrawer(currentRoute: AppRoutes.vendeurHome),
      body: RefreshIndicator(
        onRefresh: () async {
          // bindStream est déjà live, juste un petit délai cosmétique
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GreetingCard(controller: controller),
            const SizedBox(height: 16),
            _StatsBar(controller: controller),
            const SizedBox(height: 20),
            const _SectionTitle('Actions rapides'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: const [
                _ActionTile(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Nouvelle vente',
                  color: AppColors.success,
                  route: AppRoutes.vendeurPos,
                ),
                _ActionTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Mes ventes',
                  color: AppColors.primary,
                  route: AppRoutes.vendeurVentes,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Aujourd\'hui'),
            const SizedBox(height: 12),
            _RecentList(controller: controller),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.vendeurPos),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Vendre'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.lightTextMuted,
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final VendeurHomeController controller;
  const _GreetingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Bonjour';
    } else if (hour < 18) {
      greeting = 'Bon après-midi';
    } else {
      greeting = 'Bonsoir';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                Text(
                  controller.nomVendeur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.dateLong(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final VendeurHomeController controller;
  const _StatsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.receipt_long_rounded,
                value: controller.nbVentesJour.toString(),
                label: 'Ventes du jour',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.attach_money_rounded,
                value: Fmt.number(controller.caJour),
                label: 'Chiffre d\'affaires du jour',
                color: AppColors.success,
                suffix: controller.devise,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.shopping_basket_rounded,
                value: controller.nbArticlesVendus.toString(),
                label: 'Articles',
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? suffix;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            suffix ?? '',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final VendeurHomeController controller;
  const _RecentList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final list = controller.ventesAujourdhui.take(5).toList();
      if (list.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Aucune vente aujourd\'hui',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Appuyez sur « Vendre » pour commencer.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          ...list.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      Fmt.money(v.total, currency: controller.devise),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    subtitle: Text(
                      '${v.nbArticles} article(s) • ${v.modePaiement.label}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      Fmt.dateTime(v.date).split(' ').last,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Get.toNamed(
                      AppRoutes.venteDetail,
                      arguments: v.id,
                    ),
                  ),
                ),
              )),
          if (controller.ventesAujourdhui.length > 5)
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.vendeurVentes),
              child: const Text('Voir toutes mes ventes →'),
            ),
        ],
      );
    });
  }
}
