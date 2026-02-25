import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/edit_attendance_controller.dart';

class EditAttendanceView extends GetView<EditAttendanceController> {
  const EditAttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          "Edit Attendance",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        return Column(
          children: [
            // Header with class and period info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[700]!, Colors.orange[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Editing Mode",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${controller.classId} - ${controller.period}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Time: ${controller.periodTimes[controller.period]}",
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Date: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(controller.date))}",
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Student list
            Expanded(
              child: GetBuilder<EditAttendanceController>(
                builder: (controller) => ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: controller.students.length,
                  itemBuilder: (context, index) {
                    final student = controller.students[index];
                    final uid = student['uid'] as String;
                    final name = student['name'] as String;
                    final isPresent = controller.attendance[uid] ?? true;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Leading Avatar
                            CircleAvatar(
                              backgroundColor: isPresent
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              child: Icon(
                                isPresent ? Icons.check : Icons.close,
                                color: isPresent
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Student Name
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Present button
                                InkWell(
                                  onTap: () =>
                                      controller.toggleAttendance(uid, true),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPresent
                                          ? Colors.green
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Present',
                                      style: TextStyle(
                                        color: isPresent
                                            ? Colors.white
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Absent button
                                InkWell(
                                  onTap: () =>
                                      controller.toggleAttendance(uid, false),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isPresent
                                          ? Colors.red
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Absent',
                                      style: TextStyle(
                                        color: !isPresent
                                            ? Colors.white
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
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

            // Save button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF16213E)),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Update Attendance",
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
    );
  }
}
