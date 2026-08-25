import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../constants/firestore_keys.dart';

/// Service centralisant l'accès à Firestore.
/// Donne des références typées aux collections principales.
class FirestoreService extends GetxService {
  static FirestoreService get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection(FirestoreKeys.users);

  CollectionReference<Map<String, dynamic>> get boutiques =>
      _db.collection(FirestoreKeys.boutiques);

  CollectionReference<Map<String, dynamic>> get produits =>
      _db.collection(FirestoreKeys.produits);

  /// Sous-collection des variantes d'un produit (pointures, tailles, ...).
  /// Path : `produits/{produitId}/variantes`.
  CollectionReference<Map<String, dynamic>> variantesOf(String produitId) =>
      produits.doc(produitId).collection('variantes');

  CollectionReference<Map<String, dynamic>> get categories =>
      _db.collection(FirestoreKeys.categories);

  CollectionReference<Map<String, dynamic>> get ventes =>
      _db.collection(FirestoreKeys.ventes);

  CollectionReference<Map<String, dynamic>> get clients =>
      _db.collection(FirestoreKeys.clients);

  CollectionReference<Map<String, dynamic>> get reglements =>
      _db.collection(FirestoreKeys.reglements);

  CollectionReference<Map<String, dynamic>> get fournisseurs =>
      _db.collection(FirestoreKeys.fournisseurs);

  CollectionReference<Map<String, dynamic>> get approvisionnements =>
      _db.collection(FirestoreKeys.approvisionnements);

  CollectionReference<Map<String, dynamic>> get reglementsFournisseurs =>
      _db.collection(FirestoreKeys.reglementsFournisseurs);

  CollectionReference<Map<String, dynamic>> get mouvementsStock =>
      _db.collection(FirestoreKeys.mouvementsStock);

  CollectionReference<Map<String, dynamic>> get naturesDepense =>
      _db.collection(FirestoreKeys.naturesDepense);

  CollectionReference<Map<String, dynamic>> get depenses =>
      _db.collection(FirestoreKeys.depenses);

  CollectionReference<Map<String, dynamic>> get counters =>
      _db.collection(FirestoreKeys.counters);

  CollectionReference<Map<String, dynamic>> get abonnements =>
      _db.collection(FirestoreKeys.abonnements);

  /// Document singleton des paramètres d'abonnement
  /// (`parametres/abonnement`).
  DocumentReference<Map<String, dynamic>> get abonnementParamsDoc =>
      _db
          .collection(FirestoreKeys.parametres)
          .doc(FirestoreKeys.parametresAbonnementDoc);

  /// Index téléphone → email pour le login hybride. Doc-id = téléphone
  /// normalisé (`+224621785645`).
  CollectionReference<Map<String, dynamic>> get phoneIndex =>
      _db.collection(FirestoreKeys.phoneIndex);

  /// Document singleton de configuration de mise à jour forcée
  /// (`parametres/app_update`).
  DocumentReference<Map<String, dynamic>> get appUpdateConfigDoc =>
      _db
          .collection(FirestoreKeys.parametres)
          .doc(FirestoreKeys.parametresAppUpdateDoc);
}
