import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool loading = true;
  List<Map<String, dynamic>> activities = [];

  @override
  void initState() {
    super.initState();
    loadActivity();
  }

  Future<void> loadActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("user_id");

      if (userId == null) {
        setState(() => loading = false);
        return;
      }

      final data = await AuthService.getUserActivity(userId);

      setState(() {
        activities = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat aktivitas: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Aktivitas")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : activities.isEmpty
          ? const Center(
              child: Text(
                "Belum ada aktivitas",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: activities.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = activities[index];

                final activity = item["activity"]?.toString() ?? "-";
                final createdAt = item["created_at"]?.toString() ?? "-";

                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.blueGrey),
                  title: Text(activity),
                  subtitle: Text(
                    createdAt,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}
