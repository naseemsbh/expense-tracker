import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyLastPhone = 'last_phone_number';

  // 1. Save the number
  static Future<void> savePhoneNumber(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPhone, phone);
  }

  // 2. Get the number
  static Future<String?> getSavedPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastPhone);
  }

  // 3. Clear it
  static Future<void> clearPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastPhone);
  }
}