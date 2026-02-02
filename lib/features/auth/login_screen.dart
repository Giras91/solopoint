import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _pinController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_pinController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref.read(authProvider.notifier).login(_pinController.text);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        // Clear PIN and navigate to dashboard
        _pinController.clear();
        if (mounted) {
          context.go('/');
        }
      } else {
        setState(() => _errorMessage = 'Invalid PIN');
      }
    }
  }

  void _addPin(String digit) {
    if (_pinController.text.length < 6) {
      setState(() {
        _pinController.text += digit;
        _errorMessage = null;
      });
    }
  }

  void _removeLastPin() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      });
    }
  }

  void _clearPin() {
    setState(() {
      _pinController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo/Icon
                Icon(
                  Icons.point_of_sale,
                  size: 80,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'SoloPoint',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Offline POS System',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 48),

                // PIN Display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PIN: ',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(width: 12),
                      ..._buildPinDisplay(_pinController.text),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // Numeric Keypad
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  children: [
                    ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) {
                      return _buildKeypadButton(
                        label: '$num',
                        onPressed: () => _addPin('$num'),
                        isLoading: _isLoading,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom row: 0, Clear, Login
                Row(
                  children: [
                    Expanded(
                      child: _buildKeypadButton(
                        label: '0',
                        onPressed: () => _addPin('0'),
                        isLoading: _isLoading,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKeypadButton(
                        label: '⌫',
                        onPressed: _removeLastPin,
                        isLoading: _isLoading,
                        backgroundColor: colorScheme.surfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleLogin,
                        icon: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Login'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPinDisplay(String pin) {
    const dotChar = '●';
    return List.generate(
      6,
      (index) {
        if (index < pin.length) {
          return Text(
            dotChar,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          );
        } else {
          return Container(
            width: 12,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }
      },
    ).fold<List<Widget>>(
      [],
      (acc, widget) => [
        ...acc,
        if (acc.isNotEmpty) const SizedBox(width: 12),
        widget,
      ],
    );
  }

  Widget _buildKeypadButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    Color? backgroundColor,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
