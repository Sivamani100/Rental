import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/core/widgets/app_snackbar.dart';
import 'package:rental/core/widgets/bouncing_button.dart';
import 'package:rental/features/partner/data/services/partner_service.dart';
import 'package:rental/features/partner/presentation/pages/partner_dashboard_screen.dart';

class PartnerAuthScreen extends StatefulWidget {
  final bool initialIsSignUp;
  final bool isEmbeddedInEntryHandler;
  final VoidCallback? onSuccess;

  const PartnerAuthScreen({
    super.key,
    this.initialIsSignUp = false,
    this.isEmbeddedInEntryHandler = false,
    this.onSuccess,
  });

  @override
  State<PartnerAuthScreen> createState() => _PartnerAuthScreenState();
}

class _PartnerAuthScreenState extends State<PartnerAuthScreen> {
  late bool _isSignUp;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'Direct Property Owner';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Email validation
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      AppSnackbar.show(context, 'Please enter a valid email address');
      return;
    }

    // Password validation
    if (password.isEmpty || password.length < 6) {
      AppSnackbar.show(context, 'Password must be at least 6 characters long');
      return;
    }

    // Confirm password validation on sign-up
    if (_isSignUp) {
      if (confirmPassword.isEmpty) {
        AppSnackbar.show(context, 'Please confirm your password');
        return;
      }
      if (password != confirmPassword) {
        AppSnackbar.show(context, 'Passwords do not match. Please verify.');
        return;
      }
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    AuthResult result;
    if (_isSignUp) {
      result = await PartnerService.instance.signUp(
        email: email,
        password: password,
        role: _selectedRole,
      );
    } else {
      result = await PartnerService.instance.signIn(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      AppSnackbar.show(
        context,
        _isSignUp
            ? 'Account created successfully! Welcome to Partner Hub.'
            : 'Welcome back to Partner Hub!',
      );

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else if (!widget.isEmbeddedInEntryHandler) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (_) => const PartnerDashboardScreen()),
        );
      }
    } else {
      AppSnackbar.show(
        context,
        result.errorMessage ?? 'Authentication failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F9);
    final cardColor = isDark ? const Color(0xFF16181D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262A34) : const Color(0xFFECEEF2);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final inputBg = isDark ? const Color(0xFF1B1E26) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryYellow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          splashRadius: 22,
          icon: const Icon(CupertinoIcons.back, size: 24, color: Colors.black),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        title: Text(
          _isSignUp ? 'Partner Sign Up' : 'Partner Sign In',
          style: const TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon & Title
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Iconsax.crown5,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _isSignUp ? 'Create Partner Account' : 'Welcome Back, Partner',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _isSignUp
                      ? 'Sign up with your email to manage listings & live availability'
                      : 'Sign in to access your properties, edit details & toggle status',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 13,
                    color: subtextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Segmented Switch (Sign In / Create Account)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF12141A) : const Color(0xFFEDEFF3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isSignUp = false);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSignUp ? cardColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: !_isSignUp ? textColor : subtextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isSignUp = true);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSignUp ? cardColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              'Create Account',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _isSignUp ? textColor : subtextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Auto-Fill Demo Chip (Sign In Mode)
              if (!_isSignUp) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryYellow.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.flash_15, size: 18, color: Color(0xFFE5A000)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Demo Landlord',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'owner@rentalecosystem.com',
                              style: TextStyle(
                                fontFamily: 'ProximaNova',
                                fontSize: 11,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BouncingButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _emailController.text = 'owner@rentalecosystem.com';
                          _passwordController.text = 'password123';
                          AppSnackbar.show(context, 'Demo credentials filled! Tap Sign In.');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryYellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Auto-Fill',
                            style: TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Role Selection (Only on Sign Up)
              if (_isSignUp) ...[
                Text(
                  'PARTNER ROLE',
                  style: TextStyle(
                    fontFamily: 'ProximaNova',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        title: 'Property Owner',
                        subtitle: 'Direct house / flat owner',
                        roleValue: 'Direct Property Owner',
                        icon: Iconsax.building,
                        isDark: isDark,
                        borderColor: borderColor,
                        cardColor: cardColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRoleCard(
                        title: 'Dealer / Broker',
                        subtitle: 'Property agent / manager',
                        roleValue: 'Dealer / Property Manager',
                        icon: Iconsax.briefcase,
                        isDark: isDark,
                        borderColor: borderColor,
                        cardColor: cardColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Email Address
              _buildFieldLabel('EMAIL ADDRESS', subtextColor),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _emailController,
                hintText: 'Enter your email address',
                icon: Iconsax.sms,
                inputBg: inputBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password
              _buildFieldLabel(_isSignUp ? 'NEW PASSWORD' : 'PASSWORD', subtextColor),
              const SizedBox(height: 6),
              _buildPasswordField(
                controller: _passwordController,
                hintText: _isSignUp ? 'Create a secure password (min 6 chars)' : 'Enter your password',
                obscureText: _obscurePassword,
                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                inputBg: inputBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
              const SizedBox(height: 16),

              // Confirm Password (Only on Sign Up)
              if (_isSignUp) ...[
                _buildFieldLabel('CONFIRM PASSWORD', subtextColor),
                const SizedBox(height: 6),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Re-enter your password to confirm',
                  obscureText: _obscureConfirmPassword,
                  onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  inputBg: inputBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 8),
              ],

              // Submit Button
              BouncingButton(
                onTap: _isLoading ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryYellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: Colors.black)
                        : Text(
                            _isSignUp ? 'Create Account & Continue' : 'Sign In to Partner Hub',
                            style: const TextStyle(
                              fontFamily: 'ProximaNova',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle between sign up / sign in helper link
              Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isSignUp = !_isSignUp);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'ProximaNova',
                          fontSize: 13,
                          color: subtextColor,
                        ),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                          ),
                          TextSpan(
                            text: _isSignUp ? 'Sign In' : 'Create Account',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.primaryYellow : Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required String roleValue,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    required Color cardColor,
  }) {
    final isSelected = _selectedRole == roleValue;
    return BouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRole = roleValue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryYellow.withValues(alpha: isDark ? 0.2 : 0.15)
              : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryYellow : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? (isDark ? AppTheme.primaryYellow : Colors.black87) : Colors.grey,
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Iconsax.tick_circle5, size: 16, color: Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'ProximaNova',
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'ProximaNova',
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color inputBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: subtextColor),
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 13,
            color: subtextColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggle,
    required Color inputBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(
          fontFamily: 'ProximaNova',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(Iconsax.key, size: 18, color: subtextColor),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Iconsax.eye_slash : Iconsax.eye,
              size: 18,
              color: subtextColor,
            ),
            onPressed: onToggle,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: 'ProximaNova',
            fontSize: 13,
            color: subtextColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
