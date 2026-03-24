import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dataset.dart';

class ApiService {
  static const String baseUrl = "https://geodata.bandung.go.id/api/v2";

  /// Ambil semua dataset (loop semua halaman)
  static Future<List<Dataset>> fetchAllDatasets() async {
    int page = 1;
    const int pageSize = 50; // bisa ubah ke 100 kalau mau lebih cepat
    bool hasNext = true;
    List<Dataset> allDatasets = [];

    while (hasNext) {
      final url = "$baseUrl/datasets/?page=$page&page_size=$pageSize";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        throw Exception("Gagal memuat dataset halaman $page");
      }

      final data = json.decode(res.body);
      final results = (data["datasets"] ?? data["objects"] ?? []) as List;

      // tambahkan ke list semua dataset
      allDatasets.addAll(results.map((e) => Dataset.fromJson(e)).toList());

      // cek apakah masih ada halaman berikutnya
      hasNext = data["links"]?["next"] != null;
      page++;
    }

    return allDatasets;
  }

  /// Ambil dataset berdasarkan halaman
  static Future<Map<String, dynamic>> fetchDatasetsPage(
    int page, {
    int pageSize = 20,
  }) async {
    final url = "$baseUrl/datasets/?page=$page&page_size=$pageSize";
    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) {
      throw Exception("Gagal ambil dataset page $page");
    }

    final data = json.decode(res.body);
    final results = (data["datasets"] ?? data["objects"] ?? []) as List;
    final parsedResults = results.map((e) => Dataset.fromJson(e)).toList();

    return {
      "datasets": parsedResults,
      "hasNext": data["links"]?["next"] != null,
    };
  }

  /// Ambil detail dataset berdasarkan pk
  static Future<Map<String, dynamic>> fetchDatasetDetail(String pk) async {
    final url = "$baseUrl/datasets/$pk";
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200)
      throw Exception("Gagal memuat detail dataset $pk");
    return json.decode(res.body)["dataset"];
  }

  /// Ambil atribut dataset
  static Future<List<Map<String, String>>> fetchAttributes(String pk) async {
    final url = "$baseUrl/datasets/$pk";
    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) {
      throw Exception("Gagal memuat atribut: $pk");
    }

    final data = json.decode(res.body);
    final dataset = data["dataset"];
    final attrs = dataset?["attribute_set"] as List<dynamic>? ?? [];

    return attrs.map((e) {
      return {
        "name": e["attribute"]?.toString() ?? "-",
        "type": e["attribute_type"]?.toString() ?? "-",
        "label": e["attribute_label"]?.toString() ?? "",
      };
    }).toList();
  }

  /// Hitung total dataset
  static Future<int> fetchTotalDatasets() async {
    final url = "$baseUrl/datasets/?page=1&page_size=1";
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception("Gagal ambil statistik");
    final data = json.decode(res.body);
    return data["total"] ?? 0;
  }
}
