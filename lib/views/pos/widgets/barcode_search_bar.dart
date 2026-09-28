import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_parser.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/settings_provider.dart';

class BarcodeSearchBar extends StatefulWidget {
  const BarcodeSearchBar({super.key});

  @override
  State<BarcodeSearchBar> createState() => _BarcodeSearchBarState();
}

class _BarcodeSearchBarState extends State<BarcodeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _onSubmitted(String value) async {
    final pos = context.read<POSProvider>();
    final query = NumberParser.normalize(value.trim());
    if (query.isEmpty) return;

    // 1. Check if it's a barcode scan
    final wasBarcode = await pos.scanBarcode(query);
    if (wasBarcode) {
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }

    // 2. If single matching product with exactly 1 variant
    if (pos.products.length == 1 && pos.products.first.variants.length == 1) {
      final product = pos.products.first;
      final variant = product.variants.first;
      pos.addVariantToCart(product, variant);
      _controller.clear();
      pos.clearSearch();
      _focusNode.requestFocus();
      return;
    }

    // 3. Otherwise update search query
    pos.setSearchQuery(query);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<POSProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final colors = context.colors;
    final hasLogo = settings.logoPath != null && File(settings.logoPath!).existsSync();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (hasLogo) ...[
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(settings.logoPath!),
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    settings.storeName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.searchProductOrBarcode,
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.qr_code_scanner, color: colors.primary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: colors.textMuted),
                        onPressed: () {
                          _controller.clear();
                          pos.clearSearch();
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                if (val.isEmpty) {
                  pos.clearSearch();
                } else {
                  pos.setSearchQuery(val);
                }
              },
              onSubmitted: _onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
