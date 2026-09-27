import '../models/model_profile.dart';
import '../models/chat_message.dart';
import '../models/gift_item.dart';
import '../models/group_room.dart';

class MockData {
  // High quality portrait photos
  static const String imgAyeena = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80';
  static const String imgHabiba = 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80';
  static const String imgMahi = 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80';
  static const String imgRuhi = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80';
  static const String imgMoyna = 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=800&q=80';
  static const String imgTinni = 'https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?auto=format&fit=crop&w=800&q=80';
  static const String imgNosimon = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=800&q=80';
  static const String imgCubana = 'https://images.unsplash.com/photo-1546961329-78bef0414d7c?auto=format&fit=crop&w=800&q=80';
  static const String imgGulabi = 'https://images.unsplash.com/photo-1514315384763-ba401779410f?auto=format&fit=crop&w=800&q=80';
  static const String imgSimran = 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=800&q=80';
  static const String imgDanielle = 'https://images.unsplash.com/photo-1524638431109-93d95c968f03?auto=format&fit=crop&w=800&q=80';
  static const String imgSumaiya = 'https://images.unsplash.com/photo-1509967419530-da38b4704bc6?auto=format&fit=crop&w=800&q=80';
  static const String imgAmeena = 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=800&q=80';
  static const String imgAshna = 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?auto=format&fit=crop&w=800&q=80';
  static const String imgAiriss = 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=800&q=80';
  static const String imgLivePreview = 'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?auto=format&fit=crop&w=800&q=80';

  // Available Gifts catalog
  static const List<GiftItem> giftsCatalog = [
    GiftItem(id: '1', name: 'Crown Tiara', emoji: '👑', coins: 200, receivedCount: 1),
    GiftItem(id: '2', name: 'Space Jet', emoji: '🚀', coins: 1500, receivedCount: 1),
    GiftItem(id: '3', name: 'Magic Chest', emoji: '📦', coins: 200, receivedCount: 1),
    GiftItem(id: '4', name: 'Fire Dragon', emoji: '🐉', coins: 2500, receivedCount: 1),
    GiftItem(id: '5', name: 'Golden Bell', emoji: '🔔', coins: 100, receivedCount: 34),
    GiftItem(id: '6', name: 'Supercar', emoji: '🏎️', coins: 3000, receivedCount: 1),
    GiftItem(id: '7', name: 'Football', emoji: '⚽', coins: 50, receivedCount: 62),
    GiftItem(id: '8', name: 'Magic Palace', emoji: '🏰', coins: 500, receivedCount: 52),
  ];

  // Explore / Hot Models List
  static final List<ModelProfile> models = [];

  // Mock Chat Threads
  static final List<ChatThread> chatThreads = [];

  // Active Group Voice & Video Party Rooms
  static final List<GroupPartyRoom> partyRooms = [];
}

