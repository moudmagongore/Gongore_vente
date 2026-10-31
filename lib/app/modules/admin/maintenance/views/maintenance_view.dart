import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/admin_drawer.dart';
import '../../../../data/repositories/maintenance_repository.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/maintenance_controller.dart';

/// Purge des données d'une boutique. Réservé au super-admin (SuperAdminGuard).
class MaintenanceView extends GetView<MaintenanceController> {
  const MaintenanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purge des données'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Recompter',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: controller.boutiqueId.value == null ||
                      controller.isCounting.value
                  ? null
                  : controller.rafraichirCompteurs,
            ),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: AppRoutes.adminMaintenance),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _Avertissement(),
            const SizedBox(height: 16),
            _BoutiquePicker(c: controller),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.boutiqueId.value == null) {
                return const _AucuneBoutique();
              }
              return _MargesCard(c: controller);
            }),
            Obx(() {
              if (controller.boutiqueId.value == null) {
                return const SizedBox.shrink();
              }
              if (controller.isCounting.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: controller.cibles
                    .map((cible) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CibleCard(c: controller, cible: cible),
                        ))
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Reprise des marges : fige la marge des ventes passées au prix d'achat
/// actuel. Séparé des purges : rien n'est supprimé ici, on complète des
/// données manquantes.
class _MargesCard extends StatelessWidget {
  final MaintenanceController c;
  const _MargesCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final nb = c.ventesSansMarge.value;
      final analyse = c.analyseMargesEnCours.value;
      final fige = c.figeageEnCours.value;
      final rienAFaire = nb == 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: analyse
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Text(
                          nb == null ? '—' : Fmt.number(nb),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: nb != null && nb > 999 ? 12 : 14,
                            color: AppColors.primary(context),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Marges des ventes passées',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fige
                            ? 'Traitement… ${Fmt.number(c.margesTraitees.value)}'
                            : nb == null
                                ? 'Analysez pour savoir combien de ventes '
                                    'n\'ont pas encore de marge figée.'
                                : rienAFaire
                                    ? 'Toutes les ventes ont leur marge figée.'
                                    : '$nb vente(s) sans marge figée. Leur '
                                        'marge bouge encore à chaque appro.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: fige
                              ? AppColors.primary(context)
                              : AppColors.greyText(context, 600),
                          fontWeight:
                              fige ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: analyse || fige ? null : c.analyserMarges,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Analyser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (nb == null || rienAFaire || analyse || fige)
                        ? null
                        : c.confirmerEtFigerMarges,
                    icon: fige
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Figer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Les marges sont figées au prix d\'achat ACTUEL : elles '
              'cessent de bouger, mais ne reflètent pas le prix du jour de '
              'la vente. Les ventes à venir, elles, sont exactes.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.greyText(context, 600),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suppression définitive',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Firestore n\'a pas de corbeille : les données supprimées '
                  'ici sont perdues. Seule la boutique choisie est touchée.',
                  style: TextStyle(
                    fontSize: 12.5,
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

class _BoutiquePicker extends StatelessWidget {
  final MaintenanceController c;
  const _BoutiquePicker({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final safe = c.boutiques.any((b) => b.id == c.boutiqueId.value)
          ? c.boutiqueId.value
          : null;
      return DropdownButtonFormField<String?>(
        initialValue: safe,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Boutique à purger *',
          prefixIcon: Icon(Icons.store_outlined),
        ),
        // Pas d'entrée « Toutes » : une purge multi-boutique ne doit jamais
        // être à un seul clic.
        items: c.boutiques
            .map((b) => DropdownMenuItem<String?>(
                  value: b.id,
                  child: Text(b.nom, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: c.enCours.value != null
            ? null
            : (v) => c.boutiqueId.value = v,
      );
    });
  }
}

class _AucuneBoutique extends StatelessWidget {
  const _AucuneBoutique();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            'Choisissez une boutique pour voir ses données.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.greyText(context, 600)),
          ),
        ],
      ),
    );
  }
}

class _CibleCard extends StatelessWidget {
  final MaintenanceController c;
  final PurgeCible cible;
  const _CibleCard({required this.c, required this.cible});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final nb = c.compteurs[cible];
      final vide = nb == null || nb == 0;
      final busy = c.enCours.value == cible;
      final autreEnCours = c.enCours.value != null && !busy;

      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (vide ? Colors.grey : AppColors.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                nb == null ? '—' : Fmt.number(nb),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: nb != null && nb > 999 ? 12 : 14,
                  color: vide
                      ? AppColors.greyText(context, 600)
                      : AppColors.danger,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cible.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    busy
                        ? 'Suppression… ${Fmt.number(c.progression.value)}'
                        : cible.consequence,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: busy
                          ? AppColors.danger
                          : AppColors.greyText(context, 600),
                      fontWeight: busy ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              IconButton(
                tooltip: vide ? 'Aucune donnée' : 'Vider',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: vide || autreEnCours
                      ? AppColors.greyText(context, 500)
                      : AppColors.danger,
                ),
                onPressed: vide || autreEnCours
                    ? null
                    : () => c.confirmerEtPurger(cible),
              ),
          ],
        ),
      );
    });
  }
}
