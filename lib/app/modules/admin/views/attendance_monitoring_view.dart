import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/attendance_monitoring_controller.dart';

class AttendanceMonitoringView extends GetView<AttendanceMonitoringController> {
  const AttendanceMonitoringView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => controller.isLoading.value
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _dateChip(),
                  const SizedBox(height: 20),
                  _statsSection(),
                  const SizedBox(height: 20),
                  _departmentSection(),
                  const SizedBox(height: 20),
                  _classSection(),
                ],
              ),
            ),
    );
  }

  // 🔹 HEADER
  Widget _header() {
    return const Text(
      "Attendance Monitoring",
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // 🔹 DATE
  Widget _dateChip() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: Get.context!,
          initialDate: controller.selectedDate.value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF00D9FF),
                  onPrimary: Colors.black,
                  surface: Color(0xFF302B63),
                  onSurface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          controller.changeDate(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Color(0xFF00D9FF),
            ),
            const SizedBox(width: 6),
            Obx(
              () => Text(
                controller.getFormattedDate(),
                style: const TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 STATS (VERTICAL)
  Widget _statsSection() {
    return Obx(
      () => Column(
        children: [
          _statCard(
            "Overall Attendance",
            "${controller.overallAttendance.value.toStringAsFixed(1)}%",
            Icons.trending_up_rounded,
            controller.overallAttendance.value >= 75
                ? const Color(0xFF4CAF50)
                : Colors.orange,
          ),
          const SizedBox(height: 12),
          _statCard(
            "Classes Marked",
            "${controller.classesMarked.value} / ${controller.totalClasses.value}",
            Icons.check_circle_rounded,
            const Color(0xFF00D9FF),
          ),
          const SizedBox(height: 12),
          _statCard(
            "Defaulters",
            "${controller.totalDefaulters.value}",
            Icons.warning_rounded,
            const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return _card(
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 DEPARTMENT SECTION
  Widget _departmentSection() {
    return _section(
      title: "Department-wise Attendance",
      child: Obx(() {
        if (controller.departmentAttendance.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "No department data available",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return Column(
          children: controller.departmentAttendance.map((dept) {
            final percentage = double.tryParse(dept['percentage']) ?? 0;
            Color color;
            if (percentage >= 80) {
              color = Colors.green;
            } else if (percentage >= 75) {
              color = const Color(0xFF00D9FF);
            } else {
              color = Colors.orange;
            }

            return _departmentItem(
              dept['name'],
              dept['percentage'] + '%',
              color,
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _departmentItem(String name, String percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Row(
          children: [
            _iconBox(Icons.business_rounded, color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _percentageChip(percent, color),
          ],
        ),
      ),
    );
  }

  // 🔹 CLASS SECTION
  Widget _classSection() {
    return _section(
      title: "Today's Class Attendance",
      child: Obx(() {
        if (controller.todaysClassAttendance.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "No class attendance data for today",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return Column(
          children: controller.todaysClassAttendance.map((cls) {
            return _classCard(cls['name'], cls['present'], cls['absent']);
          }).toList(),
        );
      }),
    );
  }

  Widget _classCard(String name, int present, int absent) {
    final total = present + absent;
    final percent = ((present / total) * 100).toStringAsFixed(1);
    final good = double.parse(percent) >= 75;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Present: $present   Absent: $absent",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _percentageChip("$percent%", good ? Colors.green : Colors.red),
          ],
        ),
      ),
    );
  }

  // 🔹 COMMON UI
  Widget _section({required String title, required Widget child}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _percentageChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
