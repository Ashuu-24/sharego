import 'package:shared_preferences/shared_preferences.dart';

class SavedTripsService {
  static const _key = 'saved_trip_ids';
  final SharedPreferences _prefs;

  Set<int> _savedIds = {};

  SavedTripsService(this._prefs) {
    _savedIds = (_prefs.getStringList(_key) ?? []).map(int.parse).toSet();
  }

  bool isSaved(int tripId) => _savedIds.contains(tripId);
  Set<int> get savedIds => Set.unmodifiable(_savedIds);

  Future<void> toggle(int tripId) async {
    if (_savedIds.contains(tripId)) {
      _savedIds.remove(tripId);
    } else {
      _savedIds.add(tripId);
    }
    await _prefs.setStringList(
      _key,
      _savedIds.map((e) => e.toString()).toList(),
    );
  }
}
