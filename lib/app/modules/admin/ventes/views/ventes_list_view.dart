import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/ventes_controller.dart';

class VentesListView extends GetView<VentesController> {
  const VentesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      drawer: controller.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminVentes)
          : const VendeurDrawer(currentRoute: AppRoutes.vendeurVentes),
      body: Column(
        children: [
          _PeriodeBar(controller: controller),
          _StatsBar(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.filtered;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune vente sur cette période.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _VenteTile(vente: list[i]),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(
          controller.isAnyAdmin ? AppRoutes.adminPos : AppRoutes.vendeurPos,
        ),
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text('Nouvelle vente'),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtres',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (controller.isSuperAdmin) ...[
                const Text('Boutique', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<String?>(
                    initialValue: controller.filterBoutiqueId.value,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes'),
                      ),
                      ...controller.boutiques.map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.nom),
                        ),
                      ),
                    ],
                    onChanged: (v) => controller.filterBoutiqueId.value = v,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Vendeur', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<String?>(
                    initialValue: controller.filterVendeurId.value,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous'),
                      ),
                      ...controller.vendeurs.map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.nom),
                        ),
                      ),
                    ],
                    onChanged: (v) => controller.filterVendeurId.value = v,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Mode de paiement', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tous'),
                      selected: controller.filterModePaiement.value == null,
                      onSelected: (_) =>
                          controller.filterModePaiement.value = null,
                    ),
                    ...ModePaiement.values.map(
                      (m) => ChoiceChip(
                        label: Text(m.label),
                        selected: controller.filterModePaiement.value == m,
                        onSelected: (_) =>
                            controller.filterModePaiement.value = m,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => CheckboxListTile(
                  value: controller.inclureAnnulees.value,
                  onChanged: (v) =>
                      controller.inclureAnnulees.value = v ?? false,
                  title: const Text('Inclure les ventes annulées'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('Appliquer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodeBar extends StatelessWidget {
  final VentesController controller;
  const _PeriodeBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Obx(
        () => SegmentedButton<PeriodeFiltre>(
          segments: const [
            ButtonSegment(
                value: PeriodeFiltre.aujourdhui, label: Text('Aujourd\'hui')),
            ButtonSegment(value: PeriodeFiltre.semaine, label: Text('Semaine')),
            ButtonSegment(value: PeriodeFiltre.mois, label: Text('Mois')),
            ButtonSegment(value: PeriodeFiltre.tout, label: Text('Tout')),
          ],
          selected: {controller.periode.value},
          onSelectionChanged: (s) => controller.periode.value = s.first,
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final VentesController controller;
  const _StatsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _StatCard(
                color: AppColors.success,
                icon: Icons.attach_money_rounded,
                value: Fmt.number(controller.caTotal),
                label: 'Chiffre d\'affaires',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                color: AppColors.primary,
                icon: Icons.receipt_long_rounded,
                value: controller.nbVentesValidees.toString(),
                label: 'Ventes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
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

class _VenteTile extends StatelessWidget {
  final VenteModel vente;
  const _VenteTile({required this.vente});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VentesController>();
    final annulee = vente.statut == VenteStatut.annulee;
    final color = annulee ? Colors.grey : AppColors.success;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.venteDetail,
          arguments: vente.id,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  annulee
                      ? Icons.cancel_outlined
                      : Icons.receipt_long_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          Fmt.dateTime(vente.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (annulee)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ANNULÉE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.store_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            c.boutiqueNom(vente.boutiqueId),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.person_outline,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            c.vendeurNom(vente.vendeurId),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vente.nbArticles} article(s) • ${vente.modePaiement.label}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                Fmt.money(vente.total, currency: c.deviseDe(vente.boutiqueId)),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: annulee ? Colors.grey : AppColors.primary,
                  decoration: annulee ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
