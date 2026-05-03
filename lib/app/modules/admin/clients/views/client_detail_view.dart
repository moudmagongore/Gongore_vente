import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/models/reglement_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../reglements/widgets/reglement_sheet.dart';
import '../controllers/client_detail_controller.dart';

class ClientDetailView extends GetView<ClientDetailController> {
  const ClientDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(controller.client.value?.nom ?? 'Client')),
          actions: [
            Obx(() {
              final c = controller.client.value;
              if (c == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    Get.toNamed(AppRoutes.adminClientForm, arguments: c),
              );
            }),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Ventes'),
              Tab(
                  icon: Icon(Icons.payments_rounded),
                  text: 'Règlements'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Obx(() {
            final c = controller.client.value;
            if (c == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                _ClientHeader(client: c, controller: controller),
                Expanded(
                  child: TabBarView(
                    children: [
                      _VentesTab(controller: controller),
                      _ReglementsTab(controller: controller),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ============================================================================
// En-tête : avatar, nom, solde, stats, actions
// ============================================================================

class _ClientHeader extends StatelessWidget {
  final ClientModel client;
  final ClientDetailController controller;
  const _ClientHeader({required this.client, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasDette = client.solde > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  client.nom.isEmpty ? '?' : client.nom[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      client.nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (client.telephone?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            client.telephone!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasDette
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.number(client.solde.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color:
                            hasDette ? AppColors.warning : AppColors.success,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      hasDette
                          ? 'doit'
                          : (client.solde < 0 ? 'avance' : 'à jour'),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            hasDette ? AppColors.warning : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats agrégées
          Obx(() => Row(
                children: [
                  _StatChip(
                    label: 'Ventes',
                    value: '${controller.nbVentes}',
                    icon: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Total acheté',
                    value: Fmt.number(controller.totalAchete),
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Panier moyen',
                    value: Fmt.number(controller.panierMoyen),
                    icon: Icons.equalizer_rounded,
                  ),
                ],
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ReglementSheet.open(context, client),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Encaisser'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Get.toNamed(
                    AppRoutes.venteForm,
                    arguments: client, // pré-sélection du client
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('Nouvelle vente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
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
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.primary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Onglet Ventes
// ============================================================================

class _VentesTab extends StatelessWidget {
  final ClientDetailController controller;
  const _VentesTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = controller.ventes;
      if (list.isEmpty) {
        return _EmptyState(
          icon: Icons.receipt_long_outlined,
          message: 'Aucune vente pour ce client.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _VenteTile(vente: list[i]),
      );
    });
  }
}

class _VenteTile extends StatelessWidget {
  final VenteModel vente;
  const _VenteTile({required this.vente});

  @override
  Widget build(BuildContext context) {
    final annulee = vente.statut == VenteStatut.annulee;
    final hasCredit = !annulee && vente.resteAPayer > 0;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            Get.toNamed(AppRoutes.venteDetail, arguments: vente.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (annulee ? Colors.grey : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  annulee
                      ? Icons.cancel_outlined
                      : Icons.receipt_long_rounded,
                  color: annulee ? Colors.grey : AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vente.numeroAffichage,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (annulee)
                          _MiniBadge(
                              label: 'Annulée',
                              color: Colors.red,
                              decoration: TextDecoration.none)
                        else if (hasCredit)
                          _MiniBadge(
                            label: 'Crédit',
                            color: AppColors.warning,
                            decoration: TextDecoration.none,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.dateTime(vente.date),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (hasCredit) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reste : ${Fmt.number(vente.resteAPayer)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                Fmt.number(vente.total),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: annulee ? Colors.grey : AppColors.primary,
                  decoration:
                      annulee ? TextDecoration.lineThrough : TextDecoration.none,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final TextDecoration decoration;
  const _MiniBadge({
    required this.label,
    required this.color,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          color: color,
          fontWeight: FontWeight.w800,
          decoration: decoration,
        ),
      ),
    );
  }
}

// ============================================================================
// Onglet Règlements
// ============================================================================

class _ReglementsTab extends StatelessWidget {
  final ClientDetailController controller;
  const _ReglementsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = controller.reglements;
      if (list.isEmpty) {
        return _EmptyState(
          icon: Icons.payments_outlined,
          message: 'Aucun règlement enregistré.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ReglementTile(
          reglement: list[i],
          controller: controller,
        ),
      );
    });
  }
}

class _ReglementTile extends StatelessWidget {
  final ReglementModel reglement;
  final ClientDetailController controller;
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
        border: Border.all(color: AppColors.border),
      ),
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
                  reglement.modePaiement.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.dateTime(reglement.date),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (reglement.imputations.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _imputationsLabel(reglement),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
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
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.primary,
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
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
                size: 18, color: Colors.grey.shade700),
            onPressed: () => controller.reimprimerRecu(reglement),
          ),
          if (controller.isAdminOrSuper)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Supprimer',
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
              onPressed: () => controller.confirmDeleteReglement(reglement),
            ),
        ],
      ),
    );
  }
}

/// Construit un libellé compact « Imputé sur V-001 30 000 + V-002 20 000 »
/// pour afficher les imputations FIFO d'un règlement sous le tile.
String _imputationsLabel(ReglementModel r) {
  if (r.imputations.isEmpty) return '';
  final parts = r.imputations.map((i) {
    final num = i.numero ?? i.venteId.substring(0,
        i.venteId.length < 6 ? i.venteId.length : 6);
    return '$num ${Fmt.number(i.montant)}';
  });
  return 'Imputé sur ${parts.join(' + ')}';
}

// ============================================================================
// État vide générique
// ============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
