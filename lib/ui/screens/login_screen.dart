import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import '../widgets/corner_radius.dart';
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
    final densityScale = appState.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;

    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth - space(32);
              final maxWidth = available < 280
                  ? constraints.maxWidth * 0.9
                  : 440.0;
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: GlassContainer(
                  padding: EdgeInsets.all(space(32).clamp(16.0, 40.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: theme.textTheme.headlineMedium,
                      ),
                      SizedBox(height: space(8)),
                      Text(
                        'Connect your Jellyfin music library and start listening.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: ColorTokens.textSecondary(context, 0.7),
                        ),
                      ),
                      SizedBox(height: space(28)),
                      _buildField(
                        label: 'Server URL',
                        controller: _serverController,
                        hint: 'https://jellyfin.yourdomain.com',
                        densityScale: densityScale,
                      ),
                      SizedBox(height: space(16)),
                      _buildField(
                        label: 'Username',
                        controller: _usernameController,
                        densityScale: densityScale,
                      ),
                      SizedBox(height: space(16)),
                      _buildField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                        densityScale: densityScale,
                      ),
                      SizedBox(height: space(24)),
                      if (appState.authError != null)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: space(12).clamp(8.0, 16.0),
                          ),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                      SizedBox(height: space(16)),
                      Text(
                        'Tip: Use a local Jellyfin user with music library access.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ColorTokens.textSecondary(context, 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
    required double densityScale,
  }) {
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: space(8)),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: ColorTokens.cardFill(context, 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                context.scaledRadius(clamped(14, min: 10, max: 18)),
              ),
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
