import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/produit_model.dart';
import '../models/variante_model.dart';

class ProduitRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.produits;
  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;
  CollectionReference<Map<String, dynamic>> _variantes(String produitId) =>
      _fs.variantesOf(produitId);

  /// Renvoie true si le produit a déjà été **vendu** au moins une fois.
  /// Source de vérité : la collection `ventes`. Chaque vente écrit son
  /// tableau dénormalisé `articleProduitIds`, ce qui rend cette query
  /// `array-contains` efficace et sans pagination.
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query sur les
  /// rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<bool> hasUsage(String produitId, {required String boutiqueId}) async {
    if (produitId.isEmpty || boutiqueId.isEmpty) return false;
    final v = await _ventes
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('articleProduitIds', arrayContains: produitId)
        .limit(1)
        .get();
    return v.docs.isNotEmpty;
  }

  /// Stream temps réel des produits, filtrable par boutique et catégorie.
  Stream<List<ProduitModel>> watchAll({
    String? boutiqueId,
    String? categorieId,
    bool onlyActive = false,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (boutiqueId != null && boutiqueId.isNotEmpty) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (categorieId != null && categorieId.isNotEmpty) {
      query = query.where('categorieId', isEqualTo: categorieId);
    }
    if (onlyActive) {
      query = query.where('active', isEqualTo: true);
    }
    query = query.orderBy('nom');
    return query.snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(ProduitModel.fromFirestore).toList(),
        );
  }

  Future<ProduitModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ProduitModel.fromFirestore(snap);
  }

  Future<String> create(ProduitModel produit) async {
    final data = produit.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(ProduitModel produit) {
    return _col.doc(produit.id).update(produit.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Suppression simple : à n'appeler qu'après [hasUsage] négatif (sinon
  /// vous perdez la traçabilité des ventes — bien que les lignes de vente
  /// stockent un snapshot du nom et du prix).
  Future<void> delete(String id) {
    if (id.isEmpty) return Future.value();
    return _col.doc(id).delete();
  }

  // ===========================================================================
  // VARIANTES (sous-collection produits/{produitId}/variantes/{varianteId})
  // ===========================================================================

  /// Stream temps réel des variantes d'un produit, triées par libellé.
  /// Si les rules Firestore refusent l'accès (permission-denied), on
  /// émet une liste vide plutôt que de laisser les `StreamBuilder` en
  /// chargement infini.
  Stream<List<VarianteModel>> watchVariantes(String produitId) {
    if (produitId.isEmpty) {
      return Stream.value(const <VarianteModel>[]);
    }
    return _variantes(produitId)
        .orderBy('libelle')
        .snapshots()
        .map(
          (snap) => snap.docs.map(VarianteModel.fromFirestore).toList(),
        )
        .permissionDeniedAsValue(const <VarianteModel>[]);
  }

  /// One-shot : lit toutes les variantes d'un produit.
  Future<List<VarianteModel>> listVariantes(String produitId) async {
    if (produitId.isEmpty) return const <VarianteModel>[];
    final snap = await _variantes(produitId).orderBy('libelle').get();
    return snap.docs.map(VarianteModel.fromFirestore).toList();
  }

  /// Synchronise la sous-collection variantes d'un produit avec la liste
  /// fournie, en une seule transaction atomique :
  /// - crée les variantes ayant un id vide (avec leur `stock` initial)
  /// - met à jour `libelle` / `couleur` des variantes existantes —
  ///   **mais jamais leur `stock`** (le stock courant est uniquement
  ///   modifiable via les modules Stock / Ventes / Approvisionnements,
  ///   qui créent une trace mouvement)
  /// - supprime celles qui ne sont plus dans la liste
  /// - met à jour `produit.quantiteStock` = somme (stocks existants
  ///   conservés + stocks initiaux des nouvelles variantes)
  /// - met à jour `produit.hasVariantes` selon le contenu fourni
  ///
  /// La transaction Firestore garantit qu'aucune mise à jour partielle
  /// n'est jamais visible, et que `quantiteStock` reste cohérent avec la
  /// somme des variantes lues à l'instant T (pas la valeur potentiellement
  /// stale du formulaire).
  Future<void> syncVariantes({
    required String produitId,
    required List<VarianteModel> variantes,
  }) async {
    if (produitId.isEmpty) return;
    final colRef = _variantes(produitId);
    final produitRef = _col.doc(produitId);

    await _fs.db.runTransaction((tx) async {
      // 1. Lit les variantes existantes pour : (a) repérer celles à
      // supprimer, (b) connaître leur `stock` actuel à conserver.
      final existing = await colRef.get();
      final existingStockById = <String, int>{
        for (final d in existing.docs)
          d.id: (d.data()['stock'] as num?)?.toInt() ?? 0,
      };
      final existingIds = existingStockById.keys.toSet();
      final keepIds = variantes
          .where((v) => v.id.isNotEmpty)
          .map((v) => v.id)
          .toSet();

      // 2. Supprime les variantes absentes de la liste.
      for (final docId in existingIds.difference(keepIds)) {
        tx.delete(colRef.doc(docId));
      }

      // 3. Crée les nouvelles, met à jour libelle/couleur des existantes.
      var totalStock = 0;
      for (final v in variantes) {
        if (v.id.isEmpty) {
          // Nouvelle variante : on persiste libelle + couleur + stock
          // initial. C'est le seul moment où le formulaire peut écrire
          // un stock — ensuite il est figé côté UI.
          final ref = colRef.doc();
          final data = v.toMap()
            ..['createdAt'] = FieldValue.serverTimestamp();
          tx.set(ref, data);
          totalStock += v.stock;
        } else {
          // Variante existante : on met à jour seulement libelle/couleur.
          // Le stock courant lu en transaction est préservé.
          final ref = colRef.doc(v.id);
          final patch = <String, dynamic>{
            'libelle': v.libelle,
            'couleur':
                (v.couleur == null || v.couleur!.isEmpty) ? null : v.couleur,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          tx.set(ref, patch, SetOptions(merge: true));
          totalStock += existingStockById[v.id] ?? 0;
        }
      }

      // 4. Met à jour le miroir sur le produit parent.
      tx.update(produitRef, {
        'hasVariantes': variantes.isNotEmpty,
        'quantiteStock': totalStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
