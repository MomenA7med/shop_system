import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/import_service.dart';
import '../../../providers/inventory_provider.dart';

class ImportExcelDialog extends StatefulWidget {
  const ImportExcelDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ImportExcelDialog(),
    );
  }

  @override
  State<ImportExcelDialog> createState() => _ImportExcelDialogState();
}

class _ImportExcelDialogState extends State<ImportExcelDialog> {
  File? _selectedFile;
  List<ImportedItemPreview> _previewItems = [];
  bool _isParsing = false;
  bool _isImporting = false;
  String? _errorMessage;

  void _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        dialogTitle: 'اختر ملف أصناف السوبر ماركت (Excel أو CSV)',
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        setState(() {
          _selectedFile = file;
          _isParsing = true;
          _errorMessage = null;
        });

        final items = await ImportService.parseFileForPreview(file);

        if (!mounted) return;
        setState(() {
          _previewItems = items;
          _isParsing = false;
          if (items.isEmpty) {
            _errorMessage = 'لم يتم العثور على أي أصناف داخل الملف المحدد! تأكد من أن الملف يحتوي على بيانات.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _errorMessage = 'حدث خطأ أثناء قراءة الملف: $e';
        });
      }
    }
  }

  void _downloadTemplate() async {
    try {
      final bytes = ImportService.generateTemplateExcel();
      final saveUri = await FilePicker.saveFile(
        dialogTitle: 'حفظ نموذج إكسيل فارغ للأصناف',
        fileName: 'supermarket_products_template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (saveUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ النموذج بنجاح: ${saveUri.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ النموذج: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmImport() async {
    if (_previewItems.isEmpty) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final result = await ImportService.commitImport(_previewItems);

      if (!mounted) return;

      // Refresh inventory in background
      context.read<InventoryProvider>().loadInventory();

      Navigator.of(context).pop(true);

      // Show summary success dialog
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('تم الاستيراد بنجاح!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(Icons.all_inbox_rounded, 'إجمالي السجلات المقروءة:', '${result.totalRows} صنف'),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.add_shopping_cart_rounded, 'أصناف جديدة تمت إضافتها:', '${result.insertedProducts} صنف', color: Colors.green),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.sync_alt_rounded, 'أصناف تم تحديث رصيدها وسعرها:', '${result.updatedVariants} صنف', color: Colors.blue),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.category_rounded, 'أقسام جديدة تم إنشاؤها تلقائياً:', '${result.createdCategories} قسم', color: Colors.amber.shade800),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('ملاحظات/أخطاء: ${result.errors.length}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('تم'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = 'حدث خطأ أثناء حفظ الأصناف: $e';
        });
      }
    }
  }

  static Widget _buildSummaryRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          width: 800,
          constraints: const BoxConstraints(maxHeight: 680),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استيراد أصناف السوبر ماركت من ملف Excel / CSV',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'استورد آلاف المنتجات بضغطة زر مع الباركود، الأسعار، الأقسام، والأرصدة',
                          style: TextStyle(fontSize: 12, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // File pick action bar
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isImporting ? null : _pickFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    label: const Text('اختيار ملف (Excel / CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('تحميل نموذج إكسيل فارغ'),
                  ),
                  const Spacer(),
                  if (_selectedFile != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الملف: ${_selectedFile!.path.split(Platform.pathSeparator).last}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Preview Area
              Expanded(
                child: _isParsing
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('جاري قراءة وتحليل بيانات الملف...'),
                          ],
                        ),
                      )
                    : _previewItems.isEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              color: colors.cardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.table_view_rounded, size: 48, color: colors.textMuted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'اضغط على "اختيار ملف" لمعاينة الأصناف قبل الاستيراد',
                                    style: TextStyle(fontSize: 14, color: colors.textMuted),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'يدعم قراءة: رقم المادة، اسم المادة، الكمية، الوحدة، سعر الشراء، سعر البيع، والتصنيف',
                                    style: TextStyle(fontSize: 11, color: colors.textMuted.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: colors.cardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  child: Row(
                                    children: [
                                      Text(
                                        'تم العثور على (${_previewItems.length}) صنف جاهز للاستيراد:',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'معاينة أول 100 صنف',
                                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _previewItems.length > 100 ? 100 : _previewItems.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = _previewItems[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              child: Text('${index + 1}', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colors.surface,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: colors.border),
                                              ),
                                              child: Text(
                                                item.barcode,
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                item.productName,
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.categoryName,
                                                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'الوحدة: ${item.unit}',
                                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'شراء: ${item.costPrice.toStringAsFixed(1)}',
                                              style: TextStyle(fontSize: 11, color: colors.textMuted),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'بيع: ${item.sellingPrice.toStringAsFixed(1)} ج.م',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'الكمية: ${item.quantity}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (_previewItems.isEmpty || _isImporting) ? null : _confirmImport,
                    icon: _isImporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      _isImporting ? 'جاري الاستيراد والحفظ...' : 'تأكيد واستيراد ${_previewItems.length} صنف الآن',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
