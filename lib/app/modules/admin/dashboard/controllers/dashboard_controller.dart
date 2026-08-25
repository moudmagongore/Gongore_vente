import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/depense_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/vente_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/depense_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/vente_repository.dart';

class TopProduit {
  final String produitId;
  final String nom;
  final int quantite;
  final double ca;

  TopProduit({
    required this.produitId,
    required this.nom,
    required this.quantite,
    required this.ca,
  });
}

class DayPoint {
  final DateTime date;
  final double total;
  DayPoint(this.date, this.total);
}

class DashboardController extends GetxController {
  final VenteRepository _venteRepo = VenteRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final UserRepository _userRepo = UserRepository();
  final ProduitRepository _produitRepo = ProduitRepository();
  final DepenseRepository _depenseRepo = DepenseRepository();

  // ====== Données live ======
  /// Toutes les ventes du mois courant (limit 500 par sécurité)
  final RxList<VenteModel> _ventesMois = <VenteModel>[].obs;
  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<ProduitModel> produits = <ProduitModel>[].obs;

  /// Dépenses du mois courant (même fenêtre que `_ventesMois`).
  final RxList<DepenseModel> _depensesMois = <DepenseModel>[].obs;

  final RxBool isLoading = true.obs;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final scope = UserController.to.scopeBoutiqueId;

