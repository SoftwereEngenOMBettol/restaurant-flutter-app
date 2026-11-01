import 'package:flutter/material.dart';

import 'data/coffee_menu.dart';
import 'models/cafe_order.dart';
import 'models/coffee.dart';
import 'services/order_storage.dart';
import 'state/cart_store.dart';
import 'state/order_store.dart';

const Color _forest = Color(0xFF234A3A);
const Color _forestDark = Color(0xFF18372B);
const Color _cream = Color(0xFFF8F6F0);
const Color _ink = Color(0xFF202820);
const Color _muted = Color(0xFF7B827A);
const Color _orange = Color(0xFFD98B52);

void main() => runApp(const CaffeineCafeApp());

String formatOmr(double amount) => 'OMR ${amount.toStringAsFixed(3)}';

class CaffeineCafeApp extends StatefulWidget {
  const CaffeineCafeApp({super.key});

  @override
  State<CaffeineCafeApp> createState() => _CaffeineCafeAppState();
}

class _CaffeineCafeAppState extends State<CaffeineCafeApp> {
  late final CartStore _cart;
  late final OrderStore _orderStore;

  @override
  void initState() {
    super.initState();
    _cart = CartStore();
    _orderStore = OrderStore(SharedPreferencesOrderStorage());
    _orderStore.load();
  }

  Future<void> _placeOrder(String name, String phone) async {
    if (_cart.isEmpty) return;
    final now = DateTime.now();
    final order = CafeOrder(
      id: 'CC-${now.millisecondsSinceEpoch}',
      customerName: name,
      phone: phone,
      lines: List<CartLine>.unmodifiable(_cart.lines),
      total: _cart.subtotal,
      createdAt: now,
    );
    await _orderStore.addOrder(order);
    _cart.clear();
  }

  @override
  void dispose() {
    _cart.dispose();
    _orderStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: _forest,
      brightness: Brightness.light,
    ).copyWith(primary: _forest, secondary: _orange, surface: _cream);

