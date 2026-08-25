import 'package:get/get.dart';

import '../controllers/abonnement_params_controller.dart';

class AbonnementParamsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AbonnementParamsController>(
        () => AbonnementParamsController());
  }
}
