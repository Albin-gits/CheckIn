import 'package:get/get.dart';
import '../controllers/editable_attendance_list_controller.dart';

class EditableAttendanceListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EditableAttendanceListController>(
      () => EditableAttendanceListController(),
    );
  }
}
