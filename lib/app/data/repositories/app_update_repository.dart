import '../../core/services/firestore_service.dart';
import '../models/app_update_config_model.dart';

/// Lecture / écriture du singleton `parametres/app_update`.
class AppUpdateRepository {
  final FirestoreService _fs = FirestoreService.to;

  Future<AppUpdateConfigModel> get() async {
    final snap = await _fs.appUpdateConfigDoc.get();
    if (!snap.exists) return const AppUpdateConfigModel();
    return AppUpdateConfigModel.fromFirestore(snap);
  }

  Future<void> save(AppUpdateConfigModel config) {
    return _fs.appUpdateConfigDoc.set(config.toMap());
  }
}
