import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../config/routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  final _formKey = GlobalKey<FormState>();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final isLandscape = size.width > size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: _dismissKeyboard,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative blobs
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.3,
                right: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 40 : 24,
                      vertical: isLandscape ? 16 : 24,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: isWide
                            ? _buildWideLayout(authController, size)
                            : _buildNarrowLayout(authController),
                      ),
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

  Widget _buildWideLayout(AuthController authController, Size size) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left side - Branding
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.storefront(PhosphorIconsStyle.bold),
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Smart Inventory',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kelola inventori & kasir dengan mudah,\ncepat, dan akurat.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  _buildFeatureChip(
                    PhosphorIcons.lightning(PhosphorIconsStyle.bold),
                    'Cepat & Tepat',
                  ),
                  const SizedBox(height: 14),
                  _buildFeatureChip(
                    PhosphorIcons.chartBar(PhosphorIconsStyle.bold),
                    'Analisis Data Mendalam',
                  ),
                  const SizedBox(height: 14),
                  _buildFeatureChip(
                    PhosphorIcons.shieldCheck(PhosphorIconsStyle.bold),
                    'Aman & Terpercaya',
                  ),
                ],
              ),
            ),
          ),
          // Right side - Login Form
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: _buildLoginForm(authController),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(PhosphorIconData icon, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(AuthController authController) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              PhosphorIcons.storefront(PhosphorIconsStyle.bold),
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Smart Inventory',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1a1a2e),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masuk untuk melanjutkan',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6b7280),
            ),
          ),
          const SizedBox(height: 32),
          _buildLoginForm(authController),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AuthController authController) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error Message
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: authController.errorMessage != null
                ? Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.warningCircle(PhosphorIconsStyle.bold),
                          color: Colors.red.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authController.errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Username Field
          _buildTextField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            label: 'Username',
            hint: 'Masukkan username',
            icon: PhosphorIcons.user(PhosphorIconsStyle.bold),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username wajib diisi';
              }
              return null;
            },
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 18),

          // Password Field
          _buildTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: 'Password',
            hint: 'Masukkan password',
            icon: PhosphorIcons.lock(PhosphorIconsStyle.bold),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password wajib diisi';
              }
              return null;
            },
            onFieldSubmitted: (_) => _performLogin(authController),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? PhosphorIcons.eyeSlash(PhosphorIconsStyle.bold)
                    : PhosphorIcons.eye(PhosphorIconsStyle.bold),
                color: const Color(0xFF9ca3af),
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          const SizedBox(height: 28),

          // Login Button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: authController.isLoading
                  ? null
                  : () => _performLogin(authController),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF667eea).withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF667eea).withValues(alpha: 0.4),
              ),
              child: authController.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Masuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 28),

          // Demo credentials info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFfef3c7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFfde68a)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.info(PhosphorIconsStyle.bold),
                      color: Colors.orange.shade700,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Akun Demo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildCredentialChip(
                      'admin',
                      PhosphorIcons.user(PhosphorIconsStyle.bold),
                    ),
                    _buildCredentialChip(
                      'admin123',
                      PhosphorIcons.key(PhosphorIconsStyle.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialChip(String text, PhosphorIconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFfde68a)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required PhosphorIconData icon,
    required TextInputAction textInputAction,
    required String? Function(String?) validator,
    required void Function(String?) onFieldSubmitted,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          textInputAction: textInputAction,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1f2937),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: const Color(0xFF667eea), size: 22),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF9fafb),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _performLogin(AuthController authController) async {
    _dismissKeyboard();
    if (_formKey.currentState!.validate()) {
      final success = await authController.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.dashboard,
        );
      }
    }
  }
}