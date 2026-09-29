class AppStrings {
  // App General
  static const String appName = 'نظام إدارة ونقاط بيع السوبر ماركت';
  static const String appShortName = 'كاشير السوبر ماركت';

  // Navigation
  static const String navPOS = 'نقطة البيع (الكاشير)';
  static const String navInvoices = 'الفواتير المباعة';
  static const String navInventory = 'المخزون والأصناف';
  static const String navReturns = 'المرتجعات والتبديل';
  static const String navShifts = 'إدارة الورديات';
  static const String navReports = 'التقارير والأرباح';
  static const String navSettings = 'الإعدادات والنسخ الاحتياطي';
  static const String navLogout = 'تسجيل الخروج';

  // POS
  static const String searchProductOrBarcode =
      'امسح الباركود أو ابحث عن صنف...';
  static const String allCategories = 'جميع الأقسام';
  static const String currentOrder = 'الفاتورة الحالية';
  static const String emptyCart =
      'الفاتورة فارغة، امسح الباركود أو اختر صنفاً للبدء';
  static const String subtotal = 'المجموع الفرعي';
  static const String tax = 'الضريبة';
  static const String grandTotal = 'الإجمالي المطلوب';
  static const String cashReceived = 'المبلغ المستلم نقداً';
  static const String changeDue = 'الباقي للعميل';
  static const String confirmPayment = 'تأكيد الدفع وطباعة الفاتورة';
  static const String saveAndPrint = 'حفظ وطباعة (F1)';
  static const String saveWithoutPrint = 'حفظ بدون طباعة (F3)';
  static const String exactAmount = 'المبلغ بالكامل';
  static const String clearCart = 'إلغاء الفاتورة';
  static const String invoicePreview = 'معاينة الفاتورة';
  static const String selectVariant = 'اختر الوحدة / العبوة';
  static const String outOfStock = 'غير متوفر بالمخزون!';

  // Inventory
  static const String productsList = 'قائمة الأصناف والمنتجات';
  static const String addNewProduct = 'إضافة صنف جديد';
  static const String editProduct = 'تعديل الصنف';
  static const String productName = 'اسم الصنف / المادة';
  static const String category = 'القسم / التصنيف';
  static const String availableSizes = 'الوحدات / العبوات';
  static const String availableColors = 'البيان / الحجم / النكهة';
  static const String skuBarcode = 'رمز الباركود (رقم المادة)';
  static const String costPrice = 'سعر التكلفة (سعر الجملة)';
  static const String sellingPrice = 'سعر البيع (الإفرادي)';
  static const String stockQuantity = 'الكمية الحالية بالمخزون';
  static const String minStockAlert = 'حد تنبيه نقص الكمية';
  static const String stockStatus = 'حالة المخزون';
  static const String inStock = 'متوفر';
  static const String lowStock = 'منخفض';
  static const String noStock = 'نفد المخزون';
  static const String printBarcodes = 'طباعة ملصقات الباركود';
  static const String barcodeCopies = 'عدد النسخ للطباعة';
  static const String generateBarcode = 'توليد باركود تلقائي';

  // Returns
  static const String returnsTitle = 'معالجة المرتجعات والتبديل';
  static const String searchInvoiceOrBarcode =
      'أدخل رقم الفاتورة أو امسح الباركود...';
  static const String returnQuantity = 'الكمية المسترجعة';
  static const String returnReason = 'سبب الإرجاع';
  static const String refundAmount = 'المبلغ المسترد (نقداً)';
  static const String confirmReturn = 'تأكيد الإرجاع وإعادة المخزون';
  static const String returnSuccess =
      'تمت عملية الإرجاع بنجاح وتحديث المخزون والدرج النقدي';

  // Shifts
  static const String shiftTitle = 'إدارة الوردية والصندوق';
  static const String openShift = 'فتح وردية جديدة';
  static const String closeShift = 'إغلاق الوردية الحالية';
  static const String openingFloat = 'رصيد بداية الوردية (العهدة)';
  static const String cashSales = 'إجمالي المبيعات النقدية';
  static const String cashReturns = 'إجمالي المرتجعات النقدية';
  static const String expectedCash = 'النقد المتوقع في الدرج';
  static const String actualCash = 'النقد الفعلي المستلم (العد اليدوي)';
  static const String discrepancy = 'الفارق (عجز / زيادة)';
  static const String shiftMatched = 'النقد مطابق تماماً';
  static const String shiftShortage = 'يوجد عجز نقدي';
  static const String shiftOverage = 'توجد زيادة نقدية';
  static const String printShiftSummary = 'طباعة تقرير الوردية';

  // Reports
  static const String financialReports = 'التقارير المالية وحساب الأرباح';
  static const String totalSales = 'إجمالي المبيعات';
  static const String netProfit = 'صافي الربح (المبيعات - التكلفة)';
  static const String totalReturns = 'إجمالي المرتجعات';
  static const String topSellingItems = 'المنتجات الأكثر مبيعاً';
  static const String lowStockItems = 'تنبيهات نقص المخزون';

  // Settings & Backup
  static const String storeSettings = 'إعدادات المتجر والفاتورة';
  static const String storeName = 'اسم المحل';
  static const String storeSlogan = 'الشعار اللفظي للمحل';
  static const String storePhone = 'رقم هاتف المتجر';
  static const String storeAddress = 'عنوان المتجر';
  static const String currencySymbol = 'رمز العملة';
  static const String receiptFooter = 'تذييل الفاتورة';
  static const String backupDatabase = 'نسخ احتياطي للبيانات';
  static const String restoreDatabase = 'استعادة نسخة احتياطية';
  static const String backupSuccess = 'تم حفظ النسخة الاحتياطية بنجاح';
  static const String restoreSuccess =
      'تمت استعادة البيانات بنجاح، يُرجى إعادة تشغيل التطبيق';

  // Auth & Roles
  static const String loginTitle = 'تسجيل الدخول للنظام';
  static const String enterPin = 'أدخل رمز الدخول (PIN)';
  static const String adminRole = 'مدير النظام (كامل الصلاحيات)';
  static const String cashierRole = 'كاشير مبيعات';
  static const String unauthorizedAccess = 'هذه الصفحة مخصصة لمدير النظام فقط';
  static const String save = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String confirm = 'تأكيد';
  static const String print = 'طباعة';
}
