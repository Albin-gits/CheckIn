import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/user_management_controller.dart';

class UserManagementView extends GetView<UserManagementController> {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildUserTypeTabs(),
          const SizedBox(height: 16),
          Obx(() => _buildUsersList()),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          "User Management",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Color(0xFF00D9FF)),
          onPressed: _showCreateUserDialog,
        ),
      ],
    );
  }

  // ================= USER TYPE TABS =================

  Widget _buildUserTypeTabs() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Obx(
        () => Row(
          children: [_tab("Teachers", 0), _tab("Students", 1), _tab("HODs", 2)],
        ),
      ),
    );
  }

  Widget _tab(String title, int index) {
    final selected = controller.selectedUserType.value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.changeUserType(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? const Color(0xFF00D9FF) : Colors.transparent,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // ================= USERS LIST =================

  Widget _buildUsersList() {
    if (controller.isLoading.value) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
      );
    }

    if (controller.users.isEmpty) {
      return const Text(
        "No users found",
        style: TextStyle(color: Colors.white70),
      );
    }

    return Column(children: controller.users.map(_userCard).toList());
  }

  // ================= USER CARD =================

  Widget _userCard(Map<String, dynamic> user) {
    final isActive = user['isActive'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF00D9FF).withOpacity(0.2),
                child: Text(
                  user['name'] != null
                      ? user['name'].toString()[0].toUpperCase()
                      : "U",
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
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
                      user['name'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user['email'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(isActive),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: isActive ? const Color(0xFF00D9FF) : Colors.grey,
                ),
                onPressed: () =>
                    controller.toggleUserStatus(user['uid'], isActive),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF00D9FF)),
                onPressed: () => _showEditUserDialog(user),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isActive
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
      ),
      child: Text(
        isActive ? "Active" : "Inactive",
        style: TextStyle(
          fontSize: 11,
          color: isActive ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ================= CREATE USER =================

  void _showCreateUserDialog() {
    controller.clearForm();

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF302B63),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Add User",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _textField(controller.nameController, "Name"),
                const SizedBox(height: 16),
                _textField(controller.emailController, "Email"),
                const SizedBox(height: 16),
                Obx(
                  () => TextField(
                    controller: controller.passwordController,
                    obscureText: !controller.isPasswordVisible.value,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00D9FF)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: controller.togglePasswordVisibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _roleSpecificDropdowns(),
                const SizedBox(height: 16),
                // Roll No field - only for students
                Obx(() {
                  if (controller.selectedUserType.value == 1) {
                    // Only show for students
                    return Column(
                      children: [
                        _textField(controller.rollNoController, "Roll No"),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
                // Admin password for re-authentication
                Obx(
                  () => TextField(
                    controller: controller.adminPasswordController,
                    obscureText: !controller.isAdminPasswordVisible.value,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Your Admin Password",
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: "Required to re-authenticate",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.orange.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isAdminPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: controller.toggleAdminPasswordVisibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _dialogButtons(
                  onConfirm: () {
                    controller.createUserFromDialog();
                  },
                  confirmText: "Create",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= EDIT USER =================

  void _showEditUserDialog(Map<String, dynamic> user) {
    controller.populateForEdit(user);

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF302B63),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Edit User",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _textField(controller.nameController, "Name"),
                const SizedBox(height: 16),
                _roleSpecificDropdowns(),
                // Roll No field - only for students in edit
                Obx(() {
                  if (controller.selectedUserType.value == 1) {
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        _textField(controller.rollNoController, "Roll No"),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 20),
                _dialogButtons(
                  onConfirm: () {
                    controller.updateUserFromDialog(user['uid']);
                  },
                  confirmText: "Update",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= FORM HELPERS =================

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF00D9FF)),
        ),
      ),
    );
  }

  Widget _roleSpecificDropdowns() {
    return Obx(() {
      // Teachers (type 0): Department + Multi-class selection
      if (controller.selectedUserType.value == 0) {
        return Column(
          children: [
            _departmentDropdown(),
            const SizedBox(height: 16),
            _multiClassSelection(),
          ],
        );
      }
      // Students (type 1): Class dropdown only (department auto-resolved from class)
      else if (controller.selectedUserType.value == 1) {
        return _classDropdown();
      }
      // HODs (type 2): Department dropdown
      else {
        return _departmentDropdown();
      }
    });
  }

  Widget _multiClassSelection() {
    return Obx(
      () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF7C4DFF).withOpacity(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Classes (Select multiple)",
              style: TextStyle(color: Color(0xFFB388FF), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.classes.map((c) {
                final isSelected = controller.selectedClassIds.contains(
                  c['id'],
                );
                return FilterChip(
                  label: Text(
                    c['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => controller.toggleClassSelection(c['id']),
                  backgroundColor: const Color(0xFF1E1E2E),
                  selectedColor: const Color(0xFF7C4DFF),
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF7C4DFF)
                        : Colors.white.withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _departmentDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.selectedDepartment.value,
        dropdownColor: const Color(0xFF1E1E2E),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: "Department",
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00D9FF), width: 2),
            borderRadius: BorderRadius.all(Radius.circular(8)),
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
        onChanged: (v) => controller.selectedDepartment.value = v,
      ),
    );
  }

  Widget _classDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: controller.selectedClass.value,
        dropdownColor: const Color(0xFF1E1E2E),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: "Class",
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00D9FF), width: 2),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00D9FF)),
        items: controller.classes
            .map(
              (c) => DropdownMenuItem<String>(
                value: c['id'],
                child: Text(
                  c['name'],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => controller.selectedClass.value = v,
      ),
    );
  }

  Widget _dialogButtons({
    required VoidCallback onConfirm,
    required String confirmText,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextButton(onPressed: Get.back, child: const Text("Cancel")),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(onPressed: onConfirm, child: Text(confirmText)),
        ),
      ],
    );
  }
}
