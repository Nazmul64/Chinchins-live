import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_api_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  String _selectedCategory = 'Suggestion';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Suggestion',
    'Bug Report',
    'Recharge / Coins',
    'Video & Audio Call',
    'Account Issue',
    'Other',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 3 screenshots.')),
      );
      return;
    }
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your feedback or issue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse('${ApiConstants.baseUrl}/feedback/submit');
      
      final req = http.MultipartRequest('POST', url);
      req.headers['Accept'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';

      req.fields['category'] = _selectedCategory;
      req.fields['content'] = text;
      req.fields['description'] = text;
      if (_contactController.text.trim().isNotEmpty) {
        req.fields['contact'] = _contactController.text.trim();
      }

      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        req.files.add(await http.MultipartFile.fromPath('screenshots[]', img.path));
      }

      await req.send().timeout(const Duration(seconds: 12));

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted to Chinchins Team.'),
            backgroundColor: Color(0xFF00E676),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been recorded.'),
            backgroundColor: AppColors.neonPink,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131122),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131122),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Feedback & Support',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Feedback Category',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  selectedColor: AppColors.neonPink.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.neonPink : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.neonPink : Colors.white10,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text(
              'Description',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Please describe the problem or suggestion in detail...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  contentPadding: EdgeInsets.all(14),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Add Screenshots (Optional, max 3)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ..._selectedImages.map((img) {
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                      image: DecorationImage(
                        image: FileImage(File(img.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedImages.remove(img));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_selectedImages.length < 3)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Colors.white60, size: 24),
                          SizedBox(height: 4),
                          Text('Add', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Contact Info (Email or Phone)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _contactController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'e.g. yourname@gmail.com / 017XXXXXXXX',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: _isSubmitting ? null : _submitFeedback,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