    return MaterialApp(
      title: 'Caffeine Cafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: _cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: _cream,
          foregroundColor: _ink,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: _ink,
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          titleLarge: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          bodyMedium: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          hintStyle: const TextStyle(color: _muted, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _ink.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _forest, width: 1.4),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: _orderStore,
        builder: (context, child) {
          if (!_orderStore.isLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return MainShell(
            cart: _cart,
            orderStore: _orderStore,
            onPlaceOrder: _placeOrder,
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.cart,
    required this.orderStore,
    required this.onPlaceOrder,
    super.key,
  });

  final CartStore cart;
  final OrderStore orderStore;
  final Future<void> Function(String name, String phone) onPlaceOrder;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        cart: widget.cart,
        onOpenMenu: () => setState(() => _selectedIndex = 1),
        onOpenCart: () => setState(() => _selectedIndex = 2),
      ),
      MenuScreen(
        cart: widget.cart,
        onOpenCart: () => setState(() => _selectedIndex = 2),
      ),
      CartScreen(
        cart: widget.cart,
        onPlaceOrder: (name, phone) async {
          await widget.onPlaceOrder(name, phone);
          if (!mounted) return;
          setState(() => _selectedIndex = 3);
        },
      ),
      OrdersScreen(orderStore: widget.orderStore),
      ProfileScreen(orderStore: widget.orderStore),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: _forest.withValues(alpha: 0.10),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.coffee_outlined),
            selectedIcon: Icon(Icons.coffee_rounded),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: AnimatedBuilder(
              animation: widget.cart,
              builder: (context, child) => Badge(
                isLabelVisible: widget.cart.itemCount > 0,
                label: Text('${widget.cart.itemCount}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            selectedIcon: const Icon(Icons.shopping_bag_rounded),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

const TextStyle _eyebrowStyle = TextStyle(
  color: _orange,
  fontSize: 10,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.8,
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.cart,
    required this.onOpenMenu,
    required this.onOpenCart,
    super.key,
  });

  final CartStore cart;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    final popular = coffeeMenu.where((coffee) => coffee.isPopular).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _forest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CAFFEINE CAFE',
                        style: TextStyle(
                          color: _forest,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your coffee moment',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onOpenCart,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _forest,
                  ),
                  icon: AnimatedBuilder(
                    animation: cart,
                    builder: (context, child) => Badge(
                      isLabelVisible: cart.itemCount > 0,
                      label: Text('${cart.itemCount}'),
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text('GOOD COFFEE,', style: _eyebrowStyle),
            const SizedBox(height: 5),
            Text(
              'better days.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: onOpenMenu,
              borderRadius: BorderRadius.circular(17),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _ink.withValues(alpha: 0.05)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: _muted),
                    SizedBox(width: 10),
                    Text(
                      'Find your favourite coffee',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    Spacer(),
                    Icon(Icons.tune_rounded, color: _forest, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _OfferBanner(),
            const SizedBox(height: 28),
            _SectionHeading(
              title: 'Popular right now',
              action: 'See menu',
              onAction: onOpenMenu,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 244,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: popular.length,
                separatorBuilder: (_, __) => const SizedBox(width: 13),
                itemBuilder: (context, index) => SizedBox(
                  width: 190,
                  child: CoffeeTile(
                    coffee: popular[index],
                    onAdd: () => cart.add(popular[index]),
                    onTap: () => showCoffeeDetails(
                      context,
                      popular[index],
                      onAdd: () => cart.add(popular[index]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text('A little moment, made better.', style: _eyebrowStyle),
            const SizedBox(height: 7),
            const Text(
              'Freshly prepared favourites, ready when you are.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 174,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [_forest, _forestDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -57,
            child: Container(
              height: 190,
              width: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 25,
                ),
              ),
            ),
          ),
          Positioned(
            right: 27,
            bottom: 19,
            child: Transform.rotate(
              angle: -0.18,
              child: const Icon(
                Icons.local_cafe_rounded,
                size: 92,
                color: Color(0xFFE4C6A5),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 125, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MADE FOR YOUR PAUSE',
                  style: TextStyle(
                    color: Color(0xFFE7C6A5),
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Take a break.\nTake a good sip.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'Your next favourite is waiting.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            action,
            style: const TextStyle(
              color: _forest,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    required this.cart,
    required this.onOpenCart,
    super.key,
  });

  final CartStore cart;
  final VoidCallback onOpenCart;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Espresso',
    'Latte',
    'Cold',
    'Brew',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = coffeeMenu.where((coffee) {
      final matchesCategory =
          _selectedCategory == 'All' || coffee.category == _selectedCategory;
      final matchesSearch = coffee.name.toLowerCase().contains(query) ||
          coffee.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('THE GOOD STUFF', style: _eyebrowStyle),
                      const SizedBox(height: 5),
                      Text(
                        'Our menu',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: widget.onOpenCart,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _forest,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search coffee, latte, cold brew...',
                prefixIcon: Icon(Icons.search_rounded, color: _muted),
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  selectedColor: _forest,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide.none,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No coffee found',
                    message: 'Try another name or category.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 13,
                      childAspectRatio: 0.69,
                    ),
                    itemBuilder: (context, index) {
                      final coffee = filtered[index];
                      return CoffeeTile(
                        coffee: coffee,
                        onAdd: () => widget.cart.add(coffee),
                        onTap: () => showCoffeeDetails(
                          context,
                          coffee,
                          onAdd: () => widget.cart.add(coffee),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CoffeeTile extends StatelessWidget {
  const CoffeeTile({
    required this.coffee,
    required this.onAdd,
    required this.onTap,
    super.key,
  });

  final Coffee coffee;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          coffee.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE9E5DC),
                            child: const Center(
                              child: Icon(
                                Icons.local_cafe_rounded,
                                color: _forest,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (coffee.isPopular)
                      Positioned(
                        left: 7,
                        top: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              color: _forest,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                coffee.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                coffee.category,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatOmr(coffee.price),
                      style: const TextStyle(
                        color: _forest,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      height: 31,
                      width: 34,
                      decoration: BoxDecoration(
                        color: _forest,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showCoffeeDetails(
  BuildContext context,
  Coffee coffee, {
  required VoidCallback onAdd,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _muted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 205,
                width: double.infinity,
                child: Image.network(
                  coffee.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE9E5DC),
                    child: const Icon(
                      Icons.local_cafe_rounded,
                      size: 64,
                      color: _forest,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Text(
                    coffee.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  formatOmr(coffee.price),
                  style: const TextStyle(
                    color: _forest,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(coffee.description),
            const SizedBox(height: 19),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  onAdd();
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${coffee.name} added to your cart'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Add to cart'),
                style: FilledButton.styleFrom(
                  backgroundColor: _forest,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CartScreen extends StatelessWidget {
  const CartScreen({
    required this.cart,
    required this.onPlaceOrder,
    super.key,
  });

  final CartStore cart;
  final Future<void> Function(String name, String phone) onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: cart,
        builder: (context, child) {
          if (cart.isEmpty) {
            return const _EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is taking a break',
              message: 'Add a coffee from the menu and it will show up here.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ALMOST YOURS', style: _eyebrowStyle),
                    const SizedBox(height: 5),
                    Text(
                      'Your cart',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 11),
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return _CartLineTile(
                      line: line,
                      onAdd: () => cart.add(line.coffee),
                      onRemoveOne: () => cart.removeOne(line.coffee.id),
                      onRemove: () => cart.remove(line.coffee.id),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 17, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: _ink.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Subtotal', style: TextStyle(color: _muted)),
                        const Spacer(),
                        Text(
                          formatOmr(cart.subtotal),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pickup total · payment is handled at the cafe',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _openCheckout(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: _forest,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Continue to checkout',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCheckout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => CheckoutSheet(
        onSubmit: (name, phone) async {
          Navigator.pop(sheetContext);
          try {
            await onPlaceOrder(name, phone);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order saved! You can track it in Orders.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save your order. Please try again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onAdd,
    required this.onRemoveOne,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback onAdd;
  final VoidCallback onRemoveOne;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Image.network(
                line.coffee.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE9E5DC),
                  child: const Icon(Icons.coffee_rounded, color: _forest),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.coffee.name,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formatOmr(line.total),
                  style: const TextStyle(
                    color: _forest,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _QuantityButton(icon: Icons.remove, onTap: onRemoveOne),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      child: Text(
                        '${line.quantity}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QuantityButton(icon: Icons.add, onTap: onAdd),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: _muted,
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 27,
        width: 29,
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _forest, size: 15),
      ),
    );
  }
}

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({required this.onSubmit, super.key});

  final Future<void> Function(String name, String phone) onSubmit;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
        decoration: const BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _muted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Pickup details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text('Tell us who is collecting the order.'),
                const SizedBox(height: 17),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final digits =
                        value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                    return digits.length < 7
                        ? 'Enter a valid phone number'
                        : null;
                  },
                ),
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      await widget.onSubmit(
                        _nameController.text.trim(),
                        _phoneController.text.trim(),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _forest,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Place order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({required this.orderStore, super.key});

  final OrderStore orderStore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: orderStore,
        builder: (context, child) {
          final orders = orderStore.orders;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GOOD THINGS IN PROGRESS', style: _eyebrowStyle),
                    const SizedBox(height: 5),
                    Text(
                      'Your orders',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? const _EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No orders yet',
                        message: 'Your placed orders will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 13),
                        itemBuilder: (context, index) =>
                            _OrderCard(order: orders[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CafeOrder order;

  @override
  Widget build(BuildContext context) {
    final date =
        '${order.createdAt.day.toString().padLeft(2, '0')}/'
        '${order.createdAt.month.toString().padLeft(2, '0')}/'
        '${order.createdAt.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.id,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(date, style: const TextStyle(color: _muted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 11),
          ...order.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Text(
                    '${line.quantity} × ${line.coffee.name}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    formatOmr(line.total),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'Pickup for',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order.customerName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatOmr(order.total),
                style: const TextStyle(
                  color: _forest,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.check_circle, color: _forest, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  order.status.label,
                  style: const TextStyle(
                    color: _forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.status.helperText),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.orderStore, super.key});

  final OrderStore orderStore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A LITTLE ABOUT US', style: _eyebrowStyle),
            const SizedBox(height: 5),
            Text(
              'The cafe',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _forest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.coffee_rounded,
                    color: Color(0xFFE7C6A5),
                    size: 32,
                  ),
                  SizedBox(height: 17),
                  Text(
                    'Coffee tastes better when the moment feels right.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'A simple place for carefully prepared drinks and little everyday pauses.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _ProfileRow(
              icon: Icons.local_cafe_outlined,
              title: 'Freshly prepared',
              subtitle: 'Every cup is made when you order.',
            ),
            const _ProfileRow(
              icon: Icons.shopping_bag_outlined,
              title: 'Easy pickup ordering',
              subtitle: 'Build your cart and place a pickup order.',
            ),
            const _ProfileRow(
              icon: Icons.favorite_border_rounded,
              title: 'Made with care',
              subtitle: 'A small coffee shop project built with Flutter.',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RestaurantDashboardScreen(orderStore: orderStore),
                  ),
                ),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Open staff dashboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _forest,
                  side: BorderSide(color: _forest.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'STAFF DASHBOARD IS A LOCAL DEMO — NO LOGIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'CAFFEINE CAFE  ·  FLUTTER DEMO',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantDashboardScreen extends StatelessWidget {
  const RestaurantDashboardScreen({required this.orderStore, super.key});

  final OrderStore orderStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff dashboard'),
        backgroundColor: _cream,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: orderStore,
          builder: (context, child) {
            final orders = orderStore.orders;
            final completed = orders
                .where((order) => order.status == OrderStatus.completed)
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Text('RESTAURANT OVERVIEW', style: _eyebrowStyle),
                const SizedBox(height: 6),
                Text(
                  'Today at a glance',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardMetric(
                        label: 'Total orders',
                        value: '${orders.length}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _DashboardMetric(
                        label: 'In progress',
                        value: '${orderStore.activeOrderCount}',
                        icon: Icons.timelapse_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardMetric(
                        label: 'Completed',
                        value: '$completed',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _DashboardMetric(
                        label: 'Order value',
                        value: formatOmr(orderStore.totalOrderValue),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Incoming orders',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${orders.length} total',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                if (orders.isEmpty)
                  const _EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No incoming orders',
                    message: 'New pickup orders will appear here.',
                  )
                else
                  ...orders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StaffOrderCard(
                        order: order,
                        onStatusChanged: (status) async {
                          if (status == null) return;
                          try {
                            await orderStore.updateStatus(order.id, status);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not save the order status.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _forest, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StaffOrderCard extends StatelessWidget {
  const _StaffOrderCard({
    required this.order,
    required this.onStatusChanged,
  });

  final CafeOrder order;
  final ValueChanged<OrderStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.id,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                formatOmr(order.total),
                style: const TextStyle(
                  color: _forest,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.customerName} · ${order.phone}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ...order.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${line.quantity} × ${line.coffee.name}',
                style: const TextStyle(color: _ink, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OrderStatus>(
            key: ValueKey('${order.id}-${order.status.name}'),
            initialValue: order.status,
            decoration: const InputDecoration(
              labelText: 'Order status',
              prefixIcon: Icon(Icons.sync_rounded),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: OrderStatus.values
                .map(
                  (status) => DropdownMenuItem<OrderStatus>(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 75,
              width: 75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 32, color: _forest),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
