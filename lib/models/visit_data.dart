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

enum PlaceType {
  PEAK,
  TOWER,
  TREE,
  OTHER,
}

class Place {
  final String id;
  final String name;
  final PlaceType type;
  final List<PlacePhoto> photos;
  final String? description;
  final DateTime createdAt;

  const Place({
    required this.id,
    required this.name,
    required this.type,
    required this.photos,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'photos': photos.map((photo) => photo.toMap()).toList(),
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Place.fromMap(Map<String, dynamic> map) => Place(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    type: PlaceType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => PlaceType.OTHER,
    ),
    photos: (map['photos'] as List<dynamic>?)
        ?.map((photo) => PlacePhoto.fromMap(photo))
        .toList() ?? [],
    description: map['description']?.toString(),
    createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Place copyWith({
    String? id,
    String? name,
    PlaceType? type,
    List<PlacePhoto>? photos,
    String? description,
    DateTime? createdAt,
  }) => Place(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    photos: photos ?? this.photos,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
  );
}

class PlacePhoto {
  final String id;
  final String url;
  final String? description;
  final DateTime uploadedAt;
  final bool isLocal;

  const PlacePhoto({
    required this.id,
    required this.url,
    this.description,
    required this.uploadedAt,
    this.isLocal = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'description': description,
    'uploadedAt': uploadedAt.toIso8601String(),
    'isLocal': isLocal,
  };

  factory PlacePhoto.fromMap(Map<String, dynamic> map) => PlacePhoto(
    id: map['id']?.toString() ?? '',
    url: map['url']?.toString() ?? '',
    description: map['description']?.toString(),
    uploadedAt: DateTime.tryParse(map['uploadedAt']?.toString() ?? '') ?? DateTime.now(),
    isLocal: map['isLocal'] == true,
  );

  PlacePhoto copyWith({
    String? id,
    String? url,
    String? description,
    DateTime? uploadedAt,
    bool? isLocal,
  }) => PlacePhoto(
    id: id ?? this.id,
    url: url ?? this.url,
    description: description ?? this.description,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    isLocal: isLocal ?? this.isLocal,
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
  final Map<String, dynamic>? extraData; // Dynamic form data
  final List<Place> places; // New structured places
  final VisitState state;
  final String? rejectionReason;
  final DateTime? createdAt;
  final List<Map<String, dynamic>>? photos; // Photos field (includes screenshots from web)
  // Structure from web: { url, public_id, title, description, uploadedAt }
  final String? seasonId;
  final String? userId;
  final Map<String, dynamic>? user; // User data from JOIN
  final String? displayName; // Computed display name

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
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'visitDate': visitDate?.toIso8601String(),
      'routeTitle': routeTitle,
      'routeDescription': routeDescription,
      'dogName': dogName,
      'points': points,
      'visitedPlaces': visitedPlaces,
      'dogNotAllowed': dogNotAllowed,
      'routeLink': routeLink,
      'route': route,
      'seasonYear': year,
      'extraPoints': extraPoints,
      'extraData': extraData,
      'places': places.map((place) => place.toMap()).toList(),
      'state': state.name,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt?.toIso8601String(),
      'photos': photos,
      'seasonId': seasonId,
      'userId': userId,
      'user': user,
      'displayName': displayName,
    };
  }

  factory VisitData.fromMap(Map<String, dynamic> map) {
    try {
      // 1. Helper to extract extraPoints safely
      final extra = map['extraPoints'] is Map ? map['extraPoints'] as Map : {};
      
      // 2. Robust Points Parsing
      double parsedPoints = 0.0;
      if (map['points'] != null) {
        parsedPoints = TypeConverter.toDoubleWithDefault(map['points'], 0.0);
      } else if (extra['Body'] != null) {
        parsedPoints = TypeConverter.toDoubleWithDefault(extra['Body'], 0.0);
      } else if (extra['points'] != null) {
        parsedPoints = TypeConverter.toDoubleWithDefault(extra['points'], 0.0);
      }

      // 3. Robust Name Parsing
      String parsedName = 'Neznámý turista';
      if (map['displayName'] != null) parsedName = map['displayName'].toString();
      else if (map['user'] != null && map['user']['name'] != null) parsedName = map['user']['name'].toString();
      else if (map['fullName'] != null) parsedName = map['fullName'].toString();
      else if (extra['fullName'] != null) parsedName = extra['fullName'].toString();
      else if (extra['Příjmení a jméno'] != null) parsedName = extra['Příjmení a jméno'].toString();

      // 4. Robust Date Parsing
      DateTime parsedDate = DateTime.now();
      if (map['visitDate'] != null) {
        parsedDate = map['visitDate'] is DateTime 
            ? map['visitDate'] 
            : DateTime.tryParse(map['visitDate'].toString()) ?? DateTime.now();
      } else if (map['createdAt'] != null) {
        parsedDate = map['createdAt'] is DateTime 
            ? map['createdAt'] 
            : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
      }
      
      // 5. Robust Places Parsing
      String parsedPlacesStr = '';
      if (map['visitedPlaces'] != null) parsedPlacesStr = map['visitedPlaces'].toString();
      else if (extra['Navštívená místa'] != null) parsedPlacesStr = extra['Navštívená místa'].toString();

      return VisitData(
        id: map['_id'] != null ? map['_id'].toString() : (map['id']?.toString() ?? ''),
        visitDate: parsedDate,
        routeTitle: map['routeTitle']?.toString(), // Often null for legacy
        routeDescription: map['routeDescription']?.toString(),
        dogName: map['dogName']?.toString() ?? extra['Volací jméno psa']?.toString(),
        points: parsedPoints,
        visitedPlaces: parsedPlacesStr,
        dogNotAllowed: map['dogNotAllowed']?.toString(),
        routeLink: map['routeLink']?.toString(),
        route: map['route'] is Map ? Map<String, dynamic>.from(map['route']) : null,
        year: TypeConverter.toIntWithDefault(map['seasonYear'], parsedDate.year),
        extraPoints: Map<String, dynamic>.from(extra),
        extraData: map['extraData'] is Map ? Map<String, dynamic>.from(map['extraData']) : null,
        places: (map['places'] as List<dynamic>?)
            ?.map((place) => Place.fromMap(place))
            .toList() ?? [],
        state: VisitState.values.firstWhere(
          (e) => e.name == map['state'],
          orElse: () => VisitState.APPROVED, // Default legacy data to approved usually
        ),
        rejectionReason: map['rejectionReason']?.toString(),
        createdAt: map['createdAt'] is DateTime 
            ? map['createdAt'] 
            : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? parsedDate,
        photos: map['photos'] is List ? List<Map<String, dynamic>>.from(map['photos']) : null,
        seasonId: map['seasonId']?.toString(),
        userId: map['userId']?.toString(),
        user: map['user'] is Map ? Map<String, dynamic>.from(map['user']) : null,
        displayName: parsedName,
      );
    } catch (e) {
      print('❌ Error parsing VisitData: $e');
      print('❌ Map data (partial): ${map['_id']}');
      // Return a safe "Error" object instead of rethrowing, to avoid crashing list views
      return VisitData(
        id: map['_id']?.toString() ?? 'error',
        points: 0,
        visitedPlaces: 'Error parsing data',
        year: DateTime.now().year,
        extraPoints: {},
        state: VisitState.REJECTED
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
    );
  }


  Map<String, dynamic> toJson() {
    return toMap();
  }

  factory VisitData.fromJson(Map<String, dynamic> json) {
    return VisitData.fromMap(json);
  }
} 