import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/app_info_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/utils/number_parser.dart';
import '../../models/store_settings_model.dart';
import '../../models/user_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/inventory_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeNameCtrl;
  late TextEditingController _sloganCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _footerCtrl;

  final FocusNode _storeNameFocus = FocusNode();
  final FocusNode _sloganFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _currencyFocus = FocusNode();
  final FocusNode _footerFocus = FocusNode();

  String? _selectedLogoPath;
  String _activeCollection = 'all';
  StoreSettingsModel? _lastSyncedSettings;
  bool _isSaving = false;
  String? _backupStatus;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _storeNameCtrl = TextEditingController(text: settings.storeName);
    _sloganCtrl = TextEditingController(text: settings.slogan);
    _phoneCtrl = TextEditingController(text: settings.phone);
    _addressCtrl = TextEditingController(text: settings.address);
    _currencyCtrl = TextEditingController(text: settings.currencySymbol);
    _footerCtrl = TextEditingController(text: settings.receiptFooter);
    _selectedLogoPath = settings.logoPath;
    _activeCollection = settings.activeCollection;
    _lastSyncedSettings = settings;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
    });
  }

  void _syncControllersWithSettings(StoreSettingsModel settings) {
    if (_lastSyncedSettings == settings) return;
    _lastSyncedSettings = settings;

    if (!_storeNameFocus.hasFocus) _storeNameCtrl.text = settings.storeName;
    if (!_sloganFocus.hasFocus) _sloganCtrl.text = settings.slogan;
    if (!_phoneFocus.hasFocus) _phoneCtrl.text = settings.phone;
    if (!_addressFocus.hasFocus) _addressCtrl.text = settings.address;
    if (!_currencyFocus.hasFocus) _currencyCtrl.text = settings.currencySymbol;
    if (!_footerFocus.hasFocus) _footerCtrl.text = settings.receiptFooter;
    if (!_storeNameFocus.hasFocus &&
        !_sloganFocus.hasFocus &&
        !_phoneFocus.hasFocus &&
        !_addressFocus.hasFocus &&
        !_currencyFocus.hasFocus &&
        !_footerFocus.hasFocus) {
      _selectedLogoPath = settings.logoPath;
      _activeCollection = settings.activeCollection;
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _sloganCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _currencyCtrl.dispose();
    _footerCtrl.dispose();

    _storeNameFocus.dispose();
    _sloganFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _currencyFocus.dispose();
    _footerFocus.dispose();
    super.dispose();
  }

  Future<void> _onPickLogo() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        dialogTitle: 'اختر شعار (لوجو) المتجر',
      );

      if (files.isNotEmpty && files.first.path != null) {
        final pickedPath = files.first.path!;
        final file = File(pickedPath);
        if (await file.exists()) {
          final appDir = await getApplicationDocumentsDirectory();
          final logosDir = Directory(p.join(appDir.path, 'shop_logos'));
          if (!await logosDir.exists()) {
            await logosDir.create(recursive: true);
          }
          final ext = p.extension(pickedPath);
          final destPath = p.join(
            logosDir.path,
            'store_logo_${DateTime.now().millisecondsSinceEpoch}$ext',
          );
          await file.copy(destPath);

          setState(() {
            _selectedLogoPath = destPath;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر اختيار صورة اللوجو: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onRemoveLogo() {
    setState(() {
      _selectedLogoPath = null;
    });
  }

  void _onSaveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final settingsProvider = context.read<SettingsProvider>();

    final updated = settingsProvider.settings.copyWith(
      storeName: _storeNameCtrl.text.trim(),
      slogan: _sloganCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      currencySymbol: _currencyCtrl.text.trim(),
      receiptFooter: _footerCtrl.text.trim(),
      activeCollection: _activeCollection,
      logoPath: _selectedLogoPath,
      clearLogo: _selectedLogoPath == null,
    );

    _lastSyncedSettings = updated;
    final success = await settingsProvider.updateSettings(updated);
    if (mounted) {
      context.read<POSProvider>().loadPOSData();
      context.read<InventoryProvider>().loadInventory();
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم حفظ إعدادات المتجر بنجاح' : 'حدث خطأ أثناء الحفظ',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _onExportBackup() async {
    try {
      final savedPath = await BackupService.exportBackup();
      if (savedPath != null && mounted) {
        setState(() => _backupStatus = 'تم حفظ النسخة بنجاح في: $savedPath');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backupStatus = 'خطأ في النسخ الاحتياطي: $e');
      }
    }
  }

  void _onRestoreBackup() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استعادة النسخة الاحتياطية'),
        content: const Text(
          'سيتم استبدال قاعدة البيانات الحالية بالملف الذي ستختاره. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final restored = await BackupService.restoreBackup();
                if (restored && mounted) {
                  await context.read<SettingsProvider>().loadSettings();
                  setState(() => _backupStatus = 'تمت استعادة النسخة بنجاح.');
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _backupStatus = 'خطأ في الاستعادة: $e');
                }
              }
            },
            child: const Text('متابعة واختيار الملف'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String role = 'cashier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('إضافة مستخدم جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف/الكاشير',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رمز الدخول / كلمة المرور (PIN)',
                    hintText: 'مثال: 1234',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'نوع الصلاحية'),
                  items: const [
                    DropdownMenuItem(
                      value: 'cashier',
                      child: Text('كاشير (مبيعات ومرتجعات فقط)'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('مدير النظام (كامل الصلاحيات)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => role = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(AppStrings.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isNotEmpty &&
                      pinCtrl.text.trim().isNotEmpty) {
                    await context.read<SettingsProvider>().addUser(
                      nameCtrl.text.trim(),
                      role,
                      NumberParser.normalize(pinCtrl.text.trim()),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  }
                },
                child: const Text(AppStrings.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final pinCtrl = TextEditingController(text: user.pinCode);
    String role = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('تعديل بيانات: ${user.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف/المستخدم',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور / رمز الدخول (PIN)',
                    prefixIcon: Icon(Icons.lock_outline),
                    helperText: 'يمكنك تغيير رمز المرور الخاص بالمستخدم هنا',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'نوع الصلاحية',
                    prefixIcon: Icon(Icons.security_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'cashier',
                      child: Text('كاشير (مبيعات ومرتجعات)'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('مدير النظام (كامل الصلاحيات)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => role = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(AppStrings.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isNotEmpty &&
                      pinCtrl.text.trim().isNotEmpty) {
                    final updatedUser = UserModel(
                      id: user.id,
                      name: nameCtrl.text.trim(),
                      role: role,
                      pinCode: NumberParser.normalize(pinCtrl.text.trim()),
                      createdAt: user.createdAt,
                    );
                    final success = await context
                        .read<SettingsProvider>()
                        .updateUser(updatedUser);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'تم تحديث بيانات المستخدم بنجاح'
                                : 'حدث خطأ أثناء التحديث',
                          ),
                          backgroundColor: success
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settingsProvider = context.watch<SettingsProvider>();
    final users = settingsProvider.users;

    if (!_isSaving) {
      _syncControllersWithSettings(settingsProvider.settings);
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                AppStrings.storeSettings,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Theme & Appearance Card
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.palette_outlined,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المظهر وسمة التطبيق (Theme & Appearance)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'اختر المظهر المفضل لشاشات البيع ولوحة التحكم',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Dark Theme Option
                        Expanded(
                          child: _buildThemeOption(
                            context: context,
                            title: 'الوضع الليلي',
                            subtitle: 'Dark Mode (مريح للعين)',
                            icon: Icons.dark_mode_rounded,
                            iconColor: const Color(0xFF818CF8),
                            isSelected:
                                settingsProvider.themeMode == ThemeMode.dark,
                            onTap: () =>
                                settingsProvider.setThemeMode(ThemeMode.dark),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Light Theme Option
                        Expanded(
                          child: _buildThemeOption(
                            context: context,
                            title: 'الوضع النهاري',
                            subtitle: 'Light Mode (ساطع وواضح)',
                            icon: Icons.light_mode_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            isSelected:
                                settingsProvider.themeMode == ThemeMode.light,
                            onTap: () =>
                                settingsProvider.setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // System Theme Option
                        Expanded(
                          child: _buildThemeOption(
                            context: context,
                            title: 'وضع النظام',
                            subtitle: 'System Default (تلقائي)',
                            icon: Icons.brightness_auto_rounded,
                            iconColor: AppColors.accent,
                            isSelected:
                                settingsProvider.themeMode == ThemeMode.system,
                            onTap: () =>
                                settingsProvider.setThemeMode(ThemeMode.system),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Store Branding Card
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات المتجر وهوية الفاتورة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Store Logo Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          // Logo Preview
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                _selectedLogoPath != null &&
                                    File(_selectedLogoPath!).existsSync()
                                ? Image.file(
                                    File(_selectedLogoPath!),
                                    fit: BoxFit.contain,
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.storefront_outlined,
                                      size: 36,
                                      color: colors.textMuted,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),

                          // Logo Info & Actions
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'شعار المتجر (Logo)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedLogoPath != null
                                      ? 'تم تحديد شعار للمتجر وسيظهر في شاشة البيع وأعلى التطبيق'
                                      : 'اختر صورة شعار متجرك بصيغة (PNG, JPG, WEBP) لتظهر في شاشة البيع',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.upload_file_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _selectedLogoPath != null
                                            ? 'تغيير الشعار'
                                            : 'اختيار شعار للمحل',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: _onPickLogo,
                                    ),
                                    if (_selectedLogoPath != null)
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'إزالة الشعار',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onPressed: _onRemoveLogo,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _storeNameCtrl,
                            focusNode: _storeNameFocus,
                            decoration: const InputDecoration(
                              labelText: AppStrings.storeName,
                            ),
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _sloganCtrl,
                            focusNode: _sloganFocus,
                            decoration: const InputDecoration(
                              labelText: AppStrings.storeSlogan,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            decoration: const InputDecoration(
                              labelText: AppStrings.storePhone,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _currencyCtrl,
                            focusNode: _currencyFocus,
                            decoration: const InputDecoration(
                              labelText: AppStrings.currencySymbol,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _addressCtrl,
                      focusNode: _addressFocus,
                      decoration: const InputDecoration(
                        labelText: AppStrings.storeAddress,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _footerCtrl,
                      focusNode: _footerFocus,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: AppStrings.receiptFooter,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Active Collection Selector
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _activeCollection,
                      decoration: const InputDecoration(
                        labelText: 'الموسم / الكولكشن النشط للمتجر',
                        helperText:
                            'يحدد المنتجات المعروضة في نقطة البيع (الكاشير) والمخزون',
                        prefixIcon: Icon(
                          Icons.style_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'الكل / شامل (عرض كل المنتجات: الصيفي والشتوي والعام)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'summer',
                          child: Text('كولكشن صيفي ☀️'),
                        ),
                        DropdownMenuItem(
                          value: 'winter',
                          child: Text('كولكشن شتوي ❄️'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _activeCollection = val);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(
                          _isSaving ? 'جاري الحفظ...' : 'حفظ بيانات المتجر',
                        ),
                        onPressed: _isSaving ? null : _onSaveSettings,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Users & Permissions Management
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المستخدمون والصلاحيات (PIN Codes)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colors.textPrimary,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                          ),
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text(
                            'إضافة موظف',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: _showAddUserDialog,
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: user.isAdmin
                                  ? AppColors.secondary
                                  : AppColors.primary,
                              child: Text(
                                user.name.substring(0, 1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    user.isAdmin
                                        ? 'مدير النظام'
                                        : 'كاشير مبيعات',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.cardSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.key,
                                    size: 13,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PIN: ${user.pinCode}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Edit user details and password button
                            IconButton(
                              tooltip: 'تعديل الاسم أو كلمة المرور',
                              icon: Icon(
                                Icons.edit_outlined,
                                color: colors.primary,
                                size: 19,
                              ),
                              onPressed: () => _showEditUserDialog(user),
                            ),
                            if (users.length > 1)
                              IconButton(
                                tooltip: 'حذف المستخدم',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 19,
                                ),
                                onPressed: () {
                                  if (user.id != null) {
                                    showDialog(
                                      context: context,
                                      builder: (deleteCtx) => AlertDialog(
                                        title: const Text('تأكيد حذف المستخدم'),
                                        content: Text(
                                          'هل أنت متأكد من حذف المستخدم "${user.name}"؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(deleteCtx).pop(),
                                            child: const Text(
                                              AppStrings.cancel,
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                            ),
                                            onPressed: () async {
                                              Navigator.of(deleteCtx).pop();
                                              await context
                                                  .read<SettingsProvider>()
                                                  .deleteUser(user.id!);
                                            },
                                            child: const Text('حذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Backup & Restore Database Section
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'النسخ الاحتياطي واستعادة البيانات',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يمكنك تصدير نسخة كاملة من قاعدة البيانات وحفظها على فلاش ميموري USB أو مجلد خارجي لحماية البيانات.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                          ),
                          label: const Text(AppStrings.backupDatabase),
                          onPressed: _onExportBackup,
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.cloud_download_outlined,
                            size: 18,
                          ),
                          label: const Text(AppStrings.restoreDatabase),
                          onPressed: _onRestoreBackup,
                        ),
                      ],
                    ),

                    if (_backupStatus != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.cardSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _backupStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Developer & Technical Support Card
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.engineering_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معلومات المطور والدعم الفني',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'بيانات التواصل مع مبرمج النظام للدعم الفني والتطوير',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.18,
                            ),
                            child: const Icon(
                              Icons.person_pin_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المهندس : مؤمن أحمد محمد',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_iphone_rounded,
                                      size: 15,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'الموبايل : 01003779702',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: colors.primaryLight,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppInfoService.displayVersion,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.primaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : colors.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected
                          ? colors.primaryLight
                          : colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
