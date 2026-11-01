import '../../data/models/caisse_model.dart';
import '../../data/repositories/boutique_repository.dart';
import '../../data/repositories/caisse_repository.dart';
import '../services/user_controller.dart';

/// Ce qu'un formulaire d'opération doit savoir des caisses avant de
/// proposer — ou de refuser — une saisie de paiement.
///
/// Les écrans construits autour d'un `GetxController` lisent ces mêmes
/// informations depuis leur controller (streams déjà en place) ; ce
/// chargeur est destiné aux bottom sheets autonomes, qui n'ont pas de
/// controller à eux.
class CaisseContexte {
  /// Caisses actives de la boutique **accessibles à l'utilisateur**.
  final List<CaisseModel> caisses;

  /// La boutique a au moins une caisse active, accessible ou non. Lu sur
  /// `boutiques/{id}.hasCaissesActives`, seul moyen pour un gestionnaire
  /// de le savoir : il ne peut pas lire les caisses des autres.
  final bool boutiqueEquipee;

  const CaisseContexte({
    required this.caisses,
    required this.boutiqueEquipee,
  });

  /// Boutique sans caisse : l'opération se déroule comme avant le module
  /// (RG-9), et le choix de caisse n'est pas demandé.
  bool get sansCaisse => !boutiqueEquipee;

  /// La boutique a des caisses mais aucune n'est accessible : l'opération
  /// payée est bloquée (RG-19).
  bool get manquante => boutiqueEquipee && caisses.isEmpty;

  /// Une caisse est disponible : le choix devient obligatoire (RG-11).
  bool get disponible => caisses.isNotEmpty;

  static const vide = CaisseContexte(caisses: [], boutiqueEquipee: false);

  /// Stream des caisses visibles par l'utilisateur courant.
  ///
  /// **Passage obligé de tous les écrans.** Deux filtres y sont appliqués
  /// d'un seul coup :
  ///
  /// 1. le module de caisse doit être ouvert à la boutique par le
  ///    super-admin — sinon la liste est vide, et toute l'application
  ///    retombe sur le comportement d'avant le module (RG-9) sans qu'aucun
  ///    écran ait à le savoir ;
  /// 2. un gestionnaire ne voit que les caisses où son uid figure.
  ///
  /// Les contrôleurs appellent ceci plutôt que `CaisseRepository` en direct :
  /// un seul verrou, impossible à oublier en ajoutant un écran.
  static Stream<List<CaisseModel>> watchCaisses(String? scope) {
    final uc = UserController.to;
    if (!uc.caissesModuleActif) return Stream.value(<CaisseModel>[]);
    return CaisseRepository().watchScoped(
      scope: scope,
      gestionnaireId: uc.isAnyAdmin ? null : uc.user?.id,
    );
  }

  /// Charge le contexte d'une boutique. Deux lectures : le document
  /// boutique (pour le drapeau) et les caisses accessibles.
  ///
  /// En cas d'échec réseau, renvoie [vide] : mieux vaut laisser passer
  /// l'opération sans imputation que bloquer une caisse qui tourne. Le
  /// trou de trésorerie se corrige, une vente perdue non.
  static Future<CaisseContexte> charger(String boutiqueId) async {
    if (boutiqueId.isEmpty) return vide;
    final uc = UserController.to;
    // Module fermé à cette boutique : l'opération se déroule comme avant,
    // sans choix de caisse.
    if (!uc.caissesModuleActif) return vide;
    try {
      final boutique = await BoutiqueRepository().getById(boutiqueId);
      final caisses = await CaisseRepository().getActives(
        boutiqueId,
        gestionnaireId: uc.isAnyAdmin ? null : uc.user?.id,
      );
      return CaisseContexte(
        caisses: caisses,
        boutiqueEquipee: boutique?.hasCaissesActives ?? caisses.isNotEmpty,
      );
    } catch (_) {
      return vide;
    }
  }
}
