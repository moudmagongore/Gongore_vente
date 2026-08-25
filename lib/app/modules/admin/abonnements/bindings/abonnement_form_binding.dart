import 'package:get/get.dart';

import '../controllers/abonnement_form_controller.dart';

class AbonnementFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AbonnementFormController>(() => AbonnementFormController());
  }
}
