import 'package:get/get.dart';

import '../../../../core/services/user_controller.dart';
import '../../../../data/models/boutique_model.dart';
import '../../../../data/models/produit_model.dart';
import '../../../../data/models/stock_model.dart';
import '../../../../data/repositories/boutique_repository.dart';
import '../../../../data/repositories/produit_repository.dart';
import '../../../../data/repositories/stock_repository.dart';

/// Ligne d'affichage combinant produit + sa quantité dans la boutique.
class StockLine {
  final ProduitModel produit;
  final int quantite;
  final DateTime? derniereModif;

  StockLine({
    required this.produit,
    required this.quantite,
    this.derniereModif,
  });

  bool get isLow => quantite <= produit.seuilAlerte;
  bool get isOut => quantite <= 0;
}

class StockController extends GetxController {
  final ProduitRepository _produitRepo = ProduitRepository();
  final BoutiqueRepository _boutiqueRepo = BoutiqueRepository();
  final StockRepository _stockRepo = StockRepository();

  final RxList<BoutiqueModel> boutiques = <BoutiqueModel>[].obs;
  final RxnString currentBoutiqueId = RxnString();

  final RxList<ProduitModel> _produits = <ProduitModel>[].obs;
  final RxList<StockModel> _stocks = <StockModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString search = ''.obs;
  final RxBool onlyLow = false.obs;

  Worker? _boutiqueWorker;

  bool get isSuperAdmin => UserController.to.isSuperAdmin;

  @override
  void onInit() {
    super.onInit();
    final scope = UserController.to.scopeBoutiqueId;

    boutiques.bindStream(
      _boutiqueRepo.watchScoped(scope: scope, actives: true),
    );

    // ⚠️ Listener enregistré AVANT toute affectation à currentBoutiqueId,
    // sinon l'init synchrone admin/vendeur ne déclenche pas le bind.
    ever(currentBoutiqueId, _onBoutiqueChanged);

    if (scope != null && scope.isNotEmpty) {
      // Admin de boutique : verrouillé sur sa boutique
      currentBoutiqueId.value = scope;
    } else {
      // Super-admin : sélectionne la 1ère boutique dès qu'elles arrivent
      _boutiqueWorker = ever<List<BoutiqueModel>>(boutiques, (list) {
        if (currentBoutiqueId.value == null && list.isNotEmpty) {
          currentBoutiqueId.value = list.first.id;
        }
      });
    }
  }

  void _onBoutiqueChanged(String? boutiqueId) {
    if (boutiqueId == null) return;
    isLoading.value = true;
    _produits.bindStream(_produitRepo.watchAll(boutiqueId: boutiqueId));
    _stocks.bindStream(_stockRepo.watchByBoutique(boutiqueId));
    debounce(_produits, (_) => isLoading.value = false,
        time: const Duration(milliseconds: 200));
  }

  @override
  void onClose() {
    _boutiqueWorker?.dispose();
    super.onClose();
  }

  void selectBoutique(String? id) => currentBoutiqueId.value = id;

  String boutiqueNom(String id) =>
      boutiques.firstWhereOrNull((b) => b.id == id)?.nom ?? '—';

  String deviseCourante() {
    final b = boutiques.firstWhereOrNull((x) => x.id == currentBoutiqueId.value);
    return b?.devise ?? 'GNF';
  }

  /// Liste fusionnée produits + stocks pour la boutique courante.
  List<StockLine> get lines {
    if (currentBoutiqueId.value == null) return [];
    final stocksMap = {for (final s in _stocks) s.produitId: s};
    final out = _produits.map((p) {
      final s = stocksMap[p.id];
      return StockLine(
        produit: p,
        quantite: s?.quantite ?? 0,
        derniereModif: s?.derniereModif,
      );
    }).toList();

    final q = search.value.trim().toLowerCase();
    return out.where((l) {
      if (onlyLow.value && !l.isLow) return false;
      if (q.isEmpty) return true;
      return l.produit.nom.toLowerCase().contains(q) ||
          (l.produit.codeBarre?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        // En haut: ruptures, puis stocks faibles, puis le reste
        if (a.isOut != b.isOut) return a.isOut ? -1 : 1;
        if (a.isLow != b.isLow) return a.isLow ? -1 : 1;
        return a.produit.nom.compareTo(b.produit.nom);
      });
  }

  int get nbLow => lines.where((l) => l.isLow && !l.isOut).length;
  int get nbOut => lines.where((l) => l.isOut).length;
}
