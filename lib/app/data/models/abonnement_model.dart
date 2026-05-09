import 'package:cloud_firestore/cloud_firestore.dart';

/// Période couverte par un paiement d'abonnement.
enum AbonnementPeriode {
  mois,
  trimestre,
  semestre,
  annuel;

  /// Nombre de mois ajoutés à la `dateDebut` pour calculer la `dateFin`.
  int get nbMois {
    switch (this) {
      case AbonnementPeriode.mois:
        return 1;
      case AbonnementPeriode.trimestre:
        return 3;
      case AbonnementPeriode.semestre:
        return 6;
      case AbonnementPeriode.annuel:
        return 12;
    }
  }

  String get label {
    switch (this) {
      case AbonnementPeriode.mois:
        return 'Mensuel';
      case AbonnementPeriode.trimestre:
        return 'Trimestriel';
      case AbonnementPeriode.semestre:
        return 'Semestriel';
      case AbonnementPeriode.annuel:
        return 'Annuel';
    }
  }

  static AbonnementPeriode fromString(String? value) {
    return AbonnementPeriode.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AbonnementPeriode.mois,
    );
  }
}

/// Un paiement d'abonnement enregistré pour une boutique.
///
/// La boutique correspondante a son champ `subscriptionEndsAt` mis à jour
/// transactionnellement à la création de ce document — il vaut le `max(dateFin)`
/// parmi tous les abonnements de la boutique.
class AbonnementModel {
  final String id;
  final String boutiqueId;
  final AbonnementPeriode periode;

  /// Montant payé. Pré-rempli depuis [AbonnementParamsModel] mais éditable
  /// par le super-admin à chaque enregistrement.
  final double montant;
  final String devise;

  /// Début de la période payée. Par défaut, la dernière `dateFin` de la
  /// boutique (ou maintenant si aucune dateFin antérieure / déjà expirée).
  final DateTime dateDebut;

  /// Calculé : `dateDebut + periode.nbMois`.
  final DateTime dateFin;

  /// userId du super-admin qui a saisi le paiement.
  final String enregistrePar;
  final DateTime? enregistreLe;

  /// Note libre (ex: « Mobile Money MoMo, ref XXX »).
  final String? note;

  const AbonnementModel({
    required this.id,
    required this.boutiqueId,
    required this.periode,
    required this.montant,
    required this.devise,
    required this.dateDebut,
    required this.dateFin,
    required this.enregistrePar,
    this.enregistreLe,
    this.note,
  });

  factory AbonnementModel.fromMap(Map<String, dynamic> map, String id) {
    return AbonnementModel(
      id: id,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      periode: AbonnementPeriode.fromString(map['periode'] as String?),
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      devise: (map['devise'] ?? 'GNF') as String,
      dateDebut: (map['dateDebut'] as Timestamp).toDate(),
      dateFin: (map['dateFin'] as Timestamp).toDate(),
      enregistrePar: (map['enregistrePar'] ?? '') as String,
      enregistreLe: (map['enregistreLe'] as Timestamp?)?.toDate(),
      note: map['note'] as String?,
    );
  }

  factory AbonnementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AbonnementModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'boutiqueId': boutiqueId,
        'periode': periode.name,
        'montant': montant,
        'devise': devise,
        'dateDebut': Timestamp.fromDate(dateDebut),
        'dateFin': Timestamp.fromDate(dateFin),
        'enregistrePar': enregistrePar,
        'enregistreLe': FieldValue.serverTimestamp(),
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}
