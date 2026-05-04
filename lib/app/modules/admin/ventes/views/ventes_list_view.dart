import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../reglements/widgets/reglement_sheet.dart';
import '../controllers/ventes_controller.dart';

class VentesListView extends GetView<VentesController> {
  const VentesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes'),
        actions: [
          Obx(() => IconButton(
                tooltip: controller.onlyAvecCredit.value
                    ? 'Désactiver le filtre crédit'
                    : 'Voir uniquement les crédits en cours',
                icon: Icon(
                  controller.onlyAvecCredit.value
                      ? Icons.warning_amber_rounded
                      : Icons.warning_amber_outlined,
                  color: controller.onlyAvecCredit.value
                      ? AppColors.warning
                      : null,
                ),
                onPressed: () => controller.onlyAvecCredit.toggle(),
              )),
          IconButton(
            tooltip: 'Filtres',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (n° vente, client, gestionnaire)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
      ),
      drawer: controller.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminVentes)
          : const VendeurDrawer(currentRoute: AppRoutes.vendeurVentes),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          const SizedBox(height: 12),
          _PeriodeBar(controller: controller),
          const SizedBox(height: 14),
          _StatsBar(controller: controller),
          const SizedBox(height: 6),
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
      ),
      // FAB réservé au vendeur : la création d'une vente est une opération
      // métier, admin/super-admin sont en lecture seule.
      floatingActionButton: UserController.to.isVendeur
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.venteForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle vente'),
            )
          : null,
    );
  }

  void _showFilterSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
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
              ],
              // Vendeur : visible pour super-admin et admin de boutique.
              // Caché au vendeur (déjà filtré sur ses propres ventes).
              if (controller.isAnyAdmin) ...[
                const Text('Gestionnaire', style: TextStyle(fontSize: 12)),
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
              const Text('Produit', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Obx(
                () => DropdownButtonFormField<String?>(
                  initialValue: controller.filterProduitId.value,
                  decoration: const InputDecoration(isDense: true),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tous les produits'),
                    ),
                    ...controller.produits.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.nom,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => controller.filterProduitId.value = v,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Client', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Obx(
                () => DropdownButtonFormField<String?>(
                  initialValue: controller.filterClientId.value,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tous les clients'),
                    ),
                    DropdownMenuItem<String?>(
                      value: controller.diversSentinel,
                      child: const Text('Client divers'),
                    ),
                    ...controller.clients.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nom,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => controller.filterClientId.value = v,
                ),
              ),
              const SizedBox(height: 12),
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
                  value: controller.onlyAvecCredit.value,
                  onChanged: (v) =>
                      controller.onlyAvecCredit.value = v ?? false,
                  title: const Text('Seulement les crédits en cours'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
      ),
    );
  }
}

class _PeriodeBar extends StatelessWidget {
  final VentesController controller;
  const _PeriodeBar({required this.controller});

  static const _items = [
    (PeriodeFiltre.aujourdhui, 'Aujourd\'hui'),
    (PeriodeFiltre.semaine, 'Semaine'),
    (PeriodeFiltre.mois, 'Mois'),
    (PeriodeFiltre.tout, 'Tout'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Obx(() {
          final current = controller.periode.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _PillTab(
                  label: _items[i].$2,
                  selected: current == _items[i].$1,
                  onTap: () => controller.periode.value = _items[i].$1,
                ),
              ],
              const SizedBox(width: 8),
              _PillTab(
                label: current == PeriodeFiltre.personnalise
                    ? _customLabel(controller)
                    : 'Personnalisé',
                selected: current == PeriodeFiltre.personnalise,
                onTap: () => _pickCustomRange(context, controller),
              ),
            ],
          );
        }),
      ),
    );
  }

  static String _customLabel(VentesController c) {
    final d = c.customDebut.value;
    final f = c.customFin.value;
    if (d == null || f == null) return 'Personnalisé';
    return '${Fmt.dateShort(d)} → ${Fmt.dateShort(f)}';
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    VentesController c,
  ) async {
    final now = DateTime.now();
    final initial = (c.customDebut.value != null && c.customFin.value != null)
        ? DateTimeRange(start: c.customDebut.value!, end: c.customFin.value!)
        : DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked == null) return;
    c.customDebut.value = picked.start;
    c.customFin.value = picked.end;
    c.periode.value = PeriodeFiltre.personnalise;
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedText =
        isDark ? Colors.grey.shade300 : AppColors.lightText;
    final unselectedBorder = Theme.of(context).dividerColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.primary : unselectedBorder,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : unselectedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(
        () => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  color: AppColors.success,
                  icon: Icons.attach_money_rounded,
                  value: Fmt.number(controller.caTotal),
                  label: 'Chiffre d\'affaires',
                ),
              ),
              const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    final hasCredit = !annulee && vente.resteAPayer > 0;
    final iconColor = annulee
        ? Colors.grey
        : (hasCredit ? AppColors.warning : AppColors.success);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.venteDetail,
          arguments: vente.id,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  annulee
                      ? Icons.cancel_outlined
                      : Icons.receipt_long_rounded,
                  color: iconColor,
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
                          vente.numeroAffichage,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (annulee)
                          _Badge(label: 'ANNULÉE', color: Colors.red)
                        else if (hasCredit)
                          _Badge(label: 'CRÉDIT', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_pin_rounded,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            c.clientNomVente(vente),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.dateTime(vente.date)} · ${vente.nbArticles} art. · ${vente.modePaiement.label}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.money(vente.total,
                        currency: c.deviseDe(vente.boutiqueId)),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: annulee ? Colors.grey : AppColors.primary,
                      decoration: annulee
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (hasCredit)
                    Text(
                      'Reste ${Fmt.number(vente.resteAPayer)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Plus',
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.grey.shade600, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'detail':
                      Get.toNamed(AppRoutes.venteDetail,
                          arguments: vente.id);
                      break;
                    case 'reimprimer':
                      c.reimprimerRecu(vente);
                      break;
                    case 'regler':
                      final client = c.clientDeVente(vente);
                      if (client == null) {
                        Get.snackbar(
                          'Impossible',
                          'Le règlement nécessite un client identifié.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else {
                        ReglementSheet.open(context, client);
                      }
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'detail',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new_rounded),
                      title: Text('Voir le détail'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  if (hasCredit && c.clientDeVente(vente) != null)
                    const PopupMenuItem(
                      value: 'regler',
                      child: ListTile(
                        leading: Icon(Icons.payments_rounded,
                            color: AppColors.success),
                        title: Text('Régler le crédit',
                            style: TextStyle(color: AppColors.success)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'reimprimer',
                    child: ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('Imprimer le reçu'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
