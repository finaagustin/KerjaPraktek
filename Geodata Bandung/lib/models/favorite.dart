class Favorite {
  final int id;
  final String name;
  final double lat;
  final double lng;

  Favorite({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: int.parse(json['id']),
      name: json['location_name'],
      lat: double.parse(json['latitude']),
      lng: double.parse(json['longitude']),
    );
  }
}
