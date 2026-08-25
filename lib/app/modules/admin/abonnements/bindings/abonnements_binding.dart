import 'package:get/get.dart';

import '../controllers/abonnements_controller.dart';

class AbonnementsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AbonnementsController>(() => AbonnementsController());
  }
}
