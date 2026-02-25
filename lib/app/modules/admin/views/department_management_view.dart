import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/department_management_controller.dart';

class DepartmentManagementView extends GetView<DepartmentManagementController> {
  const DepartmentManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Department & Class Management",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _showCreateDepartmentDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text("Add Department"),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateClassDialog,
                icon: const Icon(Icons.class_rounded),
                label: const Text("Add Class"),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildDepartmentsList(),
          const SizedBox(height: 16),
          _buildClassesList(),
        ],
      ),
    );
  }

  // ================= DEPARTMENTS =================

  Widget _buildDepartmentsList() {
    return _card(
      title: "Departments",
      child: Obx(() {
        if (controller.departments.isEmpty) {
          return _emptyState("No departments available");
        }

        return Column(
          children: controller.departments.map(_departmentItem).toList(),
        );
      }),
    );
  }

  Widget _departmentItem(Map<String, dynamic> dept) {
    return ListTile(
      title: Text(
        dept['name'] ?? '',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        "${dept['totalClasses'] ?? 0} classes",
        style: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      trailing: Wrap(
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.cyan),
            onPressed: () => _showEditDepartmentDialog(dept),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteDepartmentConfirmation(dept['id']),
          ),
        ],
      ),
    );
  }

  // ================= CLASSES =================

  Widget _buildClassesList() {
    return _card(
      title: "Classes",
      child: Obx(() {
        if (controller.classes.isEmpty) {
          return _emptyState("No classes available");
        }

        return Column(children: controller.classes.map(_classItem).toList());
      }),
    );
  }

  Widget _classItem(Map<String, dynamic> cls) {
    return ListTile(
      title: Text(
        cls['name'] ?? '',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        "${cls['totalStudents'] ?? 0} students",
        style: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      trailing: Wrap(
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.green),
            onPressed: () => _showEditClassDialog(cls),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteClassConfirmation(cls['id']),
          ),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white54)),
      ),
    );
  }

  // ================= DIALOGS =================

  void _showCreateDepartmentDialog() {
    controller.clearDepartmentForm();

    Get.dialog(
      _departmentDialog(
        title: "Create Department",
        onSubmit: () {
          controller.createDepartment(
            controller.deptNameController.text.trim(),
            controller.deptCodeController.text.trim(),
          );
        },
      ),
    );
  }

  void _showEditDepartmentDialog(Map<String, dynamic> dept) {
    controller.deptNameController.text = dept['name'] ?? '';
    controller.deptCodeController.text = dept['code'] ?? '';
    controller.selectedHOD.value = dept['hodId'];

    Get.dialog(
      _departmentDialog(
        title: "Edit Department",
        onSubmit: () {
          controller.updateDepartment(
            dept['id'],
            controller.deptNameController.text.trim(),
            controller.deptCodeController.text.trim(),
          );
        },
      ),
    );
  }

  Widget _departmentDialog({
    required String title,
    required VoidCallback onSubmit,
  }) {
    return Dialog(
      backgroundColor: const Color(0xFF302B63),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: controller.deptNameController,
                label: "Department Name",
                icon: Icons.business,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: controller.deptCodeController,
                label: "Department Code",
                icon: Icons.code,
              ),
              const SizedBox(height: 16),
              _buildHodDropdown(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: Get.back,
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onSubmit();
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9FF),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFF00D9FF)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildHodDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.selectedHOD.value,
        dropdownColor: const Color(0xFF1E1E2E),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: "HOD (Head of Department)",
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(
            Icons.person_outline,
            color: Color(0xFF00D9FF),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00D9FF)),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text(
              "No HOD assigned",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ...controller.hods.map(
            (h) => DropdownMenuItem<String>(
              value: h['id'],
              child: Text(
                h['name'],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
        onChanged: (v) => controller.selectedHOD.value = v,
      ),
    );
  }

  void _showDeleteDepartmentConfirmation(String id) {
    Get.defaultDialog(
      title: "Delete Department",
      middleText: "Are you sure?",
      onConfirm: () {
        controller.deleteDepartment(id);
        Get.back();
      },
      textConfirm: "Delete",
      confirmTextColor: Colors.white,
    );
  }

  // ================= CLASS DIALOGS =================

  void _showCreateClassDialog() {
    controller.clearClassForm();
    Get.dialog(
      _classDialog(
        title: "Create Class",
        onSubmit: () {
          controller.createClass(
            controller.classNameController.text.trim(),
            controller.selectedDepartmentForClass.value!,
          );
        },
      ),
    );
  }

  void _showEditClassDialog(Map<String, dynamic> cls) {
    controller.classNameController.text = cls['name'] ?? '';
    controller.selectedDepartmentForClass.value = cls['departmentId'];
    controller.selectedTeacher.value = cls['facultyAdvisorUid'];

    Get.dialog(
      _classDialog(
        title: "Edit Class",
        onSubmit: () {
          controller.updateClass(
            cls['id'],
            controller.classNameController.text.trim(),
            controller.selectedDepartmentForClass.value!,
          );
        },
      ),
    );
  }

  Widget _classDialog({required String title, required VoidCallback onSubmit}) {
    return Dialog(
      backgroundColor: const Color(0xFF302B63),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: controller.classNameController,
                label: "Class Name",
                icon: Icons.class_rounded,
              ),
              const SizedBox(height: 16),
              _buildDepartmentDropdown(),
              const SizedBox(height: 16),
              _buildFacultyAdvisorDropdown(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: Get.back,
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.selectedDepartmentForClass.value ==
                            null) {
                          Get.snackbar(
                            "Error",
                            "Please select a department",
                            backgroundColor: const Color(0xFFD32F2F),
                            colorText: Colors.white,
                            snackPosition: SnackPosition.TOP,
                          );
                          return;
                        }
                        onSubmit();
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9FF),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.selectedDepartmentForClass.value,
        dropdownColor: const Color(0xFF1E1E2E),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: "Department",
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.business, color: Color(0xFF00D9FF)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00D9FF)),
        items: controller.departments
            .map(
              (d) => DropdownMenuItem<String>(
                value: d['id'],
                child: Text(
                  d['name'],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => controller.selectedDepartmentForClass.value = v,
      ),
    );
  }

  Widget _buildFacultyAdvisorDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.selectedTeacher.value,
        dropdownColor: const Color(0xFF1E1E2E),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: "Faculty Advisor",
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.school, color: Color(0xFF00D9FF)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00D9FF)),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text(
              "No advisor assigned",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ...controller.teachers.map(
            (t) => DropdownMenuItem<String>(
              value: t['id'],
              child: Text(
                t['name'],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
        onChanged: (v) => controller.selectedTeacher.value = v,
      ),
    );
  }

  void _showDeleteClassConfirmation(String id) {
    Get.defaultDialog(
      title: "Delete Class",
      middleText: "Are you sure?",
      onConfirm: () {
        controller.deleteClass(id);
        Get.back();
      },
      textConfirm: "Delete",
      confirmTextColor: Colors.white,
    );
  }
}
