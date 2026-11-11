import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration de la mise à jour forcée — doc singleton
/// `parametres/app_update`.
///
/// Édité par le super-admin via la vue paramètres. À chaque démarrage de
/// l'app, le splash compare [minVersion] avec la version installée et
/// affiche un dialog non-fermable si l'app est trop ancienne.
class AppUpdateConfigModel {
  /// Version minimale exigée des **deux** plateformes à la fois.
  /// Vide = pas de minimum commun.
  ///
  /// C'est le seul champ que comprennent les versions de l'app **déjà
  /// installées** avant l'arrivée du ciblage par plateforme : le remplir
  /// est la seule façon de forcer un parc ancien.
  final String minVersion;

  /// Version minimale exigée des seuls appareils Android. Vide = on
  /// retombe sur [minVersion].
  final String minVersionAndroid;

  /// Version minimale exigée des seuls appareils iOS. Vide = on retombe
  /// sur [minVersion].
  final String minVersionIos;

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
    this.minVersionAndroid = '',
    this.minVersionIos = '',
    this.iosStoreUrl = '',
    this.androidStoreUrl = '',
    this.message,
    this.updatedAt,
  });

  factory AppUpdateConfigModel.fromMap(Map<String, dynamic> map) {
    return AppUpdateConfigModel(
      minVersion: (map['minVersion'] ?? '') as String,
      minVersionAndroid: (map['minVersionAndroid'] ?? '') as String,
      minVersionIos: (map['minVersionIos'] ?? '') as String,
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

  /// Version minimale applicable à la plateforme courante : la valeur
  /// spécifique si elle est renseignée, sinon celle commune aux deux.
  String minVersionPour({required bool android}) {
    final specifique = android ? minVersionAndroid : minVersionIos;
    return specifique.trim().isNotEmpty ? specifique.trim() : minVersion.trim();
  }

  /// URL vers laquelle envoyer l'utilisateur pour se mettre à jour.
  String storeUrlPour({required bool android}) =>
      (android ? androidStoreUrl : iosStoreUrl).trim();

  Map<String, dynamic> toMap() => {
        'minVersion': minVersion.trim(),
        'minVersionAndroid': minVersionAndroid.trim(),
        'minVersionIos': minVersionIos.trim(),
        'iosStoreUrl': iosStoreUrl.trim(),
        'androidStoreUrl': androidStoreUrl.trim(),
        if (message != null && message!.trim().isNotEmpty)
          'message': message!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
