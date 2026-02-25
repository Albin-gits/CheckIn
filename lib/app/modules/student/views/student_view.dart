import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:check_in_app/app/routes/app_pages.dart';
import '../controllers/student_controller.dart';

class StudentView extends GetView<StudentController> {
  const StudentView({super.key});

  // Map periods to human-readable time ranges
  static const Map<String, String> periodTimes = {
    'P1': '8:30 to 9:25',
    'P2': '9:30 to 10:20',
    'P3': '10:40 to 11:35',
    'P4': '11:40 to 12:30',
    'P5': '12:35 to 1:35',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => WillPopScope(
        onWillPop: () async {
          if (controller.isMenuOpen.value) {
            controller.isMenuOpen.value = false;
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF16213E),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                controller.isMenuOpen.value
                    ? Icons.close_rounded
                    : Icons.menu_rounded,
                color: Colors.white,
              ),
              onPressed: controller.toggleMenu,
            ),
            title: const Text(
              "Student Dashboard",
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                onPressed: controller.showLogoutConfirmation,
              ),
            ],
          ),
          body: SizedBox.expand(
            child: Stack(
              children: [
                // MAIN CONTENT
                SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Welcome Back!",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  controller.studentName.value.isEmpty
                                      ? "Student"
                                      : controller.studentName.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Class: ${controller.className.value.isNotEmpty ? controller.className.value : (controller.classId.value.isNotEmpty ? controller.classId.value : 'N/A')}",
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Attendance Summary Section
                          _buildAttendanceSummary(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // GLASS SIDEBAR (MUST be after main content)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: 0,
                  bottom: 0,
                  left: controller.isMenuOpen.value
                      ? 0
                      : -MediaQuery.of(context).size.width * 0.75,
                  width: MediaQuery.of(context).size.width * 0.75,
                  child: _buildGlassSidebar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // Glass Morphism Sidebar
  Widget _buildGlassSidebar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            border: Border(
              right: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Profile Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[700],
                      child: Text(
                        controller.studentName.value.isNotEmpty
                            ? controller.studentName.value[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.studentName.value.isEmpty
                          ? "Student"
                          : controller.studentName.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.studentEmail.value,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sidebarItem(Icons.home, "Dashboard", null),
                    _sidebarItem(
                      Icons.assignment,
                      "My Attendance",
                      Routes.STUDENT_ATTENDANCE,
                    ),
                    _sidebarItem(
                      Icons.calendar_today,
                      "My Timetable",
                      Routes.STUDENT_TIMETABLE,
                    ),
                    _sidebarItem(
                      Icons.request_page,
                      "Leave Request",
                      Routes.LEAVE_REQUEST,
                    ),
                    const Divider(color: Colors.white24),
                    _sidebarItem(
                      Icons.person,
                      "Profile",
                      Routes.STUDENT_PROFILE,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sidebar Item
  Widget _sidebarItem(
    IconData icon,
    String title,
    String? route, {
    bool comingSoon = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: () {
        controller.isMenuOpen.value = false;
        if (comingSoon) {
          Get.snackbar(
            'Info',
            '$title - Coming Soon',
            backgroundColor: const Color(0xFF16213E),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        } else if (route != null) {
          Get.toNamed(route);
        }
      },
    );
  }

  // Day Selector
  Widget _buildDaySelector() {
    final dayLabels = [
      {'key': 'mon', 'label': 'Monday'},
      {'key': 'tue', 'label': 'Tuesday'},
      {'key': 'wed', 'label': 'Wednesday'},
      {'key': 'thu', 'label': 'Thursday'},
      {'key': 'fri', 'label': 'Friday'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Day:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: controller.selectedDay.value,
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: dayLabels.map((day) {
                  return DropdownMenuItem<String>(
                    value: day['key'],
                    child: Text(
                      day['label']!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.onDayChanged(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Timetable Widget
  Widget _buildTimetable() {
    if (controller.isLoadingTimetable.value) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: List.generate(5, (index) => _buildSkeletonPeriod()),
        ),
      );
    }

    if (controller.timetable.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.event_busy, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                controller.classId.value.isEmpty ||
                        controller.departmentId.value.isEmpty
                    ? 'Student class/department not configured'
                    : 'No timetable found for ${controller.dayLabel(controller.selectedDay.value)}',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (controller.classId.value.isNotEmpty &&
                  controller.departmentId.value.isNotEmpty) ...[
                Text(
                  'Class: ${controller.className.value} (${controller.classId.value})',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Department: ${controller.departmentId.value}',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'HOD needs to create the timetable for this class',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.7),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: controller.timetable.asMap().entries.map((entry) {
          final index = entry.key;
          final period = entry.value;
          final isLast = index == controller.timetable.length - 1;
          final hasClass = period['hasClass'] == true;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasClass
                        ? const Color(0xFF2196F3).withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasClass
                          ? const Color(0xFF2196F3).withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    period['period']?.toString() ?? '',
                    style: TextStyle(
                      color: hasClass ? const Color(0xFF2196F3) : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasClass
                            ? (period['subject']?.toString() ?? 'No Subject')
                            : 'Free Period',
                        style: TextStyle(
                          color: hasClass ? Colors.white : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasClass) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Time: ${periodTimes[period['period']?.toString() ?? ''] ?? 'Unknown'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Day Summary Card Widget
  Widget _buildDaySummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  // Skeleton loading for periods
  Widget _buildSkeletonPeriod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Attendance Summary Widget
  Widget _buildAttendanceSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Attendance Percentage Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: controller.overallAttendancePercentage.value >= 75
                  ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
                  : controller.overallAttendancePercentage.value >= 65
                  ? [const Color(0xFFF57C00), const Color(0xFFFFB74D)]
                  : [const Color(0xFFC62828), const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (controller.overallAttendancePercentage.value >= 75
                            ? Colors.green
                            : Colors.orange)
                        .withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Consolidated Attendance Percentage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.overallAttendancePercentage.value.toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.totalDayCredits.value.toStringAsFixed(1)} / ${controller.totalWorkingDays.value} days',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Day-wise Attendance Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildDaySummaryCard(
                icon: Icons.check_circle,
                label: 'Full Days',
                value: '${controller.fullDayPresentCount.value}',
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDaySummaryCard(
                icon: Icons.timelapse,
                label: 'Half Days',
                value: '${controller.halfDayPresentCount.value}',
                color: const Color(0xFFFF9800),
                subtitle: '1 period absent',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDaySummaryCard(
                icon: Icons.cancel,
                label: 'Absent',
                value: '${controller.fullDayAbsentCount.value}',
                color: const Color(0xFFF44336),
                subtitle: '2+ periods',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Attendance Table
        if (controller.isLoadingAttendance.value)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            ),
          )
        else if (controller.subjectAttendance.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(
              child: Text(
                'No attendance records found',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C75),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '#',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Course',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Actual Hrs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Att. by Me',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Rows
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.subjectAttendance.length,
                  itemBuilder: (context, index) {
                    final item = controller.subjectAttendance[index];
                    final isLast =
                        index == controller.subjectAttendance.length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: isLast
                              ? BorderSide.none
                              : BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item['subject'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['totalHours'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['attendedHours'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
