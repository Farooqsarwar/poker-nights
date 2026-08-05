import '../models/group.dart';
import '../models/live_game.dart';
import '../models/user.dart';

abstract class DataRepository {
  Future<AppUser?> login(String email, String password);
  Future<Group> fetchGroup(String id);
  Future<LiveGame> fetchLiveGame(String id);
}
