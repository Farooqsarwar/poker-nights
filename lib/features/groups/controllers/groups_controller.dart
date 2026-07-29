import 'dart:math';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/groups/models/group_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/core/constants/app_constants.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';

class GroupsController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  static const _storageKey = 'poker_groups';
  static const _membershipKey = 'poker_memberships';

  final RxList<GroupModel> groups = <GroupModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  String get _currentUserId {
    final user = Get.find<AuthController>().currentUser.value;
    return user?.id ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    if (_currentUserId.isNotEmpty) {
      loadGroups();
    }
  }

  Future<void> loadGroups() async {
    final userId = _currentUserId;
    if (userId.isEmpty) return;
    print('GroupsController: loadGroups for user $userId');
    isLoading.value = true;
    error.value = '';
    try {
      final doc = await _storage.getJson(_storageKey);
      final data = doc?['data'] as List<dynamic>?;
      final allGroups = data?.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      
      final mDoc = await _storage.getJson(_membershipKey);
      final mData = mDoc?['data'] as List<dynamic>?;
      final memberships = mData?.map((e) => GroupMembership.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      
      final groupIds = memberships.where((m) => m.userId == userId).map((m) => m.groupId).toSet();
      final myGroups = allGroups.where((g) => groupIds.contains(g.id)).toList();
      
      groups.assignAll(myGroups);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<GroupModel?> createGroup(String name) async {
    final userId = _currentUserId;
    if (userId.isEmpty) return null;
    print('GroupsController: createGroup $name');
    final groupId = const Uuid().v4();
    final code = _generateJoinCode();
    final group = GroupModel(
      id: groupId,
      ownerUserId: userId,
      name: name,
      joinCode: code,
      createdAt: DateTime.now(),
    );
    final doc = await _storage.getJson(_storageKey);
    final data = doc?['data'] as List<dynamic>?;
    final allGroups = data?.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    allGroups.add(group);
    await _storage.set(_storageKey, allGroups.map((e) => e.toJson()).toList());

    final membership = GroupMembership(
      groupId: groupId,
      userId: userId,
      role: 'admin',
      status: 'active',
      joinedAt: DateTime.now(),
    );
    await _saveMembership(membership);
    groups.add(group);
    return group;
  }

  Future<GroupModel?> joinGroup(String code) async {
    final userId = _currentUserId;
    if (userId.isEmpty) return null;
    print('GroupsController: attempting to join group with code $code');
    final doc = await _storage.getJson(_storageKey);
    final data = doc?['data'] as List<dynamic>?;
    final allGroups = data?.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    
    final group = allGroups.where((g) => g.joinCode == code).firstOrNull;
    print('GroupsController: joinGroup found group ${group?.id} for code $code');
    if (group == null) return null;

    final membership = GroupMembership(
      groupId: group.id,
      userId: userId,
      role: 'player',
      status: 'active',
      joinedAt: DateTime.now(),
    );
    await _saveMembership(membership);
    if (!groups.any((g) => g.id == group.id)) {
      groups.add(group);
    }
    return group;
  }

  Future<List<GroupModel>> getMyGroups() async {
    final userId = _currentUserId;
    final memberships = await _getMemberships();
    final groupIds = memberships.where((m) => m.userId == userId).map((m) => m.groupId).toSet();
    return groups.where((g) => groupIds.contains(g.id)).toList();
  }

  bool isAdmin(GroupModel group) => group.ownerUserId == _currentUserId;

  Future<void> rotateCode(String groupId) async {
    final doc = await _storage.getJson(_storageKey);
    final data = doc?['data'] as List<dynamic>?;
    final allGroups = data?.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final idx = allGroups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;
    final newCode = _generateJoinCode();
    allGroups[idx] = allGroups[idx].copyWith(
      joinCode: newCode,
      codeRotatedAt: DateTime.now(),
    );
    await _storage.set(_storageKey, allGroups.map((e) => e.toJson()).toList());
    
    final cIdx = groups.indexWhere((g) => g.id == groupId);
    if (cIdx != -1) {
      groups[cIdx] = groups[cIdx].copyWith(joinCode: newCode, codeRotatedAt: DateTime.now());
      groups.refresh();
    }
  }

  String _generateJoinCode() {
    final r = Random();
    return List.generate(AppConstants.joinCodeLength, (_) => AppConstants.joinCodeChars[r.nextInt(AppConstants.joinCodeChars.length)]).join();
  }

  Future<void> _saveMembership(GroupMembership membership) async {
    final doc = await _storage.getJson(_membershipKey);
    final data = doc?['data'] as List<dynamic>?;
    final memberships = data?.map((e) => GroupMembership.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    memberships.add(membership);
    await _storage.set(_membershipKey, memberships.map((e) => e.toJson()).toList());
  }

  Future<List<GroupMembership>> _getMemberships() async {
    final doc = await _storage.getJson(_membershipKey);
    final data = doc?['data'] as List<dynamic>?;
    return data?.map((e) => GroupMembership.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  }
}
