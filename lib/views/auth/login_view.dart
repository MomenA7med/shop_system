import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/number_parser.dart';
import '../../providers/auth_provider.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  String _currentPin = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_currentPin.length < 6) {
      setState(() {
        _currentPin += digit;
        _pinController.text = _currentPin;
      });
      if (_currentPin.length == 4) {
        _attemptLogin(_currentPin);
      }
    }
  }

  void _onClear() {
    setState(() {
      _currentPin = '';
      _pinController.text = '';
    });
  }

  void _onBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        _pinController.text = _currentPin;
      });
    }
  }

  Future<void> _attemptLogin(String pin) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.login(pin);
    if (!success) {
      setState(() {
        _currentPin = '';
        _pinController.text = '';
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
        _onDigitPressed('0');
      } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
        _onDigitPressed('1');
      } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
        _onDigitPressed('2');
      } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
        _onDigitPressed('3');
      } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
        _onDigitPressed('4');
      } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
        _onDigitPressed('5');
      } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
        _onDigitPressed('6');
      } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
        _onDigitPressed('7');
      } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
        _onDigitPressed('8');
      } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
        _onDigitPressed('9');
      } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
        _onBackspace();
      } else if (key == LogicalKeyboardKey.escape) {
        _onClear();
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        if (_currentPin.length >= 4) {
          _attemptLogin(_currentPin);
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        final extracted = NumberParser.extractDigit(event.character!);
        if (extracted != null) {
          _onDigitPressed(extracted);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallHeight = constraints.maxHeight < 680;
            final isSmallWidth = constraints.maxWidth < 480;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallWidth ? 12 : 20,
                    vertical: isSmallHeight ? 16 : 32,
                  ),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: EdgeInsets.all(isSmallHeight ? 20 : 28),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          padding: EdgeInsets.all(isSmallHeight ? 12 : 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.secondary],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.checkroom_rounded,
                            color: Colors.white,
                            size: isSmallHeight ? 28 : 34,
                          ),
                        ),

                        SizedBox(height: isSmallHeight ? 10 : 14),
                        Text(
                          AppStrings.appName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallHeight ? 15 : 17,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.enterPin,
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),

                        SizedBox(height: isSmallHeight ? 14 : 20),

                        // PIN Display Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _currentPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: isSmallHeight ? 13 : 15,
                              height: isSmallHeight ? 13 : 15,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? colors.primary : Colors.transparent,
                                border: Border.all(
                                  color: isFilled ? colors.primary : colors.border,
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),

                        if (auth.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              auth.errorMessage!,
                              style: TextStyle(color: colors.error, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],

                        SizedBox(height: isSmallHeight ? 14 : 20),

                        // Keypad
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          childAspectRatio: isSmallHeight ? 2.0 : 1.7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: [
                            for (var i = 1; i <= 9; i++) _buildKeypadBtn(context, i.toString(), isSmallHeight),
                            _buildSpecialBtn(context, 'C', _onClear, color: colors.error, isSmall: isSmallHeight),
                            _buildKeypadBtn(context, '0', isSmallHeight),
                            _buildSpecialBtn(context, '⌫', _onBackspace, color: colors.warning, isSmall: isSmallHeight),
                          ],
                        ),

                        SizedBox(height: isSmallHeight ? 14 : 18),

                        // Quick Test PINs
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.cardSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(Icons.admin_panel_settings, size: 14, color: colors.secondary),
                                label: Text('المدير: 1234', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                onPressed: () => _attemptLogin('1234'),
                              ),
                              Text('|', style: TextStyle(color: colors.border)),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(Icons.person, size: 14, color: colors.primary),
                                label: Text('الكاشير: 0000', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                onPressed: () => _attemptLogin('0000'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Developer Credit
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.cardSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.engineering_rounded, size: 14, color: colors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'تطوير: م / مؤمن أحمد محمد | 📱 01003779702',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  }

  Widget _buildKeypadBtn(BuildContext context, String text, bool isSmall) {
    final colors = context.colors;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.keypadButton,
        foregroundColor: colors.textPrimary,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: () => _onDigitPressed(text),
      child: Text(
        text,
        style: TextStyle(fontSize: isSmall ? 17 : 19, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSpecialBtn(BuildContext context, String text, VoidCallback onPressed, {required Color color, required bool isSmall}) {
    final colors = context.colors;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.keypadButton,
        foregroundColor: color,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(fontSize: isSmall ? 15 : 17, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
