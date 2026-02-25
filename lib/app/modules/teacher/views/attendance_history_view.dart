import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/attendance_history_controller.dart';

class AttendanceHistoryView extends GetView<AttendanceHistoryController> {
  const AttendanceHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          "Attendance History",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Class Selector
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
                          child: Text(classId),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => controller.changeClass(v!),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                );
              }

              if (controller.history.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[600]),
                        const SizedBox(height: 24),
                        Text(
                          'No Attendance History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No attendance records found for this class in the last 30 days.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.history.length,
                itemBuilder: (context, index) {
                  final h = controller.history[index];
                  final periods = h['periods'] as List;

                  return Card(
                    color: const Color(0xFF16213E),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Get.toNamed(
                          '/attendance-detail',
                          parameters: {
                            'classId': controller.selectedClassId.value,
                            'date': h['date'],
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: Colors.blue[300],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h['date'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${h['periodCount']} period(s): ${periods.join(", ")}',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
