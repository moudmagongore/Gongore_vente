import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/approvisionnement_model.dart';
import '../models/reglement_fournisseur_model.dart';

class ReglementFournisseurRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.reglementsFournisseurs;
  CollectionReference<Map<String, dynamic>> get _fournisseurs =>
      _fs.fournisseurs;
  CollectionReference<Map<String, dynamic>> get _approvisionnements =>
      _fs.approvisionnements;

  /// Stream des règlements d'un fournisseur donné, du plus récent au
  /// plus ancien. Le filtre `boutiqueId` est requis pour aligner sur
  /// les rules Firestore.
  Stream<List<ReglementFournisseurModel>> watchByFournisseur(
    String fournisseurId, {
    required String boutiqueId,
    int limit = 100,
  }) {
    if (fournisseurId.isEmpty || boutiqueId.isEmpty) {
      return Stream.value(<ReglementFournisseurModel>[]);
    }
    return _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('fournisseurId', isEqualTo: fournisseurId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots().ignorePermissionDenied()
        .map((s) =>
            s.docs.map(ReglementFournisseurModel.fromFirestore).toList());
  }

  /// Stream des règlements scopés à une boutique (rapports / liste).
  Stream<List<ReglementFournisseurModel>> watchByBoutique(
    String boutiqueId, {
    DateTime? after,
    int limit = 200,
  }) {
    if (boutiqueId.isEmpty) {
      return Stream.value(<ReglementFournisseurModel>[]);
    }
    Query<Map<String, dynamic>> q =
        _col.where('boutiqueId', isEqualTo: boutiqueId);
    if (after != null) {
      q = q.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    q = q.orderBy('date', descending: true).limit(limit);
    return q.snapshots().ignorePermissionDenied().map(
          (s) => s.docs.map(ReglementFournisseurModel.fromFirestore).toList(),
        );
  }

  /// Crée un règlement fournisseur et l'**impute en FIFO** sur les appros
  /// du fournisseur en crédit (les plus anciens d'abord). Met à jour
  /// `montantPaye` de chaque appro touchée, persiste les imputations,
  /// et décrémente le solde fournisseur. Si le montant dépasse les
  /// dettes, le surplus reste en avance fournisseur (solde négatif).
  /// Tout est atomique.
  Future<ReglementFournisseurModel> create(
    ReglementFournisseurModel reg,
  ) async {
    if (reg.montant <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0');
    }
    if (reg.fournisseurId.isEmpty) {
      throw ArgumentError('fournisseurId requis');
    }

    // Pré-fetch hors transaction (Firestore interdit les queries dans
    // une tx). On ré-lit chaque doc dans la tx pour avoir l'état frais.
    final approsQuery = await _approvisionnements
        .where('boutiqueId', isEqualTo: reg.boutiqueId)
        .where('fournisseurId', isEqualTo: reg.fournisseurId)
        .where('statut', isEqualTo: ApproStatut.validee.name)
        .orderBy('date', descending: false) // FIFO = anciens d'abord
        .get();
    final candidateRefs =
        approsQuery.docs.map((d) => d.reference).toList();

    return _fs.db.runTransaction<ReglementFournisseurModel>((tx) async {
      final fournRef = _fournisseurs.doc(reg.fournisseurId);
      final fournSnap = await tx.get(fournRef);
      if (!fournSnap.exists) {
        throw Exception('Fournisseur introuvable');
      }

      final approSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in candidateRefs) {
        approSnaps.add(await tx.get(ref));
      }

      // Allocation FIFO
      double remaining = reg.montant;
      final imputations = <ImputationFournisseur>[];

      for (final snap in approSnaps) {
        if (remaining <= 0) break;
        if (!snap.exists) continue;
        final appro = ApprovisionnementModel.fromFirestore(snap);
        if (appro.statut != ApproStatut.validee) continue;
        if (appro.resteAPayer <= 0) continue;

        final allocate = appro.resteAPayer < remaining
            ? appro.resteAPayer
            : remaining;
        remaining -= allocate;

        tx.update(snap.reference, {
          'montantPaye': appro.montantPaye + allocate,
        });
        imputations.add(ImputationFournisseur(
          approId: appro.id,
          numero: appro.numero,
          montant: allocate,
        ));
      }

      // Crée le règlement avec les imputations
      final ref = _col.doc();
      tx.set(ref, {
        ...reg.toMap(),
        'imputations': imputations.map((i) => i.toMap()).toList(),
      });

      // Décrémente le solde fournisseur (positif = dette → 0 ; négatif
      // = avance amplifiée si le règlement est plus gros que les dettes)
      // + flagge hasOperations.
      tx.update(fournRef, {
        'solde': FieldValue.increment(-reg.montant),
        'hasOperations': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ReglementFournisseurModel(
        id: ref.id,
        fournisseurId: reg.fournisseurId,
        boutiqueId: reg.boutiqueId,
        userId: reg.userId,
        montant: reg.montant,
        modePaiement: reg.modePaiement,
        date: reg.date,
        note: reg.note,
        imputations: imputations,
      );
    });
  }

  /// Supprime un règlement et **inverse les imputations** : restitue
  /// les montants imputés au `montantPaye` de chaque appro concernée
  /// et restaure le solde fournisseur.
  Future<void> deleteAndRestore(String reglementId) async {
    await _fs.db.runTransaction((tx) async {
      final ref = _col.doc(reglementId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Règlement introuvable');
      }
      final reg = ReglementFournisseurModel.fromFirestore(snap);

      final approUpdates = <DocumentReference, double>{};
      for (final imp in reg.imputations) {
        if (imp.approId.isEmpty) continue;
        final aRef = _approvisionnements.doc(imp.approId);
        final aSnap = await tx.get(aRef);
        if (!aSnap.exists) continue;
        final a = ApprovisionnementModel.fromFirestore(aSnap);
        final next = a.montantPaye - imp.montant;
        approUpdates[aRef] = next < 0 ? 0 : next;
      }

      approUpdates.forEach((aRef, newMontantPaye) {
        tx.update(aRef, {'montantPaye': newMontantPaye});
      });

      tx.update(_fournisseurs.doc(reg.fournisseurId), {
        'solde': FieldValue.increment(reg.montant),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.delete(ref);
    });
  }
}
