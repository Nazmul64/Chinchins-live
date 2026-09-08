import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/auth_api_service.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _selectedMethod = 0; // 0: Email, 1: Phone
  int _currentStep = 1; // 1: Request OTP/Link, 2: Enter OTP & New Password
  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  String? _resetToken;
  String _activeRecipient = '';

  // Resend Timer
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _canResend = true;
            _resendCountdown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() => _resendCountdown--);
        }
      }
    });
  }

  String get _currentIdentifier => _selectedMethod == 0 
      ? _emailController.text.trim() 
      : _phoneController.text.trim();

  void _handleSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _currentIdentifier;
    final method = _selectedMethod == 0 ? 'email' : 'phone';

    setState(() => _isLoading = true);

    final res = await AuthApiService.sendForgotPasswordCode(
      identifier: identifier,
      method: method,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _activeRecipient = res['data']?['recipient'] ?? identifier;
      setState(() {
        _currentStep = 2;
      });
      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.neonPink, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'Verification code sent successfully.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF321422),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'Failed to send verification code.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _handleResendCode() async {
    if (!_canResend || _isLoading) return;

    final identifier = _currentIdentifier;
    final method = _selectedMethod == 0 ? 'email' : 'phone';

    setState(() => _isLoading = true);

    final res = await AuthApiService.sendForgotPasswordCode(
      identifier: identifier,
      method: method,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.neonPink, width: 1),
          ),
          content: const Text(
            'New 6-digit code has been sent.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF321422),
          content: Text(
            res['message'] ?? 'Failed to resend code.',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    }
  }

  void _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _currentIdentifier;
    final code = _otpController.text.trim();
    final password = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Passwords do not match!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await AuthApiService.resetPassword(
      identifier: identifier,
      code: code,
      resetToken: _resetToken,
      password: password,
      passwordConfirmation: confirmPassword,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF321422),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'Failed to reset password.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPink.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Password Reset Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can now sign in with your new credentials.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Back to Login',
                  height: 48,
                  borderRadius: 14,
                  onTap: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // back to login
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Icon Header (Matching Screenshot)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.neonPink.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPink.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.neonPink,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title & Subtitle
                Center(
                  child: Text(
                    _currentStep == 1
                        ? 'Recover Your Account'
                        : 'Set New Password',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _currentStep == 1
                        ? 'Select which contact details should we use to reset your password.'
                        : 'Enter the 6-digit verification code sent to $_activeRecipient',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                if (_currentStep == 1) ...[
                  // Recovery Method Switcher (Via Email / Via Phone)
                  Container(
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMethod = 0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _selectedMethod == 0 ? AppColors.primaryGradient : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.alternate_email_rounded,
                                    size: 18,
                                    color: _selectedMethod == 0 ? Colors.white : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Via Email',
                                    style: TextStyle(
                                      color: _selectedMethod == 0 ? Colors.white : AppColors.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMethod = 1),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _selectedMethod == 1 ? AppColors.primaryGradient : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_android_rounded,
                                    size: 18,
                                    color: _selectedMethod == 1 ? Colors.white : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Via Phone',
                                    style: TextStyle(
                                      color: _selectedMethod == 1 ? Colors.white : AppColors.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Input Field
                  if (_selectedMethod == 0) ...[
                    const Text(
                      'Registered Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _emailController,
                      hintText: 'e.g. user@example.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your registered email';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    const Text(
                      'Registered Phone Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _phoneController,
                      hintText: '01700000000',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (val.trim().length < 6) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Send Code Button
                  GradientButton(
                    text: 'Send Verification Code',
                    isLoading: _isLoading,
                    icon: Icons.send_rounded,
                    onTap: _handleSendCode,
                  ),
                ] else ...[
                  // STEP 2: Enter OTP & New Password
                  const Text(
                    '6-Digit Verification Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _otpController,
                    hintText: 'Enter 6-digit code',
                    prefixIcon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter the 6-digit OTP code';
                      }
                      if (val.trim().length != 6) {
                        return 'Verification code must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Resend Code row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _canResend
                            ? 'Didn\'t receive code?'
                            : 'Resend code in ${_resendCountdown}s',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      if (_canResend)
                        GestureDetector(
                          onTap: _handleResendCode,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(
                              color: AppColors.neonPink,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // New Password Field
                  const Text(
                    'New Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _newPasswordController,
                    hintText: 'Enter new password (min. 6 chars)',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscureNewPass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  const Text(
                    'Confirm New Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Re-type your new password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (val != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Reset Password Button
                  GradientButton(
                    text: 'Reset Password',
                    isLoading: _isLoading,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: _handleResetPassword,
                  ),
                ],

                const SizedBox(height: 28),

                // Back to Sign In Footer
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Remember your password? ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppColors.neonPink,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
