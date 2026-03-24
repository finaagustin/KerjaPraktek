import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';

class MapHomePage extends StatefulWidget {
  final double? focusLat;
  final double? focusLng;

  const MapHomePage({super.key, this.focusLat, this.focusLng});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController mapController = MapController();
  List<dynamic> datasets = [];
  List<dynamic> filteredDatasets = [];
  bool isLoading = true;
  bool isProcessing = false;
  double globalOpacity = 0.9;

  final Map<String, bool> selectedLayers = {};
  final TextEditingController datasetSearchController = TextEditingController();

  List<LatLng> kecamatanPolygon = [];
  List<LatLng> kelurahanPolygon = [];

  // tambahan: kontrol tampilan base map
  String _selectedBaseLayer = 'medan';
  bool _isLayerMenuVisible = false;

  // tambahan: kontrol panel dataset tampil/sembunyi
  bool _showDatasetPanel = true;

  @override
  void initState() {
    super.initState();
    fetchAllDatasets();

    // ⬇️ TAMBAHAN: fokus peta dari favorit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusLat != null && widget.focusLng != null) {
        mapController.move(LatLng(widget.focusLat!, widget.focusLng!), 16);
      }
    });
  }

  Future<void> fetchAllDatasets() async {
    String? nextUrl =
        "https://geodata.bandung.go.id/api/v2/datasets/?page=1&page_size=50";
    List<dynamic> allData = [];

    setState(() => isLoading = true);
    try {
      while (nextUrl != null) {
        final res = await http.get(Uri.parse(nextUrl));
        if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");

        final data = jsonDecode(res.body);
        allData.addAll(data["datasets"] ?? []);
        nextUrl = data["links"]?["next"];
      }

      setState(() {
        datasets = allData;
        filteredDatasets = allData;

        for (var ds in datasets) {
          final alt = ds["alternate"] ?? "";
          if (alt.isNotEmpty) selectedLayers[alt] = false;
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("⚠ Gagal memuat dataset: $e")));
      }
    }
  }

  String getBaseMapUrl() {
    switch (_selectedBaseLayer) {
      case 'satelit':
        return "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}";
      case 'transportasi':
        return "https://tile.opentopomap.org/{z}/{x}/{y}.png";
      case 'medan':
      default:
        return "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
    }
  }

  List<Widget> buildActiveLayers() {
    final List<Widget> layers = [];

    for (var entry in selectedLayers.entries.where((e) => e.value)) {
      layers.add(
        Opacity(
          opacity: globalOpacity,
          child: TileLayer(
            wmsOptions: WMSTileLayerOptions(
              baseUrl: "https://geodata.bandung.go.id/geoserver/geonode/wms?",
              layers: [entry.key],
              format: "image/png",
              transparent: true,
            ),
          ),
        ),
      );
    }

    if (kecamatanPolygon.isNotEmpty) {
      layers.add(
        PolygonLayer(
          polygons: [
            Polygon(
              points: kecamatanPolygon,
              color: Colors.transparent,
              borderColor: Colors.blue,
              borderStrokeWidth: 2,
            ),
          ],
        ),
      );
    }

    if (kelurahanPolygon.isNotEmpty) {
      layers.add(
        PolygonLayer(
          polygons: [
            Polygon(
              points: kelurahanPolygon,
              color: Colors.transparent,
              borderColor: Colors.red,
              borderStrokeWidth: 2,
            ),
          ],
        ),
      );
    }

    return layers;
  }

  Future<Map<String, String>> fetchAdminLocation(LatLng latlng) async {
    final bounds = mapController.camera?.visibleBounds;
    if (bounds == null) return {"kecamatan": "-", "kelurahan": "-"};
    const width = 600, height = 400;
    final x =
        ((latlng.longitude - bounds.west) / (bounds.east - bounds.west) * width)
            .toInt();
    final y =
        ((bounds.north - latlng.latitude) /
                (bounds.north - bounds.south) *
                height)
            .toInt();

    const kecLayer = "geonode:format_kecamatan";
    const kelLayer = "geonode:format_kelurahan";

    Future<Map<String, dynamic>?> getFeature(String layer) async {
      final url =
          "https://geodata.bandung.go.id/geoserver/geonode/wms?"
          "service=WMS&version=1.1.0&request=GetFeatureInfo"
          "&layers=$layer&query_layers=$layer"
          "&bbox=${bounds.west},${bounds.south},${bounds.east},${bounds.north}"
          "&width=$width&height=$height&srs=EPSG:4326&x=$x&y=$y"
          "&info_format=application/json";

      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final features = data["features"] as List?;
          if (features != null && features.isNotEmpty) return features.first;
        }
      } catch (_) {}
      return null;
    }

    final kecFeature = await getFeature(kecLayer);
    final kelFeature = await getFeature(kelLayer);

    if (mounted) {
      setState(() {
        kecamatanPolygon = _parsePolygon(kecFeature?["geometry"]);
        kelurahanPolygon = _parsePolygon(kelFeature?["geometry"]);
      });
    }

    final kec =
        kecFeature?["properties"]?["kecamatan"] ??
        kecFeature?["properties"]?["namobj"];
    final kel =
        kelFeature?["properties"]?["desa"] ??
        kelFeature?["properties"]?["namobj"];
    return {"kecamatan": kec ?? "-", "kelurahan": kel ?? "-"};
  }

  List<LatLng> _parsePolygon(dynamic geometry) {
    List<LatLng> points = [];
    if (geometry == null) return points;
    try {
      if (geometry["type"] == "Polygon") {
        final coords = geometry["coordinates"][0] as List;
        for (var c in coords) {
          points.add(LatLng(c[1], c[0]));
        }
      } else if (geometry["type"] == "MultiPolygon") {
        final coords = geometry["coordinates"][0][0] as List;
        for (var c in coords) {
          points.add(LatLng(c[1], c[0]));
        }
      }
    } catch (_) {
      // ignore parse errors
    }
    return points;
  }

  Future<Map<String, String>> fetchCagbudResairInfo(LatLng latlng) async {
    final bounds = mapController.camera?.visibleBounds;
    if (bounds == null) return {"cagbud": "Tidak Ada", "resair": "Tidak Ada"};
    const width = 600, height = 400;
    final x =
        ((latlng.longitude - bounds.west) / (bounds.east - bounds.west) * width)
            .toInt();
    final y =
        ((bounds.north - latlng.latitude) /
                (bounds.north - bounds.south) *
                height)
            .toInt();

    final url =
        "https://geodata.bandung.go.id/geoserver/geonode/wms?"
        "service=WMS&version=1.1.0&request=GetFeatureInfo"
        "&layers=geonode:pola_ruang_ar_3"
        "&query_layers=geonode:pola_ruang_ar_3"
        "&bbox=${bounds.west},${bounds.south},${bounds.east},${bounds.north}"
        "&width=$width&height=$height&srs=EPSG:4326&x=$x&y=$y"
        "&info_format=application/json";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final features = data["features"] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features.first["properties"] ?? {};
          String cagbud = (props["cagbud"] ?? "Tidak Ada").toString();
          String resair = (props["resair"] ?? "Tidak Ada").toString();

          if (cagbud.trim().isEmpty || cagbud.toLowerCase() == "tidak ada") {
            cagbud = "Tidak Ada";
          } else if (cagbud.toLowerCase().contains("kawasan cagar budaya")) {
            cagbud = "Kawasan Cagar Budaya";
          }

          if (resair.trim().isEmpty || resair.toLowerCase() == "tidak ada") {
            resair = "Tidak Ada";
          } else if (resair.toUpperCase().contains("K08A")) {
            resair = "KBU (Kawasan Bandung Utara)";
          }

          return {"cagbud": cagbud, "resair": resair};
        }
      }
    } catch (e) {
      // ignore and return default
      // ignore: avoid_print
      print("⚠ Error ambil cagbud/resair: $e");
    }

    return {"cagbud": "Tidak Ada", "resair": "Tidak Ada"};
  }

  Future<void> onMapTap(LatLng latlng) async {
    setState(() {
      isProcessing = true;
      kecamatanPolygon.clear();
      kelurahanPolygon.clear();
    });

    String? rdtrLayer;
    String? rtrwLayer;

    for (var ds in datasets) {
      final title = (ds["title"] ?? "").toString().toLowerCase();
      final alt = ds["alternate"] ?? "";
      if (title.contains("rdtr") && selectedLayers[alt] == true)
        rdtrLayer = alt;
      if (title.contains("rencana tata ruang") && selectedLayers[alt] == true)
        rtrwLayer = alt;
    }

    final activeLayer = rdtrLayer ?? rtrwLayer;
    if (activeLayer == null) {
      setState(() => isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aktifkan layer RDTR atau RTRW terlebih dahulu."),
          ),
        );
      }
      return;
    }

    final bounds = mapController.camera?.visibleBounds;
    if (bounds == null) {
      setState(() => isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Area peta belum siap.")));
      }
      return;
    }

    const width = 600, height = 400;
    final x =
        ((latlng.longitude - bounds.west) / (bounds.east - bounds.west) * width)
            .toInt();
    final y =
        ((bounds.north - latlng.latitude) /
                (bounds.north - bounds.south) *
                height)
            .toInt();

    final url =
        "https://geodata.bandung.go.id/geoserver/geonode/wms?"
        "service=WMS&version=1.1.0&request=GetFeatureInfo"
        "&layers=$activeLayer&query_layers=$activeLayer"
        "&bbox=${bounds.west},${bounds.south},${bounds.east},${bounds.north}"
        "&width=$width&height=$height&srs=EPSG:4326&x=$x&y=$y"
        "&info_format=application/json";

    try {
      final res = await http.get(Uri.parse(url));
      final adminInfo = await fetchAdminLocation(latlng);
      final tambahanInfo = await fetchCagbudResairInfo(latlng);
      setState(() => isProcessing = false);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final features = data["features"] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features.first["properties"] as Map<String, dynamic>;
          final zona =
              props["zona"] ??
              props["namobj"] ??
              props["fungsi"] ??
              props["nama"] ??
              "Tidak diketahui";
          final keterangan =
              props["deskripsi"] ?? props["remark"] ?? props["fungsi"] ?? "-";

          if (!mounted) return;

          // NEW UI: modern bottom sheet (design version you provided)
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            builder: (context) {
              return SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // header gradient
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFEB3A8C),
                                    Color(0xFFFD5D5D),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      "Informasi Lokasi",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      clearPolygons();
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Kecamatan & Kelurahan
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  _infoTile(
                                    icon: Icons.apartment_outlined,
                                    title: "Kecamatan",
                                    value: adminInfo["kecamatan"] ?? "-",
                                  ),
                                  const SizedBox(height: 8),
                                  _infoTile(
                                    icon: Icons.location_city,
                                    title: "Kelurahan",
                                    value: adminInfo["kelurahan"] ?? "-",
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Zona
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F7FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.layers,
                                          color: Color(0xFF4A6BF5),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Zona",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4A6BF5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow("Nama Zona", zona.toString()),
                                    _infoRow(
                                      "Keterangan",
                                      keterangan.toString(),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Cagar Budaya & Resapan Air
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  _infoTile(
                                    icon: Icons.museum_outlined,
                                    title: "Cagar Budaya",
                                    value:
                                        tambahanInfo["cagbud"] ?? "Tidak Ada",
                                  ),
                                  const SizedBox(height: 8),
                                  _infoTile(
                                    icon: Icons.water_drop_outlined,
                                    title: "Resapan Air",
                                    value:
                                        tambahanInfo["resair"] ?? "Tidak Ada",
                                    linkStyle: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ================= TOMBOL FAVORIT (FIXED) =================
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.favorite_border),
                              label: const Text("Simpan ke Favorit"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                debugPrint("=== TOMBOL FAVORIT DIKLIK ===");

                                // ⬇️ ambil context root (WAJIB untuk SnackBar)
                                final rootContext = Navigator.of(
                                  context,
                                ).context;

                                try {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final userId = prefs.getInt("user_id");

                                  debugPrint("USER ID: $userId");

                                  // ====== VALIDASI LOGIN ======
                                  if (userId == null) {
                                    ScaffoldMessenger.of(
                                      rootContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Silakan login terlebih dahulu",
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  // ====== FEEDBACK AWAL ======
                                  ScaffoldMessenger.of(
                                    rootContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text("Menyimpan ke favorit..."),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );

                                  // ====== PANGGIL API ======
                                  final res = await AuthService.addFavorite(
                                    userId,
                                    zona.toString(), // locationName
                                    "Zona: $zona", // description
                                    latlng.latitude, // ✅ latitude
                                    latlng.longitude, // ✅ longitude
                                  );

                                  debugPrint("RESPONSE API: $res");

                                  // ====== HASIL ======
                                  if (res["status"] == "success") {
                                    Navigator.pop(
                                      context,
                                    ); // tutup bottom sheet

                                    ScaffoldMessenger.of(
                                      rootContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Berhasil disimpan ke favorit",
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(
                                      rootContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res["message"] ??
                                              "Gagal menyimpan favorit",
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint("ERROR FAVORIT: $e");

                                  ScaffoldMessenger.of(
                                    rootContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text("Terjadi kesalahan: $e"),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada informasi di lokasi ini.")),
        );
      }
    } catch (e) {
      setState(() => isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mengambil data: $e")));
      }
    }
  }

  void resetAllLayers() {
    setState(() {
      for (var key in selectedLayers.keys) selectedLayers[key] = false;
      kecamatanPolygon.clear();
      kelurahanPolygon.clear();
    });
  }

  void clearPolygons() {
    setState(() {
      kecamatanPolygon.clear();
      kelurahanPolygon.clear();
    });
  }

  /// WIDGET PANEL DATASET
  Widget _buildDatasetPanel() {
    if (!_showDatasetPanel) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: 20,
      right: 10,
      child: Container(
        width: screenWidth < 400 ? screenWidth * 0.9 : 320,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ★ Button Hide Panel
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _showDatasetPanel = false),
                child: const Icon(Icons.close_rounded),
              ),
            ),

            TextField(
              controller: datasetSearchController,
              decoration: InputDecoration(
                hintText: "Cari dataset...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (query) {
                final q = query.toLowerCase();
                setState(() {
                  filteredDatasets = datasets.where((ds) {
                    final title = (ds["title"] ?? "").toString().toLowerCase();
                    return title.contains(q);
                  }).toList();
                });
              },
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: resetAllLayers,
              child: const Text("Reset Semua Layer"),
            ),

            const SizedBox(height: 12),

            if (filteredDatasets.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: ListView.builder(
                  itemCount: filteredDatasets.length,
                  itemBuilder: (context, index) {
                    final ds = filteredDatasets[index];
                    final title = ds["title"] ?? "Tanpa Judul";
                    final alt = ds["alternate"] ?? "";

                    if (alt.isEmpty) return const SizedBox.shrink();

                    return CheckboxListTile(
                      dense: true,
                      title: Text(title, style: const TextStyle(fontSize: 13)),
                      value: selectedLayers[alt] ?? false,
                      onChanged: (v) =>
                          setState(() => selectedLayers[alt] = v ?? false),
                    );
                  },
                ),
              )
            else
              Text(
                "Dataset tidak ditemukan.\n(Total: ${datasets.length})",
                textAlign: TextAlign.center,
              ),

            const Divider(),

            Row(
              children: [
                const Text("Opacity: "),
                Expanded(
                  child: Slider(
                    value: globalOpacity,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    label: globalOpacity.toStringAsFixed(2),
                    onChanged: (v) => setState(() => globalOpacity = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowPanelButton() {
    if (_showDatasetPanel) return const SizedBox.shrink();

    return Positioned(
      top: 20,
      right: 20,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        onPressed: () => setState(() => _showDatasetPanel = true),
        child: const Icon(Icons.menu_open),
      ),
    );
  }

  Widget _buildLayerOption(String value, IconData icon, String label) {
    final bool selected = _selectedBaseLayer == value;
    return GestureDetector(
      onTap: () {
        if (_selectedBaseLayer != value) {
          _selectedBaseLayer = value;
          setState(() {});
        }
        setState(() => _isLayerMenuVisible = false);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: Colors.blue.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.blue : Colors.black54),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerSelector() {
    return Positioned(
      bottom: 30,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isLayerMenuVisible)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLayerOption('medan', Icons.terrain, "Medan"),
                  _buildLayerOption(
                    'transportasi',
                    Icons.directions_transit,
                    "Transportasi",
                  ),
                  _buildLayerOption('satelit', Icons.satellite_alt, "Satelit"),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "layer_toggle",
            onPressed: () =>
                setState(() => _isLayerMenuVisible = !_isLayerMenuVisible),
            backgroundColor: Colors.white,
            child: const Icon(Icons.layers, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Helper UI widgets (tidak mengubah logika)
  // -----------------------
  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    bool linkStyle = false,
  }) {
    final textWidget = linkStyle
        ? GestureDetector(
            onTap: () {
              // placeholder untuk interaksi link jika diperlukan nanti
            },
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        : Text(value, style: const TextStyle(fontWeight: FontWeight.w600));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$title",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: textWidget),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "$title:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Zoom buttons kiri-bawah (versi A: two small floating buttons stacked)
  // -----------------------
  Widget _buildZoomButtons() {
    return Positioned(
      bottom: 30,
      left: 20,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: () {
              final currentZoom = mapController.camera?.zoom ?? 12.0;
              final currentCenter =
                  mapController.camera?.center ??
                  const LatLng(-6.9175, 107.6191);
              mapController.move(currentCenter, (currentZoom + 1));
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.add, color: Colors.black87, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: () {
              final currentZoom = mapController.camera?.zoom ?? 12.0;
              final currentCenter =
                  mapController.camera?.center ??
                  const LatLng(-6.9175, 107.6191);
              mapController.move(currentCenter, (currentZoom - 1));
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.remove, color: Colors.black87, size: 18),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // BUILD
  // -----------------------
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2196F3),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF2196F3),
          thumbColor: Color(0xFF2196F3),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
              : null,
          title: const Text(
            "🌐 Peta Geodata Bandung",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        body: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: const LatLng(-6.9175, 107.6191),
                initialZoom: 12,
                onTap: (tapPos, latlng) => onMapTap(latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate: getBaseMapUrl(),
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: "com.example.mobile_geo",
                ),
                ...buildActiveLayers(),
              ],
            ),

            // dataset panel (kanan atas)
            if (!isLoading) _buildDatasetPanel(),

            _buildShowPanelButton(), // << Tambahan
            // layer selector (kanan bawah)
            _buildLayerSelector(),

            // zoom buttons kiri bawah (versi A)
            _buildZoomButtons(),

            // loading indicator
            if (isLoading)
              const Positioned(
                top: 20,
                right: 20,
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text("📡 Memuat dataset..."),
                  ),
                ),
              ),

            // processing indicator
            if (isProcessing)
              const Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    elevation: 6,
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text("Mengambil data zona..."),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
