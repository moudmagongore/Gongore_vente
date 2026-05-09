import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration de la mise à jour forcée — doc singleton
/// `parametres/app_update`.
///
/// Édité par le super-admin via la vue paramètres. À chaque démarrage de
/// l'app, le splash compare [minVersion] avec la version installée et
/// affiche un dialog non-fermable si l'app est trop ancienne.
class AppUpdateConfigModel {
  /// Version minimale requise (format `MAJOR.MINOR.PATCH`, ex: `1.2.5`).
  /// Vide = pas de minimum imposé (on laisse passer).
  final String minVersion;

  /// URL de l'App Store iOS.
  final String iosStoreUrl;

  /// URL du Play Store Android.
  final String androidStoreUrl;

  /// Message contextuel affiché à l'utilisateur (ex: « Corrections de
  /// sécurité importantes »). Optionnel.
  final String? message;

  final DateTime? updatedAt;

  const AppUpdateConfigModel({
    this.minVersion = '',
    this.iosStoreUrl = '',
    this.androidStoreUrl = '',
    this.message,
    this.updatedAt,
  });

  factory AppUpdateConfigModel.fromMap(Map<String, dynamic> map) {
    return AppUpdateConfigModel(
      minVersion: (map['minVersion'] ?? '') as String,
      iosStoreUrl: (map['iosStoreUrl'] ?? '') as String,
      androidStoreUrl: (map['androidStoreUrl'] ?? '') as String,
      message: map['message'] as String?,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AppUpdateConfigModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AppUpdateConfigModel.fromMap(doc.data() ?? {});
  }

  Map<String, dynamic> toMap() => {
        'minVersion': minVersion.trim(),
        'iosStoreUrl': iosStoreUrl.trim(),
        'androidStoreUrl': androidStoreUrl.trim(),
        if (message != null && message!.trim().isNotEmpty)
          'message': message!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
