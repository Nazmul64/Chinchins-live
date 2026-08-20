enum PartyRoomType {
  audioVoice,
  videoParty,
}

class RoomSeat {
  final int seatIndex;
  final String? userId;
  final String? userName;
  final String? userAvatar;
  final bool isHost;
  final bool isMuted;
  final bool isSpeaking;
  final int coinsReceived;

  const RoomSeat({
    required this.seatIndex,
    this.userId,
    this.userName,
    this.userAvatar,
    this.isHost = false,
    this.isMuted = false,
    this.isSpeaking = false,
    this.coinsReceived = 0,
  });

  bool get isEmpty => userId == null;

  RoomSeat copyWith({
    int? seatIndex,
    String? userId,
    String? userName,
    String? userAvatar,
    bool? isHost,
    bool? isMuted,
    bool? isSpeaking,
    int? coinsReceived,
  }) {
    return RoomSeat(
      seatIndex: seatIndex ?? this.seatIndex,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      isHost: isHost ?? this.isHost,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      coinsReceived: coinsReceived ?? this.coinsReceived,
    );
  }
}

class GroupPartyRoom {
  final String id;
  final String title;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  final String coverUrl;
  final PartyRoomType roomType;
  final String tag;
  final int audienceCount;
  final List<RoomSeat> seats;
  final List<String> audienceAvatars;

  const GroupPartyRoom({
    required this.id,
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
    required this.coverUrl,
    required this.roomType,
    required this.tag,
    this.audienceCount = 18,
    required this.seats,
    this.audienceAvatars = const [],
  });
}
