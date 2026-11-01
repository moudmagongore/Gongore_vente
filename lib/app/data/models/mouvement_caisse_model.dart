import 'package:cloud_firestore/cloud_firestore.dart';

/// Sens d'un mouvement. Le montant reste toujours positif : c'est le sens
/// qui dit s'il s'ajoute au solde ou s'en retranche.
enum SensMouvement {
  entree,
  sortie;

  static SensMouvement fromString(String? value) {
    return SensMouvement.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SensMouvement.entree,
    );
  }

  /// +1 pour une entrée, -1 pour une sortie.
  int get signe => this == SensMouvement.entree ? 1 : -1;

  String get label => this == SensMouvement.entree ? 'Entrée' : 'Sortie';
}

/// Origine d'un mouvement. Sert au filtre du relevé et au libellé affiché.
enum TypeMouvementCaisse {
  /// Solde de départ saisi à la création de la caisse, enregistré comme
  /// mouvement pour que le relevé soit complet dès le premier jour.
  ouverture,
  vente,
  encaissementClient,
  approvisionnement,
  reglementFournisseur,
  depense,
  transfert,
  apport,
  retrait,
  correction,

  /// Mouvement inverse compensant un mouvement antérieur (annulation
  /// d'opération ou de transfert).
  annulation;

  static TypeMouvementCaisse fromString(String? value) {
    return TypeMouvementCaisse.values.firstWhere(
      (t) => t.name == value,
      orElse: () => TypeMouvementCaisse.correction,
    );
  }

  String get label {
    switch (this) {
      case TypeMouvementCaisse.ouverture:
        return 'Ouverture';
      case TypeMouvementCaisse.vente:
        return 'Vente';
      case TypeMouvementCaisse.encaissementClient:
        return 'Encaissement client';
      case TypeMouvementCaisse.approvisionnement:
        return 'Arrivage';
      case TypeMouvementCaisse.reglementFournisseur:
        return 'Règlement fournisseur';
      case TypeMouvementCaisse.depense:
        return 'Dépense';
      case TypeMouvementCaisse.transfert:
        return 'Transfert';
      case TypeMouvementCaisse.apport:
        return 'Apport';
      case TypeMouvementCaisse.retrait:
        return 'Retrait';
      case TypeMouvementCaisse.correction:
        return 'Correction';
      case TypeMouvementCaisse.annulation:
        return 'Annulation';
    }
  }

  /// Types réservés à l'admin : ils n'ont aucune opération derrière eux,
  /// c'est l'admin qui décide seul du mouvement.
  bool get reserveAdmin =>
      this == TypeMouvementCaisse.apport ||
      this == TypeMouvementCaisse.retrait ||
      this == TypeMouvementCaisse.correction;
}

/// Une entrée ou une sortie d'argent sur une caisse.
///
/// Un mouvement n'est **jamais modifié ni supprimé** : une erreur se
/// corrige par l'annulation de l'opération (qui écrit un mouvement
/// inverse) ou par une correction de l'admin. Seul le super-admin peut
/// supprimer, comme pour les ventes.
class MouvementCaisseModel {
  final String id;
  final String boutiqueId;
  final String caisseId;

  /// Nom de la caisse au moment du mouvement (dénormalisé).
  final String caisseNom;

  final SensMouvement sens;

  /// Toujours positif.
  final double montant;

  /// Solde de la caisse après ce mouvement, figé à l'écriture : le relevé
  /// l'affiche sans rien recalculer.
  final double soldeApres;

  final TypeMouvementCaisse type;

  /// Opération d'origine : collection, id du document et numéro affichable
  /// (`V-2026-00042`...). Vides pour un apport, un retrait ou une
  /// correction, qui n'ont pas d'opération derrière eux.
  final String? sourceType;
  final String? sourceId;
  final String? numero;

  /// Lie les deux mouvements d'un même transfert (sortie et entrée).
  final String? transfertId;

  /// Mouvement compensé, pour un mouvement de type `annulation`.
  final String? mouvementAnnuleId;

  /// Obligatoire pour un apport, un retrait ou une correction.
  final String? motif;

  final String userId;
  final String userNom;
  final DateTime date;
  final DateTime? createdAt;

  const MouvementCaisseModel({
    required this.id,
    required this.boutiqueId,
    required this.caisseId,
    required this.caisseNom,
    required this.sens,
    required this.montant,
    required this.soldeApres,
    required this.type,
    required this.userId,
    required this.userNom,
    required this.date,
    this.sourceType,
    this.sourceId,
    this.numero,
    this.transfertId,
    this.mouvementAnnuleId,
    this.motif,
    this.createdAt,
  });

  factory MouvementCaisseModel.fromMap(Map<String, dynamic> map, String id) {
    return MouvementCaisseModel(
      id: id,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      caisseId: (map['caisseId'] ?? '') as String,
      caisseNom: (map['caisseNom'] ?? '') as String,
      sens: SensMouvement.fromString(map['sens'] as String?),
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      soldeApres: (map['soldeApres'] as num?)?.toDouble() ?? 0,
      type: TypeMouvementCaisse.fromString(map['type'] as String?),
      sourceType: map['sourceType'] as String?,
      sourceId: map['sourceId'] as String?,
      numero: map['numero'] as String?,
      transfertId: map['transfertId'] as String?,
      mouvementAnnuleId: map['mouvementAnnuleId'] as String?,
      motif: map['motif'] as String?,
      userId: (map['userId'] ?? '') as String,
      userNom: (map['userNom'] ?? '') as String,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory MouvementCaisseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      MouvementCaisseModel.fromMap(doc.data() ?? {}, doc.id);

  /// Les champs optionnels ne sont écrits que s'ils existent : un
  /// mouvement sans transfert ni motif ne porte pas les clés
  /// correspondantes, ce qui garde les documents lisibles en console.
  Map<String, dynamic> toMap() => {
        'boutiqueId': boutiqueId,
        'caisseId': caisseId,
        'caisseNom': caisseNom,
        'sens': sens.name,
        'montant': montant,
        'soldeApres': soldeApres,
        'type': type.name,
        if (sourceType != null) 'sourceType': sourceType,
        if (sourceId != null) 'sourceId': sourceId,
        if (numero != null) 'numero': numero,
        if (transfertId != null) 'transfertId': transfertId,
        if (mouvementAnnuleId != null) 'mouvementAnnuleId': mouvementAnnuleId,
        if (motif != null) 'motif': motif,
        'userId': userId,
        'userNom': userNom,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Montant signé, pratique pour les totaux d'un relevé.
  double get montantSigne => montant * sens.signe;
}
