import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/chat_api_service.dart';

class ReportUserModal extends StatefulWidget {
  final dynamic reportedUserId;
  final String partnerName;

  const ReportUserModal({
    super.key,
    required this.reportedUserId,
    required this.partnerName,
  });

  static Future<void> show(BuildContext context, {required dynamic reportedUserId, required String partnerName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => ReportUserModal(
        reportedUserId: reportedUserId,
        partnerName: partnerName,
      ),
    );
  }

  @override
  State<ReportUserModal> createState() => _ReportUserModalState();
}

class _ReportUserModalState extends State<ReportUserModal> {
  final TextEditingController _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _selectedReason = 'sexual_content';
  File? _proofImage;
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasons = ChatApiService.getPredefinedReportReasons();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked != null) {
        setState(() {
          _proofImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('[ProofImage Error]: $e');
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason.isEmpty) return;

    setState(() => _isSubmitting = true);

    final res = await ChatApiService.reportUser(
      reportedUserId: widget.reportedUserId,
      reasonType: _selectedReason,
      description: _descController.text.trim(),
      proofImage: _proofImage,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pop(context); // Close modal

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                res['message'] ?? 'Thank you. Your report has been submitted for review.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Report ${widget.partnerName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Please select the reason for your report. Our 24/7 moderation team will review this promptly.',
                style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.3),
              ),
              const SizedBox(height: 16),

              // Reason Radio Choices
              const Text(
                'Reason for Report',
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ...List.generate(_reasons.length, (index) {
                final r = _reasons[index];
                final isSelected = _selectedReason == r['key'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedReason = r['key']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonPink.withValues(alpha: 0.15)
                          : const Color(0xFF29243C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.neonPink : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.neonPink : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r['title']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 14),

              // Additional Details Text Field
              const Text(
                'Details / Notes (Optional)',
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe what happened (inappropriate words, behavior, etc.)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                  filled: true,
                  fillColor: const Color(0xFF29243C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 14),

              // Proof Screenshot Attachment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attach Screenshot (Optional)',
                    style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  if (_proofImage != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _proofImage = null),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                      label: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              if (_proofImage != null)
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: FileImage(_proofImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _pickProofImage,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('Upload Screenshot', style: TextStyle(fontSize: 12.5)),
                ),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 4,
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
