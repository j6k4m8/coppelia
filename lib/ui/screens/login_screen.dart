import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../core/color_tokens.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_background.dart';

/// Sign-in screen for connecting to Jellyfin.
class LoginScreen extends StatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: SizedBox(
            width: 440,
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect your Jellyfin music library and start listening.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildField(
                    label: 'Server URL',
                    controller: _serverController,
                    hint: 'https://jellyfin.yourdomain.com',
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Username',
                    controller: _usernameController,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  if (appState.authError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        appState.authError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _handleSignIn(appState),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tip: Use a local Jellyfin user with music library access.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: ColorTokens.cardFill(context, 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSignIn(AppState appState) async {
    setState(() {
      _isSubmitting = true;
    });
    await appState.signIn(
      serverUrl: _serverController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
