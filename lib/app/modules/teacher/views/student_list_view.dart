import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/student_list_controller.dart';

class StudentListView extends GetView<StudentListController> {
  const StudentListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text("My Students", style: TextStyle(color: Colors.white)),
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
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
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

          // Student Count
          Obx(
            () => controller.students.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.groups, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Total Students: ${controller.students.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(),
          ),

          const SizedBox(height: 16),

          // Student List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.purple),
                );
              }

              // Show message for non-faculty advisors
              if (!controller.isFacultyAdvisor.value) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            size: 60,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Faculty Advisor Access Only',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Only the Faculty Advisor can view the complete student list for this class.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[400],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are a regular teacher for ${controller.selectedClassId.value}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (controller.students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No students found',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.students.length,
                itemBuilder: (_, i) {
                  final s = controller.students[i];
                  return Card(
                    color: const Color(0xFF16213E),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple[700],
                        child: Text(
                          s['name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        s['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        s['email'],
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      trailing: Icon(Icons.person, color: Colors.purple[300]),
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
