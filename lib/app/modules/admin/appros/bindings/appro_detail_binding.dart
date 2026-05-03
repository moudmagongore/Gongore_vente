import 'package:get/get.dart';

import '../controllers/appro_detail_controller.dart';

class ApproDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApproDetailController>(() => ApproDetailController());
  }
}
