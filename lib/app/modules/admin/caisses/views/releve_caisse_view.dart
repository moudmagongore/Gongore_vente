import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/releve_caisse_pdf_service.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/mouvement_caisse_model.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/releve_caisse_controller.dart';

/// Relevé d'une caisse : solde de début, mouvements, solde de fin (RG-29).
class ReleveCaisseView extends GetView<ReleveCaisseController> {
  const ReleveCaisseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.caisse.value?.nom ?? 'Relevé')),
        actions: [
          IconButton(
            tooltip: 'Exporter en PDF',
            onPressed: () => ReleveCaissePdfService.exporter(controller),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const _PeriodeBar(),
            const _Synthese(),
            const _FiltreTypes(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = controller.filtered;
                if (list.isEmpty) {
                  return _Vide(filtre: controller.estFiltre);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _MouvementTile(mouvement: list[i]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodeBar extends StatelessWidget {
  const _PeriodeBar();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ReleveCaisseController>();
    return Obx(() {
      // La valeur est lue ici, avant la construction paresseuse des chips.
      final courante = c.periode.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(
          children: [
            for (final p in PeriodeReleve.values) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_label(p), style: const TextStyle(fontSize: 12)),
                  selected: courante == p,
                  showCheckmark: false,
                  onSelected: (_) => c.periode.value = p,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  String _label(PeriodeReleve p) {
    switch (p) {
      case PeriodeReleve.aujourdhui:
        return 'Aujourd\'hui';
      case PeriodeReleve.semaine:
        return 'Semaine';
      case PeriodeReleve.mois:
        return 'Mois';
      case PeriodeReleve.tout:
        return 'Tout';
    }
  }
}

/// Solde début + entrées − sorties = solde fin. L'égalité doit tomber
/// juste : c'est le premier critère d'acceptation du relevé.
class _Synthese extends StatelessWidget {
  const _Synthese();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ReleveCaisseController>();
    return Obx(() {
      final soldeActuel = c.caisse.value?.solde ?? 0;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde actuel',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText(context, 700),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.money(soldeActuel),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: soldeActuel < 0
                              ? AppColors.danger
                              : AppColors.primary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  c.libellePeriode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyText(context, 700),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            _Ligne(label: 'Solde au début', valeur: c.money(c.soldeDebut.value)),
            _Ligne(
              label: 'Entrées',
              valeur: '+ ${c.money(c.totalEntrees)}',
              couleur: AppColors.success,
            ),
            _Ligne(
              label: 'Sorties',
              valeur: '− ${c.money(c.totalSorties)}',
              couleur: AppColors.danger,
            ),
            _Ligne(
              label: 'Solde à la fin',
              valeur: c.money(c.soldeFin),
              gras: true,
            ),
            if (c.estFiltre) ...[
              const SizedBox(height: 6),
              Text(
                'Entrées et sorties ne comptent que le type filtré ; les '
                'soldes restent ceux de la période entière.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.greyText(context, 600),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _Ligne extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleur;
  final bool gras;
  const _Ligne({
    required this.label,
    required this.valeur,
    this.couleur,
    this.gras = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: gras ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 13,
              fontWeight: gras ? FontWeight.w800 : FontWeight.w600,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltreTypes extends StatelessWidget {
  const _FiltreTypes();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ReleveCaisseController>();
    return Obx(() {
      final types = c.typesPresents;
      if (types.length < 2) return const SizedBox(height: 4);
      final courant = c.filterType.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tous', style: TextStyle(fontSize: 11.5)),
                selected: courant == null,
                showCheckmark: false,
                onSelected: (_) => c.filterType.value = null,
              ),
            ),
            for (final t in types)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.label, style: const TextStyle(fontSize: 11.5)),
                  selected: courant == t,
                  showCheckmark: false,
                  onSelected: (_) => c.filterType.value = t,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _MouvementTile extends StatelessWidget {
  final MouvementCaisseModel mouvement;
  const _MouvementTile({required this.mouvement});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ReleveCaisseController>();
    final entree = mouvement.sens == SensMouvement.entree;
    final couleur = entree ? AppColors.success : AppColors.danger;
    final aSource =
        mouvement.sourceId != null && mouvement.sourceId!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: aSource ? () => c.ouvrirSource(mouvement) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  entree
                      ? Icons.call_received_rounded
                      : Icons.call_made_rounded,
                  size: 16,
                  color: couleur,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mouvement.numero?.isNotEmpty ?? false
                                ? '${mouvement.type.label} · '
                                    '${mouvement.numero}'
                                : mouvement.type.label,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entree ? '+' : '−'} '
                          '${Fmt.money(mouvement.montant, currency: 'GNF')}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: couleur,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${Fmt.dateTime(mouvement.date)} · '
                            '${mouvement.userNom.isEmpty ? '—' : mouvement.userNom}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.greyText(context, 600),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'solde ${Fmt.money(mouvement.soldeApres, currency: 'GNF')}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.greyText(context, 600),
                          ),
                        ),
                      ],
                    ),
                    if (mouvement.motif?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        mouvement.motif!,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.greyText(context, 700),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (c.peutAnnuler(mouvement))
                IconButton(
                  tooltip: 'Annuler ce mouvement',
                  onPressed: () => c.confirmerAnnulation(mouvement),
                  icon: Icon(
                    Icons.undo_rounded,
                    size: 18,
                    color: AppColors.greyText(context, 600),
                  ),
                )
              else if (aSource)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.greyText(context, 500),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  final bool filtre;
  const _Vide({required this.filtre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              filtre
                  ? 'Aucun mouvement de ce type sur la période.'
                  : 'Aucun mouvement sur cette période.',
              style: TextStyle(color: AppColors.greyText(context, 600)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
