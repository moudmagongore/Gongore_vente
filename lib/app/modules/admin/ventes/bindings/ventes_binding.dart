import 'package:get/get.dart';

import '../controllers/ventes_controller.dart';

class VentesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VentesController>(() => VentesController());
  }
}
