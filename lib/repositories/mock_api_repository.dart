import '../models/group.dart';
import '../models/live_game.dart';
import '../models/user.dart';
import '../utils/mock_data.dart';
import 'data_repository.dart';

class MockApiRepository implements DataRepository {
  @override
  Future<AppUser?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final found = MockData.members
        .where((m) => m.email.toLowerCase() == email.trim().toLowerCase())
        .toList();
    if (found.isNotEmpty) {
      return found.first;
    }
    return null;
  }

  @override
  Future<Group> fetchGroup(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Structure the dummy data EXACTLY as a real backend response would be:
    // JSON -> Map<String, dynamic> -> Group
    // For now, we return the MockData model directly since we are mocking the deserialization layer.
    return MockData.demoGroup;
  }

  @override
  Future<LiveGame> fetchLiveGame(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.demoGame;
  }
}
