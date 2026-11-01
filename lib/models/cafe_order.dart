import '../data/coffee_menu.dart';
import 'coffee.dart';

enum OrderStatus {
  received,
  preparing,
  ready,
  completed;

  String get label => switch (this) {
        OrderStatus.received => 'Order received',
        OrderStatus.preparing => 'Being prepared',
        OrderStatus.ready => 'Ready for pickup',
        OrderStatus.completed => 'Completed',
      };

  String get helperText => switch (this) {
        OrderStatus.received => 'The cafe has received your order.',
        OrderStatus.preparing => 'The barista is preparing your coffee.',
        OrderStatus.ready => 'Your order is ready. Enjoy!',
        OrderStatus.completed => 'Thanks for visiting Caffeine Cafe.',
      };
}

class CartLine {
  const CartLine({required this.coffee, required this.quantity});

  final Coffee coffee;
  final int quantity;

  double get total => coffee.price * quantity;

  Map<String, dynamic> toJson() => {
        'coffeeId': coffee.id,
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) {
    final coffeeId = json['coffeeId'] as String;
    final coffee = coffeeMenu.firstWhere(
      (item) => item.id == coffeeId,
      orElse: () => throw FormatException('Unknown menu item: $coffeeId'),
    );

    return CartLine(
      coffee: coffee,
      quantity: (json['quantity'] as num).toInt(),
    );
  }
}

class CafeOrder {
  const CafeOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.lines,
    required this.total,
    required this.createdAt,
    this.status = OrderStatus.received,
  });

  final String id;
  final String customerName;
  final String phone;
  final List<CartLine> lines;
  final double total;
  final DateTime createdAt;
  final OrderStatus status;

  int get itemCount =>
      lines.fold<int>(0, (count, line) => count + line.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerName': customerName,
        'phone': phone,
        'lines': lines.map((line) => line.toJson()).toList(),
        'total': total,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory CafeOrder.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    final parsedStatus = OrderStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => OrderStatus.received,
    );

    return CafeOrder(
      id: json['id'] as String,
      customerName: json['customerName'] as String,
      phone: json['phone'] as String,
      lines: rawLines
          .map((value) => CartLine.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList(growable: false),
      total: (json['total'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: parsedStatus,
    );
  }

  CafeOrder copyWith({OrderStatus? status}) => CafeOrder(
        id: id,
        customerName: customerName,
        phone: phone,
        lines: lines,
        total: total,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}
