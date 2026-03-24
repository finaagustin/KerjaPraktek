import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_geo/pages/map_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import 'package:http/http.dart' as http;

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<dynamic>> _favoritesFuture;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _reloadFavorites();
  }

  // 🔥 INI KUNCI UTAMA
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadFavorites();
  }

  void _reloadFavorites() {
    setState(() {
      _favoritesFuture = _loadFavorites();
    });
  }

  // ================= LOAD FAVORITES =================
  Future<List<dynamic>> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");

    debugPrint("USER ID DI FAVORITES: $userId");

    if (userId == null) return [];

    final data = await AuthService.getFavorites(userId);

    debugPrint("DATA FAVORITES: $data");

    return data;
  }

  // ================= DELETE FAVORITE =================
  Future<void> _deleteFavorite(dynamic rawId) async {
    final int? id = int.tryParse(rawId.toString());

    if (id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ID favorit tidak valid")));
      return;
    }

    try {
      final res = await http.post(
        Uri.parse("${AuthService.baseUrl}/delete_favorite.php"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"id": id.toString()},
      );

      final data = jsonDecode(res.body);

      if (data["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil menghapus favorit")),
        );
        _reloadFavorites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Gagal menghapus")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan: $e")));
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lokasi Favorit")),
      body: FutureBuilder<List<dynamic>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Belum ada lokasi favorit",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final favorites = snapshot.data!;

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final item = favorites[index];

              final lat = double.tryParse(item['latitude'].toString());
              final lng = double.tryParse(item['longitude'].toString());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: Text(item['location_name'] ?? "-"),
                  subtitle: Text(
                    "Lat: ${item['latitude']}\nLng: ${item['longitude']}",
                  ),
                  isThreeLine: true,

                  onTap: () {
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Koordinat tidak valid")),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MapHomePage(focusLat: lat, focusLng: lng),
                      ),
                    );
                  },

                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _deleteFavorite(item['id']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
