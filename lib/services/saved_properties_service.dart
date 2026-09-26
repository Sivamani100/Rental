import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SavedPropertiesService extends ChangeNotifier {
  static final SavedPropertiesService instance = SavedPropertiesService._();
  
  SavedPropertiesService._();
  
  Set<String> _savedIds = {};
  
  Set<String> get savedIds => _savedIds;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedList = prefs.getStringList('saved_properties_ids');
    if (savedList != null) {
      _savedIds = savedList.toSet();
    }
    notifyListeners();
  }

  Future<void> toggleSave(String propertyId) async {
    if (_savedIds.contains(propertyId)) {
      _savedIds.remove(propertyId);
    } else {
      _savedIds.add(propertyId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_properties_ids', _savedIds.toList());
    notifyListeners();
  }

  bool isSaved(String propertyId) {
    return _savedIds.contains(propertyId);
  }
}
