import '../utils/type_converter.dart';

enum UserRole {
  ADMIN,
  UZIVATEL,
  TESTER,
}

enum VisitState {
  DRAFT,
  PENDING_REVIEW,
  APPROVED,
  REJECTED,
}

/// Bodované místo — struktura odpovídá webu (`lib/visits/place.ts`): `type` je řetězec z `place_type_configs.name`.
class Place {
  final String id;
  final String name;
  final String type;
  final List<PlacePhoto> photos;
  final String description;
  final DateTime createdAt;
  final double? lat;
  final double? lng;
  final String? proofType;

  const Place({
    required this.id,
    required this.name,
    required this.type,
    required this.photos,
    this.description = '',
    required this.createdAt,
    this.lat,
    this.lng,
    this.proofType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'photos': photos.map((photo) => photo.toMap()).toList(),
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (proofType != null && proofType!.isNotEmpty) 'proofType': proofType,
      };

  factory Place.fromMap(Map<String, dynamic> map) {
    double? readCoord(dynamic v) {
      if (v == null) return null;
      final d = TypeConverter.toDoubleWithDefault(v, double.nan);
      if (d.isNaN || !d.isFinite) return null;
      return d;
    }

    final rawType = map['type']?.toString() ?? 'OTHER';
    return Place(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: rawType,
      photos: (map['photos'] as List<dynamic>?)
              ?.map((photo) => PlacePhoto.fromMap(Map<String, dynamic>.from(photo as Map)))
              .toList() ??
          [],
      description: map['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      lat: readCoord(map['lat']),
      lng: readCoord(map['lng']),
      proofType: map['proofType']?.toString(),
    );
  }

  Place copyWith({
    String? id,
    String? name,
    String? type,
    List<PlacePhoto>? photos,
    String? description,
    DateTime? createdAt,
    double? lat,
    double? lng,
    String? proofType,
  }) =>
      Place(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        photos: photos ?? this.photos,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        proofType: proofType ?? this.proofType,
      );
}

class PlacePhoto {
  final String id;
  final String url;
  final String? description;
  final DateTime uploadedAt;
  final bool isLocal;
  final String? title;
  final String? publicId;

  const PlacePhoto({
    required this.id,
    required this.url,
    this.description,
    required this.uploadedAt,
    this.isLocal = false,
    this.title,
    this.publicId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'description': description ?? '',
        'uploadedAt': uploadedAt.toIso8601String(),
        'isLocal': isLocal,
        if (title != null && title!.isNotEmpty) 'title': title,
        if (publicId != null && publicId!.isNotEmpty) 'public_id': publicId,
      };

  factory PlacePhoto.fromMap(Map<String, dynamic> map) => PlacePhoto(
        id: map['id']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
        description: map['description']?.toString(),
        uploadedAt: DateTime.tryParse(map['uploadedAt']?.toString() ?? '') ?? DateTime.now(),
        isLocal: map['isLocal'] == true,
        title: map['title']?.toString(),
        publicId: map['public_id']?.toString() ?? map['publicId']?.toString(),
      );

  PlacePhoto copyWith({
    String? id,
    String? url,
    String? description,
    DateTime? uploadedAt,
    bool? isLocal,
    String? title,
    String? publicId,
  }) =>
      PlacePhoto(
        id: id ?? this.id,
        url: url ?? this.url,
        description: description ?? this.description,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        isLocal: isLocal ?? this.isLocal,
        title: title ?? this.title,
        publicId: publicId ?? this.publicId,
      );
}

class VisitData {
  final String id;
  final DateTime? visitDate;
  final String? routeTitle;
  final String? routeDescription;
  final String? dogName;
  final double points;
  final String visitedPlaces;
  final String? dogNotAllowed;
  final String? routeLink;
  final Map<String, dynamic>? route;
  final int year;
  final Map<String, dynamic> extraPoints;
  final Map<String, dynamic>? extraData;
  final List<Place> places;
  final VisitState state;
  final String? rejectionReason;
  final DateTime? createdAt;
  final List<Map<String, dynamic>>? photos;
  final String? seasonId;
  final String? userId;
  final Map<String, dynamic>? user;
  final String? displayName;
  final double? distanceKm;
  final int? durationMinutes;

  VisitData({
    required this.id,
    this.visitDate,
    this.routeTitle,
    this.routeDescription,
    this.dogName,
    required this.points,
    required this.visitedPlaces,
    this.dogNotAllowed,
    this.routeLink,
    this.route,
    required this.year,
    required this.extraPoints,
    this.extraData,
    this.places = const [],
    this.state = VisitState.DRAFT,
    this.rejectionReason,
    this.createdAt,
    this.photos,
    this.seasonId,
    this.userId,
    this.user,
    this.displayName,
    this.distanceKm,
    this.durationMinutes,
  });

  double? _derivedDistanceKmFromRoute() {
    if (route == null) return null;
    final m = route!['totalDistance'];
    if (m == null) return null;
    final meters = TypeConverter.toDoubleWithDefault(m, 0.0);
    if (meters <= 0) return null;
    return (meters / 1000 * 1000).round() / 1000;
  }

  int? _derivedDurationMinutesFromRoute() {
    if (route == null) return null;
    final sec = route!['duration'];
    if (sec == null) return null;
    final s = TypeConverter.toDoubleWithDefault(sec, 0.0).round();
    if (s <= 0) return null;
    return (s / 60).ceil();
  }

  Map<String, dynamic> toMap() {
    final km = distanceKm ?? _derivedDistanceKmFromRoute();
    final dur = durationMinutes ?? _derivedDurationMinutesFromRoute();

    return {
      '_id': id,
      // BSON Date — Prisma `DateTime` na Mongo; ISO řetězec rozbije admin findMany (P2023).
      if (visitDate != null) 'visitDate': visitDate,
      'routeTitle': routeTitle,
      'routeDescription': routeDescription,
      'dogName': dogName,
      'points': points,
      'visitedPlaces': visitedPlaces,
      'dogNotAllowed': dogNotAllowed,
      'routeLink': routeLink,
      'route': route,
      if (km != null) 'distanceKm': km,
      if (dur != null) 'durationMinutes': dur,
      'seasonYear': year,
      'extraPoints': extraPoints,
      'extraData': extraData,
      'places': places.map((place) => place.toMap()).toList(),
      'state': state.name,
      'rejectionReason': rejectionReason,
      if (createdAt != null) 'createdAt': createdAt,
      'photos': photos,
      'seasonId': seasonId,
      'userId': userId,
      'user': user,
      'displayName': displayName,
    };
  }

  factory VisitData.fromMap(Map<String, dynamic> map) {
    try {
      final extra = map['extraPoints'] is Map ? map['extraPoints'] as Map : {};

      double parsedPoints = 0.0;
      if (map['points'] != null) {
        parsedPoints = TypeConverter.toDoubleWithDefault(map['points'], 0.0);
      } else if (extra['Body'] != null) {
        parsedPoints = TypeConverter.toDoubleWithDefault(extra['Body'], 0.0);
      } else if (extra['points'] != null) {
        parsedPoints = TypeConverter.toDoubleWithDefault(extra['points'], 0.0);
      }

      String parsedName = 'Neznámý turista';
      if (map['displayName'] != null) {
        parsedName = map['displayName'].toString();
      } else if (map['user'] != null && map['user']['name'] != null) {
        parsedName = map['user']['name'].toString();
      } else if (map['fullName'] != null) {
        parsedName = map['fullName'].toString();
      } else if (extra['fullName'] != null) {
        parsedName = extra['fullName'].toString();
      } else if (extra['Příjmení a jméno'] != null) {
        parsedName = extra['Příjmení a jméno'].toString();
      }

      DateTime parsedDate = DateTime.now();
      if (map['visitDate'] != null) {
        parsedDate = map['visitDate'] is DateTime
            ? map['visitDate'] as DateTime
            : DateTime.tryParse(map['visitDate'].toString()) ?? DateTime.now();
      } else if (map['createdAt'] != null) {
        parsedDate = map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
      }

      String parsedPlacesStr = '';
      if (map['visitedPlaces'] != null) {
        parsedPlacesStr = map['visitedPlaces'].toString();
      } else if (extra['Navštívená místa'] != null) {
        parsedPlacesStr = extra['Navštívená místa'].toString();
      }

      double? distKm;
      if (map['distanceKm'] != null) {
        distKm = TypeConverter.toDoubleWithDefault(map['distanceKm'], 0.0);
      }

      int? durMin;
      if (map['durationMinutes'] != null) {
        durMin = TypeConverter.toIntWithDefault(map['durationMinutes'], -1);
        if (durMin < 0) durMin = null;
      }

      return VisitData(
        id: map['_id'] != null ? map['_id'].toString() : (map['id']?.toString() ?? ''),
        visitDate: parsedDate,
        routeTitle: map['routeTitle']?.toString(),
        routeDescription: map['routeDescription']?.toString(),
        dogName: map['dogName']?.toString() ?? extra['Volací jméno psa']?.toString(),
        points: parsedPoints,
        visitedPlaces: parsedPlacesStr,
        dogNotAllowed: map['dogNotAllowed']?.toString(),
        routeLink: map['routeLink']?.toString(),
        route: map['route'] is Map ? Map<String, dynamic>.from(map['route'] as Map) : null,
        year: TypeConverter.toIntWithDefault(map['seasonYear'], parsedDate.year),
        extraPoints: Map<String, dynamic>.from(extra),
        extraData: map['extraData'] is Map ? Map<String, dynamic>.from(map['extraData'] as Map) : null,
        places: (map['places'] as List<dynamic>?)
                ?.map((place) => Place.fromMap(Map<String, dynamic>.from(place as Map)))
                .toList() ??
            [],
        state: VisitState.values.firstWhere(
          (e) => e.name == map['state'],
          orElse: () => VisitState.APPROVED,
        ),
        rejectionReason: map['rejectionReason']?.toString(),
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? parsedDate,
        photos: map['photos'] is List ? List<Map<String, dynamic>>.from(map['photos'] as List) : null,
        seasonId: map['seasonId']?.toString(),
        userId: map['userId']?.toString(),
        user: map['user'] is Map ? Map<String, dynamic>.from(map['user'] as Map) : null,
        displayName: parsedName,
        distanceKm: distKm,
        durationMinutes: durMin,
      );
    } catch (e) {
      print('❌ Error parsing VisitData: $e');
      print('❌ Map data (partial): ${map['_id']}');
      return VisitData(
        id: map['_id']?.toString() ?? 'error',
        points: 0,
        visitedPlaces: 'Error parsing data',
        year: DateTime.now().year,
        extraPoints: {},
        state: VisitState.REJECTED,
      );
    }
  }

  VisitData copyWith({
    String? id,
    DateTime? visitDate,
    String? routeTitle,
    String? routeDescription,
    String? dogName,
    double? points,
    String? visitedPlaces,
    String? dogNotAllowed,
    String? routeLink,
    Map<String, dynamic>? route,
    int? year,
    Map<String, dynamic>? extraPoints,
    Map<String, dynamic>? extraData,
    List<Place>? places,
    VisitState? state,
    String? rejectionReason,
    DateTime? createdAt,
    List<Map<String, dynamic>>? photos,
    String? seasonId,
    String? userId,
    Map<String, dynamic>? user,
    String? displayName,
    double? distanceKm,
    int? durationMinutes,
  }) {
    return VisitData(
      id: id ?? this.id,
      visitDate: visitDate ?? this.visitDate,
      routeTitle: routeTitle ?? this.routeTitle,
      routeDescription: routeDescription ?? this.routeDescription,
      dogName: dogName ?? this.dogName,
      points: points ?? this.points,
      visitedPlaces: visitedPlaces ?? this.visitedPlaces,
      dogNotAllowed: dogNotAllowed ?? this.dogNotAllowed,
      routeLink: routeLink ?? this.routeLink,
      route: route ?? this.route,
      year: year ?? this.year,
      extraPoints: extraPoints ?? this.extraPoints,
      extraData: extraData ?? this.extraData,
      places: places ?? this.places,
      state: state ?? this.state,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      photos: photos ?? this.photos,
      seasonId: seasonId ?? this.seasonId,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory VisitData.fromJson(Map<String, dynamic> json) => VisitData.fromMap(json);
}
