import 'package:get/get.dart';

import '../controllers/mouvement_controller.dart';

class MouvementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MouvementController>(() => MouvementController());
  }
}
