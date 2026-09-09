class ResellerModel {
  final int id;
  final String resellerId;
  final String name;
  final String avatar;
  final String avatarUrl;
  final String level;
  final String location;
  final int age;
  final String gender;
  final String phone;
  final String bio;
  final String discountTag;
  final String badgeTitle;
  final int sales;
  final String formattedSales;
  final String successRate;
  final bool isOnline;
  final String statusText;
  final String prefillMessage;

  const ResellerModel({
    required this.id,
    required this.resellerId,
    required this.name,
    required this.avatar,
    required this.avatarUrl,
    this.level = 'Lv1',
    this.location = 'Bangladesh',
    this.age = 25,
    this.gender = 'male',
    this.phone = '',
    this.bio = '',
    this.discountTag = 'Up To 29%↑',
    this.badgeTitle = 'Authorized Reseller',
    this.sales = 0,
    this.formattedSales = '💎 0',
    this.successRate = '100%',
    this.isOnline = true,
    this.statusText = 'Online',
    this.prefillMessage = '',
  });

  factory ResellerModel.fromJson(Map<String, dynamic> json) {
    final rawSales = json['sales_diamonds'] ?? json['sales'] ?? 0;
    final intSales = rawSales is num ? rawSales.toInt() : (int.tryParse('$rawSales') ?? 0);
    final formattedS = json['formatted_sales']?.toString() ??
        '💎 ${_formatNumberWithCommas(intSales)}';

    String avatarPath = json['avatar_url']?.toString() ??
        json['avatar']?.toString() ??
        json['profile_photo_url']?.toString() ??
        json['image']?.toString() ??
        '';

    if (avatarPath.isNotEmpty) {
      if (!avatarPath.startsWith('http://') &&
          !avatarPath.startsWith('https://') &&
          !avatarPath.startsWith('assets/')) {
        if (avatarPath.startsWith('/')) {
          avatarPath = 'https://chinchins.live$avatarPath';
        } else {
          avatarPath = 'https://chinchins.live/$avatarPath';
        }
      }
    }

    if (avatarPath.isEmpty) {
      final nameParam = Uri.encodeComponent(json['name']?.toString() ?? 'Reseller');
      avatarPath = 'https://ui-avatars.com/api/?name=$nameParam&background=1e1b4b&color=fbbf24&bold=true';
    }

    return ResellerModel(
      id: json['id'] is int ? json['id'] : (int.tryParse('${json['id']}') ?? 1),
      resellerId: json['reseller_id']?.toString() ??
          json['account_id']?.toString() ??
          '${json['id'] ?? 1}',
      name: json['name']?.toString() ?? 'Authorized Reseller',
      avatar: avatarPath,
      avatarUrl: avatarPath,
      level: json['level']?.toString() ?? 'Lv1',
      location: json['location']?.toString() ?? 'Bangladesh',
      age: json['age'] is int ? json['age'] : (int.tryParse('${json['age']}') ?? 25),
      gender: json['gender']?.toString() ?? 'male',
      phone: json['phone']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      discountTag: json['discount_tag']?.toString() ??
          json['badge']?.toString() ??
          'Up To 29%↑',
      badgeTitle: json['badge_title']?.toString() ?? 'Authorized Reseller',
      sales: intSales,
      formattedSales: formattedS,
      successRate: json['success_rate']?.toString() ?? '100%',
      isOnline: json['is_online'] == true || json['is_online'] == 1 || json['status'] == 'online',
      statusText: json['status_text']?.toString() ??
          (json['is_online'] == false ? 'Offline' : 'Online'),
      prefillMessage: json['prefill_message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reseller_id': resellerId,
      'name': name,
      'avatar_url': avatarUrl,
      'level': level,
      'location': location,
      'age': age,
      'gender': gender,
      'phone': phone,
      'bio': bio,
      'discount_tag': discountTag,
      'badge_title': badgeTitle,
      'sales': sales,
      'formatted_sales': formattedSales,
      'success_rate': successRate,
      'is_online': isOnline,
      'status_text': statusText,
      'prefill_message': prefillMessage,
    };
  }

  static String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
