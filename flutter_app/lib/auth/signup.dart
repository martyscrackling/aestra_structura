import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  final String? redirectTo;

  const SignUpPage({super.key, this.redirectTo});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _obscureCreatePassword = true;
  bool _obscureConfirmPassword = true;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _otpController;
  late List<TextEditingController> _otpDigitControllers;
  late List<FocusNode> _otpFocusNodes;
  bool _isLoading = false;
  bool _otpRequested = false;
  bool _isEmailVerified = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _otpController = TextEditingController();
    _otpDigitControllers = List.generate(6, (_) => TextEditingController());
    _otpFocusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    for (final controller in _otpDigitControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Color(0xFFFF6B2C),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final result = await authService.sendSignupOtp(email);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _otpRequested = true;
          _isEmailVerified = false;
        });
        final resendSeconds =
            (result['resend_available_in_seconds'] as num?)?.toInt() ?? 60;
        _startResendCountdown(resendSeconds);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final retryAfter = (result['retry_after_seconds'] as num?)?.toInt();
        if (retryAfter != null && retryAfter > 0) {
          _startResendCountdown(retryAfter);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpDigitControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit OTP'),
          backgroundColor: Color(0xFFFF6B2C),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final result = await authService.verifySignupOtp(email, otp);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _isEmailVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeEmail() {
    setState(() {
      _otpRequested = false;
      _isEmailVerified = false;
      _resendSecondsLeft = 0;
      _otpController.clear();
      for (final controller in _otpDigitControllers) {
        controller.clear();
      }
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    _resendTimer?.cancel();
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 44,
          child: TextField(
            controller: _otpDigitControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Color(0xFFFF6B2C), width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _otpFocusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _otpFocusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 800;
              return isMobile ? _buildMobileLayout() : _buildWideLayout();
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/sidebarlogin.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _buildSignUpForm(isMobile: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      decoration: BoxDecoration(),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: _buildSignUpForm(isMobile: true),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpForm({bool isMobile = false}) {
    final enteredEmail = _emailController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo & Title
        Column(
          children: [
            Image.asset(
              'assets/images/structuralogo.png',
              height: isMobile ? 100 : 80,
            ),
            const SizedBox(height: 6),
            Text(
              'STRUCTURA',
              style: TextStyle(
                fontSize: isMobile ? 28 : 36,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0A173D),
                letterSpacing: 3,
                shadows: const [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 20 : 15),
        Text(
          "Create a new account",
          style: TextStyle(
            fontSize: isMobile ? 13 : 15,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isMobile ? 20 : 25),

        if (!_otpRequested) ...[
          // Email Field
          _buildTextField(
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
          ),
          const SizedBox(height: 12),
        ],

        if (!_otpRequested) ...[
          Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)],
              ),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _sendOtp,
              child: const Text(
                "Send OTP",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_otpRequested && !_isEmailVerified) ...[
          Text(
            "The verification code has been sent to your email $enteredEmail.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          _buildOtpBoxes(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading || _resendSecondsLeft > 0 ? null : _sendOtp,
                  child: Text(
                    _resendSecondsLeft > 0
                        ? 'Resend in ${_resendSecondsLeft}s'
                        : 'Resend OTP',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _changeEmail,
                  child: const Text('Change email'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)],
              ),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _verifyOtp,
              child: const Text(
                "Verify OTP",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_isEmailVerified) ...[
          // Create Password Field
          _buildTextField(
            label: 'Create Password',
            icon: Icons.lock_outline,
            obscureText: _obscureCreatePassword,
            controller: _passwordController,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureCreatePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(
                () => _obscureCreatePassword = !_obscureCreatePassword,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          _buildTextField(
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            controller: _confirmPasswordController,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
          const SizedBox(height: 25),
        ],

        // Sign Up Button
        if (_isEmailVerified)
          Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B2C).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isLoading
                ? null
                : () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();
                    final confirmPassword = _confirmPasswordController.text
                        .trim();

                    // Validation
                    if (!_isEmailVerified) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please verify your email first'),
                          backgroundColor: Color(0xFFFF6B2C),
                        ),
                      );
                      return;
                    }

                    if (email.isEmpty ||
                        password.isEmpty ||
                        confirmPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all fields'),
                          backgroundColor: Color(0xFFFF6B2C),
                        ),
                      );
                      return;
                    }

                    if (password != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passwords do not match'),
                          backgroundColor: Color(0xFFFF6B2C),
                        ),
                      );
                      return;
                    }

                    if (password.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must be at least 6 characters',
                          ),
                          backgroundColor: Color(0xFFFF6B2C),
                        ),
                      );
                      return;
                    }

                    setState(() => _isLoading = true);

                    try {
                      final authService = context.read<AuthService>();
                      final success = await authService.signup(
                        email,
                        password,
                        'User',
                        'Account',
                      );

                      if (!mounted) return;

                      if (success) {
                        // Signup successful, navigate to infos page or redirectTo if provided
                        if (widget.redirectTo != null) {
                          context.go(widget.redirectTo!);
                        } else {
                          context.go('/infos');
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Email already exists or signup failed',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Signup error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "OR",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
          ],
        ),
        SizedBox(height: isMobile ? 16 : 20),

        // Login Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.grey[700],
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: const Text(
                "Log In",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFFF6B2C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    TextEditingController? controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF0C1C4D).withOpacity(0.6),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF6B2C), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
