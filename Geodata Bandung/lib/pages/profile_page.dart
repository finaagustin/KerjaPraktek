import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();

  int? _userId;
  bool _loading = true;
  bool _isEditMode = false;

  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  // ================= LOAD PROFILE + ACTIVITY =================
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt("user_id");

      if (_userId == null) {
        setState(() => _loading = false);
        return;
      }

      // LOG ACTIVITY (BUKA PROFILE)
      await AuthService.logActivity(_userId!, "Buka Halaman Profile");

      // GET PROFILE
      final profileRes = await AuthService.getProfile(_userId!);
      if (profileRes["status"] == "success") {
        _fullName.text = profileRes["profile"]["full_name"] ?? "";
        _email.text = profileRes["profile"]["email"] ?? "";
      }

      // GET ACTIVITY
      final activityRes = await AuthService.getUserActivity(_userId!);
      _activities = List<Map<String, dynamic>>.from(activityRes);

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat profil: $e")));
    }
  }

  // ================= SAVE PROFILE =================
  Future<void> _saveProfile() async {
    if (_userId == null) return;

    final res = await AuthService.saveProfile(
      _userId!,
      _fullName.text.trim(),
      _email.text.trim(),
    );

    if (res["status"] == "success") {
      setState(() => _isEditMode = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profil berhasil disimpan")));
    }
  }

  // ================= LOGOUT =================
  Future<void> _logout() async {
    if (_userId != null) {
      await AuthService.logActivity(_userId!, "Logout");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xffF4F6FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isEditMode ? _buildEditCard() : _buildViewCard(),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActivityCard(),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff2F6FED), Color(0xff5A8DEE)],
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 45, color: Color(0xff2F6FED)),
          ),
          const SizedBox(height: 12),
          Text(
            _fullName.text.isEmpty ? "Nama Pengguna" : _fullName.text,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // ================= VIEW MODE =================
  Widget _buildViewCard() {
    return _card(
      Column(
        children: [
          _infoRow(Icons.email, _email.text),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text("Edit Profil"),
            onPressed: () => setState(() => _isEditMode = true),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  // ================= EDIT MODE =================
  Widget _buildEditCard() {
    return _card(
      Column(
        children: [
          TextField(
            controller: _fullName,
            decoration: const InputDecoration(labelText: "Nama Lengkap"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _saveProfile, child: const Text("Simpan")),
        ],
      ),
    );
  }

  // ================= ACTIVITY CARD =================
  Widget _buildActivityCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Riwayat Aktivitas",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (_activities.isEmpty)
            const Text("Belum ada aktivitas")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.length > 5 ? 5 : _activities.length,
              itemBuilder: (_, i) {
                final a = _activities[i];
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(a["activity"] ?? "-"),
                  subtitle: Text(a["created_at"] ?? "-"),
                );
              },
            ),
        ],
      ),
    );
  }

  // ================= HELPER =================
  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(child: Text(text.isEmpty ? "-" : text)),
      ],
    );
  }
}
