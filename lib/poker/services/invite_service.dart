import 'package:share_plus/share_plus.dart';
import '../models/poker_room.dart';

class InviteService {
  Future<void> inviteToRoom({
    required PokerRoom room,
  }) async {
    final code = room.inviteCode;
    final msg = room.visibility == RoomVisibility.inviteOnly
        ? "Únete a mi sala de Poker Texas Hold'em: código $code"
        : "Únete a mi sala pública de Poker: ${room.title}";
    await Share.share(msg);
  }
}
