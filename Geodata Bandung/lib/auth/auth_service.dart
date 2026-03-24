import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  // ================= BASE URL =================
  static const String baseUrl = "http://localhost/geodata_api";
  //static const String baseUrl = "http://10.15.157.108/geodata_api"; // HP

  /* ================= LOGIN ================= */
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse("$baseUrl/login.php"),
            headers: {"Content-Type": "application/x-www-form-urlencoded"},
            body: {"username": username, "password": password},
          )
          .timeout(const Duration(seconds: 6));

      debugPrint("LOGIN RESPONSE: ${res.body}");
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint("LOGIN ERROR: $e");
      return {"status": "failed", "message": "Tidak bisa terhubung ke server"};
    }
  }

  /* ================= REGISTER ================= */
  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/register.php"),
      body: {"username": username, "password": password},
    );

    return jsonDecode(res.body);
  }

  /* ================= GET PROFILE ================= */
  static Future<Map<String, dynamic>> getProfile(int userId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/get_profile.php?user_id=$userId"),
    );

    return jsonDecode(res.body);
  }

  /* ================= SAVE PROFILE ================= */
  static Future<Map<String, dynamic>> saveProfile(
    int userId,
    String fullName,
    String email,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/save_profile.php"),
      body: {
        "user_id": userId.toString(),
        "full_name": fullName,
        "email": email,
      },
    );

    return jsonDecode(res.body);
  }

  /* ================= LOG USER ACTIVITY ================= */
  static Future<void> logActivity(int userId, String activity) async {
    await http.post(
      Uri.parse("$baseUrl/add_activity.php"),
      body: {"user_id": userId.toString(), "activity": activity},
    );
  }

  /* ================= GET USER ACTIVITY ================= */
  static Future<List<dynamic>> getUserActivity(int userId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/get_activity.php?user_id=$userId"),
    );

    final data = jsonDecode(res.body);

    if (data["status"] != "success") {
      return [];
    }

    return data["activities"] ?? [];
  }

  // ================= ADD FAVORITE =================
  static Future<Map<String, dynamic>> addFavorite(
    int userId,
    String locationName,
    String description,
    double latitude,
    double longitude,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/add_favorite.php"),
      body: {
        "user_id": userId.toString(),
        "location_name": locationName,
        "description": description,
        "latitude": latitude.toString(),
        "longitude": longitude.toString(),
      },
    );

    try {
      return jsonDecode(res.body);
    } catch (e) {
      return {
        "status": "failed",
        "message": "Response bukan JSON valid",
        "raw": res.body,
      };
    }
  }

  // ================= GET FAVORITES =================
  static Future<List<dynamic>> getFavorites(int userId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/get_favorites.php?user_id=$userId"),
    );

    final data = jsonDecode(res.body);
    return data["data"] ?? [];
  }
}
