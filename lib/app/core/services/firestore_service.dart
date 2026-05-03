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

  CollectionReference<Map<String, dynamic>> get categories =>
      _db.collection(FirestoreKeys.categories);

  CollectionReference<Map<String, dynamic>> get stocks =>
      _db.collection(FirestoreKeys.stocks);

  CollectionReference<Map<String, dynamic>> get mouvementsStock =>
      _db.collection(FirestoreKeys.mouvementsStock);

  CollectionReference<Map<String, dynamic>> get ventes =>
      _db.collection(FirestoreKeys.ventes);

  CollectionReference<Map<String, dynamic>> get clients =>
      _db.collection(FirestoreKeys.clients);

  CollectionReference<Map<String, dynamic>> get reglements =>
      _db.collection(FirestoreKeys.reglements);

  CollectionReference<Map<String, dynamic>> get counters =>
      _db.collection(FirestoreKeys.counters);
}
