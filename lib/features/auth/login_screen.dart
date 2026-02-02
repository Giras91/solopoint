import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
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
  User? _selectedUser;

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
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.clear();
      });
    }
  }

  void _selectUser(User user) {
    setState(() {
      _selectedUser = user;
      _pinController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usersAsync = ref.watch(activeUsersProvider);

    final isWide = MediaQuery.of(context).size.width >= 900;

    usersAsync.whenData((users) {
      if (_selectedUser == null && users.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedUser = users.first;
            });
          }
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = isWide
                ? Row(
                    children: [
                      Expanded(child: _buildWelcomePanel(colorScheme, textTheme)),
                      Expanded(
                        child: _buildLoginPanel(
                          context: context,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          usersAsync: usersAsync,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildWelcomePanel(colorScheme, textTheme),
                      Expanded(
                        child: _buildLoginPanel(
                          context: context,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          usersAsync: usersAsync,
                        ),
                      ),
                    ],
                  );

            return Container(
              padding: const EdgeInsets.all(24),
              color: colorScheme.surface,
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomePanel(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.point_of_sale,
            size: 96,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 20),
          Text(
            'SoloPoint',
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fast, offline POS for retail & restaurants',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Enter your PIN to continue',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel({
    required BuildContext context,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required AsyncValue<List<User>> usersAsync,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign in',
                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedUser?.name ?? 'Select a user',
                style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                textAlign: TextAlign.center,
              ),
              if (_selectedUser?.role != null) ...[
                const SizedBox(height: 4),
                Text(
                  _selectedUser!.role.toUpperCase(),
                  style: textTheme.labelMedium?.copyWith(color: colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              usersAsync.when(
                data: (users) => _buildUserSelector(users, colorScheme, textTheme),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Failed to load users',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
              ),
              const SizedBox(height: 20),
              Center(child: _buildPinDisplay(_pinController.text, colorScheme)),
              const SizedBox(height: 16),
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
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
              Row(
                children: [
                  Expanded(
                    child: _buildKeypadButton(
                      label: 'Clear',
                      onPressed: _clearPin,
                      isLoading: _isLoading,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      labelStyle: textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSelector(
    List<User> users,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (users.isEmpty) {
      return Text(
        'No active users found',
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surface,
      ),
      child: DropdownButton<User>(
        value: _selectedUser,
        hint: Text(
          'Select a staff member',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
        ),
        isExpanded: true,
        underline: const SizedBox(),
        items: users.map((user) {
          return DropdownMenuItem<User>(
            value: user,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.name,
                  style: textTheme.bodyLarge,
                ),
                Text(
                  user.role.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (user) {
          if (user != null) {
            _selectUser(user);
          }
        },
        style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
      ),
    );
  }

  Widget _buildPinDisplay(String pin, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (index) {
        final filled = index < pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colorScheme.primary : Colors.transparent,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    Color? backgroundColor,
    TextStyle? labelStyle,
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
          style: labelStyle ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
