import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cafe_order.dart';

abstract interface class OrderStorage {
  Future<List<CafeOrder>> readOrders();
  Future<void> writeOrders(List<CafeOrder> orders);
}

class SharedPreferencesOrderStorage implements OrderStorage {
  static const String _storageKey = 'caffeine_cafe.orders.v1';

  @override
  Future<List<CafeOrder>> readOrders() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved orders must be a JSON list.');
    }

    return decoded
        .map((value) => CafeOrder.fromJson(
              Map<String, dynamic>.from(value as Map),
            ))
        .toList(growable: true);
  }

  @override
  Future<void> writeOrders(List<CafeOrder> orders) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(orders.map((order) => order.toJson()).toList());
    final saved = await preferences.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('Could not save orders on this device.');
    }
  }
}
