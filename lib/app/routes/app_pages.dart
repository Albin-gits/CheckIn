import 'package:get/get.dart';

import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/views/auth_gate.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';

import '../modules/admin/bindings/admin_binding.dart';
import '../modules/admin/views/admin_dashboard_view.dart';
import '../modules/hod/views/hod_view.dart';
import '../modules/hod/views/hod_timetable_view.dart';
import '../modules/hod/views/teacher_management_view.dart';
import '../modules/hod/views/student_management_view.dart';
import '../modules/hod/views/class_management_view.dart';
import '../modules/hod/views/hod_settings_view.dart';
import '../modules/hod/bindings/hod_timetable_binding.dart';
import '../modules/student/views/student_profile_view.dart';
import '../modules/student/views/student_attendance_view.dart';
import '../modules/student/views/student_timetable_view.dart';
import '../modules/student/views/leave_request_view.dart';
import '../modules/student/views/student_view.dart';
import '../modules/student/bindings/student_binding.dart';
import '../modules/teacher/views/teacher_view.dart';
import '../modules/teacher/views/attendance_view.dart';
import '../modules/teacher/bindings/attendance_binding.dart';
import '../modules/teacher/bindings/attendance_history_binding.dart';
import '../modules/teacher/bindings/student_list_binding.dart';
import '../modules/teacher/bindings/teacher_profile_binding.dart';
import '../modules/teacher/bindings/editable_attendance_list_binding.dart';
import '../modules/teacher/bindings/edit_attendance_binding.dart';
import '../modules/teacher/bindings/attendance_detail_binding.dart';
import '../modules/teacher/bindings/teacher_reports_binding.dart';
import '../modules/teacher/views/attendance_history_view.dart';
import '../modules/teacher/views/student_list_view.dart';
import '../modules/teacher/views/teacher_profile_view.dart';
import '../modules/teacher/views/editable_attendance_list_view.dart';
import '../modules/teacher/views/edit_attendance_view.dart';
import '../modules/teacher/views/attendance_detail_view.dart';
import '../modules/teacher/views/leave_management_view.dart';
import '../modules/teacher/views/teacher_reports_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  // App starts from AuthGate which checks login state
  static const INITIAL = Routes.AUTH_GATE;

  static final routes = [
    // 🔐 Auth Gate - Checks if user is logged in
    GetPage(name: Routes.AUTH_GATE, page: () => const AuthGate()),

    // 🔐 Login
    GetPage(
      name: Routes.AUTH,
      page: () => const AuthView(),
      binding: AuthBinding(),
    ),

    // 🏠 Generic Home (optional, router later)
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),

    // 👑 Admin Dashboard
    GetPage(
      name: Routes.ADMIN,
      page: () => const AdminDashboardView(),
      binding: AdminBinding(),
    ),

    // 🏢 HOD Dashboard
    GetPage(name: Routes.HOD, page: () => const HodView()),

    // 🗓️ HOD Timetable (Mon-Fri, permanent)
    GetPage(
      name: Routes.HOD_TIMETABLE,
      page: () => const HodTimetableView(),
      binding: HodTimetableBinding(),
    ),

    //  HOD Teacher Management
    GetPage(
      name: Routes.HOD_TEACHER_MANAGEMENT,
      page: () => const TeacherManagementView(),
    ),

    // 🎓 HOD Student Management
    GetPage(
      name: Routes.HOD_STUDENT_MANAGEMENT,
      page: () => const StudentManagementView(),
    ),

    // 🏫 HOD Class Management
    GetPage(
      name: Routes.HOD_CLASS_MANAGEMENT,
      page: () => const ClassManagementView(),
    ),

    // ⚙️ HOD Settings
    GetPage(name: Routes.HOD_SETTINGS, page: () => const HodSettingsView()),

    // 🎓 Student Dashboard
    GetPage(
      name: Routes.STUDENT,
      page: () => const StudentView(),
      binding: StudentBinding(),
    ),

    // 👤 Student Profile
    GetPage(
      name: Routes.STUDENT_PROFILE,
      page: () => const StudentProfileView(),
    ),

    // 📊 Student Attendance
    GetPage(
      name: Routes.STUDENT_ATTENDANCE,
      page: () => const StudentAttendanceView(),
    ),

    // � Student Timetable
    GetPage(
      name: Routes.STUDENT_TIMETABLE,
      page: () => const StudentTimetableView(),
    ),

    // �📝 Leave Request
    GetPage(name: Routes.LEAVE_REQUEST, page: () => const LeaveRequestView()),

    // 👩‍🏫 Teacher Dashboard
    GetPage(name: Routes.TEACHER, page: () => const TeacherView()),

    // 📋 Mark Attendance
    GetPage(
      name: Routes.TEACHER_ATTENDANCE,
      page: () => const AttendanceView(),
      binding: AttendanceBinding(),
    ),

    // 📅 Attendance History
    GetPage(
      name: Routes.ATTENDANCE_HISTORY,
      page: () => const AttendanceHistoryView(),
      binding: AttendanceHistoryBinding(),
    ),

    // 📋 Attendance Detail
    GetPage(
      name: Routes.ATTENDANCE_DETAIL,
      page: () => const AttendanceDetailView(),
      binding: AttendanceDetailBinding(),
    ),

    // 👨‍🎓 Student List
    GetPage(
      name: Routes.STUDENT_LIST,
      page: () => const StudentListView(),
      binding: StudentListBinding(),
    ),

    // 👤 Teacher Profile
    GetPage(
      name: Routes.TEACHER_PROFILE,
      page: () => const TeacherProfileView(),
      binding: TeacherProfileBinding(),
    ),

    // ✏️ Editable Attendance List
    GetPage(
      name: Routes.EDITABLE_ATTENDANCE_LIST,
      page: () => const EditableAttendanceListView(),
      binding: EditableAttendanceListBinding(),
    ),

    // 📝 Edit Attendance
    GetPage(
      name: Routes.EDIT_ATTENDANCE,
      page: () => const EditAttendanceView(),
      binding: EditAttendanceBinding(),
    ),

    // 📋 Leave Management (Faculty Advisor)
    GetPage(
      name: Routes.LEAVE_MANAGEMENT,
      page: () => const LeaveManagementView(),
    ),

    // 📊 Teacher Reports (Faculty Advisor)
    GetPage(
      name: Routes.TEACHER_REPORTS,
      page: () => const TeacherReportsView(),
      binding: TeacherReportsBinding(),
    ),
  ];
}
