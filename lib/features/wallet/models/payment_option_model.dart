class PaymentOption {
  final dynamic id;
  final String key;
  final String name;
  final String type; // 'gateway', 'in_app_purchase', 'reseller'
  final String? accountType;
  final String? accountNumber;
  final String? icon;
  final String? badge;
  final String? badgeColor;
  final int? activeCount;
  final String? instructions;

  const PaymentOption({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    this.accountType,
    this.accountNumber,
    this.icon,
    this.badge,
    this.badgeColor,
    this.activeCount,
    this.instructions,
  });

  bool get isReseller => type == 'reseller' || key.toLowerCase() == 'reseller';
  bool get isInAppPurchase => type == 'in_app_purchase' || key.toLowerCase() == 'google_play';
  bool get isGateway => type == 'gateway';

  factory PaymentOption.fromJson(Map<String, dynamic> json) {
    return PaymentOption(
      id: json['id'] ?? json['key'] ?? 'unknown',
      key: json['key']?.toString().toLowerCase() ?? 'gateway',
      name: json['name']?.toString() ?? 'Payment Option',
      type: json['type']?.toString().toLowerCase() ?? 'gateway',
      accountType: json['account_type']?.toString(),
      accountNumber: json['account_number']?.toString(),
      icon: json['icon']?.toString(),
      badge: json['badge']?.toString(),
      badgeColor: json['badge_color']?.toString(),
      activeCount: json['active_count'] is int ? json['active_count'] : int.tryParse('${json['active_count']}'),
      instructions: json['instructions']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'name': name,
      'type': type,
      'account_type': accountType,
      'account_number': accountNumber,
      'icon': icon,
      'badge': badge,
      'badge_color': badgeColor,
      'active_count': activeCount,
      'instructions': instructions,
    };
  }
}
