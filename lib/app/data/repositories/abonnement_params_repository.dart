import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/abonnement_params_model.dart';

/// Lecture / écriture du document singleton `parametres/abonnement`.
class AbonnementParamsRepository {
  final FirestoreService _fs = FirestoreService.to;

  Stream<AbonnementParamsModel> watch() {
    return _fs.abonnementParamsDoc
        .snapshots()
        .map((s) => s.exists
            ? AbonnementParamsModel.fromFirestore(s)
            : const AbonnementParamsModel())
        .permissionDeniedAsValue(const AbonnementParamsModel());
  }

  Future<AbonnementParamsModel> get() async {
    final snap = await _fs.abonnementParamsDoc.get();
    if (!snap.exists) return const AbonnementParamsModel();
    return AbonnementParamsModel.fromFirestore(snap);
  }

  Future<void> save(AbonnementParamsModel params) {
    return _fs.abonnementParamsDoc.set(params.toMap());
  }
}
