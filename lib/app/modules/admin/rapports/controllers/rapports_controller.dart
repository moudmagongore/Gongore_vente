import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

enum PeriodePreset { jour, semaine, mois, trimestre, personnalise }

class RapportsController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();
  final ProduitRepository _produitRepo = ProduitRepository();

  // ====== Filtres ======
  final Rx<PeriodePreset> preset = PeriodePreset.mois.obs;
  final Rx<DateTime> dateDebut = DateTime.now().obs;
  final Rx<DateTime> dateFin = DateTime.now().obs;
  final RxnString boutiqueId = RxnString();
  final RxnString vendeurId = RxnString();

  // ====== Données ======
  final RxList<VenteModel> ventes = <VenteModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;

  final RxBool isLoading = true.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;
  bool get isAnyAdmin => UserController.to.isAnyAdmin;
  bool get isVendeur => UserController.to.isVendeur;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));
    produits.bindStream(_produitRepo.watchAll(boutiqueId: scope));

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
    debounce(ventes, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 250));
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
  double get caMoyenne => nbVentes == 0 ? 0 : caTotal / nbVentes;
  int get nbArticlesVendus =>
      _validees.fold(0, (acc, v) => acc + v.nbArticles);

  // ====== Bénéfice ======
  double get beneficeTotal {
    double benefice = 0;
    final prodMap = {for (final p in produits) p.id: p};
    for (final v in _validees) {
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
  Map<ModePaiement, double> get caParModePaiement {
    final out = <ModePaiement, double>{};
    for (final v in _validees) {
      out[v.modePaiement] = (out[v.modePaiement] ?? 0) + v.total;
    }
    return out;
  }

}
