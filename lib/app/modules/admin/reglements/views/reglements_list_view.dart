import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../core/widgets/vendeur_drawer.dart';
import '../../../../data/models/reglement_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/reglements_controller.dart';
import '../widgets/encaissement_global_sheet.dart';

class ReglementsListView extends GetView<ReglementsController> {
  const ReglementsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Règlements'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (client, gestionnaire, note)...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => controller.search.value = v,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      drawer: UserController.to.isAnyAdmin
          ? const AdminDrawer(currentRoute: AppRoutes.adminReglements)
          : const VendeurDrawer(currentRoute: AppRoutes.adminReglements),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Sélecteur boutique visible UNIQUEMENT pour super-admin
          // (admin/vendeur sont scopés sur leur propre boutique).
          if (controller.isSuperAdmin) _BoutiquePicker(controller: controller),
          const SizedBox(height: 12),
          _PeriodeBar(controller: controller),
          const SizedBox(height: 14),
          _StatsRow(controller: controller),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.filtered;
              if (list.isEmpty) {
                return _EmptyState(
                  hasSearch:
                      controller.search.value.isNotEmpty ||
                          controller.filterClientId.value != null ||
                          controller.filterMode.value != null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _ReglementTile(reglement: list[i], controller: controller),
              );
            }),
          ),
        ],
        ),
      ),
      // FAB ouvert au super-admin (sans restriction) ou au gestionnaire.
      // Obx → réagit au cumul admin+gestionnaire en direct.
      floatingActionButton: Obx(
        () => UserController.to.canPerformSales
            ? FloatingActionButton.extended(
                onPressed: () => EncaissementGlobalSheet.open(context),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Encaisser'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    Get.bottomSheet(
      isScrollControlled: true,
      wrapBottomSheet(
        context,
        Container(
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
              const Text('Filtres',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
              const Text('Client', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Obx(
                () => DropdownButtonFormField<String?>(
                  initialValue: controller.filterClientId.value,
                  decoration: const InputDecoration(isDense: true),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tous les clients'),
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
              // Vendeur : super-admin et admin de boutique. Caché au vendeur
              // (qui ne voit que ses propres encaissements de toute façon).
              if (controller.isAnyAdmin) ...[
                const Text('Gestionnaire', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<String?>(
                    initialValue: controller.filterUserId.value,
                    decoration: const InputDecoration(isDense: true),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous'),
                      ),
                      ...controller.users.map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.nom,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => controller.filterUserId.value = v,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Mode', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tous'),
                      selected: controller.filterMode.value == null,
                      onSelected: (_) =>
                          controller.filterMode.value = null,
                    ),
                    ...ModePaiement.values.map(
                      (m) => ChoiceChip(
                        label: Text(m.label),
                        selected: controller.filterMode.value == m,
                        onSelected: (_) =>
                            controller.filterMode.value = m,
                      ),
                    ),
                  ],
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

// ============================================================================
// Sélecteur boutique pour super-admin (visible en haut de l'écran).
// Sans ce dropdown, super-admin ne pourrait pas savoir quelle boutique est
// affichée et passer par le sheet de filtres serait moins ergonomique.
// ============================================================================

class _BoutiquePicker extends StatelessWidget {
  final ReglementsController controller;
  const _BoutiquePicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Obx(() {
        final list = controller.boutiques;
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Aucune boutique disponible.',
              style: TextStyle(fontSize: 12),
            ),
          );
        }
        final safe =
            list.any((b) => b.id == controller.filterBoutiqueId.value)
                ? controller.filterBoutiqueId.value
                : null;
        return DropdownButtonFormField<String?>(
          initialValue: safe,
          decoration: const InputDecoration(
            labelText: 'Boutique',
            prefixIcon: Icon(Icons.store_rounded),
            isDense: true,
          ),
          isExpanded: true,
          items: list
              .map((b) => DropdownMenuItem<String?>(
                    value: b.id,
                    child: Text(b.nom,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => controller.filterBoutiqueId.value = v,
        );
      }),
    );
  }
}

// ============================================================================

class _PeriodeBar extends StatelessWidget {
  final ReglementsController controller;
  const _PeriodeBar({required this.controller});

  static const _items = [
    (PeriodeReglement.aujourdhui, 'Aujourd\'hui'),
    (PeriodeReglement.semaine, 'Semaine'),
    (PeriodeReglement.mois, 'Mois'),
    (PeriodeReglement.tout, 'Tout'),
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
            ],
          );
        }),
      ),
    );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary(context) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.primary(context)
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : AppColors.lightText),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================

class _StatsRow extends StatelessWidget {
  final ReglementsController controller;
  const _StatsRow({required this.controller});

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
                  icon: Icons.payments_rounded,
                  value: Fmt.number(controller.totalEncaisse),
                  label: 'Total encaissé',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long_rounded,
                  value: '${controller.nbReglements}',
                  label: 'Règlements',
                  color: AppColors.primary(context),
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
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.greyText(context, 700),
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

// ============================================================================

class _ReglementTile extends StatelessWidget {
  final ReglementModel reglement;
  final ReglementsController controller;
  const _ReglementTile({
    required this.reglement,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final c = controller.clientById(reglement.clientId);
          if (c != null) {
            Get.toNamed(AppRoutes.adminClientDetail, arguments: c);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.clientNom(reglement.clientId),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.dateTime(reglement.date)} · ${reglement.modePaiement.label}',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.greyText(context, 600)),
                    ),
                    if (reglement.imputations.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _imputationsLabelGlobal(reglement),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.greyText(context, 600),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (reglement.surplus > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Avance : ${Fmt.number(reglement.surplus)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (reglement.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        reglement.note!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText(context, 700),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${Fmt.number(reglement.montant)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.success,
                  letterSpacing: -0.2,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Imprimer le reçu',
                icon: Icon(Icons.print_outlined,
                    size: 18, color: AppColors.greyText(context, 700)),
                onPressed: () => controller.reimprimerRecu(reglement),
              ),
              // Suppression : VENDEUR uniquement (admin/super-admin lecture seule).
              // Obx → réagit au cumul admin+gestionnaire en direct.
              Obx(
                () => UserController.to.canPerformSales
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Supprimer',
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: Colors.red.shade400),
                        onPressed: () =>
                            controller.deleteReglement(reglement),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.payments_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? 'Aucun règlement ne correspond.'
                  : 'Aucun règlement sur cette période.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.greyText(context, 600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Construit le libellé compact des imputations pour la liste globale.
String _imputationsLabelGlobal(ReglementModel r) {
  if (r.imputations.isEmpty) return '';
  final parts = r.imputations.map((i) {
    final num = i.numero ?? i.venteId.substring(0,
        i.venteId.length < 6 ? i.venteId.length : 6);
    return '$num ${Fmt.number(i.montant)}';
  });
  return 'Imputé sur ${parts.join(' + ')}';
}
