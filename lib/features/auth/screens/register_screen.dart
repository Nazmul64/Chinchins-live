import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../profile/screens/edit_profile_media_screen.dart';
import '../services/auth_api_service.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Required Fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Supported Countries
  final List<Map<String, String>> _countries = const [
    {'name': 'Bangladesh', 'code': '+880', 'flag': '🇧🇩'},
    {'name': 'Pakistan', 'code': '+92', 'flag': '🇵🇰'},
    {'name': 'India', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦'},
    {'name': 'United Arab Emirates', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'Malaysia', 'code': '+60', 'flag': '🇲🇾'},
    {'name': 'Singapore', 'code': '+65', 'flag': '🇸🇬'},
    {'name': 'Other', 'code': '+', 'flag': '🌐'},
  ];

  // State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = true;
  bool _isLoading = false;
  String _selectedCountry = 'Bangladesh';
  String _countryCode = '+880';
  String _countryFlag = '🇧🇩';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _countries.where((c) {
              final q = searchQuery.toLowerCase();
              return c['name']!.toLowerCase().contains(q) || c['code']!.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Country / Region',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search country or code...',
                        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                        icon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(color: AppColors.cardBorder, height: 1),
                      itemBuilder: (context, idx) {
                        final c = filtered[idx];
                        final isSelected = c['name'] == _selectedCountry;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          leading: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(c['flag'] ?? '🌐', style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(
                            c['name'] ?? '',
                            style: TextStyle(
                              color: isSelected ? AppColors.neonPink : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c['code'] ?? '',
                                style: TextStyle(
                                  color: isSelected ? AppColors.neonPink : AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded, color: AppColors.neonPink, size: 18),
                              ],
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCountry = c['name']!;
                              _countryCode = c['code']!;
                              _countryFlag = c['flag']!;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.badgePink),
          ),
          content: const Text(
            'Please agree to the Terms of Service & Privacy Policy',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Format phone number
    String phoneInput = _phoneController.text.trim();
    if (phoneInput.startsWith('0')) {
      phoneInput = phoneInput.substring(1);
    }
    final fullPhone = phoneInput.startsWith('+')
        ? phoneInput
        : (_countryCode == '+' ? phoneInput : '$_countryCode$phoneInput');

    final emailInput = _emailController.text.trim();

    final result = await AuthApiService.register(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: fullPhone,
      email: emailInput.isNotEmpty ? emailInput : null,
      password: _passwordController.text,
      passwordConfirmation: _confirmPasswordController.text,
      country: _selectedCountry,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'];
      final name = user != null
          ? (user['first_name'] ?? user['name'] ?? _firstNameController.text.trim())
          : _firstNameController.text.trim();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.onlineGreen, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.celebration_rounded, color: AppColors.onlineGreen, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Welcome, $name! Account created successfully.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileMediaScreen(
            isInitialSetup: true,
            initialProfile: user != null && user is Map<String, dynamic> ? ModelProfile.fromJson(user) : null,
          ),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2A1520),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.badgePink, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.badgePink, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Registration failed',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join Chinchins Live to chat, stream and meet amazing hosts',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Name Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AuthTextField(
                        label: 'First Name',
                        hintText: 'John',
                        controller: _firstNameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'First name required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AuthTextField(
                        label: 'Last Name',
                        hintText: 'Doe',
                        controller: _lastNameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Last name required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Country / Region Field (with dedicated label & spacing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Country / Region',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _showCountryPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_countryFlag, style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedCountry,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.neonPink.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _countryCode,
                                style: const TextStyle(
                                  color: AppColors.neonPink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Phone Number Field
                AuthTextField(
                  label: 'Phone Number',
                  hintText: 'Enter phone number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _countryCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(
                          height: 20,
                          child: VerticalDivider(
                            color: AppColors.cardBorder,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (val.trim().length < 6) {
                      return 'Enter valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Email Address
                AuthTextField(
                  label: 'Email Address (Optional)',
                  hintText: 'name@example.com',
                  controller: _emailController,
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Password
                AuthTextField(
                  label: 'Password',
                  hintText: 'Create strong password (min 6 chars)',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Confirmation Password
                AuthTextField(
                  label: 'Confirmation Password',
                  hintText: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  prefixIcon: Icons.lock_reset_rounded,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Terms of Service
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreeToTerms,
                        activeColor: AppColors.neonPink,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                        onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          text: 'I agree to Chinchins Live ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppColors.neonPink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.neonPink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.neonPink,
                          ),
                        )
                      : GradientButton(
                          text: 'Create Account',
                          height: 52,
                          borderRadius: 16,
                          fontSize: 16,
                          icon: Icons.person_add_rounded,
                          onTap: _handleRegister,
                        ),
                ),
                const SizedBox(height: 24),

                // Footer
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: AppColors.neonPink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
