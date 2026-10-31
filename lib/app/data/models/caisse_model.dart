import 'package:cloud_firestore/cloud_firestore.dart';

/// Compte de trésorerie d'une boutique : tiroir espèces, Orange Money,
/// MTN MoMo, compte bancaire... Créé et paramétré par l'ADMIN seul.
///
/// Le gestionnaire ne voit que les caisses dont il figure dans
/// [gestionnaireIds] ; l'admin voit toutes celles de sa boutique.
class CaisseModel {
  final String id;
  final String nom;

  /// Montant présent dans la caisse.
  ///
  /// **Jamais saisi** : il ne bouge que par des mouvements, à l'intérieur
  /// d'une transaction (cf. `CaisseRepository`). C'est pourquoi
  /// [toMapParametres] ne le contient pas — un enregistrement du
  /// formulaire ne doit pas pouvoir écraser le solde avec la valeur
  /// chargée à l'ouverture de l'écran.
  final double solde;

  /// Une caisse désactivée n'est plus proposée dans les opérations, mais
  /// reste visible dans les relevés et les rapports. C'est le repli quand
  /// la suppression est bloquée par l'existence de mouvements.
  final bool active;

  /// uid des gestionnaires ayant accès. Vide = aucun gestionnaire.
  ///
  /// Les admins (même ceux qui cumulent le rôle gestionnaire) n'y figurent
  /// jamais : ils voient déjà toutes les caisses de leur boutique.
  final List<String> gestionnaireIds;

  /// Autorise le solde à devenir négatif. Par défaut non : une opération
  /// qui ferait passer la caisse sous zéro est refusée.
  final bool autoriseNegatif;

  /// Ordre d'affichage dans les sélecteurs et le tableau de bord.
  final int ordre;

  /// Passe à `true` au premier mouvement et ne redescend jamais : une
  /// caisse qui a servi ne peut plus être supprimée, seulement désactivée.
  final bool hasMouvements;

  final String boutiqueId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CaisseModel({
    required this.id,
    required this.nom,
    required this.boutiqueId,
    this.solde = 0,
    this.active = true,
    this.gestionnaireIds = const [],
    this.autoriseNegatif = false,
    this.ordre = 0,
    this.hasMouvements = false,
    this.createdAt,
    this.updatedAt,
  });

  factory CaisseModel.fromMap(Map<String, dynamic> map, String id) {
    return CaisseModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      solde: (map['solde'] as num?)?.toDouble() ?? 0,
      active: (map['active'] ?? true) as bool,
      gestionnaireIds:
          ((map['gestionnaireIds'] as List?) ?? const []).cast<String>(),
      autoriseNegatif: (map['autoriseNegatif'] ?? false) as bool,
      ordre: (map['ordre'] as num?)?.toInt() ?? 0,
      hasMouvements: (map['hasMouvements'] ?? false) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory CaisseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      CaisseModel.fromMap(doc.data() ?? {}, doc.id);

  /// Document complet, utilisé à la **création** uniquement : c'est le seul
  /// moment où le solde est écrit depuis le modèle (solde de départ).
  Map<String, dynamic> toMap() => {
        ...toMapParametres(),
        'solde': solde,
        'hasMouvements': hasMouvements,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Champs modifiables depuis l'écran de paramétrage. `solde` et
  /// `hasMouvements` en sont volontairement absents (cf. [solde]).
  Map<String, dynamic> toMapParametres() => {
        'nom': nom,
        'boutiqueId': boutiqueId,
        'active': active,
        'gestionnaireIds': gestionnaireIds,
        'autoriseNegatif': autoriseNegatif,
        'ordre': ordre,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Vrai si ce gestionnaire a accès à la caisse. Sans objet pour un
  /// admin, qui voit tout : l'appelant ne pose la question que pour un
  /// gestionnaire.
  bool accessiblePar(String uid) => gestionnaireIds.contains(uid);

  CaisseModel copyWith({
    String? nom,
    double? solde,
    bool? active,
    List<String>? gestionnaireIds,
    bool? autoriseNegatif,
    int? ordre,
    bool? hasMouvements,
  }) {
    return CaisseModel(
      id: id,
      nom: nom ?? this.nom,
      boutiqueId: boutiqueId,
      solde: solde ?? this.solde,
      active: active ?? this.active,
      gestionnaireIds: gestionnaireIds ?? this.gestionnaireIds,
      autoriseNegatif: autoriseNegatif ?? this.autoriseNegatif,
      ordre: ordre ?? this.ordre,
      hasMouvements: hasMouvements ?? this.hasMouvements,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
