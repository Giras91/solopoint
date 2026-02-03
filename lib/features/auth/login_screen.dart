import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';
import 'attendance_repository.dart';
import 'user_repository.dart';

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

  void _handleClockIn() async {
    if (_pinController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref
          .read(userRepositoryProvider)
          .authenticateByPin(_pinController.text);

      if (user != null) {
        await ref
            .read(attendanceRepositoryProvider)
            .clockIn(user.id);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
            _pinController.clear();
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} clocked in')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid PIN';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _handleClockOut() async {
    if (_pinController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref
          .read(userRepositoryProvider)
          .authenticateByPin(_pinController.text);

      if (user != null) {
        await ref
            .read(attendanceRepositoryProvider)
            .clockOut(user.id);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
            _pinController.clear();
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} clocked out')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid PIN';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _handleBreakStart() async {
    if (_pinController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref
          .read(userRepositoryProvider)
          .authenticateByPin(_pinController.text);

      if (user != null) {
        await ref
            .read(attendanceRepositoryProvider)
            .startBreak(user.id);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} on break')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid PIN';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
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

  // ignore: unused_element
  void _clearPin() {
    setState(() {
      _pinController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
            onError: (exception, stackTrace) {},
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: isTablet ? 900 : double.infinity),
              margin: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Left side - PIN Pad
                  Expanded(
                    flex: isTablet ? 5 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          topRight: isTablet ? Radius.zero : Radius.circular(12),
                          bottomRight: isTablet ? Radius.zero : Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // PIN Display with asterisks
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _pinController.text.isEmpty
                                    ? '****'
                                    : '*' * _pinController.text.length,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                              ),
                            ),

                          // Numeric Keypad (3x4 grid)
                          AspectRatio(
                            aspectRatio: 0.85,
                            child: GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                // Numbers 1-9
                                ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((number) {
                                  return _buildKeypadButton(
                                    label: '$number',
                                    onPressed: () => _addPin('$number'),
                                    isLoading: _isLoading,
                                  );
                                }),
                                // Back button
                                _buildKeypadButton(
                                  label: '←',
                                  onPressed: _removeLastPin,
                                  isLoading: _isLoading,
                                  backgroundColor: Colors.grey.shade200,
                                ),
                                // Zero
                                _buildKeypadButton(
                                  label: '0',
                                  onPressed: () => _addPin('0'),
                                  isLoading: _isLoading,
                                ),
                                // Clear button
                                _buildKeypadButton(
                                  label: '×',
                                  onPressed: () => setState(() => _pinController.clear()),
                                  isLoading: _isLoading,
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right side - Logo and Action Buttons
                  if (isTablet)
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800.withOpacity(0.95),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo and Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.grid_3x3,
                                  color: Color(0xFFFDB825),
                                  size: 48,
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'SOLO',
                                            style: TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.w300,
                                              color: Colors.white,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'POINT',
                                            style: TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFDB825),
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'SALES REVOLUTION',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white70,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),

                            // Action Buttons
                            _buildActionButton(
                              label: 'LOGIN',
                              onPressed: _isLoading ? null : _handleLogin,
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              label: 'CLOCK IN',
                              onPressed: _isLoading ? null : _handleClockIn,
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              label: 'CLOCK OUT',
                              onPressed: _isLoading ? null : _handleClockOut,
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              label: 'BREAK',
                              onPressed: _isLoading ? null : _handleBreakStart,
                            ),
                          ],
                        ),
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

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFDB825),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    Color? backgroundColor,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.white,
        foregroundColor: Colors.grey.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        elevation: 1,
        shadowColor: Colors.black12,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 32,
          fontWeight: label == '←' || label == '×' ? FontWeight.w300 : FontWeight.w400,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
