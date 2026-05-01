import 'package:get/get.dart';

import '../controllers/rapports_controller.dart';

class RapportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RapportsController>(() => RapportsController());
  }
}
