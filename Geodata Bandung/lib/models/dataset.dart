class Dataset {
  final String pk;
  final String title;
  final String description;
  final String alternate;
  final String owner;
  final String category;
  final String? thumbnailUrl;

  Dataset({
    required this.pk,
    required this.title,
    required this.description,
    required this.alternate,
    required this.owner,
    this.category = "",
    this.thumbnailUrl,
  });

  factory Dataset.fromJson(Map<String, dynamic> json) {
    return Dataset(
      pk: json["pk"]?.toString() ?? "",
      title: json["title"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      alternate: json["alternate"]?.toString() ?? "",
      owner: json["owner"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "",
      thumbnailUrl:
          json["thumbnail_url"] ??
          json["thumbnail"] ??
          json["image"] ??
          null, // cek beberapa kemungkinan dari API
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "pk": pk,
      "title": title,
      "description": description,
      "alternate": alternate,
      "owner": owner,
      "category": category,
      "thumbnailUrl": thumbnailUrl,
    };
  }
}
