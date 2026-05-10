import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/abonnement_model.dart';

class AbonnementRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.abonnements;
  CollectionReference<Map<String, dynamic>> get _boutiques => _fs.boutiques;
  CollectionReference<Map<String, dynamic>> get _users => _fs.users;

  /// Stream des paiements d'une boutique, du plus récent au plus ancien.
  Stream<List<AbonnementModel>> watchByBoutique(String boutiqueId) {
    if (boutiqueId.isEmpty) return Stream.value(const <AbonnementModel>[]);
    return _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .orderBy('dateFin', descending: true)
        .snapshots()
        .ignorePermissionDenied()
        .map((s) => s.docs.map(AbonnementModel.fromFirestore).toList());
  }

  /// Stream de tous les paiements (super-admin uniquement).
  Stream<List<AbonnementModel>> watchAll() {
    return _col
        .orderBy('dateFin', descending: true)
        .snapshots()
        .ignorePermissionDenied()
        .map((s) => s.docs.map(AbonnementModel.fromFirestore).toList());
  }

  /// Enregistre un paiement et étend la date de fin d'abonnement de la
  /// boutique. Si la boutique (ou ses utilisateurs admin/gestionnaire) avait
  /// été désactivée pour cause d'expiration, elle est automatiquement
  /// réactivée.
  ///
  /// Logique de la `dateDebut` :
  /// - Si la boutique a un abonnement encore actif (`subscriptionEndsAt >
  ///   now`), la nouvelle période s'enchaîne après l'ancienne (paiement
  ///   anticipé ne perd pas de jours).
  /// - Sinon, la période démarre maintenant.
  ///
  /// La transaction couvre la création du paiement + l'update de la
  /// boutique. La réactivation des utilisateurs se fait dans un batch
  /// post-transaction (acceptable car cas de bord rare).
  Future<AbonnementModel> create({
    required String boutiqueId,
    required AbonnementPeriode periode,
    required double montant,
    required String devise,
    required String enregistrePar,
    String? note,
  }) async {
    if (boutiqueId.isEmpty) {
      throw ArgumentError('boutiqueId requis');
    }
    // Le montant 0 est autorisé (ex: période offerte, geste commercial).
    // On refuse uniquement les montants négatifs.
    if (montant < 0) {
      throw ArgumentError('Le montant ne peut pas être négatif');
    }

    final boutiqueRef = _boutiques.doc(boutiqueId);
    final newDocRef = _col.doc();

    final created = await _fs.db.runTransaction((tx) async {
      final boutiqueSnap = await tx.get(boutiqueRef);
      if (!boutiqueSnap.exists) {
        throw StateError('Boutique introuvable : $boutiqueId');
      }
      final data = boutiqueSnap.data() ?? {};
      final currentEnd =
          (data['subscriptionEndsAt'] as Timestamp?)?.toDate();
      final now = DateTime.now();

      // Démarre la nouvelle période après la fin courante si encore active,
      // sinon démarre maintenant.
      final dateDebut = (currentEnd != null && currentEnd.isAfter(now))
          ? currentEnd
          : now;
      final dateFin = _addMonths(dateDebut, periode.nbMois);

      final abo = AbonnementModel(
        id: newDocRef.id,
        boutiqueId: boutiqueId,
        periode: periode,
        montant: montant,
        devise: devise,
        dateDebut: dateDebut,
        dateFin: dateFin,
        enregistrePar: enregistrePar,
        note: note,
      );

      tx.set(newDocRef, abo.toMap());
      tx.update(boutiqueRef, {
        'subscriptionEndsAt': Timestamp.fromDate(dateFin),
        // Réactivation de la boutique si elle avait été désactivée pour
        // expiration. Cas d'une boutique manuellement désactivée par le
        // super-admin : la réactivation est volontaire ici (le paiement
        // signifie qu'on relance l'activité).
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return abo;
    });

    // Réactivation des utilisateurs admin/gestionnaire de la boutique qui
    // auraient été désactivés. Hors transaction — best-effort.
    await _reactivateBoutiqueUsers(boutiqueId);

    return created;
  }

  /// Réactive (active=true) tous les utilisateurs admin et gestionnaire
  /// d'une boutique qui sont actuellement inactifs. Best-effort : les
  /// éventuelles erreurs réseau ne font pas échouer la création du paiement.
  Future<void> _reactivateBoutiqueUsers(String boutiqueId) async {
    try {
      final inactifs = await _users
          .where('boutiqueId', isEqualTo: boutiqueId)
          .where('active', isEqualTo: false)
          .get();
      if (inactifs.docs.isEmpty) return;
      final batch = _fs.db.batch();
      for (final d in inactifs.docs) {
        batch.update(d.reference, {
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      // Silencieux : si la query/batch échoue, l'opération de paiement
      // est déjà persistée. Le super-admin peut réactiver manuellement.
    }
  }
}

/// Ajoute N mois à une date, en gérant les fins de mois (31 janvier + 1 mois
/// = 28 ou 29 février, pas un overflow vers mars).
DateTime _addMonths(DateTime base, int months) {
  final year = base.year + ((base.month - 1 + months) ~/ 12);
  final month = ((base.month - 1 + months) % 12) + 1;
  // Clamp le jour au dernier jour valide du mois cible.
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  final day = base.day > lastDayOfMonth ? lastDayOfMonth : base.day;
  return DateTime(year, month, day, base.hour, base.minute, base.second);
}
