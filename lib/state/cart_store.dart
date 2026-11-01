import 'package:flutter/foundation.dart';

import '../data/coffee_menu.dart';
import '../models/cafe_order.dart';
import '../models/coffee.dart';

class CartStore extends ChangeNotifier {
  final Map<String, int> _quantities = {};

  List<CartLine> get lines => _quantities.entries.map((entry) {
        final coffee = coffeeMenu.firstWhere((item) => item.id == entry.key);
        return CartLine(coffee: coffee, quantity: entry.value);
      }).toList(growable: false);

  int get itemCount => _quantities.values.fold<int>(
        0,
        (total, quantity) => total + quantity,
      );

  bool get isEmpty => _quantities.isEmpty;

  double get subtotal => lines.fold<double>(
        0,
        (total, line) => total + line.total,
      );

  void add(Coffee coffee) {
    _quantities.update(
      coffee.id,
      (quantity) => quantity + 1,
      ifAbsent: () => 1,
    );
    notifyListeners();
  }

  void removeOne(String coffeeId) {
    final current = _quantities[coffeeId];
    if (current == null) return;

    if (current <= 1) {
      _quantities.remove(coffeeId);
    } else {
      _quantities[coffeeId] = current - 1;
    }
    notifyListeners();
  }

  void remove(String coffeeId) {
    if (_quantities.remove(coffeeId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_quantities.isEmpty) return;
    _quantities.clear();
    notifyListeners();
  }
}
