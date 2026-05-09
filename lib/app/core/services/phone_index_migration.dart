import '../../data/models/user_model.dart';
import '../../data/repositories/phone_index_repository.dart';
import '../utils/phone_normalizer.dart';
import 'firestore_service.dart';

/// Reconstruit la collection `phone_index` à partir des utilisateurs
/// existants. Utilisé une fois lors du déploiement de la fonctionnalité
/// « login par numéro » et ré-utilisable si l'index est désynchronisé.
///
/// À lancer par un super-admin uniquement (l'écriture en masse est
/// permise par les rules pour ce rôle).
class PhoneIndexMigration {
  PhoneIndexMigration._();

  /// Lit tous les users, normalise leur téléphone et écrit l'entrée
  /// correspondante dans `phone_index`. Renvoie un résumé.
  static Future<MigrationResult> run() async {
    final snap = await FirestoreService.to.users.get();
    final users = snap.docs.map(UserModel.fromFirestore).toList();
    final repo = PhoneIndexRepository();

    var written = 0;
    var skipped = 0;
    var failed = 0;

    for (final user in users) {
      final normalized = PhoneNormalizer.normalize(user.telephone);
      if (normalized == null || user.email.isEmpty) {
        skipped++;
        continue;
      }
      try {
        await repo.setEntry(
          normalizedPhone: normalized,
          email: user.email,
          uid: user.id,
        );
        written++;
      } catch (_) {
        failed++;
      }
    }

    return MigrationResult(
      total: users.length,
      written: written,
      skipped: skipped,
      failed: failed,
    );
  }
}

class MigrationResult {
  final int total;
  final int written;
  final int skipped;
  final int failed;

  const MigrationResult({
    required this.total,
    required this.written,
    required this.skipped,
    required this.failed,
  });

  String get summary =>
      'Total: $total · Indexés: $written · Sans téléphone: $skipped · Erreurs: $failed';
}
