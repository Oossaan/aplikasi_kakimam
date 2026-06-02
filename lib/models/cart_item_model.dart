import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;
  double customPrice; // Harga kustom (bisa diedit oleh admin)
  bool isPriceModified; // Menandakan apakah harga sudah dimodifikasi
  bool fromPurchaseMode; // Menandakan apakah item ditambahkan saat mode beli

  double itemDiscountAmount; // diskon item (nominal/amount) per transaksi (tersimpan ke DB via transactionItems.itemDiscount

  CartItem({
    required this.product,
    this.quantity = 1,
    double? customPrice,
    this.isPriceModified = false,
    this.fromPurchaseMode = false,
    this.itemDiscountAmount = 0,
  }) : customPrice = customPrice ?? product.sellingPrice;

  // Harga yang berlaku (prioritas ke custom price)
  // Jika dari purchase mode, gunakan purchasePrice sebagai dasar
  double get effectivePrice => customPrice;

  double get itemSubtotal => effectivePrice * quantity;

  /// Diskon item dalam persen (%), berdasarkan base subtotal item (tanpa memperhitungkan itemDiscountAmount).
  double get itemDiscountPercent {
    final base = itemSubtotal;
    if (base <= 0) return 0;
    return (itemDiscountAmount / base) * 100;
  }

  // subtotal setelah diskon item (amount)
  double get subtotal => (itemSubtotal - itemDiscountAmount).clamp(0, double.infinity);

  // Reset ke harga aslinya berdasarkan mode
  void resetPrice({bool purchaseMode = false}) {
    if (purchaseMode) {
      customPrice = product.purchasePrice;
    } else {
      customPrice = product.sellingPrice;
    }
    isPriceModified = false;
  }

  // Update dengan harga kustom
  void updatePrice(double newPrice) {
    customPrice = newPrice;
    isPriceModified = newPrice !=
        (fromPurchaseMode ? product.purchasePrice : product.sellingPrice);
  }

  void updateItemDiscountAmount(double amount) {
    itemDiscountAmount = amount;
  }

  /// Update item discount by percentage
  /// Example: updateItemDiscountByPercent(10) untuk 10% discount
  void updateItemDiscountByPercent(double percent) {
    if (percent < 0 || percent > 100) return;
    final discountAmount = itemSubtotal * (percent / 100);
    itemDiscountAmount = discountAmount.clamp(0, itemSubtotal);
  }

  /// Update item discount by nominal amount
  void updateItemDiscountByNominal(double nominal) {
    itemDiscountAmount = nominal.clamp(0, itemSubtotal);
  }
}
