class StoreSettingsModel {
  final int? id;
  final String storeName;
  final String slogan;
  final String phone;
  final String address;
  final String currencySymbol;
  final String receiptFooter;
  final double taxRatePercent;
  final String themeMode; // 'dark', 'light', 'system'
  final String? logoPath;

  StoreSettingsModel({
    this.id = 1,
    required this.storeName,
    required this.slogan,
    required this.phone,
    required this.address,
    this.currencySymbol = 'ج.م',
    this.receiptFooter = 'شكراً لزيارتكم! البضاعة المباعة ترد وتستبدل خلال 14 يوماً مع أصل الفاتورة',
    this.taxRatePercent = 0.0,
    this.themeMode = 'dark',
    this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id ?? 1,
      'store_name': storeName,
      'slogan': slogan,
      'phone': phone,
      'address': address,
      'currency_symbol': currencySymbol,
      'receipt_footer': receiptFooter,
      'tax_rate_percent': taxRatePercent,
      'theme_mode': themeMode,
      'logo_path': logoPath,
    };
  }

  factory StoreSettingsModel.fromMap(Map<String, dynamic> map) {
    return StoreSettingsModel(
      id: map['id'] as int? ?? 1,
      storeName: map['store_name'] as String? ?? 'محل الأزياء والأناقة',
      slogan: map['slogan'] as String? ?? 'أحدث صيحات الملابس والموضة',
      phone: map['phone'] as String? ?? '01000000000',
      address: map['address'] as String? ?? 'الشارع الرئيسي - وسط البلد',
      currencySymbol: map['currency_symbol'] as String? ?? 'ج.م',
      receiptFooter: map['receipt_footer'] as String? ?? 'شكراً لزيارتكم! البضاعة المباعة ترد وتستبدل خلال 14 يوماً مع الفاتورة',
      taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0.0,
      themeMode: map['theme_mode'] as String? ?? 'dark',
      logoPath: map['logo_path'] as String?,
    );
  }

  StoreSettingsModel copyWith({
    String? storeName,
    String? slogan,
    String? phone,
    String? address,
    String? currencySymbol,
    String? receiptFooter,
    double? taxRatePercent,
    String? themeMode,
    String? logoPath,
    bool clearLogo = false,
  }) {
    return StoreSettingsModel(
      id: id,
      storeName: storeName ?? this.storeName,
      slogan: slogan ?? this.slogan,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      themeMode: themeMode ?? this.themeMode,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreSettingsModel &&
        other.id == id &&
        other.storeName == storeName &&
        other.slogan == slogan &&
        other.phone == phone &&
        other.address == address &&
        other.currencySymbol == currencySymbol &&
        other.receiptFooter == receiptFooter &&
        other.taxRatePercent == taxRatePercent &&
        other.themeMode == themeMode &&
        other.logoPath == logoPath;
  }

  @override
  int get hashCode => Object.hash(
        id,
        storeName,
        slogan,
        phone,
        address,
        currencySymbol,
        receiptFooter,
        taxRatePercent,
        themeMode,
        logoPath,
      );
}
