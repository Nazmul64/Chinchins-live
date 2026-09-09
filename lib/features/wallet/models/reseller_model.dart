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
    this.level = 'Lv5',
    this.location = 'Dhaka, Bangladesh',
    this.age = 27,
    this.gender = 'male',
    this.phone = '01848340232',
    this.bio = 'কয়েন রিচার্জ, হোস্টিং এবং বিভিন্ন ধরণের গিফট ক্রয় করা হয়\nযোগাযোগ ০১৮৪৮৩৪০২৩২\nহোস্টিং স্যালারি তুলনামূলক বেশি দেওয়া হয়\nঅনেক কথা বলা\nমানুষটা যদি হঠাৎ চুপ হয়ে যায়,\nবুঝে নিও আঘাতটা অনেক গভীরে লেগেছে।',
    this.discountTag = 'Up To 29%↑',
    this.badgeTitle = 'Diamond Reseller',
    this.sales = 15549000,
    this.formattedSales = '💎 15,549,000',
    this.successRate = '91.79%',
    this.isOnline = true,
    this.statusText = 'Online',
    this.prefillMessage = '',
  });

  factory ResellerModel.fromJson(Map<String, dynamic> json) {
    final rawSales = json['sales_diamonds'] ?? json['sales'] ?? 15549000;
    final intSales = rawSales is num ? rawSales.toInt() : (int.tryParse('$rawSales') ?? 15549000);
    final formattedS = json['formatted_sales']?.toString() ??
        '💎 ${_formatNumberWithCommas(intSales)}';

    final avatarPath = json['avatar_url']?.toString() ??
        json['avatar']?.toString() ??
        'https://ui-avatars.com/api/?name=Murad+Reseller&background=1e1b4b&color=fbbf24&bold=true';

    return ResellerModel(
      id: json['id'] is int ? json['id'] : (int.tryParse('${json['id']}') ?? 1),
      resellerId: json['reseller_id']?.toString() ??
          json['account_id']?.toString() ??
          '595082249',
      name: json['name']?.toString() ?? 'MURAD COINS RESELLER',
      avatar: avatarPath,
      avatarUrl: avatarPath,
      level: json['level']?.toString() ?? 'Lv5',
      location: json['location']?.toString() ?? 'Dhaka, Bangladesh',
      age: json['age'] is int ? json['age'] : (int.tryParse('${json['age']}') ?? 27),
      gender: json['gender']?.toString() ?? 'male',
      phone: json['phone']?.toString() ?? '01848340232',
      bio: json['bio']?.toString() ??
          'কয়েন রিচার্জ, হোস্টিং এবং বিভিন্ন ধরণের গিফট ক্রয় করা হয়\nযোগাযোগ ০১৮৪৮৩৪০২৩২\nহোস্টিং স্যালারি তুলনামূলক বেশি দেওয়া হয়\nঅনেক কথা বলা\nমানুষটা যদি হঠাৎ চুপ হয়ে যায়,\nবুঝে নিও আঘাতটা অনেক গভীরে লেগেছে।',
      discountTag: json['discount_tag']?.toString() ??
          json['badge']?.toString() ??
          'Up To 29%↑',
      badgeTitle: json['badge_title']?.toString() ?? 'Diamond Reseller',
      sales: intSales,
      formattedSales: formattedS,
      successRate: json['success_rate']?.toString() ?? '91.79%',
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
