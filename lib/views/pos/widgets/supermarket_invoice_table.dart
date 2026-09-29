import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/number_parser.dart';
import '../../../models/product_model.dart';
import '../../../models/product_variant_model.dart';
import '../../../providers/pos_provider.dart';

class SupermarketInvoiceTable extends StatefulWidget {
  const SupermarketInvoiceTable({super.key});

  @override
  State<SupermarketInvoiceTable> createState() => _SupermarketInvoiceTableState();
}

class _SupermarketInvoiceTableState extends State<SupermarketInvoiceTable> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<ProductModel> _matchingProducts = [];
  bool _showDropdown = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) async {
    final pos = context.read<POSProvider>();
    final query = NumberParser.normalize(value.trim());
    if (query.isEmpty) return;

    // 1. Try barcode scan
    final wasBarcode = await pos.scanBarcode(query);
    if (wasBarcode) {
      _searchController.clear();
      setState(() {
        _showDropdown = false;
        _matchingProducts = [];
      });
      _searchFocus.requestFocus();
      return;
    }

    // 2. If single matching product
    if (pos.products.length == 1 && pos.products.first.variants.isNotEmpty) {
      final product = pos.products.first;
      final variant = product.variants.first;
      pos.addVariantToCart(product, variant);
      _searchController.clear();
      pos.clearSearch();
      setState(() {
        _showDropdown = false;
        _matchingProducts = [];
      });
      _searchFocus.requestFocus();
      return;
    }

    // 3. Otherwise show matching results
    pos.setSearchQuery(query);
    setState(() {
      _matchingProducts = pos.products;
      _showDropdown = pos.products.isNotEmpty;
    });
  }

  void _onSearchChanged(String val) {
    final pos = context.read<POSProvider>();
    if (val.isEmpty) {
      pos.clearSearch();
      setState(() {
        _showDropdown = false;
        _matchingProducts = [];
      });
    } else {
      pos.setSearchQuery(val);
      setState(() {
        _matchingProducts = pos.products;
        _showDropdown = pos.products.isNotEmpty;
      });
    }
  }

  void _addQuickItem(String name, double price, String unit, String barcode) async {
    final pos = context.read<POSProvider>();
    // Try to find if exists in products, otherwise create standard cart item
    final found = await pos.scanBarcode(barcode);
    if (!found) {
      // Create ad-hoc variant & product
      final product = ProductModel(id: 999900 + barcode.hashCode.abs() % 1000, categoryId: 1, name: name);
      final variant = ProductVariantModel(
        id: 999900 + barcode.hashCode.abs() % 1000,
        productId: product.id!,
        skuBarcode: barcode,
        size: unit,
        color: '-',
        costPrice: price * 0.75,
        sellingPrice: price,
        stockQuantity: 999,
      );
      pos.addVariantToCart(product, variant);
    }
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pos = context.watch<POSProvider>();
    final cartItems = pos.cartItems;

    return Column(
      children: [
        // 1. Top Barcode Scanner & Search Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'امسح الباركود بالسكانر أو اكتب اسم الصنف / الكود ثم اضغط Enter...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        filled: true,
                        fillColor: colors.cardSurface,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSubmitted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('إضافة (Enter)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _onSubmitted(_searchController.text),
                  ),
                  if (cartItems.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('مسح الفاتورة'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: AlertDialog(
                              title: const Text('تأكيد مسح الفاتورة'),
                              content: const Text('هل أنت متأكد من تفريغ كافة أصناف الفاتورة الحالية؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                  onPressed: () {
                                    pos.clearCart();
                                    Navigator.of(ctx).pop();
                                  },
                                  child: const Text('تفريغ الفاتورة'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),

              // Quick Chips (Bread, Bags, Water, Eggs, Soda)
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('أصناف سريعة: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 4),
                  _buildQuickChip('🍞 عيش بلدي', 5.0, 'رغيف', '999001'),
                  const SizedBox(width: 6),
                  _buildQuickChip('🛍️ كيس بلاستيك', 1.0, 'قطعة', '999002'),
                  const SizedBox(width: 6),
                  _buildQuickChip('💧 مياه معدنية', 7.0, 'زجاجة', '999003'),
                  const SizedBox(width: 6),
                  _buildQuickChip('🥚 بيض', 6.0, 'بيضة', '999004'),
                  const SizedBox(width: 6),
                  _buildQuickChip('🥤 كانز بيبسي', 15.0, 'كانز', '999005'),
                ],
              ),
            ],
          ),
        ),

        // Live Search Results Dropdown Overlay if active
        if (_showDropdown && _matchingProducts.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _matchingProducts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final prod = _matchingProducts[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                  title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    prod.variants.map((v) {
                      final hasDesc = v.color.isNotEmpty &&
                          v.color != '-' &&
                          v.color != 'افتراضي';
                      final label = hasDesc ? '${v.size} (${v.color})' : v.size;
                      return '$label: ${v.sellingPrice.toStringAsFixed(0)}ج (مخزون: ${NumberParser.formatQuantity(v.stockQuantity)})';
                    }).join(' | '),
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: prod.variants.map((v) {
                      final hasDesc = v.color.isNotEmpty &&
                          v.color != '-' &&
                          v.color != 'افتراضي';
                      final btnLabel = hasDesc
                          ? '+ ${v.size} (${v.color}) - ${v.sellingPrice.toStringAsFixed(0)}ج'
                          : '+ ${v.size} (${v.sellingPrice.toStringAsFixed(0)}ج)';
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: const Size(44, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          pos.addVariantToCart(prod, v);
                          _searchController.clear();
                          setState(() {
                            _showDropdown = false;
                            _matchingProducts = [];
                          });
                          _searchFocus.requestFocus();
                        },
                        child: Text(
                          btnLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

        // 2. Invoice Items Table
        Expanded(
          child: cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 72, color: colors.textMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'الفاتورة فارغة حالياً',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'امسح باركود الصنف أو اختر من الأصناف السريعة أعلاه لبدء البيع',
                        style: TextStyle(fontSize: 13, color: colors.textMuted),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: colors.cardSurface,
                      child: Row(
                        children: [
                          _buildHeaderCell('#', width: 36),
                          _buildHeaderCell('الباركود', width: 140),
                          _buildHeaderCell('اسم الصنف / المادة', flex: 4),
                          _buildHeaderCell('الوحدة', flex: 2, align: TextAlign.center),
                          _buildHeaderCell('السعر', flex: 2, align: TextAlign.center),
                          _buildHeaderCell('الوزن / الكمية', flex: 3, align: TextAlign.center),
                          _buildHeaderCell('الإجمالي', flex: 2, align: TextAlign.center),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Table Body Rows
                    Expanded(
                      child: ListView.separated(
                        itemCount: cartItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: index % 2 == 0 ? colors.surface : colors.cardSurface.withValues(alpha: 0.3),
                            child: Row(
                              children: [
                                // #
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textMuted),
                                  ),
                                ),

                                // Barcode
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    item.skuBarcode,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Name
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item.productName,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Unit
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.cardSurface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Text(
                                      (item.color.isNotEmpty && item.color != '-' && item.color != 'افتراضي')
                                          ? '${item.size} (${item.color})'
                                          : (item.size.isNotEmpty ? item.size : 'قطعة'),
                                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                                // Unit Price
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    CurrencyFormatter.format(item.unitPrice, symbol: ''),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                // Quantity (+ / - & Weight Dialog)
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                        color: AppColors.error,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: () {
                                          if (item.quantity <= 1.0 && item.quantity > 0.25) {
                                            pos.decrementQuantity(index, 0.25);
                                          } else {
                                            pos.decrementQuantity(index, 1.0);
                                          }
                                        },
                                      ),
                                      InkWell(
                                        onTap: () => _showWeightQuantityDialog(index),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Tooltip(
                                          message: 'اضغط لتعديل الوزن أو الكسور (ربع، نص، تلت...)',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: colors.surface,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primary, width: 1.2),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (item.quantity < 1.0) ...[
                                                  const Icon(Icons.scale_rounded, size: 13, color: AppColors.primary),
                                                  const SizedBox(width: 3),
                                                ],
                                                Text(
                                                  NumberParser.formatQuantity(item.quantity),
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                        color: AppColors.primary,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: () {
                                          if (item.quantity < 1.0) {
                                            pos.incrementQuantity(index, 0.25);
                                          } else {
                                            pos.incrementQuantity(index, 1.0);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // Total Item Price
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    CurrencyFormatter.format(item.totalPrice, symbol: 'ج.م'),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                // Delete
                                SizedBox(
                                  width: 44,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                    tooltip: 'حذف من الفاتورة',
                                    onPressed: () => pos.removeItem(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Table Footer Summary Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(top: BorderSide(color: colors.border)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'عدد البنود: ${cartItems.length} | إجمالي الكميات: ${NumberParser.formatQuantity(cartItems.fold(0.0, (sum, i) => sum + i.quantity))}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
                          ),
                          const Spacer(),
                          Text(
                            'المجموع الفرعي: ${CurrencyFormatter.format(pos.subtotal, symbol: 'ج.م')}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showWeightQuantityDialog(int index) {
    final pos = context.read<POSProvider>();
    if (index < 0 || index >= pos.cartItems.length) return;
    final item = pos.cartItems[index];

    final ctrl = TextEditingController(text: NumberParser.formatQuantity(item.quantity));
    final focus = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.scale_rounded, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'سعر الكيلو / الوحدة: ${CurrencyFormatter.format(item.unitPrice, symbol: 'ج.م')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (ctx, setDlgState) {
              double currentVal = NumberParser.tryParseDouble(ctrl.text, item.quantity);
              double estTotal = currentVal * item.unitPrice;

              void setFraction(double frac) {
                ctrl.text = NumberParser.formatQuantity(frac);
                setDlgState(() {});
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أوزان وكسور سريعة (للجبن واللحوم والموزونات):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFractionChip('⅛ تمن (0.125)', 0.125, currentVal, setFraction),
                      _buildFractionChip('¼ ربع (0.25)', 0.25, currentVal, setFraction),
                      _buildFractionChip('⅓ تلت (0.333)', 0.333, currentVal, setFraction),
                      _buildFractionChip('½ نص (0.50)', 0.50, currentVal, setFraction),
                      _buildFractionChip('¾ إلا ربع (0.75)', 0.75, currentVal, setFraction),
                      _buildFractionChip('1 كجم', 1.0, currentVal, setFraction),
                      _buildFractionChip('1.5 كجم', 1.5, currentVal, setFraction),
                      _buildFractionChip('2 كجم', 2.0, currentVal, setFraction),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('أو اكتب الوزن / الكمية يدوياً:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: AppColors.error, size: 28),
                        onPressed: () {
                          double v = NumberParser.tryParseDouble(ctrl.text, 1.0);
                          if (v > 0.25) {
                            v = (v - (v <= 1.0 ? 0.25 : 0.5));
                          } else {
                            v = 0.125;
                          }
                          ctrl.text = NumberParser.formatQuantity(v);
                          setDlgState(() {});
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          focusNode: focus,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'مثال: 0.25 أو ربع أو 1.5',
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            suffixText: item.size.isNotEmpty ? item.size : 'كجم',
                          ),
                          onChanged: (val) {
                            setDlgState(() {});
                          },
                          onSubmitted: (val) {
                            final parsed = NumberParser.parseQuantity(val, item.quantity);
                            pos.updateQuantity(index, parsed);
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                        onPressed: () {
                          double v = NumberParser.tryParseDouble(ctrl.text, 0.0);
                          v = (v + (v < 1.0 ? 0.25 : 0.5));
                          ctrl.text = NumberParser.formatQuantity(v);
                          setDlgState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي سعر هذا الوزن:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          CurrencyFormatter.format(estTotal, symbol: 'ج.م'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final parsed = NumberParser.parseQuantity(ctrl.text, item.quantity);
                pos.updateQuantity(index, parsed);
                Navigator.of(ctx).pop();
              },
              child: const Text('تأكيد الوزن / الكمية'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFractionChip(String label, double value, double currentVal, Function(double) onSelect) {
    final isSelected = (value - currentVal).abs() < 0.01;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      onSelected: (_) => onSelect(value),
    );
  }

  Widget _buildHeaderCell(String title, {int? flex, double? width, TextAlign align = TextAlign.start}) {
    final colors = context.colors;
    final text = Text(
      title,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
      textAlign: align,
    );

    if (width != null) {
      return SizedBox(width: width, child: text);
    }
    return Expanded(flex: flex ?? 1, child: text);
  }

  Widget _buildQuickChip(String label, double price, String unit, String code) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _addQuickItem(label.replaceAll(RegExp(r'^[^\s]+\s'), ''), price, unit, code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          '$label (${price.toStringAsFixed(0)}ج)',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
