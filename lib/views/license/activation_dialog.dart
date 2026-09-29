import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/license_service.dart';
import '../../providers/license_provider.dart';

class ActivationDialog extends StatefulWidget {
  final String? initialReason;

  const ActivationDialog({super.key, this.initialReason});

  static Future<bool?> show(BuildContext context, {String? reason}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ActivationDialog(initialReason: reason),
    );
  }

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  final TextEditingController _keyController = TextEditingController();
  bool _isActivating = false;
  String? _errorText;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _openWhatsApp() async {
    final url = await LicenseService.getWhatsAppPurchaseUrl();
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح المتصفح تلقائياً. يمكنك مراسلتنا على: 01003779702'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onActivate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorText = 'يرجى إدخال كود التفعيل المكون من 16 حرفاً';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _errorText = null;
    });

    final provider = context.read<LicenseProvider>();
    final success = await provider.activate(key);

    if (!mounted) return;

    setState(() {
      _isActivating = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تهانينا! تم التفعيل بنجاح', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'تم تفعيل البرنامج بشكل دائم وكامل على هذا الجهاز.\nشكراً لثقتكم بنا!',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorText = provider.errorMessage ?? 'كود التفعيل غير صحيح! تأكد من إدخاله بدقة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseProvider>();
    final hw = license.hardwareInfo;
    final colors = context.colors;

    final motherboard = hw?.motherboardSerial ?? 'جاري القراءة...';
    final disk = hw?.diskSerial ?? 'جاري القراءة...';
    final machineId = hw?.machineId ?? 'جاري القراءة...';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'شراء وتفعيل النظام',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            license.isActivated ? 'النسخة مفعلة بشكل دائم' : 'النسخة التجريبية - ترخيص دائم للجهاز',
                            style: TextStyle(
                              fontSize: 12,
                              color: license.isActivated ? Colors.green : colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),

                if (widget.initialReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.initialReason!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Motherboard Serial
                _buildHardwareField(
                  label: 'رقم البورد الخاص بك هو (Motherboard):',
                  value: motherboard,
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // Disk Serial
                _buildHardwareField(
                  label: 'رقم الهارديسك الخاص بك هو (Hard Disk):',
                  value: disk,
                  colors: colors,
                ),
                const SizedBox(height: 12),

                // Machine ID
                _buildHardwareField(
                  label: 'كود جهازك الفريد (Device Machine ID):',
                  value: machineId,
                  colors: colors,
                  isHighlight: true,
                ),
                const SizedBox(height: 20),

                // Input Box for Activation Key
                Text(
                  'ادخل كود شراء النظام:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX-XXXX-XXXX',
                    hintStyle: TextStyle(letterSpacing: 2, color: colors.textMuted.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.amber.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.amber.shade700, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),

                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons: Activate Now & WhatsApp
                Row(
                  children: [
                    // Activate Button
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: _isActivating ? null : _onActivate,
                        icon: _isActivating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.vpn_key_rounded, size: 20),
                        label: Text(
                          _isActivating ? 'جاري التحقق...' : 'تفعيل الآن',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // WhatsApp Button
                    Expanded(
                      flex: 6,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                          backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _openWhatsApp,
                        icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                        label: const Text(
                          'طلب كود الشراء (واتساب)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Information & Guarantee Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'قم بشراء النظام مرة واحدة فقط والتفعيل لا يحتاج إلى إنترنت',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• مدة كود التفعيل دائمة مدى الحياة لأنها تعتمد على لوحة الأم للجهاز.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '• عند حذف الويندوز وإعادة تنصيب البرنامج وإدخال الكود سيعمل مباشرة.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '• شراء الكود لمرة واحدة وللأولى فقط.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHardwareField({
    required String label,
    required String value,
    required AppColorsExtension colors,
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlight ? AppColors.primary.withValues(alpha: 0.08) : colors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHighlight ? AppColors.primary.withValues(alpha: 0.4) : colors.border,
              width: isHighlight ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isHighlight ? AppColors.primary : colors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ البيانات إلى الحافظة بنجاح'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: colors.textPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'نسخ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
