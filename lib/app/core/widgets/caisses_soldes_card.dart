import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/caisse_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../utils/format_helpers.dart';

/// Soldes des caisses visibles par l'utilisateur, et leur total (RG-31).
///
/// Partagé par le tableau de bord admin et l'accueil gestionnaire : chacun
/// passe la liste qu'il a le droit de voir, le widget ne fait aucune
/// lecture lui-même.
///
/// Ne rend rien si la liste est vide : une boutique sans caisse ne doit pas
/// voir apparaître une carte vide sur son accueil.
class CaissesSoldesCard extends StatelessWidget {
  final List<CaisseModel> caisses;

  const CaissesSoldesCard({super.key, required this.caisses});

  @override
  Widget build(BuildContext context) {
    final actives = caisses.where((c) => c.active).toList();
    if (actives.isEmpty) return const SizedBox.shrink();

    final total = actives.fold<double>(0, (acc, c) => acc + c.solde);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_rounded,
                    size: 18, color: AppColors.primary(context)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Trésorerie',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  Fmt.money(total, currency: 'GNF'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: total < 0
                        ? AppColors.danger
                        : AppColors.primary(context),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...actives.map(
              (c) => InkWell(
                onTap: () =>
                    Get.toNamed(AppRoutes.caisseReleve, arguments: c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 15,
                          color: AppColors.greyText(context, 600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.nom,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Fmt.money(c.solde, currency: 'GNF'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.solde < 0
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.greyText(context, 500)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
