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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'امسح الباركود الآن أو ابحث بالاسم (Enter لإضافة الصنف)...',
                        hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
                        filled: true,
                        fillColor: colors.cardSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  pos.clearSearch();
                                  setState(() {
                                    _showDropdown = false;
                                    _matchingProducts = [];
                                  });
                                  _searchFocus.requestFocus();
                                },
                              )
                            : null,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSubmitted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (cartItems.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => pos.clearCart(),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('مسح الفاتورة'),
                    ),
                ],
              ),

              // Autocomplete suggestions dropdown if search query active
              if (_showDropdown && _matchingProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: colors.cardSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _matchingProducts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _matchingProducts[index];
                      final variant = p.variants.isNotEmpty ? p.variants.first : null;
                      if (variant == null) return const SizedBox.shrink();

                      return ListTile(
                        dense: true,
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('الباركود: ${variant.skuBarcode} | الوحدة: ${variant.size}', style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          '${variant.sellingPrice.toStringAsFixed(1)} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                        ),
                        onTap: () {
                          pos.addVariantToCart(p, variant);
                          _searchController.clear();
                          pos.clearSearch();
                          setState(() {
                            _showDropdown = false;
                            _matchingProducts = [];
                          });
                          _searchFocus.requestFocus();
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Quick Supermarket Chips Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: colors.cardSurface,
          child: Row(
            children: [
              Text('أصناف سريعة:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickChip('🥖 عيش بلدي', 1.0, 'رغيف', 'QUICK_BREAD'),
                      const SizedBox(width: 6),
                      _buildQuickChip('🛍️ كيس بلاستيك', 1.0, 'كيس', 'QUICK_BAG'),
                      const SizedBox(width: 6),
                      _buildQuickChip('💧 مياه معدنية 600مل', 5.0, 'زجاجة', 'QUICK_WATER'),
                      const SizedBox(width: 6),
                      _buildQuickChip('🥚 بيض أحمر', 6.0, 'بيضة', 'QUICK_EGG'),
                      const SizedBox(width: 6),
                      _buildQuickChip('🥤 كانز بيبسي', 15.0, 'كانز', 'QUICK_PEPSI'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Status Notification Bar
        if (pos.statusMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.primary.withValues(alpha: 0.12),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  pos.statusMessage!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primaryLight),
                ),
              ],
            ),
          ),

        // 4. Main Invoice Items Table
        Expanded(
          child: cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colors.cardSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: colors.textMuted.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'الفاتورة فارغة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'امسح الباركود باستخدام القارئ الضوئي أو ابحث عن صنف لإضافته فوراً',
                        style: TextStyle(fontSize: 13, color: colors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'اختصارات سريعة: Enter لإضافة الصنف | F12 حفظ وطباعة | F10 حفظ بدون طباعة',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          bottom: BorderSide(color: colors.border, width: 1.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('#', width: 36),
                          _buildHeaderCell('الباركود', width: 140),
                          _buildHeaderCell('اسم الصنف / المادة', flex: 4),
                          _buildHeaderCell('الوحدة', flex: 2),
                          _buildHeaderCell('سعر الوحدة', flex: 2, align: TextAlign.center),
                          _buildHeaderCell('الكمية', flex: 3, align: TextAlign.center),
                          _buildHeaderCell('الإجمالي', flex: 2, align: TextAlign.center),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),

                    // Table Rows
                    Expanded(
                      child: ListView.separated(
                        itemCount: cartItems.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: colors.border.withValues(alpha: 0.6)),
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final isEven = index % 2 == 0;

                          return Container(
                            color: isEven ? colors.cardSurface.withValues(alpha: 0.3) : colors.surface,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                      item.size.isNotEmpty ? item.size : 'قطعة',
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

                                // Quantity (+ / -)
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
                                        onPressed: () => pos.decrementQuantity(index),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primary, width: 1.2),
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                        color: AppColors.primary,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: () => pos.incrementQuantity(index),
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
                            'عدد البنود: ${cartItems.length} | إجمالي القطع: ${cartItems.fold(0, (sum, i) => sum + i.quantity)}',
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
