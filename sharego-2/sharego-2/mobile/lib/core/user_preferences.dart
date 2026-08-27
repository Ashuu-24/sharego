import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const _marketplaceDisclaimerKey = 'marketplace_disclaimer_ack';

  Future<bool> isMarketplaceDisclaimerAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_marketplaceDisclaimerKey) ?? false;
  }

  Future<void> setMarketplaceDisclaimerAcknowledged({
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_marketplaceDisclaimerKey, value);
  }
}
