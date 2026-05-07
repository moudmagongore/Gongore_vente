import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/bottom_sheet_helpers.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../theme/app_colors.dart';
import '../../fournisseurs/widgets/reglement_fournisseur_sheet.dart';

/// Bottom sheet « Verser un règlement fournisseur » accessible globalement
/// (FAB de la liste règlements fournisseurs). Affiche un picker fournisseur
/// (recherche + liste, dette mise en avant), puis enchaîne sur
/// [ReglementFournisseurSheet] pour la saisie du montant.
class VersementGlobalFournisseurSheet extends StatefulWidget {
  const VersementGlobalFournisseurSheet({super.key});

  static void open(BuildContext context) {
    Get.bottomSheet(
      const VersementGlobalFournisseurSheet(),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<VersementGlobalFournisseurSheet> createState() =>
      _VersementGlobalFournisseurSheetState();
}

class _VersementGlobalFournisseurSheetState
    extends State<VersementGlobalFournisseurSheet> {
  final _fournRepo = FournisseurRepository();
  final _searchCtrl = TextEditingController();
  final _fournisseurs = <FournisseurModel>[].obs;
  bool _onlyDettes = true;

  @override
  void initState() {
    super.initState();
    _fournisseurs.bindStream(
      _fournRepo.watchScoped(UserController.to.scopeBoutiqueId),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fournisseurs.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: androidOnlySafeArea(
          Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payments_rounded,
                          color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Verser un règlement',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un fournisseur...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(
                        _onlyDettes ? 'Avec dette' : 'Tous',
                        style: const TextStyle(fontSize: 12),
                      ),
                      avatar: Icon(
                        _onlyDettes
                            ? Icons.warning_amber_rounded
                            : Icons.local_shipping_outlined,
                        size: 14,
                        color: _onlyDettes
                            ? AppColors.warning
                            : AppColors.greyText(context, 600),
                      ),
                      selected: _onlyDettes,
                      onSelected: (v) => setState(() => _onlyDettes = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Obx(() {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final list = _fournisseurs.where((f) {
                    if (_onlyDettes && f.solde <= 0) return false;
                    if (q.isEmpty) return true;
                    return f.nom.toLowerCase().contains(q) ||
                        (f.telephone?.toLowerCase().contains(q) ?? false);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _onlyDettes
                              ? 'Aucun fournisseur avec dette en cours.'
                              : 'Aucun fournisseur.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.greyText(context, 600)),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final f = list[i];
                      final hasDette = f.solde > 0;
                      final hasAvance = f.solde < 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary(context).withValues(alpha: 0.12),
                          child: Text(
                            f.nom.isEmpty ? '?' : f.nom[0].toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(f.nom),
                        subtitle: f.telephone == null
                            ? null
                            : Text(f.telephone!,
                                style: const TextStyle(fontSize: 12)),
                        trailing: hasDette
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  Fmt.number(f.solde),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              )
                            : hasAvance
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Avance ${Fmt.number(-f.solde)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  )
                                : Icon(Icons.check_circle_outline_rounded,
                                    size: 18, color: Colors.grey.shade400),
                        onTap: () {
                          Navigator.of(context).pop();
                          ReglementFournisseurSheet.open(context, f);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
