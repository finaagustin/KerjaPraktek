import 'package:flutter/material.dart';
import '../models/dataset.dart';
import '../services/api_service.dart';

class DatasetDetailPage extends StatefulWidget {
  final Dataset dataset;
  const DatasetDetailPage({super.key, required this.dataset});

  @override
  State<DatasetDetailPage> createState() => _DatasetDetailPageState();
}

class _DatasetDetailPageState extends State<DatasetDetailPage> {
  Map<String, dynamic>? _datasetDetail;
  List<Map<String, String>> _attributes = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final detail = await ApiService.fetchDatasetDetail(widget.dataset.pk);
      final attrs = await ApiService.fetchAttributes(widget.dataset.pk);

      setState(() {
        _datasetDetail = detail;
        _attributes = attrs;
      });
    } catch (e) {
      debugPrint("❌ DatasetDetail error: $e");
      setState(() {
        _hasError = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildAttributes() {
    if (_attributes.isEmpty) {
      return const Text(
        "Tidak ada atribut.",
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _attributes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final attr = _attributes[index];
        return ListTile(
          contentPadding: EdgeInsets.zero, // rata kiri
          title: Text(
            attr["name"] ?? "-",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(attr["type"] ?? "-"),
          trailing: Text(attr["label"] ?? ""),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.dataset.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Gagal memuat detail dataset."),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadDetail,
                    child: const Text("Coba Lagi"),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.dataset.thumbnailUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.dataset.thumbnailUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft, // geser ke kiri
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    widget.dataset.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.dataset.description,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Atribut Dataset",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAttributes(),
                ],
              ),
            ),
    );
  }
}
