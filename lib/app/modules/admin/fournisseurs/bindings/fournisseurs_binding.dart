import 'package:get/get.dart';

import '../controllers/fournisseurs_controller.dart';

class FournisseursBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FournisseursController>(() => FournisseursController());
  }
}
