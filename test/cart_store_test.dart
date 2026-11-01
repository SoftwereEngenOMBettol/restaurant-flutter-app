import 'package:flutter_test/flutter_test.dart';
import 'package:caffeine_cafe_mobile/data/coffee_menu.dart';
import 'package:caffeine_cafe_mobile/state/cart_store.dart';

void main() {
  group('CartStore', () {
    late CartStore cart;

    setUp(() {
      cart = CartStore();
    });

    tearDown(() {
      cart.dispose();
    });

    test('starts empty', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0);
    });

    test('adds items and combines quantities for the same coffee', () {
      final coffee = coffeeMenu.first;

      cart.add(coffee);
      cart.add(coffee);

      expect(cart.itemCount, 2);
      expect(cart.lines, hasLength(1));
      expect(cart.lines.first.quantity, 2);
      expect(cart.subtotal, coffee.price * 2);
    });

    test('decreases quantity and removes the line at zero', () {
      final coffee = coffeeMenu.first;

      cart.add(coffee);
      cart.add(coffee);
      cart.removeOne(coffee.id);

      expect(cart.itemCount, 1);
      expect(cart.lines.first.quantity, 1);

      cart.removeOne(coffee.id);

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
    });

    test('removes a complete line and clears the cart', () {
      final first = coffeeMenu[0];
      final second = coffeeMenu[1];

      cart.add(first);
      cart.add(second);
      cart.remove(first.id);

      expect(cart.itemCount, 1);
      expect(cart.lines.single.coffee.id, second.id);

      cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.subtotal, 0);
    });
  });
}
