import 'package:get/get.dart';

import '../controllers/appros_controller.dart';

class ApprosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApprosController>(() => ApprosController());
  }
}
