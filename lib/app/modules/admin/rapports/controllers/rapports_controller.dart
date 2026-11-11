import 'package:get/get.dart';

import '../../../../core/services/catalogue_cache_service.dart';
import '../../../../core/services/user_controller.dart';
import '../../../../data/models/mouvement_caisse_model.dart';
import '../../../../data/models/approvisionnement_model.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/depense_model.dart';
import '../../../../data/models/fournisseur_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/caisse_repository.dart';
import '../../../../data/repositories/approvisionnement_repository.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/depense_repository.dart';
import '../../../../data/repositories/fournisseur_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

enum PeriodePreset { jour, semaine, mois, trimestre, personnalise }

/// Entrées, sorties et variation d'une caisse sur la période (RG-32).
class SyntheseCaisse {
  final String caisseId;
  final String nom;
  final double entrees;
  final double sorties;

  const SyntheseCaisse({
    required this.caisseId,
    required this.nom,
    required this.entrees,
    required this.sorties,
  });

  double get variation => entrees - sorties;
}

class RapportsController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();
  final ApprovisionnementRepository _approRepo =
      ApprovisionnementRepository();
  final FournisseurRepository _fournRepo = FournisseurRepository();
  final DepenseRepository _depenseRepo = DepenseRepository();

  // ====== Filtres ======
  final Rx<PeriodePreset> preset = PeriodePreset.mois.obs;
  final Rx<DateTime> dateDebut = DateTime.now().obs;
  final Rx<DateTime> dateFin = DateTime.now().obs;
  final RxnString boutiqueId = RxnString();
  final RxnString vendeurId = RxnString();

  // ====== Données ======
  final RxList<VenteModel> ventes = <VenteModel>[].obs;
  final RxList<ApprovisionnementModel> appros =
      <ApprovisionnementModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;
  final RxList<FournisseurModel> fournisseurs = <FournisseurModel>[].obs;
  final RxList<DepenseModel> depenses = <DepenseModel>[].obs;

  /// Synthèse de trésorerie par caisse sur la période (RG-32).
  ///
  /// Chargée par une requête ponctuelle et non par un stream : elle
  /// balaie toutes les caisses de la boutique, ce qui n'est permis qu'à
  /// l'admin — la règle de lecture d'un gestionnaire exige un `get()` par
  /// caisse et ferait sauter le quota sur une requête multi-caisses.
  final RxList<SyntheseCaisse> syntheseCaisses = <SyntheseCaisse>[].obs;

  final RxBool isLoading = true.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;
  bool get isVendeur => UserController.to.isVendeur;

  /// Marges, bénéfices et marge brute : réservés à l'admin (RG-8).
  /// Le gestionnaire garde tous les chiffres de vente et d'achat.
  bool get canSeeMarges => UserController.to.canSeeMarges;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));
    produits.bindStream(CatalogueCacheService.to.watchProduits(scope));
    fournisseurs.bindStream(_fournRepo.watchScoped(scope));

    // Pour admin de boutique : verrouiller le filtre sur sa boutique
    if (scope != null) {
      boutiqueId.value = scope;
    }
    // Pour le vendeur : verrouiller AUSSI le filtre sur son propre user id,
    // afin qu'il ne voit que SES ventes dans le rapport.
    if (isVendeur) {
      vendeurId.value = UserController.to.user?.id;
    }

    _applyPreset(PeriodePreset.mois);

    everAll([preset, dateDebut, dateFin, boutiqueId, vendeurId], (_) => _bind());

    // Premier chargement : everAll ne fire pas sur les valeurs initiales,
    // il faut donc appeler _bind() explicitement au démarrage.
    _bind();
  }

  void _applyPreset(PeriodePreset p) {
    preset.value = p;
    final now = DateTime.now();
    switch (p) {
      case PeriodePreset.jour:
        dateDebut.value = DateTime(now.year, now.month, now.day);
        dateFin.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PeriodePreset.semaine:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        dateDebut.value = DateTime(monday.year, monday.month, monday.day);
        dateFin.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PeriodePreset.mois:
        dateDebut.value = DateTime(now.year, now.month, 1);
        dateFin.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PeriodePreset.trimestre:
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        dateDebut.value = DateTime(now.year, q, 1);
        dateFin.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case PeriodePreset.personnalise:
        // ne rien faire — l'utilisateur définit dateDebut/dateFin manuellement
        break;
    }
  }

  void selectPreset(PeriodePreset p) => _applyPreset(p);

  void setDateDebut(DateTime d) {
    preset.value = PeriodePreset.personnalise;
    dateDebut.value = DateTime(d.year, d.month, d.day);
  }

  void setDateFin(DateTime d) {
    preset.value = PeriodePreset.personnalise;
    dateFin.value = DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  void _bind() {
    isLoading.value = true;
    ventes.bindStream(_venteRepo.watchAll(
      boutiqueId: boutiqueId.value,
      vendeurId: vendeurId.value,
      after: dateDebut.value,
      before: dateFin.value.add(const Duration(seconds: 1)),
      limit: 1000,
    ));
    appros.bindStream(_approRepo.watchAll(
      boutiqueId: boutiqueId.value,
      // Pas de filtre par utilisateur sur les appros : la gestion d'achat
      // n'est pas individuelle au vendeur (un appro réceptionné par X
      // bénéficie à toute la boutique).
      after: dateDebut.value,
      before: dateFin.value.add(const Duration(seconds: 1)),
      limit: 1000,
    ));
    depenses.bindStream(_depenseRepo.watchAll(
      boutiqueId: boutiqueId.value,
      // Comme pour les appros : pas de filtre par utilisateur. Une dépense
      // engage la boutique entière, pas le gestionnaire qui l'a saisie.
      after: dateDebut.value,
      before: dateFin.value.add(const Duration(seconds: 1)),
      limit: 1000,
    ));
    _chargerSyntheseCaisses();
    debounce(ventes, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 250));
  }

  /// Agrège les mouvements de caisse de la période par caisse.
  ///
  /// Les mouvements d'annulation ne sont pas écartés : ils sont de vraies
  /// entrées et sorties, et les retirer ferait mentir la variation.
  Future<void> _chargerSyntheseCaisses() async {
    final bid = boutiqueId.value;
    // Module fermé à la boutique : la section disparaît du rapport, même
    // s'il reste des mouvements en base.
    if (bid == null ||
        bid.isEmpty ||
        !UserController.to.isAnyAdmin ||
        !UserController.to.caissesModuleActif) {
      syntheseCaisses.clear();
      return;
    }
    try {
      final mouvements = await CaisseRepository().mouvementsDeLaBoutique(
        boutiqueId: bid,
        after: dateDebut.value,
        before: dateFin.value.add(const Duration(seconds: 1)),
      );
      final parCaisse = <String, ({String nom, double entrees, double sorties})>{};
      for (final m in mouvements) {
        final cur = parCaisse[m.caisseId] ??
            (nom: m.caisseNom, entrees: 0.0, sorties: 0.0);
        parCaisse[m.caisseId] = (
          nom: cur.nom,
          entrees: cur.entrees +
              (m.sens == SensMouvement.entree ? m.montant : 0),
          sorties: cur.sorties +
              (m.sens == SensMouvement.sortie ? m.montant : 0),
        );
      }
      final list = parCaisse.entries
          .map((e) => SyntheseCaisse(
                caisseId: e.key,
                nom: e.value.nom,
                entrees: e.value.entrees,
                sorties: e.value.sorties,
              ))
          .toList()
        ..sort((a, b) => b.variation.abs().compareTo(a.variation.abs()));
      syntheseCaisses.assignAll(list);
    } catch (_) {
      // Une synthèse de trésorerie indisponible ne doit pas priver
      // l'utilisateur du reste du rapport.
      syntheseCaisses.clear();
    }
  }

  // ====== Helpers ======
  List<VenteModel> get _validees =>
      ventes.where((v) => v.statut == VenteStatut.validee).toList();

  List<VenteModel> get _annulees =>
      ventes.where((v) => v.statut == VenteStatut.annulee).toList();

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  // ====== Stats ventes ======
  int get nbVentes => _validees.length;
  int get nbAnnulees => _annulees.length;
  double get caTotal => _validees.fold(0.0, (acc, v) => acc + v.total);
  double get caAnnule => _annulees.fold(0.0, (acc, v) => acc + v.total);
  int get nbArticlesVendus =>
      _validees.fold(0, (acc, v) => acc + v.nbArticles);

  // ====== Stats achats (appros) ======
  List<ApprovisionnementModel> get _approsValidees =>
      appros.where((a) => a.statut == ApproStatut.validee).toList();

  int get nbAppros => _approsValidees.length;

  double get totalAchats =>
      _approsValidees.fold(0.0, (acc, a) => acc + a.total);

  /// Reste à payer (dette en cours) sur les appros de la période filtrée.
  double get detteFournisseurPeriode =>
      _approsValidees.fold(0.0, (acc, a) => acc + a.resteAPayer);

  /// Dette fournisseur TOTALE — somme des soldes positifs (toutes
  /// périodes, scopée à la boutique du filtre si défini).
  double get detteFournisseurGlobale {
    return fournisseurs
        .where((f) =>
            boutiqueId.value == null || f.boutiqueId == boutiqueId.value)
        .fold(0.0, (acc, f) => acc + (f.solde > 0 ? f.solde : 0));
  }

  /// Marge brute = CA ventes - coût d'achat des produits achetés sur la
  /// période. Indicateur grossier (les unités vendues peuvent provenir
  /// d'achats antérieurs à la période). Pour un calcul exact il faudrait
  /// snapshooter le PA dans VenteArticle au moment de la vente.
  double get margePeriode => caTotal - totalAchats;

  String fournisseurNom(String id) =>
      fournisseurs.firstWhereOrNull((f) => f.id == id)?.nom ?? '—';

  // ====== Top fournisseurs (par CA acheté sur la période) ======
  List<({String fournisseurId, String nom, int nbAppros, double total})>
      get topFournisseurs {
    final byF = <String, ({String nom, int nbAppros, double total})>{};
    for (final a in _approsValidees) {
      final nom = fournisseurNom(a.fournisseurId);
      final cur = byF[a.fournisseurId] ??
          (nom: nom, nbAppros: 0, total: 0.0);
      byF[a.fournisseurId] = (
        nom: nom,
        nbAppros: cur.nbAppros + 1,
        total: cur.total + a.total,
      );
    }
    final list = byF.entries
        .map((e) => (
              fournisseurId: e.key,
              nom: e.value.nom,
              nbAppros: e.value.nbAppros,
              total: e.value.total,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  // ====== Dépenses ======
  int get nbDepenses => depenses.length;

  double get totalDepenses =>
      depenses.fold(0.0, (acc, d) => acc + d.montant);

  /// Résultat net estimé = bénéfice sur ventes - dépenses de la période.
  /// C'est le seul indicateur qui tienne compte des charges de la boutique
  /// (loyer, salaires, transport...), le bénéfice seul n'étant qu'une marge
  /// commerciale.
  double get resultatNet => beneficeTotal - totalDepenses;

  /// Répartition des dépenses par nature, de la plus lourde à la plus
  /// légère. Le regroupement se fait sur `natureId` mais affiche le libellé
  /// dénormalisé, pour que les natures supprimées restent lisibles.
  List<({String natureId, String nom, int nb, double total})>
      get depensesParNature {
    final byNature = <String, ({String nom, int nb, double total})>{};
    for (final d in depenses) {
      final cur = byNature[d.natureId] ?? (nom: d.natureNom, nb: 0, total: 0.0);
      byNature[d.natureId] = (
        nom: cur.nom,
        nb: cur.nb + 1,
        total: cur.total + d.montant,
      );
    }
    final list = byNature.entries
        .map((e) => (
              natureId: e.key,
              nom: e.value.nom,
              nb: e.value.nb,
              total: e.value.total,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  // ====== Bénéfice ======
  double get beneficeTotal {
    double benefice = 0;
    final prodMap = {for (final p in produits) p.id: p};
    for (final v in _validees) {
      // Marge figée à la validation : c'est la valeur de référence, elle
      // ne bouge plus quand un appro change le CMUP (ONBOARDING.md §6).
      if (v.aMargeFigee) {
        benefice += v.margeTotale!;
        continue;
      }
      // Repli pour les ventes antérieures à la reprise
      // (`scripts/backfill_marges_ventes.js`) : ancien calcul au prix du
      // jour. À retirer une fois la reprise appliquée partout.
      for (final a in v.articles) {
        final p = prodMap[a.produitId];
        if (p != null) {
          benefice += (a.prixUnitaire - p.prixAchat) * a.quantite - a.remise;
        }
      }
      benefice -= v.remise;
    }
    return benefice;
  }

  // ====== Top produits ======
  List<({String produitId, String nom, int qte, double ca})> get topProduits {
    final byProduit = <String, ({String nom, int qte, double ca})>{};
    for (final v in _validees) {
      for (final a in v.articles) {
        final cur = byProduit[a.produitId] ?? (nom: a.nom, qte: 0, ca: 0.0);
        byProduit[a.produitId] = (
          nom: cur.nom,
          qte: cur.qte + a.quantite,
          ca: cur.ca + a.sousTotal,
        );
      }
    }
    final list = byProduit.entries
        .map((e) => (
              produitId: e.key,
              nom: e.value.nom,
              qte: e.value.qte,
              ca: e.value.ca,
            ))
        .toList()
      ..sort((a, b) => b.qte.compareTo(a.qte));
    return list;
  }

  // ====== Par mode paiement ======
  /// Ventilation du CA par canal d'encaissement.
  ///
  /// La clé est un **libellé** et non l'enum `ModePaiement` : une même
  /// période contient des ventes encaissées sur des caisses (« Tiroir
  /// espèces ») et des ventes antérieures qui ne portent qu'un mode
  /// (« Espèces »). Les deux doivent apparaître côte à côte le temps que
  /// l'historique se renouvelle.
  ///
  /// Une vente encaissée sur plusieurs caisses compte une fois par caisse,
  /// au prorata du montant encaissé sur chacune : sans ça, un paiement
  /// mixte faussserait le total de la ventilation.
  Map<String, double> get caParCanalPaiement {
    final out = <String, double>{};
    for (final v in _validees) {
      if (v.passeParCaisse) {
        for (final p in v.paiements) {
          out[p.caisseNom] = (out[p.caisseNom] ?? 0) + p.montant;
        }
        continue;
      }
      final cle = v.modePaiement?.label ?? '—';
      out[cle] = (out[cle] ?? 0) + v.total;
    }
    return out;
  }

}
