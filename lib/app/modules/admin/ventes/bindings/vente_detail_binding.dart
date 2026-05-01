import 'package:get/get.dart';

import '../controllers/vente_detail_controller.dart';

class VenteDetailBinding extends Bindings {
  @override
  void dependencies() {
    // `put` (eager) plutôt que lazyPut : la VenteDetailView lit le controller
    // mais on s'assure que les fetchs onInit démarrent immédiatement.
    Get.put<VenteDetailController>(VenteDetailController());
  }
}
