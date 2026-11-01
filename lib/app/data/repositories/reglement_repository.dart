import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/caisse_calculator.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/mouvement_caisse_model.dart';
import '../models/reglement_model.dart';
import '../models/vente_model.dart';
import 'caisse_repository.dart';

class ReglementRepository {
  final FirestoreService _fs = FirestoreService.to;
  final CaisseRepository _caisses = CaisseRepository();

  CollectionReference<Map<String, dynamic>> get _col => _fs.reglements;
  CollectionReference<Map<String, dynamic>> get _clients => _fs.clients;
  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;

  /// Stream des règlements d'un client donné, du plus récent au plus ancien.
  /// Le filtre `boutiqueId` est requis pour aligner sur les rules Firestore
  /// (`resource.data.boutiqueId == userBoutiqueId()`), sinon la query est
  /// refusée d'office.
  Stream<List<ReglementModel>> watchByClient(
    String clientId, {
    required String boutiqueId,
    int limit = 100,
  }) {
    if (clientId.isEmpty || boutiqueId.isEmpty) {
      return Stream.value(<ReglementModel>[]);
    }
    return _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots().ignorePermissionDenied()
        .map((s) => s.docs.map(ReglementModel.fromFirestore).toList());
  }

  /// Stream des règlements scopés à une boutique (pour rapports / liste).
  Stream<List<ReglementModel>> watchByBoutique(String boutiqueId,
      {DateTime? after, int limit = 200}) {
    if (boutiqueId.isEmpty) return Stream.value(<ReglementModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where('boutiqueId', isEqualTo: boutiqueId);
    if (after != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    q = q.orderBy('date', descending: true).limit(limit);
    return q
        .snapshots().ignorePermissionDenied()
        .map((s) => s.docs.map(ReglementModel.fromFirestore).toList());
  }

  /// Crée un règlement et l'impute en **FIFO** sur les ventes en crédit du
  /// client (les plus anciennes d'abord). Met à jour `montantPaye` de chaque
  /// vente touchée, persiste les imputations sur le règlement, et décrémente
  /// le solde du client. Si le montant dépasse les dettes, le surplus reste
  /// en avance (solde négatif). Tout est atomique.
  ///
  /// Retourne le règlement persisté avec son `id` et la liste des imputations
  /// calculées en FIFO — utile pour générer un reçu PDF dans la foulée.
  Future<ReglementModel> create(
    ReglementModel reg, {
    required String userNom,
  }) async {
    if (reg.montant <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0');
    }
    if (reg.clientId.isEmpty) {
      throw ArgumentError('clientId requis pour un règlement');
    }
    // RG-14 : le total des paiements est le montant imputé.
    final probleme = verifierRepartition(
      paiements: reg.paiements,
      attendu: reg.montant,
    );
    if (probleme != null) throw CaisseException(probleme);

    // ===== Pré-fetch des ventes en crédit du client (hors transaction) =====
    // Le filtre `boutiqueId` est obligatoire pour aligner la query sur la
    // règle Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
    // sinon la query est refusée d'office (PERMISSION_DENIED).
    // On ne peut pas faire de query dans une transaction, on récupère
    // donc les références ici, et on re-lit chaque doc dans la tx pour avoir
    // l'état frais (gérera les conflits via le retry intégré de Firestore).
    final ventesQuery = await _ventes
        .where('boutiqueId', isEqualTo: reg.boutiqueId)
        .where('clientId', isEqualTo: reg.clientId)
        .where('statut', isEqualTo: VenteStatut.validee.name)
        .orderBy('date', descending: false) // FIFO = anciennes d'abord
        .get();
    final candidateRefs = ventesQuery.docs.map((d) => d.reference).toList();

    return _fs.db.runTransaction<ReglementModel>((tx) async {
      // ===== Étape 1 : tous les reads d'abord =====
      final clientRef = _clients.doc(reg.clientId);
      final clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) {
        throw Exception('Client introuvable');
      }

      final venteSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in candidateRefs) {
        venteSnaps.add(await tx.get(ref));
      }

      // ===== Étape 1b : encaissement sur les caisses =====
      // Avant la boucle FIFO, qui écrit : `appliquerPaiements` lit les
      // caisses, et Firestore interdit toute lecture après une écriture
      // dans la même transaction.
      final ref = _col.doc();
      final paiements = await _caisses.appliquerPaiements(
        tx: tx,
        paiements: reg.paiements,
        sens: SensMouvement.entree,
        boutiqueId: reg.boutiqueId,
        type: TypeMouvementCaisse.encaissementClient,
        userId: reg.userId,
        userNom: userNom,
        date: reg.date,
        sourceType: 'reglements',
        sourceId: ref.id,
      );

      // ===== Étape 2 : allocation FIFO =====
      double remaining = reg.montant;
      final imputations = <Imputation>[];

      for (final snap in venteSnaps) {
        if (remaining <= 0) break;
        if (!snap.exists) continue;
        final vente = VenteModel.fromFirestore(snap);
        // Garde-fous : on saute les ventes annulées ou déjà soldées (au cas où
        // l'état aurait changé entre la query et la tx).
        if (vente.statut != VenteStatut.validee) continue;
        if (vente.resteAPayer <= 0) continue;

        final allocate =
            vente.resteAPayer < remaining ? vente.resteAPayer : remaining;
        remaining -= allocate;

        tx.update(snap.reference, {
          'montantPaye': vente.montantPaye + allocate,
        });
        imputations.add(Imputation(
          venteId: vente.id,
          numero: vente.numero,
          montant: allocate,
        ));
      }

      // ===== Étape 3 : créer le règlement avec les imputations =====
      tx.set(ref, {
        ...reg.toMap(),
        'paiements': paiements.map((p) => p.toMap()).toList(),
        'imputations': imputations.map((i) => i.toMap()).toList(),
      });

      // ===== Étape 4 : décrémenter le solde du client + flagger =====
      // `hasOperations: true` est posé pour que les rules Firestore
      // bloquent la suppression côté serveur (irréversible une fois
      // qu'un règlement existe sur ce client).
      tx.update(clientRef, {
        'solde': FieldValue.increment(-reg.montant),
        'hasOperations': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ReglementModel(
        id: ref.id,
        clientId: reg.clientId,
        boutiqueId: reg.boutiqueId,
        userId: reg.userId,
        montant: reg.montant,
        modePaiement: reg.modePaiement,
        paiements: paiements,
        date: reg.date,
        note: reg.note,
        imputations: imputations,
      );
    });
  }

  /// Supprime un règlement et **inverse les imputations** : restitue les
  /// montants imputés au `montantPaye` de chaque vente concernée et restaure
  /// le solde du client.
  /// Supprime un règlement et **inverse les imputations**.
  ///
  /// Si l'encaissement était passé par des caisses, l'argent en ressort :
  /// chaque mouvement d'entrée est compensé par une sortie. Une caisse qui
  /// n'autorise pas le négatif et dont les fonds ont été dépensés depuis
  /// **fait échouer la suppression** (RG-16) — il faut alors un apport, ou
  /// autoriser le négatif sur cette caisse.
  Future<void> deleteAndRestore(
    String reglementId, {
    required String userId,
    required String userNom,
  }) async {
    await _fs.db.runTransaction((tx) async {
      final ref = _col.doc(reglementId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Règlement introuvable');
      }
      final reg = ReglementModel.fromFirestore(snap);

      // Lit chaque vente touchée pour avoir le montantPaye actuel
      final venteUpdates = <DocumentReference, double>{};
      for (final imp in reg.imputations) {
        if (imp.venteId.isEmpty) continue;
        final vRef = _ventes.doc(imp.venteId);
        final vSnap = await tx.get(vRef);
        if (!vSnap.exists) continue;
        final v = VenteModel.fromFirestore(vSnap);
        // Réduit le montantPaye du montant qui avait été imputé
        final next = v.montantPaye - imp.montant;
        venteUpdates[vRef] = next < 0 ? 0 : next;
      }

      // L'argent ressort des caisses où il était entré. Avant les
      // premières écritures : `appliquerPaiements` lit les caisses.
      if (reg.passeParCaisse) {
        final annules = <String, String>{};
        for (final p in reg.paiements) {
          final mid = p.mouvementId;
          if (mid != null) annules[p.caisseId] = mid;
        }
        await _caisses.appliquerPaiements(
          tx: tx,
          paiements: reg.paiements,
          sens: SensMouvement.sortie,
          boutiqueId: reg.boutiqueId,
          type: TypeMouvementCaisse.annulation,
          userId: userId,
          userNom: userNom,
          date: DateTime.now(),
          sourceType: 'reglements',
          sourceId: reglementId,
          mouvementsAnnules: annules,
          exigerActive: false,
        );
      }

      // Writes : ventes
      venteUpdates.forEach((vRef, newMontantPaye) {
        tx.update(vRef, {'montantPaye': newMontantPaye});
      });

      // Restitue le montant total au solde du client
      tx.update(_clients.doc(reg.clientId), {
        'solde': FieldValue.increment(reg.montant),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Supprime le règlement
      tx.delete(ref);
    });
  }
}