    _ventesMois.bindStream(_venteRepo.watchAll(
      after: startOfMonth,
      limit: 500,
      boutiqueId: scope,
    ));
    boutiques.bindStream(_boutiqueRepo.watchScoped(scope: scope));
    users.bindStream(_userRepo.watchScoped(scope: scope));
    produits.bindStream(_produitRepo.watchAll(boutiqueId: scope));
    _depensesMois.bindStream(_depenseRepo.watchAll(
      boutiqueId: scope,
      after: startOfMonth,
    ));
    debounce(_ventesMois, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 250));
  }

  // ====== Helpers ======
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<VenteModel> get _validees =>
      _ventesMois.where((v) => v.statut == VenteStatut.validee).toList();

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String userNom(String id) =>
      users.firstWhereOrNull((u) => u.id == id)?.nom ?? '—';

  // ====== KPIs Jour ======
  List<VenteModel> get _ventesJour {
    final today = DateTime.now();
    return _validees.where((v) => _sameDay(v.date, today)).toList();
  }

  double get caJour => _ventesJour.fold(0.0, (acc, v) => acc + v.total);
  int get nbVentesJour => _ventesJour.length;
  int get nbArticlesJour =>
      _ventesJour.fold(0, (acc, v) => acc + v.nbArticles);
  int get nbAnnulationsJour {
    final today = DateTime.now();
    return _ventesMois
        .where((v) =>
            v.statut == VenteStatut.annulee && _sameDay(v.date, today))
        .length;
  }

  // ====== KPIs Mois ======
  double get caMois => _validees.fold(0.0, (acc, v) => acc + v.total);
  int get nbVentesMois => _validees.length;

  // ====== Estimation bénéfice (basée sur prixAchat des produits) ======
  double get beneficeJour {
    double benefice = 0;
    final prodMap = {for (final p in produits) p.id: p};
    for (final v in _ventesJour) {
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

  double get beneficeMois {
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

  // ====== Dépenses ======
  List<DepenseModel> get _depensesJour {
    final today = DateTime.now();
    return _depensesMois.where((d) => _sameDay(d.date, today)).toList();
  }

  double get depensesJour =>
      _depensesJour.fold(0.0, (acc, d) => acc + d.montant);

  double get depensesMois =>
      _depensesMois.fold(0.0, (acc, d) => acc + d.montant);

  int get nbDepensesJour => _depensesJour.length;
  int get nbDepensesMois => _depensesMois.length;

  /// Résultat net = bénéfice commercial estimé - dépenses déclarées.
  double get resultatNetJour => beneficeJour - depensesJour;
  double get resultatNetMois => beneficeMois - depensesMois;

  /// Top natures de dépense du mois (les 3 postes les plus lourds).
  List<({String nom, double total})> get topDepensesMois {
    final byNature = <String, ({String nom, double total})>{};
    for (final d in _depensesMois) {
      final cur = byNature[d.natureId] ?? (nom: d.natureNom, total: 0.0);
      byNature[d.natureId] = (nom: cur.nom, total: cur.total + d.montant);
    }
    final list = byNature.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list.take(3).toList();
  }

  // ====== Série 7 derniers jours ======
  List<DayPoint> get serie7Jours {
    final now = DateTime.now();
    final List<DayPoint> out = [];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final total = _validees
          .where((v) => _sameDay(v.date, day))
          .fold<double>(0, (acc, v) => acc + v.total);
      out.add(DayPoint(day, total));
    }
    return out;
  }

  double get max7Jours {
    final m = serie7Jours.fold<double>(0, (acc, p) => p.total > acc ? p.total : acc);
    return m == 0 ? 1 : m;
  }

  // ====== Top produits vendus (mois) ======
  List<TopProduit> get topProduits {
    final byProduit = <String, TopProduit>{};
    for (final v in _validees) {
      for (final a in v.articles) {
        final existing = byProduit[a.produitId];
        if (existing == null) {
          byProduit[a.produitId] = TopProduit(
            produitId: a.produitId,
            nom: a.nom,
            quantite: a.quantite,
            ca: a.sousTotal,
          );
        } else {
          byProduit[a.produitId] = TopProduit(
            produitId: a.produitId,
            nom: existing.nom,
            quantite: existing.quantite + a.quantite,
            ca: existing.ca + a.sousTotal,
          );
        }
      }
    }
    final list = byProduit.values.toList()
      ..sort((a, b) => b.quantite.compareTo(a.quantite));
    return list.take(5).toList();
  }

  int get topProduitsMaxQuantite =>
      topProduits.isEmpty ? 1 : topProduits.first.quantite;

  // ====== Répartition par mode de paiement ======
  Map<ModePaiement, double> get caParModePaiement {
    final out = <ModePaiement, double>{};
    for (final v in _validees) {
      out[v.modePaiement] = (out[v.modePaiement] ?? 0) + v.total;
    }
    return out;
  }

  // ====== Stats par boutique ======
  List<({BoutiqueModel boutique, double ca, int nb})> get caParBoutique {
    final out = <String, ({double ca, int nb})>{};
    for (final v in _validees) {
      final cur = out[v.boutiqueId] ?? (ca: 0.0, nb: 0);
      out[v.boutiqueId] = (ca: cur.ca + v.total, nb: cur.nb + 1);
    }
    final result = out.entries
        .map((e) {
          final b = boutiques.firstWhereOrNull((x) => x.id == e.key);
          if (b == null) return null;
          return (boutique: b, ca: e.value.ca, nb: e.value.nb);
        })
        .whereType<({BoutiqueModel boutique, double ca, int nb})>()
        .toList()
      ..sort((a, b) => b.ca.compareTo(a.ca));
    return result;
  }

  // ====== Top vendeurs ======
  List<({UserModel user, double ca, int nb})> get topVendeurs {
    final out = <String, ({double ca, int nb})>{};
    for (final v in _validees) {
      final cur = out[v.vendeurId] ?? (ca: 0.0, nb: 0);
      out[v.vendeurId] = (ca: cur.ca + v.total, nb: cur.nb + 1);
    }
    final result = out.entries
        .map((e) {
          final u = users.firstWhereOrNull((x) => x.id == e.key);
          if (u == null) return null;
          return (user: u, ca: e.value.ca, nb: e.value.nb);
        })
        .whereType<({UserModel user, double ca, int nb})>()
        .toList()
      ..sort((a, b) => b.ca.compareTo(a.ca));
    return result.take(5).toList();
  }
}
