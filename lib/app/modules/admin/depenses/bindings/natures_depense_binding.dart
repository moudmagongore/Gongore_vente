import 'package:get/get.dart';

import '../controllers/natures_depense_controller.dart';

class NaturesDepenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NaturesDepenseController>(() => NaturesDepenseController());
  }
}
