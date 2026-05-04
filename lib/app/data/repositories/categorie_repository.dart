import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/categorie_model.dart';

class CategorieRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.categories;
  CollectionReference<Map<String, dynamic>> get _produits => _fs.produits;

  /// Renvoie true si au moins un produit utilise cette catégorie.
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query sur les
  /// rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<bool> hasUsage(String categorieId, {required String boutiqueId}) async {
    if (categorieId.isEmpty || boutiqueId.isEmpty) return false;
    final p = await _produits
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('categorieId', isEqualTo: categorieId)
        .limit(1)
        .get();
    return p.docs.isNotEmpty;
  }

  Stream<List<CategorieModel>> watchAll({String? boutiqueId}) {
    Query<Map<String, dynamic>> query = _col;
    if (boutiqueId != null && boutiqueId.isNotEmpty) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    return query.orderBy('nom').snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(CategorieModel.fromFirestore).toList(),
        );
  }

  Future<List<CategorieModel>> fetchAll({String? boutiqueId}) async {
    Query<Map<String, dynamic>> query = _col;
    if (boutiqueId != null && boutiqueId.isNotEmpty) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    final snap = await query.orderBy('nom').get();
    return snap.docs.map(CategorieModel.fromFirestore).toList();
  }

  Future<CategorieModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return CategorieModel.fromFirestore(snap);
  }

  Future<String> create(CategorieModel cat) async {
    final data = cat.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(CategorieModel cat) {
    return _col.doc(cat.id).update(cat.toMap());
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
