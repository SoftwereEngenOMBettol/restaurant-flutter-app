import 'package:flutter_test/flutter_test.dart';
import 'package:caffeine_cafe_mobile/data/coffee_menu.dart';
import 'package:caffeine_cafe_mobile/models/cafe_order.dart';
import 'package:caffeine_cafe_mobile/services/order_storage.dart';
import 'package:caffeine_cafe_mobile/state/order_store.dart';

class _MemoryOrderStorage implements OrderStorage {
  List<CafeOrder> saved = [];

  @override
  Future<List<CafeOrder>> readOrders() async => List.of(saved);

  @override
  Future<void> writeOrders(List<CafeOrder> orders) async {
    saved = List.of(orders);
  }
}

CafeOrder _sampleOrder({String id = 'CC-100'}) => CafeOrder(
      id: id,
      customerName: 'Amina',
      phone: '90000000',
      lines: [CartLine(coffee: coffeeMenu.first, quantity: 2)],
      total: coffeeMenu.first.price * 2,
      createdAt: DateTime.utc(2026, 11, 1),
    );

void main() {
  group('OrderStore', () {
    late _MemoryOrderStorage storage;
    late OrderStore store;

    setUp(() {
      storage = _MemoryOrderStorage();
      store = OrderStore(storage);
    });

    tearDown(() {
      store.dispose();
    });

    test('loads with an empty order list', () async {
      await store.load();

      expect(store.isLoaded, isTrue);
      expect(store.orders, isEmpty);
      expect(store.activeOrderCount, 0);
    });

    test('persists new orders and restores them in a new store', () async {
      await store.load();
      final order = _sampleOrder();

      await store.addOrder(order);

      expect(storage.saved.single.id, order.id);
      expect(store.totalOrderValue, order.total);

      final restored = OrderStore(storage);
      await restored.load();

      expect(restored.orders.single.customerName, 'Amina');
      expect(restored.orders.single.lines.single.quantity, 2);
      restored.dispose();
    });

    test('persists staff status changes', () async {
      await store.load();
      await store.addOrder(_sampleOrder());

      await store.updateStatus('CC-100', OrderStatus.preparing);

      expect(store.orders.single.status, OrderStatus.preparing);
      expect(storage.saved.single.status, OrderStatus.preparing);
      expect(store.activeOrderCount, 1);
    });

    test('counts completed orders and retains their total value', () async {
      await store.load();
      await store.addOrder(_sampleOrder());

      await store.updateStatus('CC-100', OrderStatus.completed);

      expect(store.activeOrderCount, 0);
      expect(store.totalOrderValue, _sampleOrder().total);
    });
  });
}
