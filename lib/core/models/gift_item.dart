class GiftItem {
  final String id;
  final String name;
  final String emoji;
  final int coins;
  final String bgGradient;
  final int receivedCount;

  const GiftItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coins,
    this.bgGradient = 'purple',
    this.receivedCount = 0,
  });
}
