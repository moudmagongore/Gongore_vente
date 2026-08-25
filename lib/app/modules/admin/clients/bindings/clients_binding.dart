import 'package:get/get.dart';

import '../controllers/clients_controller.dart';

class ClientsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ClientsController>(() => ClientsController());
  }
}
