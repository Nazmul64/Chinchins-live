import 'package:flutter/material.dart';
import '../../../core/services/country_service.dart';
import '../../../core/theme/app_colors.dart';

class CountryPickerBottomSheet extends StatefulWidget {
  final ValueChanged<Country> onSelect;
  final String? initialSelectedCountry;

  const CountryPickerBottomSheet({
    super.key,
    required this.onSelect,
    this.initialSelectedCountry,
  });

  /// Static helper to display the Country Picker anywhere in the app
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Country> onSelect,
    String? initialSelectedCountry,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CountryPickerBottomSheet(
        onSelect: onSelect,
        initialSelectedCountry: initialSelectedCountry ?? 'Bangladesh',
      ),
    );
  }

  @override
  State<CountryPickerBottomSheet> createState() => _CountryPickerBottomSheetState();
}

class _CountryPickerBottomSheetState extends State<CountryPickerBottomSheet> {
  List<Country> _countries = [];
  List<Country> _filtered = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Instant sync lookup so UI renders in 0.00ms with Bangladesh first
    _countries = CountryService.getCountriesSync();
    _filtered = _countries;
    _loadRemoteCountries();
  }

  Future<void> _loadRemoteCountries() async {
    final list = await CountryService.getCountries();
    if (mounted) {
      setState(() {
        _countries = list;
        _filter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _filter(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      setState(() {
        _filtered = _countries;
      });
      return;
    }
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = _countries.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.iso3.toLowerCase().contains(q) ||
            c.dialCode.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset * 0.5,
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 8 : 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161823),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Title + Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Country / Region',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF222533),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                onChanged: _filter,
                decoration: const InputDecoration(
                  hintText: 'Search country, code, or dial code (+880, +977, etc.)...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  icon: Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Countries List
            Expanded(
              child: _isLoading && _filtered.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.neonPink),
                    )
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No country found',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: Colors.white10,
                            height: 1,
                          ),
                          itemBuilder: (context, idx) {
                            final c = _filtered[idx];
                            final isSelected = c.name.toLowerCase() ==
                                (widget.initialSelectedCountry ?? 'Bangladesh').toLowerCase();

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              leading: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  c.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        color: isSelected ? AppColors.neonPink : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (c.name.toLowerCase() == 'bangladesh') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006A4E).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF006A4E).withValues(alpha: 0.6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Text(
                                        'Default',
                                        style: TextStyle(
                                          color: Color(0xFF4ADE80),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.dialCode,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.neonPink : Colors.white54,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.neonPink,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () {
                                widget.onSelect(c);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
