import 'package:flutter/material.dart';
import 'gifts_received_card.dart';

export 'gifts_received_card.dart';

class GiftsReceivedGrid extends StatelessWidget {
  final String userId;

  const GiftsReceivedGrid({
    super.key,
    this.userId = '1',
  });

  @override
  Widget build(BuildContext context) {
    return GiftsReceivedCard(userId: userId);
  }
}
