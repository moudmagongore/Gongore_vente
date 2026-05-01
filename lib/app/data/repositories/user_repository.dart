import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.users;

  Stream<List<UserModel>> watchAll() {
    return _col.orderBy('nom').snapshots().map(
          (snap) => snap.docs.map(UserModel.fromFirestore).toList(),
        );
  }

  Stream<List<UserModel>> watchByBoutique(String boutiqueId) {
    if (boutiqueId.isEmpty) {
      return Stream.value(<UserModel>[]);
    }
    return _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .orderBy('nom')
        .snapshots()
        .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
  }

  /// Stream scopé : super-admin voit tous, admin voit ses vendeurs, sinon vide.
  Stream<List<UserModel>> watchScoped({required String? scope}) {
    if (scope == null) return watchAll();
    if (scope.isEmpty) return Stream.value(<UserModel>[]);
    return watchByBoutique(scope);
  }

  Future<UserModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  /// Crée le document Firestore d'un user (l'UID Firebase est utilisé comme ID).
  Future<void> createDoc(UserModel user) {
    final data = user.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    return _col.doc(user.id).set(data);
  }

  Future<void> update(UserModel user) {
    return _col.doc(user.id).update(user.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime UNIQUEMENT le document Firestore.
  /// Le compte Firebase Auth reste — il faut le supprimer manuellement
  /// depuis la console Firebase si nécessaire (limitation sans Cloud Functions).
  Future<void> deleteDoc(String id) {
    return _col.doc(id).delete();
  }
}
