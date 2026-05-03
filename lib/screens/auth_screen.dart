import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AuthScreen({super.key, this.onBack});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _mobileRedirectUrl = 'com.novaparfum.barfum://login-callback/';

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _message;
  bool _isError = false;
  bool _showVerification = false;

  SupabaseClient get _client => Supabase.instance.client;

  String? get _redirectTo {
    if (!kIsWeb) return _mobileRedirectUrl;
    final origin = Uri.base.origin;
    return origin == 'null' ? null : origin;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.length < 8) {
      _showMessage(l10n.enterValidEmailPassword, true);
      return;
    }
    if (_isSignUp && name.isEmpty) {
      _showMessage(l10n.enterName, true);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      if (_isSignUp) {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _redirectTo,
          data: {'name': name},
        );
        // Enforce email verification: sign out even if Supabase auto-confirmed
        if (response.session != null) {
          await _client.auth.signOut();
        }
        if (mounted) {
          setState(() {
            _showVerification = true;
            _loading = false;
          });
        }
      } else {
        final response = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = response.user;
        if (user != null && user.emailConfirmedAt == null) {
          await _client.auth.signOut();
          if (mounted) {
            _showMessage(l10n.pleaseConfirmEmail, true);
          }
        }
      }
    } on AuthException catch (error) {
      _showMessage(error.message, true);
    } catch (_) {
      _showMessage(l10n.error, true);
    } finally {
      if (mounted && !_showVerification) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      _showMessage(error.message, true);
    } catch (_) {
      _showMessage(l10n.loginFailed, true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithAppleNative() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('No identity token from Apple');
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      _showMessage(l10n.loginFailed, true);
    } catch (_) {
      _showMessage(l10n.loginFailed, true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String value, bool isError) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _isError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 26),
                if (_showVerification)
                  _buildVerificationPanel()
                else
                  _buildPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (widget.onBack != null)
          Align(
            alignment: AlignmentDirectional.topStart,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: kWarmGray),
              onPressed: widget.onBack,
            ),
          ),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [kGold, kGoldLight]),
          ),
          child: Center(
            child: Text(
              AppLocalizations.of(context).appTitle.characters.first,
              style: arabicStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: kOud,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.appTitle,
          style: arabicStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.loginToSave,
          style: arabicStyle(fontSize: 14, color: kWarmGray),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeToggle(),
          const SizedBox(height: 16),
          if (_isSignUp) ...[
            _field(
              controller: _nameCtrl,
              hint: l10n.name,
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 10),
          ],
          _field(
            controller: _emailCtrl,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _field(
            controller: _passwordCtrl,
            hint: l10n.password,
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loading ? null : _submitEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kOud,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kOud,
                    ),
                  )
                : Text(
                    _isSignUp ? l10n.signup : l10n.login,
                    style: arabicStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kOud,
                    ),
                  ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 12,
                color: _isError ? Colors.red.shade700 : kSuccess,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFEDE4DA))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  l10n.or,
                  style: arabicStyle(fontSize: 12, color: kSand),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFEDE4DA))),
            ],
          ),
          const SizedBox(height: 14),
          _oauthButton(
            label: l10n.googleSignIn,
            icon: Icons.g_mobiledata_rounded,
            onTap: () => _signInWithOAuth(OAuthProvider.google),
          ),
          const SizedBox(height: 10),
          _oauthButton(
            label: l10n.appleSignIn,
            icon: Icons.apple_rounded,
            onTap: _signInWithAppleNative,
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kGoldPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _modeButton(l10n.signin, !_isSignUp, false),
          _modeButton(l10n.newAccount, _isSignUp, true),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool active, bool signUpMode) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isSignUp = signUpMode;
          _message = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? kOud : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: arabicStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? Colors.white : kWarmGray,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textDirection: Directionality.of(context),
      decoration: InputDecoration(
        hintText: hint,
        hintTextDirection: Directionality.of(context),
        prefixIcon: Icon(icon, color: kSand),
        filled: true,
        fillColor: const Color(0xFFFFFCF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5DDD4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5DDD4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGold, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildVerificationPanel() {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 48, color: kGold),
          const SizedBox(height: 16),
          Text(
            l10n.verifyEmail,
            textAlign: TextAlign.center,
            style: arabicStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kEspresso,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.verificationSent,
            textAlign: TextAlign.center,
            style: arabicStyle(fontSize: 14, color: kWarmGray),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: arabicStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kOud,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.verifyInstructions,
            textAlign: TextAlign.center,
            style: arabicStyle(fontSize: 13, color: kSand, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showVerification = false;
                _isSignUp = false;
                _passwordCtrl.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kOud,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.backToLogin,
              style: arabicStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kOud,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oauthButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : onTap,
      icon: Icon(icon, size: 22, color: kEspresso),
      label: Text(
        label,
        style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: const BorderSide(color: Color(0xFFE5DDD4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
