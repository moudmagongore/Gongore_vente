import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  /// Super-administrateur : accès global, gère les boutiques et leurs admins.
  /// Créé UNIQUEMENT manuellement dans Firestore (jamais via l'app).
  superAdmin,

  /// Administrateur d'une boutique : gère ses produits, catégories, vendeurs.
  /// Lié à une boutique précise via `boutiqueId`.
  admin,

  /// Vendeur d'une boutique : utilise la caisse, voit ses propres ventes.
  /// Lié à une boutique précise via `boutiqueId`.
  vendeur;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.vendeur,
    );
  }

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.vendeur:
        return 'Vendeur';
    }
  }
}

class UserModel {
  final String id;
  final String nom;
  final String email;
  final String? telephone;
  final UserRole role;
  final String? boutiqueId;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.telephone,
    this.boutiqueId,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      telephone: map['telephone'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      boutiqueId: map['boutiqueId'] as String?,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'role': role.name,
        'boutiqueId': boutiqueId,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin;
  bool get isVendeur => role == UserRole.vendeur;

  /// Renvoie true si l'utilisateur a un accès admin (super-admin OU admin
  /// de boutique). Utile pour cacher les écrans réservés aux vendeurs.
  bool get isAnyAdmin => isSuperAdmin || isAdmin;

  UserModel copyWith({
    String? nom,
    String? email,
    String? telephone,
    UserRole? role,
    String? boutiqueId,
    bool? active,
  }) {
    return UserModel(
      id: id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
