import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/attendance_controller.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  final Map<String, String> periodTimes = const {
    'P1': '8:30 to 9:25',
    'P2': '9:30 to 10:20',
    'P3': '10:40 to 11:35',
    'P4': '11:40 to 12:30',
    'P5': '12:35 to 1:35',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          "Mark Attendance",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Date Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Class Dropdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(
              () => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: DropdownButton<String>(
                  value: controller.selectedClassId.value.isEmpty
                      ? null
                      : controller.selectedClassId.value,
                  hint: const Text(
                    "Select Class",
                    style: TextStyle(color: Colors.white70),
                  ),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF16213E),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  items: controller.classList
                      .map(
                        (classId) => DropdownMenuItem(
                          value: classId,
                          child: Text(
                            controller.classNames[classId] ?? classId,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => controller.changeClass(v!),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Obx(
                    () => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: DropdownButton<String>(
                        value:
                            controller.availablePeriods.contains(
                              controller.selectedPeriod.value,
                            )
                            ? controller.selectedPeriod.value
                            : (controller.availablePeriods.isNotEmpty
                                  ? controller.availablePeriods[0]
                                  : null),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF16213E),
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                        ),
                        items: controller.availablePeriods
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text("$p - ${periodTimes[p]}"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => controller.changePeriod(v!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() {
                    // Show loading indicator while checking authorization
                    if (controller.isCheckingAuth.value) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00D9FF)),
                            SizedBox(height: 16),
                            Text(
                              'Checking authorization...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    }

                    // Check if teacher is authorized for this class/period
                    if (!controller.isAuthorized.value) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: Colors.orange[400],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Not Authorized',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'You are not assigned to teach ${controller.classNames[controller.selectedClassId.value] ?? controller.selectedClassId.value} during ${controller.selectedPeriod.value}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Show assigned slots
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16213E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: Colors.green[400],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Your Assignments Today',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Obx(
                                    () => Text(
                                      controller.assignedSlotInfo.value,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info box
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16213E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue[300],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'How to Mark Attendance',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '1. Select the correct class from the dropdown above\n'
                                    '2. Select the period you are assigned to\n'
                                    '3. You can only mark attendance for your assigned slots',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Contact your HOD for timetable changes or substitution requests.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Check if attendance has already been saved
                    if (controller.isAttendanceSaved.value) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 80,
                                color: Colors.green[400],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Attendance Already Saved',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                controller.selectedPeriod.value,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                periodTimes[controller.selectedPeriod.value] ??
                                    '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Flexible(
                                child: Text(
                                  'Attendance for this period has already been marked and saved.',
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child: Text(
                                  'To make changes, use the "Edit Today\'s Attendance" option.',
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Check if the selected period is active
                    final isActive = controller.isPeriodActive(
                      controller.selectedPeriod.value,
                    );

                    if (!isActive) {
                      // Show message when period is not active
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                controller.selectedPeriod.value,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                periodTimes[controller.selectedPeriod.value] ??
                                    '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                controller.getPeriodMessage(
                                  controller.selectedPeriod.value,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Show student list when period is active
                    return Column(
                      children: [
                        Expanded(
                          child: GetBuilder<AttendanceController>(
                            builder: (controller) => ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: controller.students.length,
                              itemBuilder: (_, i) {
                                final s = controller.students[i];
                                final present =
                                    controller.attendance[s['uid']] ?? true;

                                return Card(
                                  color: const Color(0xFF16213E),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s['name'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Radio<bool>(
                                              value: true,
                                              groupValue: present,
                                              activeColor: Colors.green,
                                              onChanged: (_) =>
                                                  controller.toggleAttendance(
                                                    s['uid'],
                                                    true,
                                                  ),
                                            ),
                                            const Text(
                                              'P',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Radio<bool>(
                                              value: false,
                                              groupValue: present,
                                              activeColor: Colors.red,
                                              onChanged: (_) =>
                                                  controller.toggleAttendance(
                                                    s['uid'],
                                                    false,
                                                  ),
                                            ),
                                            const Text(
                                              'A',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: controller.saveAttendance,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Save Attendance",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
