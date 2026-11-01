import 'package:get/get.dart';

import '../controllers/releve_caisse_controller.dart';

class ReleveCaisseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReleveCaisseController>(() => ReleveCaisseController());
  }
}
