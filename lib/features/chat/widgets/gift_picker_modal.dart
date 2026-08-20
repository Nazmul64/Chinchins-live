import 'package:flutter/material.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/theme/app_colors.dart';

class GiftPickerModal extends StatefulWidget {
  final ValueChanged<GiftItem> onGiftSelected;

  const GiftPickerModal({
    super.key,
    required this.onGiftSelected,
  });

  @override
  State<GiftPickerModal> createState() => _GiftPickerModalState();
}

class _GiftPickerModalState extends State<GiftPickerModal> {
  int _selectedGiftIndex = 0;
  final int _userCoins = 38500;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header with Coin balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Send a Gift 🎁',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardDarkElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gemYellow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_userCoins',
                      style: const TextStyle(
                        color: AppColors.gemYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gifts Grid (2 rows x 4 items)
          SizedBox(
            height: 220,
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.82,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: MockData.giftsCatalog.length,
              itemBuilder: (context, index) {
                final gift = MockData.giftsCatalog[index];
                final isSelected = _selectedGiftIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGiftIndex = index;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonPink.withValues(alpha: 0.18)
                          : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonPink
                            : AppColors.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift.emoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gift.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diamond, color: AppColors.gemYellow, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              '${gift.coins}',
                              style: const TextStyle(
                                color: AppColors.gemYellow,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 6,
              ),
              onPressed: () {
                final selectedGift = MockData.giftsCatalog[_selectedGiftIndex];
                widget.onGiftSelected(selectedGift);
                Navigator.pop(context);
              },
              child: Text(
                'Send ${MockData.giftsCatalog[_selectedGiftIndex].name} (${MockData.giftsCatalog[_selectedGiftIndex].coins} 💎)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
