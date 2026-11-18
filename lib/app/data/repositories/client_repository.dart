import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/client_model.dart';
import 'solde_verrouille_exception.dart';

export 'solde_verrouille_exception.dart';

class ClientRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.clients;
  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;
  CollectionReference<Map<String, dynamic>> get _reglements =>
      _fs.reglements;

  /// Renvoie true si le client a au moins une vente ou un règlement liés.
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query sur les
  /// rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<bool> hasUsage(String clientId, {required String boutiqueId}) async {
    if (clientId.isEmpty || boutiqueId.isEmpty) return false;
    final v = await _ventes
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('clientId', isEqualTo: clientId)
        .limit(1)
        .get();
    if (v.docs.isNotEmpty) return true;
    final r = await _reglements
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('clientId', isEqualTo: clientId)
        .limit(1)
        .get();
    return r.docs.isNotEmpty;
  }

  /// Stream scopé selon le rôle :
  /// - `scope == null` → super-admin, tous les clients de toutes les boutiques
  /// - `scope` non vide → admin/vendeur, uniquement ceux de sa boutique
  /// - `scope` vide → liste vide
  Stream<List<ClientModel>> watchScoped(String? scope) {
    if (scope == null) {
      return _col.orderBy('nom').snapshots().ignorePermissionDenied().map(
            (snap) => snap.docs.map(ClientModel.fromFirestore).toList(),
          );
    }
    if (scope.isEmpty) return Stream.value(<ClientModel>[]);
    return _col
        .where('boutiqueId', isEqualTo: scope)
        .orderBy('nom')
        .snapshots().ignorePermissionDenied()
        .map((snap) => snap.docs.map(ClientModel.fromFirestore).toList());
  }

  Future<ClientModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ClientModel.fromFirestore(snap);
  }

  /// Stream live d'un client unique. À utiliser quand on veut que le solde
  /// (et autres champs) se mette à jour automatiquement après une vente,
  /// un règlement, ou toute écriture du backend.
  Stream<ClientModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col
        .doc(id)
        .snapshots().ignorePermissionDenied()
        .map((s) => s.exists ? ClientModel.fromFirestore(s) : null);
  }

  Future<String> create(ClientModel client) async {
    final data = client.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  /// `true` si le solde initial ne peut plus être modifié : le client a
  /// déjà au moins un vente ou un règlement.
  ///
  /// On interroge aussi l'historique, car le drapeau `hasOperations` peut
  /// manquer sur d'anciennes fiches. Dans ce cas on le répare au passage.
  Future<bool> soldeVerrouille(ClientModel client) async {
    if (client.hasOperations) return true;
    final usage = await hasUsage(client.id, boutiqueId: client.boutiqueId);
    if (usage) {
      try {
        await _col.doc(client.id).update({'hasOperations': true});
      } catch (_) {
        // Réparation au mieux : sans effet sur le verrouillage.
      }
    }
    return usage;
  }

  /// Met à jour la fiche. `solde` et `hasOperations` ne sont jamais
  /// écrits ici : ils sont tenus par les transactions des opérations, et
  /// les écrire depuis une copie locale écraserait leurs changements.
  ///
  /// Si [soldeInitial] est fourni, il remplace le solde, mais seulement
  /// tant qu'aucune opération n'existe ; sinon [SoldeVerrouilleException].
  Future<void> update(ClientModel client, {double? soldeInitial}) async {
    final data = client.toMap()
      ..remove('solde')
      ..remove('hasOperations');
    if (soldeInitial == null) {
      await _col.doc(client.id).update(data);
      return;
    }
    if (await hasUsage(client.id, boutiqueId: client.boutiqueId)) {
      throw const SoldeVerrouilleException();
    }
    final ref = _col.doc(client.id);
    await _fs.db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['hasOperations'] == true) {
        throw const SoldeVerrouilleException();
      }
      tx.update(ref, {...data, 'solde': soldeInitial});
    });
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }

  /// Ajuste le solde du client de [delta] de manière atomique.
  /// `delta > 0` augmente la dette (vente à crédit), `delta < 0` la diminue
  /// (remboursement). Crée le doc si inexistant n'est pas géré ici (le client
  /// doit déjà exister dans la base).
  Future<void> adjustSolde(String clientId, double delta) {
    return _col.doc(clientId).update({
      'solde': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
