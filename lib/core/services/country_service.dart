import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class Country {
  final String name;
  final String code; // ISO-2 (e.g. BD)
  final String iso3; // ISO-3 (e.g. BGD)
  final String flag; // Emoji flag (e.g. 🇧🇩)
  final String dialCode; // Dial code (e.g. +880)

  const Country({
    required this.name,
    required this.code,
    required this.iso3,
    required this.flag,
    required this.dialCode,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? json['country_code']?.toString() ?? '',
      iso3: json['iso3']?.toString() ?? json['iso_3']?.toString() ?? '',
      flag: json['flag']?.toString() ?? json['emoji']?.toString() ?? '🌐',
      dialCode: json['dial_code']?.toString() ?? json['dialCode']?.toString() ?? '+',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'iso3': iso3,
    'flag': flag,
    'dial_code': dialCode,
  };

  Map<String, String> toMap() => {
    'name': name,
    'code': dialCode,
    'flag': flag,
    'iso2': code,
    'iso3': iso3,
  };
}

class CountryService {
  static List<Country>? _cachedCountries;

  /// Default country is ALWAYS Bangladesh 🇧🇩 (+880) as requested
  static const Country defaultCountry = Country(
    name: 'Bangladesh',
    code: 'BD',
    iso3: 'BGD',
    flag: '🇧🇩',
    dialCode: '+880',
  );

  /// Get countries list with Bangladesh ALWAYS first
  static Future<List<Country>> getCountries({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCountries != null && _cachedCountries!.isNotEmpty) {
      return _cachedCountries!;
    }

    try {
      final res = await http
          .get(Uri.parse(ApiConstants.countries))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data']?['countries'] ?? data['countries']) as List?;
        if (list != null && list.isNotEmpty) {
          final parsed = list
              .whereType<Map<String, dynamic>>()
              .map((c) => Country.fromJson(c))
              .toList();

          _cachedCountries = _ensureBangladeshFirst(parsed);
          return _cachedCountries!;
        }
      }
    } catch (e) {
      debugPrint('[CountryService] Remote fetch error, using worldwide fallback: $e');
    }

    // Worldwide fallback with 90+ countries, Bangladesh ALWAYS first
    _cachedCountries = _ensureBangladeshFirst(_getWorldwideCountries());
    return _cachedCountries!;
  }

  /// Synchronous instant worldwide countries list (0.00ms delay)
  static List<Country> getCountriesSync() {
    if (_cachedCountries != null && _cachedCountries!.isNotEmpty) {
      return _cachedCountries!;
    }
    _cachedCountries = _ensureBangladeshFirst(_getWorldwideCountries());
    return _cachedCountries!;
  }

  /// Ensure Bangladesh is ALWAYS at index 0 and selected first
  static List<Country> _ensureBangladeshFirst(List<Country> list) {
    final copy = List<Country>.from(list);
    Country? bd;

    for (int i = 0; i < copy.length; i++) {
      if (copy[i].name.toLowerCase() == 'bangladesh' || copy[i].code.toUpperCase() == 'BD') {
        bd = copy.removeAt(i);
        break;
      }
    }

    bd ??= defaultCountry;
    copy.insert(0, bd);
    return copy;
  }

  /// Find country by name or code
  static Country findCountry(String nameOrCode) {
    final list = getCountriesSync();
    final q = nameOrCode.trim().toLowerCase();
    for (final c in list) {
      if (c.name.toLowerCase() == q ||
          c.code.toLowerCase() == q ||
          c.iso3.toLowerCase() == q ||
          c.dialCode == q) {
        return c;
      }
    }
    return defaultCountry;
  }

  /// Complete list of 90+ worldwide countries
  static List<Country> _getWorldwideCountries() {
    return const [
      defaultCountry, // 1. Bangladesh 🇧🇩 (+880) - FIRST & SELECTED BY DEFAULT
      Country(name: 'Pakistan', code: 'PK', iso3: 'PAK', flag: '🇵🇰', dialCode: '+92'),
      Country(name: 'India', code: 'IN', iso3: 'IND', flag: '🇮🇳', dialCode: '+91'),
      Country(name: 'Nepal', code: 'NP', iso3: 'NPL', flag: '🇳🇵', dialCode: '+977'),
      Country(name: 'Philippines', code: 'PH', iso3: 'PHL', flag: '🇵🇭', dialCode: '+63'),
      Country(name: 'Bhutan', code: 'BT', iso3: 'BTN', flag: '🇧🇹', dialCode: '+975'),
      Country(name: 'Malaysia', code: 'MY', iso3: 'MYS', flag: '🇲🇾', dialCode: '+60'),
      Country(name: 'Saudi Arabia', code: 'SA', iso3: 'SAU', flag: '🇸🇦', dialCode: '+966'),
      Country(name: 'United Arab Emirates', code: 'AE', iso3: 'ARE', flag: '🇦🇪', dialCode: '+971'),
      Country(name: 'Afghanistan', code: 'AF', iso3: 'AFG', flag: '🇦🇫', dialCode: '+93'),
      Country(name: 'United States', code: 'US', iso3: 'USA', flag: '🇺🇸', dialCode: '+1'),
      Country(name: 'United Kingdom', code: 'GB', iso3: 'GBR', flag: '🇬🇧', dialCode: '+44'),
      Country(name: 'Canada', code: 'CA', iso3: 'CAN', flag: '🇨🇦', dialCode: '+1'),
      Country(name: 'Australia', code: 'AU', iso3: 'AUS', flag: '🇦🇺', dialCode: '+61'),
      Country(name: 'Singapore', code: 'SG', iso3: 'SGP', flag: '🇸🇬', dialCode: '+65'),
      Country(name: 'Indonesia', code: 'ID', iso3: 'IDN', flag: '🇮🇩', dialCode: '+62'),
      Country(name: 'Thailand', code: 'TH', iso3: 'THA', flag: '🇹🇭', dialCode: '+66'),
      Country(name: 'Vietnam', code: 'VN', iso3: 'VNM', flag: '🇻🇳', dialCode: '+84'),
      Country(name: 'Sri Lanka', code: 'LK', iso3: 'LKA', flag: '🇱🇰', dialCode: '+94'),
      Country(name: 'Maldives', code: 'MV', iso3: 'MDV', flag: '🇲🇻', dialCode: '+960'),
      Country(name: 'Qatar', code: 'QA', iso3: 'QAT', flag: '🇶🇦', dialCode: '+974'),
      Country(name: 'Kuwait', code: 'KW', iso3: 'KWT', flag: '🇰🇼', dialCode: '+965'),
      Country(name: 'Oman', code: 'OM', iso3: 'OMN', flag: '🇴🇲', dialCode: '+968'),
      Country(name: 'Bahrain', code: 'BH', iso3: 'BHR', flag: '🇧🇭', dialCode: '+973'),
      Country(name: 'Turkey', code: 'TR', iso3: 'TUR', flag: '🇹🇷', dialCode: '+90'),
      Country(name: 'Egypt', code: 'EG', iso3: 'EGY', flag: '🇪🇬', dialCode: '+20'),
      Country(name: 'Germany', code: 'DE', iso3: 'DEU', flag: '🇩🇪', dialCode: '+49'),
      Country(name: 'France', code: 'FR', iso3: 'FRA', flag: '🇫🇷', dialCode: '+33'),
      Country(name: 'Italy', code: 'IT', iso3: 'ITA', flag: '🇮🇹', dialCode: '+39'),
      Country(name: 'Spain', code: 'ES', iso3: 'ESP', flag: '🇪🇸', dialCode: '+34'),
      Country(name: 'Brazil', code: 'BR', iso3: 'BRA', flag: '🇧🇻', dialCode: '+55'),
      Country(name: 'Japan', code: 'JP', iso3: 'JPN', flag: '🇯🇵', dialCode: '+81'),
      Country(name: 'South Korea', code: 'KR', iso3: 'KOR', flag: '🇰🇷', dialCode: '+82'),
      Country(name: 'China', code: 'CN', iso3: 'CHN', flag: '🇨🇳', dialCode: '+86'),
      Country(name: 'Hong Kong', code: 'HK', iso3: 'HKG', flag: '🇭🇰', dialCode: '+852'),
      Country(name: 'Taiwan', code: 'TW', iso3: 'TWN', flag: '🇹🇼', dialCode: '+886'),
      Country(name: 'South Africa', code: 'ZA', iso3: 'ZAF', flag: '🇿🇦', dialCode: '+27'),
      Country(name: 'Nigeria', code: 'NG', iso3: 'NGA', flag: '🇳🇬', dialCode: '+234'),
      Country(name: 'Kenya', code: 'KE', iso3: 'KEN', flag: '🇰🇪', dialCode: '+254'),
      Country(name: 'Ghana', code: 'GH', iso3: 'GHA', flag: '🇬🇭', dialCode: '+233'),
      Country(name: 'Morocco', code: 'MA', iso3: 'MAR', flag: '🇲🇦', dialCode: '+212'),
      Country(name: 'Iraq', code: 'IQ', iso3: 'IRQ', flag: '🇮🇶', dialCode: '+964'),
      Country(name: 'Jordan', code: 'JO', iso3: 'JOR', flag: '🇯🇴', dialCode: '+962'),
      Country(name: 'Lebanon', code: 'LB', iso3: 'LBN', flag: '🇱🇧', dialCode: '+961'),
      Country(name: 'Yemen', code: 'YE', iso3: 'YEM', flag: '🇾🇪', dialCode: '+967'),
      Country(name: 'Iran', code: 'IR', iso3: 'IRN', flag: '🇮🇷', dialCode: '+98'),
      Country(name: 'Russia', code: 'RU', iso3: 'RUS', flag: '🇷🇺', dialCode: '+7'),
      Country(name: 'Ukraine', code: 'UA', iso3: 'UKR', flag: '🇺🇦', dialCode: '+380'),
      Country(name: 'Netherlands', code: 'NL', iso3: 'NLD', flag: '🇳🇱', dialCode: '+31'),
      Country(name: 'Belgium', code: 'BE', iso3: 'BEL', flag: '🇧🇪', dialCode: '+32'),
      Country(name: 'Switzerland', code: 'CH', iso3: 'CHE', flag: '🇨🇭', dialCode: '+41'),
      Country(name: 'Sweden', code: 'SE', iso3: 'SWE', flag: '🇸🇪', dialCode: '+46'),
      Country(name: 'Norway', code: 'NO', iso3: 'NOR', flag: '🇳🇴', dialCode: '+47'),
      Country(name: 'Denmark', code: 'DK', iso3: 'DNK', flag: '🇩🇰', dialCode: '+45'),
      Country(name: 'Finland', code: 'FI', iso3: 'FIN', flag: '🇫🇮', dialCode: '+358'),
      Country(name: 'Poland', code: 'PL', iso3: 'POL', flag: '🇵🇱', dialCode: '+48'),
      Country(name: 'Portugal', code: 'PT', iso3: 'PRT', flag: '🇵🇹', dialCode: '+351'),
      Country(name: 'Greece', code: 'GR', iso3: 'GRC', flag: '🇬🇷', dialCode: '+30'),
      Country(name: 'Ireland', code: 'IE', iso3: 'IRL', flag: '🇮🇪', dialCode: '+353'),
      Country(name: 'New Zealand', code: 'NZ', iso3: 'NZL', flag: '🇳🇿', dialCode: '+64'),
      Country(name: 'Mexico', code: 'MX', iso3: 'MEX', flag: '🇲🇽', dialCode: '+52'),
      Country(name: 'Argentina', code: 'AR', iso3: 'ARG', flag: '🇦🇷', dialCode: '+54'),
      Country(name: 'Colombia', code: 'CO', iso3: 'COL', flag: '🇨🇴', dialCode: '+57'),
      Country(name: 'Chile', code: 'CL', iso3: 'CHL', flag: '🇨🇱', dialCode: '+56'),
      Country(name: 'Peru', code: 'PE', iso3: 'PER', flag: '🇵🇪', dialCode: '+51'),
      Country(name: 'Myanmar', code: 'MM', iso3: 'MMR', flag: '🇲🇲', dialCode: '+95'),
      Country(name: 'Cambodia', code: 'KH', iso3: 'KHM', flag: '🇰🇭', dialCode: '+855'),
      Country(name: 'Laos', code: 'LA', iso3: 'LAO', flag: '🇱🇦', dialCode: '+856'),
      Country(name: 'Brunei', code: 'BN', iso3: 'BRN', flag: '🇧🇳', dialCode: '+673'),
      Country(name: 'Kazakhstan', code: 'KZ', iso3: 'KAZ', flag: '🇰🇿', dialCode: '+7'),
      Country(name: 'Uzbekistan', code: 'UZ', iso3: 'UZB', flag: '🇺🇿', dialCode: '+998'),
      Country(name: 'Azerbaijan', code: 'AZ', iso3: 'AZE', flag: '🇦🇿', dialCode: '+994'),
      Country(name: 'Georgia', code: 'GE', iso3: 'GEO', flag: '🇬🇪', dialCode: '+995'),
      Country(name: 'Cyprus', code: 'CY', iso3: 'CYP', flag: '🇨🇾', dialCode: '+357'),
      Country(name: 'Austria', code: 'AT', iso3: 'AUT', flag: '🇦🇹', dialCode: '+43'),
      Country(name: 'Czech Republic', code: 'CZ', iso3: 'CZE', flag: '🇨🇿', dialCode: '+420'),
      Country(name: 'Hungary', code: 'HU', iso3: 'HUN', flag: '🇭🇺', dialCode: '+36'),
      Country(name: 'Romania', code: 'RO', iso3: 'ROU', flag: '🇷🇴', dialCode: '+40'),
      Country(name: 'Israel', code: 'IL', iso3: 'ISR', flag: '🇮🇱', dialCode: '+972'),
      Country(name: 'Algeria', code: 'DZ', iso3: 'DZA', flag: '🇩🇿', dialCode: '+213'),
      Country(name: 'Tunisia', code: 'TN', iso3: 'TUN', flag: '🇹🇳', dialCode: '+216'),
      Country(name: 'Ethiopia', code: 'ET', iso3: 'ETH', flag: '🇪🇹', dialCode: '+251'),
      Country(name: 'Tanzania', code: 'TZ', iso3: 'TZA', flag: '🇹🇿', dialCode: '+255'),
      Country(name: 'Uganda', code: 'UG', iso3: 'UGA', flag: '🇺🇬', dialCode: '+256'),
      Country(name: 'Mauritius', code: 'MU', iso3: 'MUS', flag: '🇲🇺', dialCode: '+230'),
      Country(name: 'Fiji', code: 'FJ', iso3: 'FJI', flag: '🇫🇯', dialCode: '+679'),
      Country(name: 'Iceland', code: 'IS', iso3: 'ISL', flag: '🇮🇸', dialCode: '+354'),
      Country(name: 'Luxembourg', code: 'LU', iso3: 'LUX', flag: '🇱🇺', dialCode: '+352'),
      Country(name: 'Monaco', code: 'MC', iso3: 'MCO', flag: '🇲🇨', dialCode: '+377'),
      Country(name: 'Other', code: 'OTHER', iso3: 'OTH', flag: '🌐', dialCode: '+'),
    ];
  }
}
