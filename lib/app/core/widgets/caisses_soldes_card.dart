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

  /// Un accueil n'est pas un écran de gestion : au-delà de trois caisses,
  /// la carte renvoie vers la liste complète plutôt que de s'allonger.
  static const int _maxAffichees = 3;

  @override
  Widget build(BuildContext context) {
    final actives = caisses.where((c) => c.active).toList();
    if (actives.isEmpty) return const SizedBox.shrink();

    // Le total porte sur TOUTES les caisses, pas seulement sur celles
    // affichées : « Trésorerie » doit rester le montant réel, sinon le
    // chiffre mentirait dès qu'il y a plus de trois caisses.
    final total = actives.fold<double>(0, (acc, c) => acc + c.solde);
    // Les caisses arrivent déjà triées sur `ordre`, le rang d'affichage
    // choisi par l'admin : les trois premières sont celles qu'il a mises
    // en avant.
    final affichees = actives.take(_maxAffichees).toList();
    final restantes = actives.length - affichees.length;

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
            ...affichees.map(
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
            if (restantes > 0) ...[
              const Divider(height: 12),
              InkWell(
                onTap: () => Get.toNamed(AppRoutes.adminCaisses),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        restantes == 1
                            ? 'Voir la caisse restante'
                            : 'Voir les $restantes autres caisses',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.primary(context)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
