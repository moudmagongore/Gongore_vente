import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.users;

  Stream<List<UserModel>> watchAll() {
    return _col.orderBy('nom').snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(UserModel.fromFirestore).toList(),
        );
  }

  /// Utilisateurs d'une boutique : ceux dont c'est la boutique principale,
  /// plus les admins qui l'ont en boutique supplémentaire (sans quoi un
  /// admin multi-boutique serait invisible dans les listes de ses autres
  /// boutiques). Triés par nom.
  Stream<List<UserModel>> watchByBoutique(String boutiqueId) {
    if (boutiqueId.isEmpty) {
      return Stream.value(<UserModel>[]);
    }
    final principaux = _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .orderBy('nom')
        .snapshots()
        .ignorePermissionDenied();
    // Pas d'orderBy ici : avec array-contains il exigerait un index
    // composite. Le tri final est fait en mémoire.
    final supplementaires = _col
        .where('additionalBoutiqueIds', arrayContains: boutiqueId)
        .snapshots()
        .ignorePermissionDenied();

    List<UserModel> p = const [];
    List<UserModel> s = const [];
    late final StreamController<List<UserModel>> ctrl;
    final subs = <StreamSubscription<dynamic>>[];

    void emettre() {
      final parId = <String, UserModel>{
        for (final u in p) u.id: u,
        for (final u in s) u.id: u,
      };
      ctrl.add(parId.values.toList()
        ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase())));
    }

    ctrl = StreamController<List<UserModel>>(
      onListen: () {
        // La liste principale s'affiche dès son arrivée, sans attendre
        // la seconde (qui peut être vide, ou refusée par d'anciennes rules).
        subs.add(principaux.listen((snap) {
          p = snap.docs.map(UserModel.fromFirestore).toList();
          emettre();
        }, onError: ctrl.addError));
        subs.add(supplementaires.listen((snap) {
          s = snap.docs.map(UserModel.fromFirestore).toList();
          emettre();
        }, onError: ctrl.addError));
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return ctrl.stream;
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
