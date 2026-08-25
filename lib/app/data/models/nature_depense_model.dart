import 'package:cloud_firestore/cloud_firestore.dart';

/// Nature de dépense paramétrée par l'ADMIN d'une boutique (loyer,
/// électricité, transport, salaires, ...). Sert de référentiel au
/// formulaire de déclaration de dépense : le gestionnaire choisit une
/// nature existante, il n'en crée jamais.
class NatureDepenseModel {
  final String id;
  final String nom;
  final String? description;
  final String boutiqueId;

  /// Une nature désactivée reste visible dans l'historique des dépenses
  /// déjà saisies, mais n'est plus proposée à la saisie. C'est la
  /// solution de repli quand la suppression est bloquée par l'existence
  /// de dépenses rattachées.
  final bool active;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NatureDepenseModel({
    required this.id,
    required this.nom,
    required this.boutiqueId,
    this.description,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory NatureDepenseModel.fromMap(Map<String, dynamic> map, String id) {
    return NatureDepenseModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      description: map['description'] as String?,
      boutiqueId: (map['boutiqueId'] ?? '') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory NatureDepenseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      NatureDepenseModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'description': description,
        'boutiqueId': boutiqueId,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  NatureDepenseModel copyWith({
    String? nom,
    String? description,
    String? boutiqueId,
    bool? active,
  }) {
    return NatureDepenseModel(
      id: id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
