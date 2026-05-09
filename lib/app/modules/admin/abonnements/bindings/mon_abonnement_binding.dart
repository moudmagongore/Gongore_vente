import 'package:get/get.dart';

import '../controllers/mon_abonnement_controller.dart';

class MonAbonnementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MonAbonnementController>(() => MonAbonnementController());
  }
}
