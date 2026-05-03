import 'package:get/get.dart';

import '../controllers/client_detail_controller.dart';

class ClientDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClientDetailController>(() => ClientDetailController());
  }
}
