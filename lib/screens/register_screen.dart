import 'package:flutter/material.dart';
import '../auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisterSuccess;

  const RegisterScreen({super.key, required this.onRegisterSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedDiet = 'Veg';
  String _selectedTargetGroup = 'Family';

  final List<String> _dietOptions = ['Veg', 'Non-Veg', 'Vegan', 'Jain'];
  final List<String> _targetOptions = ['Family', 'Kids & Babies', 'Fitness', 'Seniors'];

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTerms) {
      setState(() {
        _errorMessage = 'Please accept the Terms of Service & Privacy Policy.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.register(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        dietaryPreference: _selectedDiet,
        targetGroup: _selectedTargetGroup,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          Navigator.pop(context); // Pop registration screen
          widget.onRegisterSuccess();
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Registration failed.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9F6F0);
    final Color surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
    final Color onPrimaryColor = isDark ? const Color(0xFF121212) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF3E2723);
    final Color textSecondaryColor = isDark ? Colors.white54 : const Color(0xFF8D7B68);
    final Color borderColor = isDark ? Colors.white10 : const Color(0xFFEBE3D5);
    final Color inputBgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3EFE6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Account',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join NutriLens AI',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Personalize food safety scores for your diet and loved ones',
                      style: TextStyle(fontSize: 14, color: textSecondaryColor),
                    ),
                    const SizedBox(height: 24),

                    // Main Form Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Full Name
                          _buildLabel('Full Name', textColor),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: textColor),
                            decoration: _buildInputDecoration(
                              hint: 'e.g. Rahul Sharma',
                              icon: Icons.badge_outlined,
                              primaryColor: primaryColor,
                              inputBgColor: inputBgColor,
                              textSecondaryColor: textSecondaryColor,
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                          ),
                          const SizedBox(height: 16),

                          // Username
                          _buildLabel('Username', textColor),
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(color: textColor),
                            decoration: _buildInputDecoration(
                              hint: 'e.g. rahul_fit',
                              icon: Icons.alternate_email_rounded,
                              primaryColor: primaryColor,
                              inputBgColor: inputBgColor,
                              textSecondaryColor: textSecondaryColor,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Choose a username';
                              if (val.trim().length < 3) return 'Username must be at least 3 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          _buildLabel('Email Address', textColor),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: textColor),
                            decoration: _buildInputDecoration(
                              hint: 'name@example.com',
                              icon: Icons.email_outlined,
                              primaryColor: primaryColor,
                              inputBgColor: inputBgColor,
                              textSecondaryColor: textSecondaryColor,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter your email';
                              if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Dietary Preference Chips
                          _buildLabel('Dietary Preference', textColor),
                          Wrap(
                            spacing: 8,
                            children: _dietOptions.map((diet) {
                              final isSelected = _selectedDiet == diet;
                              return ChoiceChip(
                                label: Text(diet),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedDiet = diet);
                                },
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(
                                  color: isSelected ? onPrimaryColor : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                backgroundColor: inputBgColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? primaryColor : borderColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Target Focus Chips
                          _buildLabel('Primary Scanning Focus', textColor),
                          Wrap(
                            spacing: 8,
                            children: _targetOptions.map((target) {
                              final isSelected = _selectedTargetGroup == target;
                              return ChoiceChip(
                                label: Text(target),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedTargetGroup = target);
                                },
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(
                                  color: isSelected ? onPrimaryColor : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                backgroundColor: inputBgColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? primaryColor : borderColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _buildLabel('Password (min 6 characters)', textColor),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: textColor),
                            decoration: _buildInputDecoration(
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              primaryColor: primaryColor,
                              inputBgColor: inputBgColor,
                              textSecondaryColor: textSecondaryColor,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: textSecondaryColor,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password
                          _buildLabel('Confirm Password', textColor),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: TextStyle(color: textColor),
                            decoration: _buildInputDecoration(
                              hint: '••••••••',
                              icon: Icons.lock_reset_rounded,
                              primaryColor: primaryColor,
                              inputBgColor: inputBgColor,
                              textSecondaryColor: textSecondaryColor,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: textSecondaryColor,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (val) {
                              if (val != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Terms agreement
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _agreeTerms,
                                  activeColor: primaryColor,
                                  checkColor: onPrimaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) => setState(() => _agreeTerms = val ?? true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'I agree to the Terms of Service & Privacy Policy',
                                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: onPrimaryColor,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: onPrimaryColor,
                                    ),
                                  )
                                : const Text(
                                    'Create Free Account',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Back to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: textSecondaryColor, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required Color primaryColor,
    required Color inputBgColor,
    required Color textSecondaryColor,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.6), fontSize: 14),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: inputBgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
