class Coffee {
  const Coffee({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final String imageUrl;
  final bool isPopular;
}
