import 'package:get/get.dart';

import '../controllers/caisses_controller.dart';

class CaissesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CaissesController>(() => CaissesController());
  }
}
