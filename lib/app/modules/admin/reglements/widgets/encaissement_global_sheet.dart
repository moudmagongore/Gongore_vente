import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../data/models/client_model.dart';
import '../../../../data/repositories/client_repository.dart';
import '../../../../theme/app_colors.dart';
import 'reglement_sheet.dart';

/// Bottom sheet « Encaisser un règlement » accessible globalement
/// (drawer, etc.). Affiche d'abord un picker client (recherche + liste),
/// puis enchaîne sur [ReglementSheet] pour la saisie du montant.
class EncaissementGlobalSheet extends StatefulWidget {
  const EncaissementGlobalSheet({super.key});

  static void open(BuildContext context) {
    Get.bottomSheet(
      const EncaissementGlobalSheet(),
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
    );
  }

  @override
  State<EncaissementGlobalSheet> createState() =>
      _EncaissementGlobalSheetState();
}

class _EncaissementGlobalSheetState extends State<EncaissementGlobalSheet> {
  final _clientRepo = ClientRepository();
  final _searchCtrl = TextEditingController();
  final _clients = <ClientModel>[].obs;
  bool _onlyDettes = true;

  @override
  void initState() {
    super.initState();
    _clients.bindStream(
      _clientRepo.watchScoped(UserController.to.scopeBoutiqueId),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _clients.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: AppColors.success, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Encaisser un règlement',
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
                  hintText: 'Rechercher un client (nom, téléphone)...',
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
                          : Icons.people_alt_outlined,
                      size: 14,
                      color: _onlyDettes
                          ? AppColors.warning
                          : Colors.grey.shade600,
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
                final list = _clients.where((c) {
                  if (_onlyDettes && c.solde <= 0) return false;
                  if (q.isEmpty) return true;
                  return c.nom.toLowerCase().contains(q) ||
                      (c.telephone?.toLowerCase().contains(q) ?? false);
                }).toList();
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _onlyDettes
                            ? 'Aucun client avec dette en cours.'
                            : 'Aucun client.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
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
                    final c = list[i];
                    final hasDette = c.solde > 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          c.nom.isEmpty ? '?' : c.nom[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(c.nom),
                      subtitle: c.telephone == null
                          ? null
                          : Text(c.telephone!,
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
                                Fmt.number(c.solde),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            )
                          : Icon(Icons.check_circle_outline_rounded,
                              size: 18, color: Colors.grey.shade400),
                      onTap: () {
                        Navigator.of(context).pop();
                        ReglementSheet.open(context, c);
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
