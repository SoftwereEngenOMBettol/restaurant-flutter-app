import 'package:flutter/foundation.dart';

import '../models/cafe_order.dart';
import '../services/order_storage.dart';

class OrderStore extends ChangeNotifier {
  OrderStore(this._storage);

  final OrderStorage _storage;
  final List<CafeOrder> _orders = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<CafeOrder> get orders => List.unmodifiable(_orders);

  int get activeOrderCount =>
      _orders.where((order) => order.status != OrderStatus.completed).length;

  double get totalOrderValue =>
      _orders.fold<double>(0, (total, order) => total + order.total);

  Future<void> load() async {
    try {
      final savedOrders = await _storage.readOrders();
      _orders
        ..clear()
        ..addAll(savedOrders);
    } catch (_) {
      // A corrupted local cache should not prevent the customer app from opening.
      _orders.clear();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> addOrder(CafeOrder order) async {
    _orders.insert(0, order);
    try {
      await _persist();
    } catch (_) {
      _orders.removeWhere((item) => item.id == order.id);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0 || _orders[index].status == status) return;

    final previous = _orders[index];
    _orders[index] = previous.copyWith(status: status);
    try {
      await _persist();
    } catch (_) {
      _orders[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _persist() => _storage.writeOrders(_orders);
}
