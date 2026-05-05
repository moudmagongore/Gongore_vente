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
  /// - crée les variantes ayant un id vide
  /// - met à jour celles qui existent
  /// - supprime celles qui ne sont plus dans la liste
  /// - met à jour `produit.quantiteStock` = somme des stocks des variantes
  /// - met à jour `produit.hasVariantes` selon le contenu fourni
  ///
  /// La transaction Firestore garantit qu'aucune mise à jour partielle
  /// n'est jamais visible, et que `quantiteStock` reste cohérent avec la
  /// somme des variantes.
  Future<void> syncVariantes({
    required String produitId,
    required List<VarianteModel> variantes,
  }) async {
    if (produitId.isEmpty) return;
    final colRef = _variantes(produitId);
    final produitRef = _col.doc(produitId);

    await _fs.db.runTransaction((tx) async {
      // 1. Lit les variantes existantes pour repérer celles à supprimer.
      final existing = await colRef.get();
      final existingIds = existing.docs.map((d) => d.id).toSet();
      final keepIds = variantes
          .where((v) => v.id.isNotEmpty)
          .map((v) => v.id)
          .toSet();

      // 2. Supprime les variantes absentes de la liste.
      for (final docId in existingIds.difference(keepIds)) {
        tx.delete(colRef.doc(docId));
      }

      // 3. Crée / met à jour.
      var totalStock = 0;
      for (final v in variantes) {
        totalStock += v.stock;
        final ref = v.id.isEmpty ? colRef.doc() : colRef.doc(v.id);
        final data = v.toMap();
        if (v.id.isEmpty) {
          data['createdAt'] = FieldValue.serverTimestamp();
          tx.set(ref, data);
        } else {
          tx.set(ref, data, SetOptions(merge: true));
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
