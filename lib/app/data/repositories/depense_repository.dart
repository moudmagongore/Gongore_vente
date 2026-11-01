import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/caisse_calculator.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/depense_model.dart';
import '../models/mouvement_caisse_model.dart';
import 'caisse_repository.dart';

class DepenseRepository {
  final FirestoreService _fs = FirestoreService.to;
  final CaisseRepository _caisses = CaisseRepository();

  CollectionReference<Map<String, dynamic>> get _col => _fs.depenses;

  /// Stream des dépenses, de la plus récente à la plus ancienne.
  ///
  /// - `boutiqueId == null` → pas de filtre boutique (super-admin)
  /// - `boutiqueId` vide → liste vide (utilisateur sans boutique)
  /// - `after` / `before` bornent la période sur le champ `date`
  Stream<List<DepenseModel>> watchAll({
    String? boutiqueId,
    DateTime? after,
    DateTime? before,
    int limit = 300,
  }) {
    if (boutiqueId != null && boutiqueId.isEmpty) {
      return Stream.value(<DepenseModel>[]);
    }
    Query<Map<String, dynamic>> q = _col;
    if (boutiqueId != null) {
      q = q.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (after != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    if (before != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(before));
    }
    q = q.orderBy('date', descending: true).limit(limit);
    return q.snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(DepenseModel.fromFirestore).toList(),
        );
  }

  Future<DepenseModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return DepenseModel.fromFirestore(snap);
  }

  /// Enregistre une dépense et, si elle est payée depuis des caisses, les
  /// mouvements de sortie correspondants — le tout atomiquement.
  ///
  /// Sans paiement (boutique sans caisse, RG-9), on reste sur une simple
  /// écriture : inutile d'ouvrir une transaction pour un seul document.
  Future<String> create(
    DepenseModel depense, {
    required String userNom,
  }) async {
    if (depense.montant <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0');
    }
    if (depense.natureId.isEmpty) {
      throw ArgumentError('Nature de dépense requise');
    }

    if (depense.paiements.isEmpty) {
      final data =
          depense.toMap()..['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(data);
      return ref.id;
    }

    // RG-15 : la répartition doit couvrir exactement le montant. Le
    // formulaire le vérifie déjà ; on le revérifie ici parce que c'est la
    // dernière barrière avant l'écriture des mouvements.
    final probleme = verifierRepartition(
      paiements: depense.paiements,
      attendu: depense.montant,
    );
    if (probleme != null) throw CaisseException(probleme);

    // L'id du document est réservé avant la transaction : les mouvements
    // doivent pouvoir pointer vers la dépense qui les a provoqués.
    final ref = _col.doc();

    await _fs.db.runTransaction((tx) async {
      // Lectures puis écritures : `appliquerPaiements` fait les deux, il
      // doit donc être appelé avant tout `tx.set` de cette transaction.
      final paiements = await _caisses.appliquerPaiements(
        tx: tx,
        paiements: depense.paiements,
        sens: SensMouvement.sortie,
        boutiqueId: depense.boutiqueId,
        type: TypeMouvementCaisse.depense,
        userId: depense.userId,
        userNom: userNom,
        date: depense.date,
        sourceType: 'depenses',
        sourceId: ref.id,
      );

      tx.set(ref, {
        ...depense.copyWith(paiements: paiements).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return ref.id;
  }

  /// Correction d'une dépense. `date`, `boutiqueId` et `userId` sont
  /// volontairement figés (audit).
  ///
  /// **Le montant n'est plus modifiable dès que la dépense a été payée
  /// depuis une caisse** : l'argent est sorti, et un solde ne se corrige
  /// pas en réécrivant l'opération (RG-5). Il faut alors supprimer la
  /// dépense — ce qui recrédite les caisses — et la ressaisir.
  Future<void> update(DepenseModel depense) async {
    if (depense.montant <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0');
    }

    final actuelle = await getById(depense.id);
    if (actuelle == null) {
      throw Exception('Dépense introuvable');
    }
    if (actuelle.estPayeeSurCaisse && depense.montant != actuelle.montant) {
      throw CaisseException(
        'Cette dépense a été payée depuis une caisse : son montant n\'est '
        'plus modifiable. Supprimez-la — les caisses seront recréditées — '
        'puis ressaisissez-la.',
      );
    }

    return _col.doc(depense.id).update({
      'natureId': depense.natureId,
      'natureNom': depense.natureNom,
      'montant': depense.montant,
      'commentaire': depense.commentaire,
    });
  }

  /// Supprime une dépense en recréditant les caisses qui l'avaient payée.
  ///
  /// Chaque mouvement de sortie est compensé par une entrée de type
  /// `annulation` pointant vers lui (RG-16) ; les soldes reviennent à leur
  /// état antérieur. Une caisse désactivée entre-temps est quand même
  /// recréditée, sinon la dépense serait impossible à supprimer.
  ///
  /// [userId] et [userNom] sont ceux de l'utilisateur qui supprime, pas de
  /// l'auteur de la dépense.
  Future<void> delete(
    String id, {
    required String userId,
    required String userNom,
  }) async {
    await _fs.db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final depense = DepenseModel.fromFirestore(snap);

      if (depense.estPayeeSurCaisse) {
        final annules = <String, String>{};
        for (final p in depense.paiements) {
          final mid = p.mouvementId;
          if (mid != null) annules[p.caisseId] = mid;
        }
        await _caisses.appliquerPaiements(
          tx: tx,
          paiements: depense.paiements,
          sens: SensMouvement.entree,
          boutiqueId: depense.boutiqueId,
          type: TypeMouvementCaisse.annulation,
          userId: userId,
          userNom: userNom,
          date: DateTime.now(),
          sourceType: 'depenses',
          sourceId: id,
          mouvementsAnnules: annules,
          exigerActive: false,
        );
      }

      tx.delete(ref);
    });
  }
}
