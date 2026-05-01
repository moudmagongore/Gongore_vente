import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/produit_model.dart';

class ProduitRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.produits;

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
    return query.snapshots().map(
          (snap) => snap.docs.map(ProduitModel.fromFirestore).toList(),
        );
  }

  Future<ProduitModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ProduitModel.fromFirestore(snap);
  }

  Future<ProduitModel?> findByCodeBarre(String codeBarre, String boutiqueId) async {
    final snap = await _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('codeBarre', isEqualTo: codeBarre)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ProduitModel.fromFirestore(snap.docs.first);
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

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
