import 'package:cloud_firestore/cloud_firestore.dart';

import 'abonnement_model.dart';

/// Paramètres globaux du module abonnements (singleton stocké dans
/// `parametres/abonnement`).
///
/// Édité uniquement par le super-admin via la vue paramètres. Les tarifs
/// pré-remplissent le formulaire d'enregistrement de paiement (mais le
/// super-admin peut toujours saisir un montant différent).
class AbonnementParamsModel {
  /// Tarif par défaut pour chaque période d'abonnement, par devise.
  /// Clé Firestore = `${devise}_${periode.name}`. Ex: `GNF_mois: 50000`.
  ///
  /// On stocke à plat plutôt qu'en map imbriquée pour éviter les problèmes
  /// de merge partiel côté Firestore.
  final Map<String, double> tarifs;

  /// Période de grâce post-expiration (en jours). L'app reste accessible
  /// pendant ce délai avec un bandeau d'alerte ; au-delà, login refusé.
  final int graceDays;

  /// Seuil d'alerte (en jours) à partir duquel le snackbar de connexion
  /// et le bandeau du tableau de bord deviennent visibles. Default 7 :
  /// l'admin/gestionnaire est prévenu une semaine avant l'expiration.
  final int warningThresholdDays;

  final DateTime? updatedAt;

  const AbonnementParamsModel({
    this.tarifs = const {},
    this.graceDays = 3,
    this.warningThresholdDays = 7,
    this.updatedAt,
  });

  /// Lit le tarif pour une période donnée dans une devise. Retourne 0 si
  /// pas configuré (le super-admin saisira manuellement le montant).
  double tarifPour(AbonnementPeriode periode, String devise) {
    return tarifs['${devise}_${periode.name}'] ?? 0;
  }

  factory AbonnementParamsModel.fromMap(Map<String, dynamic> map) {
    final raw = map['tarifs'];
    final tarifs = <String, double>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value;
        if (v is num) tarifs[e.key.toString()] = v.toDouble();
      }
    }
    return AbonnementParamsModel(
      tarifs: tarifs,
      graceDays: (map['graceDays'] as num?)?.toInt() ?? 3,
      warningThresholdDays:
          (map['warningThresholdDays'] as num?)?.toInt() ?? 7,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AbonnementParamsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AbonnementParamsModel.fromMap(doc.data() ?? {});
  }

  Map<String, dynamic> toMap() => {
        'tarifs': tarifs,
        'graceDays': graceDays,
        'warningThresholdDays': warningThresholdDays,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AbonnementParamsModel copyWith({
    Map<String, double>? tarifs,
    int? graceDays,
    int? warningThresholdDays,
  }) {
    return AbonnementParamsModel(
      tarifs: tarifs ?? this.tarifs,
      graceDays: graceDays ?? this.graceDays,
      warningThresholdDays:
          warningThresholdDays ?? this.warningThresholdDays,
      updatedAt: DateTime.now(),
    );
  }
}
