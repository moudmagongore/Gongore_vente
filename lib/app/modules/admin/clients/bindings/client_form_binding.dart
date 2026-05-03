import 'package:get/get.dart';

import '../controllers/client_form_controller.dart';

class ClientFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClientFormController>(() => ClientFormController());
  }
}
