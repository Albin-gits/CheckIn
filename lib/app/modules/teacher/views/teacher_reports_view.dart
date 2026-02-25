import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/teacher_reports_controller.dart';
import 'teacher_student_report_view.dart';
import 'teacher_class_report_view.dart';

class TeacherReportsView extends GetView<TeacherReportsController> {
  const TeacherReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
              )
            : controller.advisorClasses.isEmpty
            ? _buildNoAccessView()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    _advisorInfo(),
                    const SizedBox(height: 16),
                    _analyticsCards(),
                    const SizedBox(height: 16),
                    _exportButton(context),
                    const SizedBox(height: 20),
                    _reportTypes(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNoAccessView() {
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
              'Reports are only available for Faculty Advisors. You are not assigned as a Faculty Advisor for any class.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return const Text(
      "Your Class Reports",
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _advisorInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Faculty Advisor For',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.advisorClasses.map((c) => c['name']).join(', '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Quick Stats"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                "Total Students",
                "${controller.totalStudents.value}",
                Icons.people,
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                "Class Average",
                "${controller.classAverage.value.toStringAsFixed(1)}%",
                Icons.analytics,
                controller.classAverage.value >= 75
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                "Below 75%",
                "${controller.belowThreshold.value}",
                Icons.warning_amber,
                const Color(0xFFF44336),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                "Perfect Attendance",
                "${controller.perfectAttendance.value}",
                Icons.star,
                const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _exportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showExportDialog(context),
        icon: const Icon(Icons.download),
        label: const Text("Export Reports"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D9FF),
          foregroundColor: const Color(0xFF0F0C29),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TeacherExportReportDialog(controller: controller),
    );
  }

  Widget _reportTypes(BuildContext context) {
    final reports = [
      (
        "Student Reports",
        Icons.person,
        const Color(0xFF00D9FF),
        const TeacherStudentReportView(),
      ),
      (
        "Class Reports",
        Icons.class_,
        const Color(0xFF4CAF50),
        const TeacherClassReportView(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Report Types"),
        const SizedBox(height: 12),
        Column(
          children: reports
              .map((r) => _reportCard(r.$1, r.$2, r.$3, r.$4, context))
              .toList(),
        ),
      ],
    );
  }

  Widget _reportCard(
    String title,
    IconData icon,
    Color color,
    Widget targetView,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetView),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: _card(
          child: Row(
            children: [
              _icon(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
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

  Widget _icon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// Export Dialog Widget for Teacher
class TeacherExportReportDialog extends StatefulWidget {
  final TeacherReportsController controller;

  const TeacherExportReportDialog({super.key, required this.controller});

  @override
  State<TeacherExportReportDialog> createState() =>
      _TeacherExportReportDialogState();
}

class _TeacherExportReportDialogState extends State<TeacherExportReportDialog> {
  String selectedReportType = 'student';
  String selectedFormat = 'pdf';
  String? selectedClassId;
  String? selectedStudentId;

  List<Map<String, dynamic>> students = [];
  bool isLoadingData = false;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    // Auto-select first class if only one
    if (widget.controller.advisorClasses.length == 1) {
      selectedClassId = widget.controller.advisorClasses.first['id'];
      if (selectedReportType == 'student') {
        _loadStudents(selectedClassId!);
      }
    }
  }

  Future<void> _loadStudents(String classId) async {
    setState(() {
      isLoadingData = true;
      students = [];
      selectedStudentId = null;
    });

    try {
      final snapshot = await widget.controller.firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .get();

      if (mounted) {
        final studentList = snapshot.docs
            .map(
              (doc) => {'id': doc.id, 'name': doc.data()['name'] ?? 'Unknown'},
            )
            .toList();
        studentList.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );

        setState(() {
          students = studentList;
          isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingData = false);
    }
  }

  bool get canExport {
    switch (selectedReportType) {
      case 'student':
        return selectedStudentId != null;
      case 'class':
        return selectedClassId != null;
      default:
        return false;
    }
  }

  Future<void> _export() async {
    if (!canExport) return;

    setState(() => isExporting = true);

    try {
      String? entityId;
      String entityName = '';

      switch (selectedReportType) {
        case 'student':
          entityId = selectedStudentId;
          entityName = students.firstWhere((s) => s['id'] == entityId)['name'];
          break;
        case 'class':
          entityId = selectedClassId;
          entityName = widget.controller.advisorClasses.firstWhere(
            (c) => c['id'] == entityId,
          )['name'];
          break;
      }

      Navigator.of(context).pop();

      await widget.controller.exportReport(
        reportType: selectedReportType,
        format: selectedFormat,
        entityId: entityId!,
        entityName: entityName,
      );
    } catch (e) {
      if (mounted) {
        setState(() => isExporting = false);
        Get.snackbar(
          'Error',
          'Failed to export: $e',
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.download,
                    color: Color(0xFF00D9FF),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Export Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Report Type Selection
              const Text(
                'Report Type',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildReportTypeSelector(),
              const SizedBox(height: 16),

              // Entity Selection based on report type
              _buildEntitySelection(),
              const SizedBox(height: 16),

              // Format Selection
              const Text(
                'Export Format',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildFormatSelector(),
              const SizedBox(height: 24),

              // Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canExport && !isExporting ? _export : null,
                  icon: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          selectedFormat == 'pdf'
                              ? Icons.picture_as_pdf
                              : Icons.table_chart,
                        ),
                  label: Text(isExporting ? 'Exporting...' : 'Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: const Color(0xFF0F0C29),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Row(
      children: [
        _buildTypeChip('Student', 'student', Icons.person),
        const SizedBox(width: 8),
        _buildTypeChip('Class', 'class', Icons.class_),
      ],
    );
  }

  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = selectedReportType == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedReportType = value;
            selectedStudentId = null;
            students = [];
          });
          // Load students if class is already selected
          if (value == 'student' && selectedClassId != null) {
            _loadStudents(selectedClassId!);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00D9FF).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00D9FF)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntitySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Class Dropdown (always shown)
        _buildDropdown(
          label: 'Class',
          value: selectedClassId,
          items: widget.controller.advisorClasses
              .map(
                (c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedClassId = value;
              selectedStudentId = null;
              students = [];
            });
            if (value != null && selectedReportType == 'student') {
              _loadStudents(value);
            }
          },
        ),

        // Student Dropdown (only for student reports)
        if (selectedReportType == 'student') ...[
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Student',
            value: selectedStudentId,
            items: students
                .map(
                  (s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(s['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => selectedStudentId = value);
            },
          ),
        ],

        if (isLoadingData)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00D9FF),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                'Select $label',
                style: const TextStyle(color: Colors.white54),
              ),
              isExpanded: true,
              dropdownColor: const Color(0xFF16213E),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Row(
      children: [
        _buildFormatChip(
          'PDF',
          'pdf',
          Icons.picture_as_pdf,
          const Color(0xFFF44336),
        ),
        const SizedBox(width: 12),
        _buildFormatChip(
          'Excel',
          'excel',
          Icons.table_chart,
          const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildFormatChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedFormat == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedFormat = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
