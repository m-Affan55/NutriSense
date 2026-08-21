import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/family_member.dart';

class FamilyViewModel extends ChangeNotifier {
  static final FamilyViewModel _instance = FamilyViewModel._internal();
  static FamilyViewModel get instance => _instance;
  factory FamilyViewModel() => _instance;

  FamilyViewModel._internal() {
    _loadFromLocalCache();
  }

  static const String _cacheKey = 'nutrisense_cached_family_members';
  static const String _activeMemberKey = 'nutrisense_active_family_member_id';

  List<FamilyMember> _members = [];
  List<FamilyMember> get members => List.unmodifiable(_members);

  FamilyMember? _activeMember;
  FamilyMember? get activeMember => _activeMember;
  bool get isManagingDependent => _activeMember != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Switch active profile (null represents the primary account user)
  void setActiveMember(FamilyMember? member) async {
    _activeMember = member;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (member == null) {
        await prefs.remove(_activeMemberKey);
      } else {
        await prefs.setString(_activeMemberKey, member.id);
      }
    } catch (_) {}
  }

  /// Load family members from Supabase (with fallback to local storage)
  Future<void> loadMembers({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final res = await supabase
          .from('family_members')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final List<FamilyMember> loaded = (res as List)
          .map((m) => FamilyMember.fromMap(m as Map<String, dynamic>))
          .toList();

      _members = loaded;
      await _saveToLocalCache();

      // Restore active member if ID exists in list
      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getString(_activeMemberKey);
      if (activeId != null) {
        _activeMember = _members.cast<FamilyMember?>().firstWhere(
              (m) => m?.id == activeId,
              orElse: () => null,
            );
      }
    } catch (e) {
      debugPrint('[FamilyViewModel] Error loading members from Supabase: $e');
      _errorMessage = e.toString();
      await _loadFromLocalCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new family dependent
  Future<bool> addMember(FamilyMember member) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final payload = member.toMap();
      payload['user_id'] = user.id;

      final res = await supabase
          .from('family_members')
          .insert(payload)
          .select()
          .single();

      final created = FamilyMember.fromMap(res);
      _members = [..._members, created];
      await _saveToLocalCache();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[FamilyViewModel] Error creating family member: $e');
      // If table doesn't exist yet on remote or offline, save locally
      final localMember = member.copyWith(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        createdAt: DateTime.now(),
      );
      _members = [..._members, localMember];
      await _saveToLocalCache();
      notifyListeners();
      return true;
    }
  }

  /// Update existing family dependent
  Future<bool> updateMember(FamilyMember member) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (!member.id.startsWith('local_')) {
        await supabase
            .from('family_members')
            .update(member.toMap())
            .eq('id', member.id)
            .eq('user_id', user.id);
      }

      final index = _members.indexWhere((m) => m.id == member.id);
      if (index != -1) {
        final updatedList = List<FamilyMember>.from(_members);
        updatedList[index] = member;
        _members = updatedList;
      }

      if (_activeMember?.id == member.id) {
        _activeMember = member;
      }

      await _saveToLocalCache();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[FamilyViewModel] Error updating family member: $e');
      return false;
    }
  }

  /// Delete a family dependent
  Future<bool> deleteMember(String memberId) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (!memberId.startsWith('local_')) {
        await supabase
            .from('family_members')
            .delete()
            .eq('id', memberId)
            .eq('user_id', user.id);
      }

      _members = _members.where((m) => m.id != memberId).toList();
      if (_activeMember?.id == memberId) {
        _activeMember = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_activeMemberKey);
      }

      await _saveToLocalCache();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[FamilyViewModel] Error deleting family member: $e');
      return false;
    }
  }

  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _members.map((m) => m.toJson()).toList();
      await prefs.setStringList(_cacheKey, jsonList);
    } catch (_) {}
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_cacheKey);
      if (jsonList != null && jsonList.isNotEmpty) {
        _members = jsonList.map((s) => FamilyMember.fromJson(s)).toList();
      }

      final activeId = prefs.getString(_activeMemberKey);
      if (activeId != null && _members.isNotEmpty) {
        _activeMember = _members.cast<FamilyMember?>().firstWhere(
              (m) => m?.id == activeId,
              orElse: () => null,
            );
      }
    } catch (_) {}
  }
}
