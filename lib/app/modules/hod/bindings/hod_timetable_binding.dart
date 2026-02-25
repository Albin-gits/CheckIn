import 'package:get/get.dart';

import '../controllers/hod_timetable_controller.dart';

class HodTimetableBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HodTimetableController>(() => HodTimetableController());
  }
}
