class OrderItemModel {
  final String menuItemId;
  final String name; // Saved snapshot name (in the language order was made, or general)
  final double price; // Saved snapshot price
  final int quantity;

  OrderItemModel({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  OrderItemModel copyWith({
    int? quantity,
  }) {
    return OrderItemModel(
      menuItemId: menuItemId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }
}
