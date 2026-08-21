import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_client.dart';

class GroceryViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const _cacheKey = 'cached_grocery_list';

  GroceryViewModel() {
    loadCachedList();
  }

  Future<void> loadCachedList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as List;
        _categories = decoded.map((c) => {
          'category': c['category'] as String,
          'items': (c['items'] as List).map((i) => Map<String, dynamic>.from(i)).toList(),
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached grocery list: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_categories));
    } catch (e) {
      debugPrint('Error caching grocery list: $e');
    }
  }

  Future<void> fetchGroceryList() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No active session found.');

      final url = Uri.parse('${ApiClient.getBaseUrl()}/meals/grocery-list/${user.id}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List;
        _categories = decoded.map((c) => {
          'category': c['category'] as String,
          'items': (c['items'] as List).map((i) => Map<String, dynamic>.from(i)).toList(),
        }).toList();
        await _saveToCache();
      } else {
        throw Exception('Failed to generate grocery list: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error fetching grocery list: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleItemChecked(int categoryIndex, int itemIndex) {
    if (categoryIndex >= 0 && categoryIndex < _categories.length) {
      final category = _categories[categoryIndex];
      final items = category['items'] as List<Map<String, dynamic>>;
      if (itemIndex >= 0 && itemIndex < items.length) {
        final item = items[itemIndex];
        item['checked'] = !(item['checked'] as bool);
        _saveToCache();
        notifyListeners();
      }
    }
  }

  void addItem(String categoryName, String itemName, String quantity) {
    if (itemName.trim().isEmpty) return;

    int catIdx = _categories.indexWhere(
      (c) => c['category'].toString().toLowerCase() == categoryName.trim().toLowerCase()
    );

    if (catIdx == -1) {
      _categories.add({
        'category': categoryName.trim(),
        'items': <Map<String, dynamic>>[]
      });
      catIdx = _categories.length - 1;
    }

    final items = _categories[catIdx]['items'] as List<Map<String, dynamic>>;
    items.add({
      'name': itemName.trim(),
      'quantity': quantity.trim().isEmpty ? '1 unit' : quantity.trim(),
      'checked': false
    });

    _saveToCache();
    notifyListeners();
  }

  void removeItem(int categoryIndex, int itemIndex) {
    if (categoryIndex >= 0 && categoryIndex < _categories.length) {
      final category = _categories[categoryIndex];
      final items = category['items'] as List<Map<String, dynamic>>;
      if (itemIndex >= 0 && itemIndex < items.length) {
        items.removeAt(itemIndex);
        if (items.isEmpty) {
          _categories.removeAt(categoryIndex);
        }
        _saveToCache();
        notifyListeners();
      }
    }
  }

  void clearCheckedItems() {
    for (int i = _categories.length - 1; i >= 0; i--) {
      final items = _categories[i]['items'] as List<Map<String, dynamic>>;
      for (int j = items.length - 1; j >= 0; j--) {
        if (items[j]['checked'] == true) {
          items.removeAt(j);
        }
      }
      if (items.isEmpty) {
        _categories.removeAt(i);
      }
    }
    _saveToCache();
    notifyListeners();
  }
}
