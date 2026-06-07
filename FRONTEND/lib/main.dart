import 'dart:convert';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_web_button.dart';

void main() {
  runApp(const TouristSpotFinderApp());
}

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );
  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '285680876693-8a59pf59fbefi2stf5356lbht781ob34.apps.googleusercontent.com',
  );
}

String mediaUrl(String url) {
  if (url.startsWith('/')) {
    return '${ApiConfig.baseUrl}$url';
  }
  return url;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.isAdmin,
  });

  final int id;
  final String fullName;
  final String email;
  final bool isAdmin;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? 'Renejay Explorer',
      email: json['email'] as String? ?? 'renejay@example.com',
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }
}

class TouristSpot {
  const TouristSpot({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.rating,
    this.imageUrl = '',
    this.entranceFee = 'Check local tourism office',
    this.openingHours = 'Open daily',
    this.transportGuide = 'Use local transport or map directions',
    this.emergencyInfo = 'Call 911 for emergencies',
    this.weatherNote = 'Check weather before traveling',
  });

  final int id;
  final String name;
  final String location;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final double rating;
  final String imageUrl;
  final String entranceFee;
  final String openingHours;
  final String transportGuide;
  final String emergencyInfo;
  final String weatherNote;

  factory TouristSpot.fromJson(Map<String, dynamic> json) {
    return TouristSpot(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Nature',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      imageUrl: json['image_url'] as String? ?? '',
      entranceFee:
          json['entrance_fee'] as String? ?? 'Check local tourism office',
      openingHours: json['opening_hours'] as String? ?? 'Open daily',
      transportGuide:
          json['transport_guide'] as String? ??
          'Use local transport or map directions',
      emergencyInfo:
          json['emergency_info'] as String? ?? 'Call 911 for emergencies',
      weatherNote:
          json['weather_note'] as String? ?? 'Check weather before traveling',
    );
  }
}

class SpotReview {
  const SpotReview({
    required this.rating,
    required this.comment,
    required this.authorName,
  });

  final int rating;
  final String comment;
  final String authorName;

  factory SpotReview.fromJson(Map<String, dynamic> json) {
    return SpotReview(
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Traveler',
    );
  }
}

class SpotPhoto {
  const SpotPhoto({
    required this.imageUrl,
    required this.caption,
    required this.authorName,
  });

  final String imageUrl;
  final String caption;
  final String authorName;

  factory SpotPhoto.fromJson(Map<String, dynamic> json) {
    return SpotPhoto(
      imageUrl: json['image_url'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Traveler',
    );
  }
}

class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.title,
    required this.travelDate,
    required this.notes,
    required this.spotName,
  });

  final int id;
  final String title;
  final String travelDate;
  final String notes;
  final String spotName;

  factory ItineraryItem.fromJson(Map<String, dynamic> json) => ItineraryItem(
    id: json['id'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    travelDate: json['travel_date'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    spotName: json['spot_name'] as String? ?? '',
  );
}

class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
  });

  final int id;
  final String label;
  final double amount;
  final String category;

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    id: json['id'] as int? ?? 0,
    label: json['label'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    category: json['category'] as String? ?? 'Other',
  );
}

class TravelBadge {
  const TravelBadge({required this.title, required this.description});

  final String title;
  final String description;

  factory TravelBadge.fromJson(Map<String, dynamic> json) => TravelBadge(
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

class PostComment {
  const PostComment({
    required this.body,
    required this.authorName,
    this.createdAt,
  });

  final String body;
  final String authorName;
  final DateTime? createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    body: json['body'] as String? ?? '',
    authorName: json['author_name'] as String? ?? 'Traveler',
    createdAt: parseDateTime(json['created_at']),
  );
}

DateTime? parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String formatDateTime(DateTime? value) {
  if (value == null) return 'Just now';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.month}/${value.day}/${value.year} $hour:$minute $period';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['requires_verification'] as bool? ?? true;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _readAuthResponse(response);
  }

  Future<AppUser> loginWithGoogle(String idToken) async {
    final response = await _client.post(
      _uri('/auth/google'),
      headers: _headers,
      body: jsonEncode({'id_token': idToken}),
    );
    return _readAuthResponse(response);
  }

  Future<AppUser> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      _uri('/auth/verify-email'),
      headers: _headers,
      body: jsonEncode({'email': email, 'code': code}),
    );
    return _readAuthResponse(response);
  }

  Future<void> resendVerification({required String email}) async {
    final response = await _client.post(
      _uri('/auth/resend-verification'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  AppUser _readAuthResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    token = data['token'] as String?;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<List<TouristSpot>> fetchSpots({
    String q = '',
    String category = '',
  }) async {
    final uri = _uri('/spots').replace(
      queryParameters: {
        if (q.isNotEmpty) 'q': q,
        if (category.isNotEmpty) 'category': category,
      },
    );
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => TouristSpot.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<TravelPost>> fetchPosts() async {
    final response = await _client.get(_uri('/posts'), headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => TravelPost.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<TravelPost> createPost(
    String body, {
    String title = 'Traveler Update',
    String spotName = '',
    List<String> photoUrls = const [],
  }) async {
    final response = await _client.post(
      _uri('/posts'),
      headers: _headers,
      body: jsonEncode({
        'body': body,
        'title': title,
        'spot_name': spotName,
        'photo_urls': photoUrls,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return TravelPost.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AppUser> updateProfileName(String fullName) async {
    final response = await _client.put(
      _uri('/me'),
      headers: _headers,
      body: jsonEncode({'full_name': fullName}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> forgotPassword(String email) async {
    final response = await _client.post(
      _uri('/auth/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _client.post(
      _uri('/auth/reset-password'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  Future<TouristSpot> createSpot({
    required String name,
    required String location,
    required String description,
    required String category,
    required double latitude,
    required double longitude,
    String imageUrl = '',
    String entranceFee = 'Check local tourism office',
    String openingHours = 'Open daily',
    String transportGuide = 'Use local transport or map directions',
    String emergencyInfo = 'Call 911 for emergencies',
    String weatherNote = 'Check weather before traveling',
  }) async {
    final response = await _client.post(
      _uri('/admin/spots'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'location': location,
        'description': description,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'entrance_fee': entranceFee,
        'opening_hours': openingHours,
        'transport_guide': transportGuide,
        'emergency_info': emergencyInfo,
        'weather_note': weatherNote,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return TouristSpot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SpotReview>> fetchReviews(int spotId) async {
    final response = await _client.get(
      _uri('/spots/$spotId/reviews'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => SpotReview.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<SpotReview> createReview(
    int spotId,
    int rating,
    String comment,
  ) async {
    final response = await _client.post(
      _uri('/spots/$spotId/reviews'),
      headers: _headers,
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return SpotReview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SpotPhoto>> fetchPhotos(int spotId) async {
    final response = await _client.get(
      _uri('/spots/$spotId/photos'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => SpotPhoto.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<SpotPhoto> createPhoto(
    int spotId,
    String imageUrl,
    String caption,
  ) async {
    final response = await _client.post(
      _uri('/spots/$spotId/photos'),
      headers: _headers,
      body: jsonEncode({'image_url': imageUrl, 'caption': caption}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return SpotPhoto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SpotPhoto> uploadPhotoFile(
    int spotId,
    XFile file,
    String caption,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/spots/$spotId/photo-files'),
    );
    request.headers.addAll({
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.fields['caption'] = caption;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return SpotPhoto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, bool>> getSpotStatus(int spotId) async {
    final response = await _client.get(
      _uri('/spots/$spotId/status'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'visited': data['visited'] as bool? ?? false,
      'favorite': data['favorite'] as bool? ?? false,
      'want_to_visit': data['want_to_visit'] as bool? ?? false,
    };
  }

  Future<void> updateSpotStatus(
    int spotId, {
    required bool visited,
    required bool favorite,
    required bool wantToVisit,
  }) async {
    final response = await _client.put(
      _uri('/spots/$spotId/status'),
      headers: _headers,
      body: jsonEncode({
        'visited': visited,
        'favorite': favorite,
        'want_to_visit': wantToVisit,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  Future<List<ItineraryItem>> fetchItinerary() async {
    final response = await _client.get(_uri('/itinerary'), headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => ItineraryItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<ItineraryItem> createItinerary({
    required String title,
    required String travelDate,
    required String notes,
    int? spotId,
  }) async {
    final response = await _client.post(
      _uri('/itinerary'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'travel_date': travelDate,
        'notes': notes,
        'spot_id': spotId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return ItineraryItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteItinerary(int itemId) async {
    final response = await _client.delete(
      _uri('/itinerary/$itemId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  Future<List<BudgetItem>> fetchBudget() async {
    final response = await _client.get(_uri('/budget'), headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => BudgetItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetItem> createBudget({
    required String label,
    required double amount,
    required String category,
  }) async {
    final response = await _client.post(
      _uri('/budget'),
      headers: _headers,
      body: jsonEncode({
        'label': label,
        'amount': amount,
        'category': category,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return BudgetItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteBudget(int itemId) async {
    final response = await _client.delete(
      _uri('/budget/$itemId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  Future<List<TravelBadge>> fetchBadges() async {
    final response = await _client.get(_uri('/me/badges'), headers: _headers);
    if (response.statusCode != 200) return const [];
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => TravelBadge.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<PostComment>> fetchComments(int postId) async {
    final response = await _client.get(
      _uri('/posts/$postId/comments'),
      headers: _headers,
    );
    if (response.statusCode != 200) return const [];
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => PostComment.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<PostComment> createComment(int postId, String body) async {
    final response = await _client.post(
      _uri('/posts/$postId/comments'),
      headers: _headers,
      body: jsonEncode({'body': body}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return PostComment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<int> toggleLike(int postId) async {
    final response = await _client.post(
      _uri('/posts/$postId/like'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(_readError(response), response.statusCode);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['like_count']
            as int? ??
        0;
  }

  Future<void> reportSpot({
    int? spotId,
    required String reason,
    required String details,
  }) async {
    final response = await _client.post(
      _uri('/reports'),
      headers: _headers,
      body: jsonEncode({
        'spot_id': spotId,
        'reason': reason,
        'details': details,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response), response.statusCode);
    }
  }

  Future<Map<String, dynamic>> fetchAdminAnalytics() async {
    final response = await _client.get(
      _uri('/admin/analytics'),
      headers: _headers,
    );
    if (response.statusCode != 200) return const {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _readError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? 'Request failed';
    } catch (_) {
      return 'Request failed';
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

const fallbackUser = AppUser(
  id: 0,
  fullName: 'Renejay Explorer',
  email: 'renejay@example.com',
  isAdmin: false,
);

const fallbackSpots = [
  TouristSpot(
    id: 1,
    name: 'El Nido',
    location: 'Palawan',
    description: 'Crystal lagoons and island hopping routes.',
    category: 'Beach',
    latitude: 11.1956,
    longitude: 119.4075,
    rating: 4.9,
  ),
  TouristSpot(
    id: 2,
    name: 'Mayon Volcano',
    location: 'Albay',
    description: 'Scenic trails and perfect cone views.',
    category: 'Mountain',
    latitude: 13.2572,
    longitude: 123.6859,
    rating: 4.8,
  ),
  TouristSpot(
    id: 3,
    name: 'Chocolate Hills',
    location: 'Bohol',
    description: 'Iconic Bohol landscape.',
    category: 'Nature',
    latitude: 9.8297,
    longitude: 124.1397,
    rating: 4.7,
  ),
  TouristSpot(
    id: 4,
    name: 'Intramuros',
    location: 'Manila',
    description: 'Historic walls and Spanish-era streets.',
    category: 'Heritage',
    latitude: 14.5896,
    longitude: 120.9747,
    rating: 4.6,
  ),
];

const fallbackPosts = [
  TravelPost(
    '🏝️ Palawan Paradise',
    'Beautiful white sand beaches!',
    authorName: 'Community',
  ),
  TravelPost(
    '🌋 Mayon Adventure',
    'The perfect cone volcano experience.',
    authorName: 'Community',
  ),
];

class TouristSpotFinderApp extends StatelessWidget {
  const TouristSpotFinderApp({this.api, super.key});

  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tourist Spot Finder PH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff00c6ff)),
      ),
      home: AuthGate(api: api ?? ApiClient()),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({required this.api, super.key});

  final ApiClient api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final api = widget.api;
  static const communityTabIndex = 3;
  bool isLoggedIn = false;
  AppUser? user;
  List<TouristSpot> spots = fallbackSpots;
  List<TravelPost> posts = fallbackPosts;
  String? apiStatus;
  Timer? communityRefreshTimer;
  bool isCommunityVisible = false;
  bool isRefreshingPosts = false;

  Future<void> completeAuth(AppUser signedInUser) async {
    setState(() {
      user = signedInUser;
      isLoggedIn = true;
      apiStatus = null;
    });
    await loadRemoteData();
  }

  @override
  void dispose() {
    communityRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadRemoteData() async {
    try {
      final results = await Future.wait([api.fetchSpots(), api.fetchPosts()]);
      if (!mounted) return;
      setState(() {
        spots = results[0] as List<TouristSpot>;
        posts = results[1] as List<TravelPost>;
        apiStatus = 'Connected to FastAPI backend';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        apiStatus = 'Offline preview mode';
      });
    }
  }

  Future<TravelPost> addPost(String body) async {
    try {
      final post = await api.createPost(body);
      setState(
        () => posts = [post, ...posts.where((item) => item.id != post.id)],
      );
      return post;
    } catch (_) {
      final post = TravelPost(
        '🌐 Traveler Update',
        body,
        authorName: user?.fullName ?? 'Traveler',
      );
      setState(() => posts = [post, ...posts]);
      return post;
    }
  }

  Future<void> refreshPosts() async {
    if (isRefreshingPosts) return;
    isRefreshingPosts = true;
    try {
      final nextPosts = await api.fetchPosts();
      if (!mounted) return;
      setState(() => posts = nextPosts);
    } catch (_) {
      // Keep the current list visible if the backend is temporarily unavailable.
    } finally {
      isRefreshingPosts = false;
    }
  }

  void handleTabChanged(int index) {
    final nextIsCommunityVisible = index == communityTabIndex;
    if (isCommunityVisible == nextIsCommunityVisible &&
        communityRefreshTimer != null) {
      return;
    }
    isCommunityVisible = nextIsCommunityVisible;
    communityRefreshTimer?.cancel();
    communityRefreshTimer = null;
    if (!isCommunityVisible) return;
    unawaited(refreshPosts());
    communityRefreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(refreshPosts()),
    );
  }

  Future<AppUser> updateUserName(String fullName) async {
    final updatedUser = await api.updateProfileName(fullName);
    setState(() => user = updatedUser);
    return updatedUser;
  }

  Future<void> refreshSpots({String q = '', String category = ''}) async {
    try {
      final nextSpots = await api.fetchSpots(q: q, category: category);
      if (!mounted) return;
      setState(() => spots = nextSpots);
    } catch (_) {}
  }

  Future<void> addSpot(TouristSpot spot) async {
    setState(() => spots = [...spots, spot]);
  }

  void logout() {
    api.token = null;
    communityRefreshTimer?.cancel();
    communityRefreshTimer = null;
    isCommunityVisible = false;
    setState(() {
      isLoggedIn = false;
      user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoggedIn) {
      return AppShell(
        onLogout: logout,
        user: user ?? fallbackUser,
        spots: spots,
        posts: posts,
        apiStatus: apiStatus,
        onAddPost: addPost,
        api: api,
        onRefreshSpots: refreshSpots,
        onSpotCreated: addSpot,
        onUpdateName: updateUserName,
        onTabChanged: handleTabChanged,
      );
    }

    return AuthScreen(api: api, onAuthenticated: completeAuth);
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.onLogout,
    required this.user,
    required this.spots,
    required this.posts,
    required this.onAddPost,
    required this.api,
    required this.onRefreshSpots,
    required this.onSpotCreated,
    required this.onUpdateName,
    required this.onTabChanged,
    this.apiStatus,
    super.key,
  });

  final VoidCallback onLogout;
  final AppUser user;
  final List<TouristSpot> spots;
  final List<TravelPost> posts;
  final Future<TravelPost> Function(String body) onAddPost;
  final ApiClient api;
  final Future<void> Function({String q, String category}) onRefreshSpots;
  final Future<void> Function(TouristSpot spot) onSpotCreated;
  final Future<AppUser> Function(String fullName) onUpdateName;
  final void Function(int index) onTabChanged;
  final String? apiStatus;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.onTabChanged(selectedIndex);
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onTabChanged(selectedIndex);
  }

  List<String> get navItems => [
    'Home',
    'Map',
    'Planner',
    'Community',
    'Profile',
    if (widget.user.isAdmin) 'Admin',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        spots: widget.spots,
        apiStatus: widget.apiStatus,
        onSearch: widget.onRefreshSpots,
      ),
      MapScreen(spots: widget.spots, api: widget.api),
      PlannerScreen(spots: widget.spots, api: widget.api),
      CommunityScreen(
        posts: widget.posts,
        api: widget.api,
        onAddPost: widget.onAddPost,
      ),
      ProfileScreen(
        user: widget.user,
        postsCount: widget.posts.length,
        spots: widget.spots,
        posts: widget.posts,
        onUpdateName: widget.onUpdateName,
      ),
      if (widget.user.isAdmin)
        AdminScreen(api: widget.api, onSpotCreated: widget.onSpotCreated),
    ];
    final safeIndex = selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PhilippinesScenicBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                GlassNavbar(
                  selectedIndex: selectedIndex,
                  items: navItems,
                  onSelected: (index) {
                    setState(() => selectedIndex = index);
                    widget.onTabChanged(index);
                  },
                  onLogout: widget.onLogout,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0, .025),
                        end: Offset.zero,
                      ).animate(animation);

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(safeIndex),
                      child: pages[safeIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PhilippinesScenicBackground extends StatelessWidget {
  const PhilippinesScenicBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff163a4c), Color(0xff103828), Color(0xff182846)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Image.asset(
          'assets/images/philippines_map_background.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          opacity: const AlwaysStoppedAnimation(.58),
        ),
        Container(color: const Color(0xff06141f).withValues(alpha: .58)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xbf06141f), Color(0x9906141f), Color(0xd906141f)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

class GlassNavbar extends StatelessWidget {
  const GlassNavbar({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    required this.onLogout,
    super.key,
  });

  final int selectedIndex;
  final List<String> items;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 18 : 34,
            vertical: isCompact ? 12 : 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xff07121c).withValues(alpha: .42),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .10)),
            ),
          ),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: BrandTitle()),
                        LogoutButton(onLogout: onLogout, iconOnly: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    NavLinks(
                      items: items,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                      compact: true,
                    ),
                  ],
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1282),
                    child: Row(
                      children: [
                        const BrandTitle(),
                        const Spacer(),
                        NavLinks(
                          items: items,
                          selectedIndex: selectedIndex,
                          onSelected: onSelected,
                        ),
                        const SizedBox(width: 14),
                        LogoutButton(onLogout: onLogout),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.onAuthenticated,
    super.key,
  });

  final ApiClient api;
  final Future<void> Function(AppUser user) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final otpController = TextEditingController();
  bool isRegistering = false;
  bool isVerifying = false;
  bool isResetting = false;
  String? errorText;
  String? successText;
  bool isSubmitting = false;
  bool showPassword = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? googleAuthSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeGoogleSignIn());
  }

  Future<void> _initializeGoogleSignIn() async {
    if (ApiConfig.googleClientId.isEmpty) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: ApiConfig.googleClientId,
        serverClientId: ApiConfig.googleClientId,
      );
      googleAuthSubscription =
          GoogleSignIn.instance.authenticationEvents.listen(
            _handleGoogleAuthEvent,
          )..onError(_handleGoogleAuthError);
    } catch (_) {
      if (mounted) {
        setState(() => errorText = 'Google Sign-In is not configured yet.');
      }
    }
  }

  @override
  void dispose() {
    googleAuthSubscription?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    if (ApiConfig.googleClientId.isEmpty) {
      setState(
        () => errorText = 'Add GOOGLE_CLIENT_ID before using Google Sign-In.',
      );
      return;
    }
    setState(() {
      isSubmitting = true;
      errorText = null;
      successText = null;
    });
    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        final account = await GoogleSignIn.instance.authenticate();
        await _finishGoogleLogin(account);
      } else if (!kIsWeb) {
        setState(
          () =>
              errorText = 'Google Sign-In is not available on this device yet.',
        );
      }
    } on GoogleSignInException catch (error) {
      setState(() {
        errorText = error.code == GoogleSignInExceptionCode.canceled
            ? 'Google Sign-In was cancelled.'
            : 'Google Sign-In failed.';
      });
    } catch (_) {
      setState(() => errorText = 'Google Sign-In failed.');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _handleGoogleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      await _finishGoogleLogin(event.user);
    }
  }

  void _handleGoogleAuthError(Object error) {
    if (mounted) {
      setState(() {
        isSubmitting = false;
        errorText = 'Google Sign-In failed.';
      });
    }
  }

  Future<void> _finishGoogleLogin(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() => errorText = 'Google did not return a sign-in token.');
      return;
    }
    try {
      final signedInUser = await widget.api.loginWithGoogle(idToken);
      await widget.onAuthenticated(signedInUser);
    } on ApiException catch (error) {
      setState(() => errorText = error.message);
    } catch (_) {
      setState(() => errorText = 'Cannot connect to the backend.');
    }
  }

  Future<void> submit() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (isRegistering && name.isEmpty) {
      setState(() => errorText = 'Enter your full name.');
      return;
    }

    if (!email.contains('@') || password.length < 6) {
      setState(
        () => errorText = 'Use a valid email and 6+ character password.',
      );
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
    });

    try {
      if (isRegistering) {
        final requiresVerification = await widget.api.register(
          fullName: name,
          email: email,
          password: password,
        );
        if (!mounted) return;
        if (!requiresVerification) {
          final signedInUser = await widget.api.login(
            email: email,
            password: password,
          );
          await widget.onAuthenticated(signedInUser);
          return;
        }
        setState(() {
          isRegistering = false;
          isVerifying = true;
          successText = 'OTP sent to $email. Check your email.';
          passwordController.clear();
        });
        return;
      }

      final signedInUser = await widget.api.login(
        email: email,
        password: password,
      );
      await widget.onAuthenticated(signedInUser);
    } on ApiException catch (error) {
      setState(() {
        errorText = error.message;
        if (error.statusCode == 403) {
          isVerifying = true;
          successText =
              'Enter the OTP sent to your email, or resend a new one.';
        }
      });
    } catch (_) {
      setState(
        () => errorText =
            'Cannot connect to the backend. Please start FastAPI and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> verifyOtp() async {
    final email = emailController.text.trim();
    final code = otpController.text.trim();

    if (!email.contains('@') || code.length != 6) {
      setState(() => errorText = 'Enter your email and 6-digit OTP.');
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
      successText = null;
    });

    try {
      final signedInUser = await widget.api.verifyEmail(
        email: email,
        code: code,
      );
      await widget.onAuthenticated(signedInUser);
    } on ApiException catch (error) {
      setState(() => errorText = error.message);
    } catch (_) {
      setState(
        () => errorText =
            'Cannot connect to the backend. Please start FastAPI and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> requestPasswordReset() async {
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => errorText = 'Enter your email address first.');
      return;
    }
    setState(() {
      isSubmitting = true;
      errorText = null;
      successText = null;
    });
    try {
      await widget.api.forgotPassword(email);
      setState(() {
        isResetting = true;
        successText = 'Password reset OTP sent to $email.';
      });
    } on ApiException catch (error) {
      setState(() => errorText = error.message);
    } catch (_) {
      setState(() => errorText = 'Cannot connect to the backend.');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final code = otpController.text.trim();
    final password = passwordController.text.trim();
    if (!email.contains('@') || code.length != 6 || password.length < 6) {
      setState(() => errorText = 'Enter email, 6-digit OTP, and new password.');
      return;
    }
    setState(() {
      isSubmitting = true;
      errorText = null;
      successText = null;
    });
    try {
      await widget.api.resetPassword(
        email: email,
        code: code,
        newPassword: password,
      );
      setState(() {
        isResetting = false;
        successText = 'Password updated. You can login now.';
        otpController.clear();
        passwordController.clear();
      });
    } on ApiException catch (error) {
      setState(() => errorText = error.message);
    } catch (_) {
      setState(() => errorText = 'Cannot connect to the backend.');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> resendOtp() async {
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => errorText = 'Enter your email address first.');
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
      successText = null;
    });

    try {
      await widget.api.resendVerification(email: email);
      setState(() => successText = 'New OTP sent to $email.');
    } on ApiException catch (error) {
      setState(() => errorText = error.message);
    } catch (_) {
      setState(
        () => errorText =
            'Cannot connect to the backend. Please start FastAPI and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void toggleMode() {
    setState(() {
      isRegistering = !isRegistering;
      isVerifying = false;
      isResetting = false;
      showPassword = false;
      errorText = null;
      successText = null;
      otpController.clear();
      passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PhilippinesScenicBackground(),
          Container(color: Colors.black.withValues(alpha: .18)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const BrandTitle(),
                      SizedBox(height: width < 720 ? 34 : 58),
                      GlassBox(
                        borderRadius: 25,
                        blur: 12,
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                isVerifying
                                    ? 'Verify Email'
                                    : isResetting
                                    ? 'Reset Password'
                                    : isRegistering
                                    ? 'Create Account'
                                    : 'Login',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isVerifying
                                    ? 'Enter the OTP we sent to your email.'
                                    : isResetting
                                    ? 'Enter your reset OTP and new password.'
                                    : isRegistering
                                    ? 'Register before exploring destinations.'
                                    : 'Sign in to continue your travel map.',
                                textAlign: TextAlign.center,
                                style: GlassTextStyles.body,
                              ),
                              const SizedBox(height: 24),
                              if (isRegistering && !isVerifying) ...[
                                AuthTextField(
                                  controller: nameController,
                                  hintText: 'Full name',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 12),
                              ],
                              AuthTextField(
                                controller: emailController,
                                hintText: 'Email address',
                                icon: Icons.email_outlined,
                              ),
                              if (isVerifying || isResetting) ...[
                                const SizedBox(height: 12),
                                AuthTextField(
                                  controller: otpController,
                                  hintText: '6-digit OTP',
                                  icon: Icons.verified_user_outlined,
                                ),
                              ],
                              if (!isVerifying) ...[
                                const SizedBox(height: 12),
                                AuthTextField(
                                  controller: passwordController,
                                  hintText: isResetting
                                      ? 'New password'
                                      : 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: !showPassword,
                                  suffixIcon: IconButton(
                                    tooltip: showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    onPressed: () {
                                      setState(
                                        () => showPassword = !showPassword,
                                      );
                                    },
                                    icon: Icon(
                                      showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                              ],
                              if (successText != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  successText!,
                                  style: const TextStyle(
                                    color: Color(0xffb8fff4),
                                  ),
                                ),
                              ],
                              if (errorText != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: Color(0xffffd1d1),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              GradientButton(
                                label: isSubmitting
                                    ? 'Please wait...'
                                    : isVerifying
                                    ? 'Verify OTP'
                                    : isResetting
                                    ? 'Reset Password'
                                    : isRegistering
                                    ? 'Register'
                                    : 'Login',
                                onPressed: isVerifying
                                    ? verifyOtp
                                    : isResetting
                                    ? resetPassword
                                    : submit,
                              ),
                              if (!isVerifying && !isResetting) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withValues(
                                          alpha: .28,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'or',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: .76,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withValues(
                                          alpha: .28,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (kIsWeb &&
                                    ApiConfig.googleClientId.isNotEmpty &&
                                    !GoogleSignIn.instance
                                        .supportsAuthenticate())
                                  Center(child: renderGoogleWebButton())
                                else
                                  OutlinedButton.icon(
                                    onPressed: isSubmitting
                                        ? null
                                        : signInWithGoogle,
                                    icon: const Icon(
                                      Icons.g_mobiledata,
                                      size: 28,
                                    ),
                                    label: const Text('Continue with Google'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: .38,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 14),
                              if (isVerifying)
                                TextButton(
                                  onPressed: resendOtp,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xff00ffd5),
                                  ),
                                  child: const Text('Resend OTP'),
                                ),
                              TextButton(
                                onPressed: toggleMode,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xff00ffd5),
                                ),
                                child: Text(
                                  isVerifying || isResetting
                                      ? 'Back to Login'
                                      : isRegistering
                                      ? 'Already have an account? Login'
                                      : 'No account yet? Register',
                                ),
                              ),
                              if (!isRegistering &&
                                  !isVerifying &&
                                  !isResetting)
                                TextButton(
                                  onPressed: requestPasswordReset,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xffb8fff4),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({
    required this.onLogout,
    this.iconOnly = false,
    super.key,
  });

  final VoidCallback onLogout;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onLogout,
      icon: const Icon(Icons.logout, size: 18),
      label: iconOnly ? const SizedBox.shrink() : const Text('Logout'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: iconOnly ? 8 : 12,
          vertical: 10,
        ),
        minimumSize: iconOnly ? const Size(42, 42) : null,
        textStyle: const TextStyle(fontSize: 16, letterSpacing: 0),
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇵🇭', style: TextStyle(fontSize: 25)),
          SizedBox(width: 8),
          Text(
            'Tourist Spot Finder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class NavLinks extends StatelessWidget {
  const NavLinks({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
    super.key,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? Colors.white.withValues(alpha: .15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: i == selectedIndex
                        ? const Color(0xff5eead4).withValues(alpha: .55)
                        : Colors.transparent,
                  ),
                ),
                child: TextButton(
                  onPressed: () => onSelected(i),
                  style: TextButton.styleFrom(
                    foregroundColor: i == selectedIndex
                        ? const Color(0xff5eead4)
                        : Colors.white.withValues(alpha: .86),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 14,
                      vertical: 10,
                    ),
                    textStyle: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: i == selectedIndex
                          ? FontWeight.w800
                          : FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  child: Text(items[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PageScroll extends StatelessWidget {
  const PageScroll({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 35,
        compact ? 20 : 35,
        compact ? 18 : 35,
        compact ? 96 : 52,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1282),
          child: child,
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.spots,
    required this.onSearch,
    this.apiStatus,
    super.key,
  });

  final List<TouristSpot> spots;
  final Future<void> Function({String q, String category}) onSearch;
  final String? apiStatus;

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      child: Column(
        children: [
          HeroPanel(apiStatus: apiStatus),
          const SizedBox(height: 30),
          SpotSearchPanel(onSearch: onSearch),
          const SizedBox(height: 30),
          const ResponsiveGlassGrid(
            minTileWidth: 260,
            children: [
              GlassFeatureCard(
                emoji: '📍',
                title: 'Pin Locations',
                body: 'Mark visited and dream destinations.',
              ),
              GlassFeatureCard(
                emoji: '📸',
                title: 'Upload Photos',
                body: 'Upload multiple travel pictures instantly.',
              ),
              GlassFeatureCard(
                emoji: '⭐',
                title: 'Ratings',
                body: 'Rate tourist spots and share experiences.',
              ),
              GlassFeatureCard(
                emoji: '🧭',
                title: 'Trip Tools',
                body: 'Plan trips, budget costs, and find nearby spots.',
              ),
            ],
          ),
          const SizedBox(height: 30),
          PopularSpotsPanel(spots: spots),
        ],
      ),
    );
  }
}

class SpotSearchPanel extends StatefulWidget {
  const SpotSearchPanel({required this.onSearch, super.key});

  final Future<void> Function({String q, String category}) onSearch;

  @override
  State<SpotSearchPanel> createState() => _SpotSearchPanelState();
}

class _SpotSearchPanelState extends State<SpotSearchPanel> {
  final searchController = TextEditingController();
  String category = '';
  bool isSearching = false;
  String? statusText;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> runSearch() async {
    setState(() {
      isSearching = true;
      statusText = null;
    });
    await widget.onSearch(q: searchController.text.trim(), category: category);
    if (!mounted) return;
    setState(() {
      isSearching = false;
      final term = searchController.text.trim();
      statusText = term.isEmpty && category.isEmpty
          ? 'Showing all tourist spots'
          : 'Search updated';
    });
  }

  Future<void> clearSearch() async {
    searchController.clear();
    setState(() {
      category = '';
      statusText = 'Showing all tourist spots';
    });
    await widget.onSearch(q: '', category: '');
  }

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: searchController,
              hintText: 'Search tourist spot or location',
              icon: Icons.search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => runSearch(),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: isSearching ? null : clearSearch,
                      icon: const Icon(Icons.close),
                    ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final categoryField = DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: const Color(0xff102033),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All categories')),
                    DropdownMenuItem(value: 'Beach', child: Text('Beach')),
                    DropdownMenuItem(
                      value: 'Mountain',
                      child: Text('Mountain'),
                    ),
                    DropdownMenuItem(value: 'Nature', child: Text('Nature')),
                    DropdownMenuItem(
                      value: 'Heritage',
                      child: Text('Heritage'),
                    ),
                  ],
                  onChanged: isSearching
                      ? null
                      : (value) => setState(() => category = value ?? ''),
                );
                final searchButton = GradientButton(
                  label: isSearching ? 'Searching...' : 'Search',
                  icon: Icons.tune,
                  onPressed: isSearching ? null : runSearch,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      categoryField,
                      const SizedBox(height: 12),
                      searchButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 12),
                    searchButton,
                  ],
                );
              },
            ),
            if (statusText != null) ...[
              const SizedBox(height: 10),
              Text(statusText!, style: GlassTextStyles.bodyMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({this.apiStatus, super.key});

  final String? apiStatus;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final textSection = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xff5eead4).withValues(alpha: .15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xff5eead4).withValues(alpha: .35),
            ),
          ),
          child: const Text(
            'Philippines travel companion',
            style: TextStyle(
              color: Color(0xffb8fff4),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Explore The Philippines',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 39 : 58,
            height: .98,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Discover beaches, mountains, food stops, and community stories across the islands.',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .88),
            fontSize: compact ? 17 : 20,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 22),
        GradientButton(
          label: 'Start Exploring',
          icon: Icons.explore_outlined,
          onPressed: () {},
        ),
        if (apiStatus != null) ...[
          const SizedBox(height: 12),
          Text(apiStatus!, style: GlassTextStyles.bodyMuted),
        ],
      ],
    );

    return GlassBox(
      borderRadius: 25,
      blur: 10,
      child: SizedBox(
        width: double.infinity,
        height: compact ? 540 : 390,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: PhilippinesMapPainter(opacity: .18)),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 24 : 34),
              child: compact
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        textSection,
                        const SizedBox(height: 22),
                        const DestinationStack(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 7, child: textSection),
                        const SizedBox(width: 34),
                        const Expanded(flex: 5, child: DestinationStack()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DestinationStack extends StatelessWidget {
  const DestinationStack({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;

    return SizedBox(
      height: compact ? 160 : 260,
      child: Stack(
        children: [
          Positioned(
            left: compact ? 0 : 14,
            right: compact ? 0 : 42,
            top: compact ? 0 : 12,
            child: DestinationTile(
              icon: '🏝️',
              title: 'El Nido',
              subtitle: 'Island hopping',
              accent: const Color(0xff14b8a6),
            ),
          ),
          Positioned(
            left: compact ? 18 : 70,
            right: compact ? 18 : 0,
            top: compact ? 72 : 106,
            child: DestinationTile(
              icon: '🌋',
              title: 'Mayon',
              subtitle: 'Volcano views',
              accent: const Color(0xffffd166),
            ),
          ),
          if (!compact)
            const Positioned(
              left: 0,
              right: 90,
              bottom: 0,
              child: DestinationTile(
                icon: '🏞️',
                title: 'Bohol',
                subtitle: 'Chocolate Hills',
                accent: Color(0xff60a5fa),
              ),
            ),
        ],
      ),
    );
  }
}

class DestinationTile extends StatelessWidget {
  const DestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    super.key,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: 20,
      blur: 16,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: GlassTextStyles.cardTitleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: GlassTextStyles.bodyMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopularSpotsPanel extends StatelessWidget {
  const PopularSpotsPanel({required this.spots, super.key});

  final List<TouristSpot> spots;

  @override
  Widget build(BuildContext context) {
    final visibleSpots = [...spots]
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return GlassBox(
      borderRadius: 22,
      blur: 14,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Popular Tourist Spots',
              style: GlassTextStyles.cardTitle,
            ),
            const SizedBox(height: 16),
            if (visibleSpots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No tourist spots found. Try another location or category.',
                  style: GlassTextStyles.bodyMuted,
                ),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final spot in visibleSpots)
                    SizedBox(
                      width: 280,
                      child: DestinationTile(
                        icon: spot.category == 'Beach'
                            ? '🏝️'
                            : spot.category == 'Mountain'
                            ? '🌋'
                            : spot.category == 'Heritage'
                            ? '🏛️'
                            : '🏞️',
                        title: spot.name,
                        subtitle:
                            '${spot.location} • ${spot.rating.toStringAsFixed(1)}',
                        accent: const Color(0xff5eead4),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({required this.spots, required this.api, super.key});

  final List<TouristSpot> spots;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      child: Column(
        children: [
          const GlassSectionTitle(title: 'Interactive Map'),
          const SizedBox(height: 18),
          MapPreview(spots: spots),
          const SizedBox(height: 30),
          SpotDetailPanel(spots: spots, api: api),
          const SizedBox(height: 30),
          const ResponsiveGlassGrid(
            minTileWidth: 260,
            children: [
              GlassFeatureCard(
                emoji: '📌',
                title: 'Visited',
                body: '42 places saved.',
              ),
              GlassFeatureCard(
                emoji: '❤️',
                title: 'Favorites',
                body: '18 top picks.',
              ),
              GlassFeatureCard(
                emoji: '🧭',
                title: 'Want To Visit',
                body: '27 future trips.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MapPreview extends StatelessWidget {
  const MapPreview({required this.spots, super.key});

  final List<TouristSpot> spots;

  @override
  Widget build(BuildContext context) {
    final pins = spots.isEmpty ? fallbackSpots : spots;

    return GlassBox(
      borderRadius: 20,
      blur: 10,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).width < 720 ? 420 : 390,
        width: double.infinity,
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(12.8797, 121.7740),
            initialZoom: 5.2,
            minZoom: 4,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'tourist_spot_finder_ph_smooth',
            ),
            MarkerLayer(
              markers: [
                for (final spot in pins)
                  Marker(
                    point: LatLng(spot.latitude, spot.longitude),
                    width: 140,
                    height: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: Color(0xffffd166),
                          size: 30,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xff07121c,
                            ).withValues(alpha: .72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
            Positioned(
              left: 18,
              top: 18,
              child: GlassBox(
                borderRadius: 18,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Live Map • ${pins.length} spots',
                    style: GlassTextStyles.cardTitleSmall,
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

class MapPinMarker extends StatelessWidget {
  const MapPinMarker({required this.spot, super.key});

  final TouristSpot spot;

  @override
  Widget build(BuildContext context) {
    final alignment = _alignmentFor(spot);

    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_pin, color: Color(0xffffd166), size: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xff07121c).withValues(alpha: .62),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Text(
              spot.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Alignment _alignmentFor(TouristSpot spot) {
    final longitude = spot.longitude.clamp(116.0, 127.0);
    final latitude = spot.latitude.clamp(5.0, 19.0);
    final x = ((longitude - 116.0) / 11.0) * 1.5 - .75;
    final y = ((19.0 - latitude) / 14.0) * 1.55 - .78;
    return Alignment(x.clamp(-.88, .88), y.clamp(-.82, .82));
  }
}

class SpotDetailPanel extends StatefulWidget {
  const SpotDetailPanel({required this.spots, required this.api, super.key});

  final List<TouristSpot> spots;
  final ApiClient api;

  @override
  State<SpotDetailPanel> createState() => _SpotDetailPanelState();
}

class _SpotDetailPanelState extends State<SpotDetailPanel> {
  TouristSpot? selectedSpot;
  final reviewController = TextEditingController();
  final captionController = TextEditingController();
  final reportController = TextEditingController();
  int rating = 5;
  bool visited = false;
  bool favorite = false;
  bool wantToVisit = false;
  List<SpotReview> reviews = [];
  List<SpotPhoto> photos = [];
  List<SelectedPhoto> selectedPhotos = [];
  String? message;
  bool isLoadingSpot = false;
  bool isUploadingPhoto = false;

  @override
  void dispose() {
    reviewController.dispose();
    captionController.dispose();
    reportController.dispose();
    super.dispose();
  }

  Future<void> selectSpot(TouristSpot spot) async {
    setState(() {
      selectedSpot = spot;
      message = null;
      isLoadingSpot = true;
    });
    try {
      final nextReviews = await widget.api.fetchReviews(spot.id);
      final nextPhotos = await widget.api.fetchPhotos(spot.id);
      final status = await widget.api.getSpotStatus(spot.id);
      if (!mounted) return;
      setState(() {
        reviews = nextReviews;
        photos = nextPhotos;
        visited = status['visited'] ?? false;
        favorite = status['favorite'] ?? false;
        wantToVisit = status['want_to_visit'] ?? false;
        isLoadingSpot = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingSpot = false;
        message = 'Could not load latest reviews and photos.';
      });
    }
  }

  Future<void> saveStatus() async {
    final spot = selectedSpot;
    if (spot == null) return;
    try {
      await widget.api.updateSpotStatus(
        spot.id,
        visited: visited,
        favorite: favorite,
        wantToVisit: wantToVisit,
      );
      setState(() => message = 'Saved to your travel list.');
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> openDirections(TouristSpot spot) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${spot.latitude},${spot.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> submitReport() async {
    final spot = selectedSpot;
    if (spot == null) return;
    final details = reportController.text.trim();
    if (details.isEmpty) {
      setState(() => message = 'Write report details first.');
      return;
    }
    try {
      await widget.api.reportSpot(
        spotId: spot.id,
        reason: 'User report',
        details: details,
      );
      setState(() {
        reportController.clear();
        message = 'Report submitted. Thank you.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> addReview() async {
    final spot = selectedSpot;
    if (spot == null) return;
    final comment = reviewController.text.trim();
    if (comment.isEmpty) {
      setState(() => message = 'Write a short review first.');
      return;
    }
    try {
      final review = await widget.api.createReview(spot.id, rating, comment);
      setState(() {
        reviews = [review, ...reviews];
        reviewController.clear();
        message = 'Review saved.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> pickPhotos() async {
    final spot = selectedSpot;
    if (spot == null) return;
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 58,
        maxWidth: 760,
      );
      if (picked.isEmpty) {
        return;
      }
      final next = <SelectedPhoto>[];
      for (final image in picked.take(20)) {
        final bytes = await image.readAsBytes();
        final extension = image.name.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpeg';
        next.add(
          SelectedPhoto(
            file: image,
            previewDataUrl:
                'data:image/$extension;base64,${base64Encode(bytes)}',
          ),
        );
      }
      setState(() {
        selectedPhotos = next;
        message =
            '${next.length} photo${next.length == 1 ? '' : 's'} ready to upload.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> uploadSelectedPhotos() async {
    final spot = selectedSpot;
    if (spot == null) return;
    if (selectedPhotos.isEmpty) {
      setState(() => message = 'Choose photos first.');
      return;
    }
    setState(() => isUploadingPhoto = true);
    final caption = captionController.text.trim();
    try {
      final uploaded = <SpotPhoto>[];
      for (final photo in selectedPhotos) {
        uploaded.add(
          await widget.api.uploadPhotoFile(spot.id, photo.file, caption),
        );
      }
      await widget.api.createPost(
        caption.isEmpty
            ? 'Shared ${uploaded.length} photo${uploaded.length == 1 ? '' : 's'} from ${spot.name}.'
            : caption,
        title: '${spot.name} travel photos',
        spotName: spot.name,
        photoUrls: uploaded.map((photo) => photo.imageUrl).toList(),
      );
      setState(() {
        photos = [...uploaded.reversed, ...photos];
        selectedPhotos = [];
        captionController.clear();
        message = 'Photos uploaded and shared to Community.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => isUploadingPhoto = false);
    }
  }

  void removeSelectedPhoto(int index) {
    setState(() {
      selectedPhotos = [
        ...selectedPhotos.take(index),
        ...selectedPhotos.skip(index + 1),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final spots = widget.spots.isEmpty ? fallbackSpots : widget.spots;
    final spot = selectedSpot ?? spots.first;

    if (selectedSpot == null && spots.isNotEmpty) {
      Future.microtask(() => selectSpot(spot));
    }

    return GlassBox(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spot Reviews & Photos',
              style: GlassTextStyles.cardTitle,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: spot.id,
              dropdownColor: const Color(0xff102033),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Choose tourist spot',
                labelStyle: GlassTextStyles.bodyMuted,
                filled: true,
                fillColor: Colors.white.withValues(alpha: .10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                for (final item in spots)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (id) {
                TouristSpot? next;
                for (final item in spots) {
                  if (item.id == id) {
                    next = item;
                    break;
                  }
                }
                if (next != null) selectSpot(next);
              },
            ),
            if (isLoadingSpot) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 18),
            Text(
              '${spot.name} • ${spot.location}',
              style: GlassTextStyles.cardTitleSmall,
            ),
            Text(spot.description, style: GlassTextStyles.bodyMuted),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 250,
                  child: DestinationTile(
                    icon: '🎟️',
                    title: 'Entrance',
                    subtitle: spot.entranceFee,
                    accent: const Color(0xff60a5fa),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: DestinationTile(
                    icon: '🕘',
                    title: 'Hours',
                    subtitle: spot.openingHours,
                    accent: const Color(0xff5eead4),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: DestinationTile(
                    icon: '☁️',
                    title: 'Weather',
                    subtitle: spot.weatherNote,
                    accent: const Color(0xffffd166),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Transport: ${spot.transportGuide}',
              style: GlassTextStyles.bodyMuted,
            ),
            Text(
              'Emergency: ${spot.emergencyInfo}',
              style: GlassTextStyles.bodyMuted,
            ),
            const SizedBox(height: 14),
            const Text('My Travel List', style: GlassTextStyles.cardTitleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: const Text('Favorite'),
                  selected: favorite,
                  onSelected: (value) => setState(() => favorite = value),
                ),
                FilterChip(
                  label: const Text('Visited'),
                  selected: visited,
                  onSelected: (value) => setState(() => visited = value),
                ),
                FilterChip(
                  label: const Text('Wishlist'),
                  selected: wantToVisit,
                  onSelected: (value) => setState(() => wantToVisit = value),
                ),
                GradientButton(label: 'Save List', onPressed: saveStatus),
                GradientButton(
                  label: 'Directions',
                  icon: Icons.directions_outlined,
                  onPressed: () => openDirections(spot),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Rate This Spot', style: GlassTextStyles.cardTitleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    initialValue: rating,
                    items: [1, 2, 3, 4, 5]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value ⭐'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => rating = value ?? 5),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: AuthTextField(
                    controller: reviewController,
                    hintText: 'Write a review',
                    icon: Icons.rate_review_outlined,
                  ),
                ),
                GradientButton(label: 'Save Review', onPressed: addReview),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Add Photos', style: GlassTextStyles.cardTitleSmall),
            const SizedBox(height: 4),
            Text(
              'You can select multiple photos (up to 20)',
              style: GlassTextStyles.bodyMuted,
            ),
            const SizedBox(height: 12),
            PhotoUploadWorkspace(
              selectedPhotos: selectedPhotos,
              captionController: captionController,
              isUploading: isUploadingPhoto,
              onPickPhotos: pickPhotos,
              onRemovePhoto: removeSelectedPhoto,
              onUpload: uploadSelectedPhotos,
            ),
            const SizedBox(height: 12),
            const Text(
              'Report a Problem',
              style: GlassTextStyles.cardTitleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 360,
                  child: AuthTextField(
                    controller: reportController,
                    hintText: 'Report wrong info or unsafe content',
                    icon: Icons.flag_outlined,
                  ),
                ),
                GradientButton(label: 'Submit Report', onPressed: submitReport),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(message!, style: GlassTextStyles.bodyMuted),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final review in reviews.take(4))
                  SizedBox(
                    width: 260,
                    child: GlassPostCard(
                      post: TravelPost(
                        '${review.rating} ⭐ by ${review.authorName}',
                        review.comment.isEmpty ? 'No comment.' : review.comment,
                      ),
                    ),
                  ),
                for (final photo in photos.take(4))
                  SizedBox(width: 220, child: SpotPhotoPreview(photo: photo)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SpotPhotoPreview extends StatelessWidget {
  const SpotPhotoPreview({required this.photo, super.key});

  final SpotPhoto photo;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (photo.imageUrl.startsWith('data:image/')) {
      final commaIndex = photo.imageUrl.indexOf(',');
      final payload = commaIndex >= 0
          ? photo.imageUrl.substring(commaIndex + 1)
          : '';
      try {
        image = Image.memory(
          base64Decode(payload),
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {
        image = _PhotoFallback(caption: photo.caption);
      }
    } else {
      image = Image.network(
        mediaUrl(photo.imageUrl),
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _PhotoFallback(caption: photo.caption),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          image,
          if (photo.caption.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.black.withValues(alpha: .48),
              child: Text(photo.caption, style: GlassTextStyles.body),
            ),
        ],
      ),
    );
  }
}

class SelectedPhoto {
  const SelectedPhoto({required this.file, required this.previewDataUrl});

  final XFile file;
  final String previewDataUrl;
}

class PhotoUploadWorkspace extends StatelessWidget {
  const PhotoUploadWorkspace({
    required this.selectedPhotos,
    required this.captionController,
    required this.isUploading,
    required this.onPickPhotos,
    required this.onRemovePhoto,
    required this.onUpload,
    super.key,
  });

  final List<SelectedPhoto> selectedPhotos;
  final TextEditingController captionController;
  final bool isUploading;
  final VoidCallback onPickPhotos;
  final void Function(int index) onRemovePhoto;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final previewCount = selectedPhotos.length.clamp(0, 4);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final picker = InkWell(
          onTap: isUploading ? null : onPickPhotos,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: compact ? double.infinity : 330,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: .45),
                style: BorderStyle.solid,
              ),
              color: Colors.white.withValues(alpha: .08),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xff3b82f6),
                  size: 44,
                ),
                const SizedBox(height: 10),
                Text(
                  selectedPhotos.isEmpty
                      ? 'Choose Photos'
                      : '${selectedPhotos.length} selected',
                  style: const TextStyle(
                    color: Color(0xff60a5fa),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'JPG, PNG, WEBP up to 10MB each',
                  style: GlassTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
        );

        final previews = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < previewCount; index++)
              SelectedPhotoTile(
                dataUrl: selectedPhotos[index].previewDataUrl,
                onRemove: () => onRemovePhoto(index),
              ),
            if (selectedPhotos.length > 4)
              Container(
                width: compact ? double.infinity : 220,
                height: 126,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .16),
                  ),
                ),
                child: Text(
                  '+${selectedPhotos.length - 4}\nmore',
                  textAlign: TextAlign.center,
                  style: GlassTextStyles.cardTitle,
                ),
              ),
          ],
        );

        final captionField = AuthTextField(
          controller: captionController,
          hintText: 'Write a caption (optional)',
          icon: Icons.closed_caption_outlined,
        );
        final uploadButton = SizedBox(
          width: compact ? double.infinity : 230,
          child: GradientButton(
            label: isUploading ? 'Uploading...' : 'Upload Photos',
            icon: Icons.cloud_upload_outlined,
            onPressed: isUploading ? null : onUpload,
          ),
        );
        final actions = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  captionField,
                  const SizedBox(height: 12),
                  uploadButton,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: captionField),
                  const SizedBox(width: 18),
                  uploadButton,
                ],
              );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              picker,
              if (selectedPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                previews,
              ],
              const SizedBox(height: 14),
              actions,
            ],
          );
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                picker,
                if (selectedPhotos.isNotEmpty) ...[
                  const SizedBox(width: 36),
                  Expanded(child: previews),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.only(left: selectedPhotos.isEmpty ? 0 : 396),
              child: actions,
            ),
          ],
        );
      },
    );
  }
}

class SelectedPhotoTile extends StatelessWidget {
  const SelectedPhotoTile({
    required this.dataUrl,
    required this.onRemove,
    super.key,
  });

  final String dataUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final commaIndex = dataUrl.indexOf(',');
    final payload = commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : '';
    Widget image;
    try {
      image = Image.memory(
        base64Decode(payload),
        width: double.infinity,
        height: 126,
        fit: BoxFit.cover,
      );
    } catch (_) {
      image = const _PhotoFallback(caption: 'Preview unavailable');
    }

    return SizedBox(
      width: 220,
      height: 126,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filled(
                tooltip: 'Remove photo',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .55),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: Colors.white.withValues(alpha: .12),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        caption.isEmpty ? 'Photo preview unavailable' : caption,
        style: GlassTextStyles.bodyMuted,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({required this.spots, required this.api, super.key});

  final List<TouristSpot> spots;
  final ApiClient api;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final notesController = TextEditingController();
  final budgetLabelController = TextEditingController();
  final budgetAmountController = TextEditingController();
  String budgetCategory = 'Food';
  List<ItineraryItem> itinerary = [];
  List<BudgetItem> budget = [];
  List<TravelBadge> badges = [];
  List<TouristSpot> nearbySpots = [];
  String? message;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    loadPlanner();
    loadOfflineSaved();
  }

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    notesController.dispose();
    budgetLabelController.dispose();
    budgetAmountController.dispose();
    super.dispose();
  }

  Future<void> loadPlanner() async {
    try {
      final nextItinerary = await widget.api.fetchItinerary();
      final nextBudget = await widget.api.fetchBudget();
      final nextBadges = await widget.api.fetchBadges();
      if (!mounted) return;
      setState(() {
        itinerary = nextItinerary;
        budget = nextBudget;
        badges = nextBadges;
      });
    } catch (_) {}
  }

  Future<void> findNearbySpots() async {
    setState(() {
      locating = true;
      message = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(
          () => message = 'Location permission is needed for nearby spots.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final distance = const Distance();
      final sorted = [...widget.spots]
        ..sort((a, b) {
          final aKm = distance.as(
            LengthUnit.Kilometer,
            LatLng(position.latitude, position.longitude),
            LatLng(a.latitude, a.longitude),
          );
          final bKm = distance.as(
            LengthUnit.Kilometer,
            LatLng(position.latitude, position.longitude),
            LatLng(b.latitude, b.longitude),
          );
          return aKm.compareTo(bKm);
        });
      if (!mounted) return;
      setState(() {
        nearbySpots = sorted.take(5).toList();
        message = nearbySpots.isEmpty ? 'No spots available yet.' : null;
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> loadOfflineSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('offline_spots') ?? const [];
    if (saved.isNotEmpty && mounted) {
      setState(
        () => message = '${saved.length} spots saved for offline viewing.',
      );
    }
  }

  Future<void> saveOfflineSpots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'offline_spots',
      widget.spots
          .take(8)
          .map(
            (spot) => jsonEncode({
              'name': spot.name,
              'location': spot.location,
              'description': spot.description,
            }),
          )
          .toList(),
    );
    setState(() => message = 'Top spots saved for offline viewing.');
  }

  Future<void> addItinerary() async {
    if (titleController.text.trim().isEmpty) {
      setState(() => message = 'Add a plan title first.');
      return;
    }
    try {
      final item = await widget.api.createItinerary(
        title: titleController.text.trim(),
        travelDate: dateController.text.trim(),
        notes: notesController.text.trim(),
      );
      setState(() {
        itinerary = [item, ...itinerary];
        titleController.clear();
        dateController.clear();
        notesController.clear();
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> removeItinerary(ItineraryItem item) async {
    try {
      await widget.api.deleteItinerary(item.id);
      if (!mounted) return;
      setState(() {
        itinerary = itinerary.where((row) => row.id != item.id).toList();
        message = 'Plan removed.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> addBudget() async {
    if (budgetLabelController.text.trim().isEmpty ||
        budgetAmountController.text.trim().isEmpty) {
      setState(() => message = 'Add an expense label and amount first.');
      return;
    }
    try {
      final item = await widget.api.createBudget(
        label: budgetLabelController.text.trim(),
        amount: double.parse(budgetAmountController.text.trim()),
        category: budgetCategory,
      );
      setState(() {
        budget = [item, ...budget];
        budgetLabelController.clear();
        budgetAmountController.clear();
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> removeBudget(BudgetItem item) async {
    try {
      await widget.api.deleteBudget(item.id);
      if (!mounted) return;
      setState(() {
        budget = budget.where((row) => row.id != item.id).toList();
        message = 'Expense removed.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = budget.fold<double>(0, (sum, item) => sum + item.amount);

    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassBox(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trip Planner', style: GlassTextStyles.cardTitle),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: AuthTextField(
                          controller: titleController,
                          hintText: 'Plan title',
                          icon: Icons.event_note,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: AuthTextField(
                          controller: dateController,
                          hintText: 'Date',
                          icon: Icons.calendar_month,
                        ),
                      ),
                      SizedBox(
                        width: 360,
                        child: AuthTextField(
                          controller: notesController,
                          hintText: 'Notes',
                          icon: Icons.notes,
                        ),
                      ),
                      GradientButton(
                        label: 'Add Plan',
                        onPressed: addItinerary,
                      ),
                      GradientButton(
                        label: 'Save Offline',
                        icon: Icons.offline_pin_outlined,
                        onPressed: saveOfflineSpots,
                      ),
                    ],
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(message!, style: GlassTextStyles.bodyMuted),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in itinerary.take(6))
                        SizedBox(
                          width: 280,
                          child: PlannerItemTile(
                            title: item.title,
                            subtitle: [
                              if (item.travelDate.isNotEmpty) item.travelDate,
                              if (item.spotName.isNotEmpty) item.spotName,
                              if (item.notes.isNotEmpty) item.notes,
                            ].join(' • '),
                            icon: Icons.event_note_outlined,
                            onDelete: () => removeItinerary(item),
                          ),
                        ),
                      if (itinerary.isEmpty)
                        const Text(
                          'No plans yet. Add your first route or travel day.',
                          style: GlassTextStyles.bodyMuted,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassBox(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Travel Tools',
                    style: GlassTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GradientButton(
                        label: locating ? 'Checking...' : 'Nearby Spots',
                        icon: Icons.near_me_outlined,
                        onPressed: findNearbySpots,
                      ),
                      for (final badge in badges)
                        SizedBox(
                          width: 240,
                          child: DestinationTile(
                            icon: '🏅',
                            title: badge.title,
                            subtitle: badge.description,
                            accent: const Color(0xffffd166),
                          ),
                        ),
                    ],
                  ),
                  if (nearbySpots.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final spot in nearbySpots)
                          SizedBox(
                            width: 250,
                            child: DestinationTile(
                              icon: '📌',
                              title: spot.name,
                              subtitle: spot.location,
                              accent: const Color(0xff5eead4),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassBox(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Planner • ₱${total.toStringAsFixed(2)} total',
                    style: GlassTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: AuthTextField(
                          controller: budgetLabelController,
                          hintText: 'Expense label',
                          icon: Icons.receipt_long,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: AuthTextField(
                          controller: budgetAmountController,
                          hintText: 'Amount',
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: budgetCategory,
                          items:
                              const [
                                    'Food',
                                    'Fare',
                                    'Hotel',
                                    'Entrance',
                                    'Other',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => budgetCategory = value ?? 'Other'),
                        ),
                      ),
                      GradientButton(
                        label: 'Add Expense',
                        onPressed: addBudget,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in budget.take(8))
                        SizedBox(
                          width: 220,
                          child: PlannerItemTile(
                            icon: Icons.payments_outlined,
                            title: item.label,
                            subtitle:
                                '${item.category} • ₱${item.amount.toStringAsFixed(2)}',
                            onDelete: () => removeBudget(item),
                          ),
                        ),
                      if (budget.isEmpty)
                        const Text(
                          'No expenses yet. Add fare, food, hotel, or entrance fees.',
                          style: GlassTextStyles.bodyMuted,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlannerItemTile extends StatelessWidget {
  const PlannerItemTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onDelete,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff5eead4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GlassTextStyles.cardTitleSmall),
                const SizedBox(height: 3),
                Text(
                  subtitle.isEmpty ? 'No extra details' : subtitle,
                  style: GlassTextStyles.bodyMuted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    required this.posts,
    required this.api,
    required this.onAddPost,
    super.key,
  });

  final List<TravelPost> posts;
  final ApiClient api;
  final Future<TravelPost> Function(String body) onAddPost;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final controller = TextEditingController();
  bool isPosting = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> addPost() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() => isPosting = true);
    await widget.onAddPost(text);
    controller.clear();
    if (mounted) setState(() => isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassBox(
            borderRadius: 22,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GlassSectionTitle(title: 'Share Your Travel'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: isPosting ? 'Posting...' : 'Post',
                    icon: Icons.send_outlined,
                    onPressed: addPost,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (final post in widget.posts) ...[
            CommunityPostCard(post: post, api: widget.api),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class CommunityPostCard extends StatefulWidget {
  const CommunityPostCard({required this.post, required this.api, super.key});

  final TravelPost post;
  final ApiClient api;

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  final commentController = TextEditingController();
  late int likeCount = widget.post.likeCount;
  late int commentCount = widget.post.commentCount;
  List<PostComment> comments = [];
  bool commentsLoaded = false;
  bool isBusy = false;
  String? message;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> likePost() async {
    if (widget.post.id == 0 || isBusy) return;
    setState(() => isBusy = true);
    try {
      final nextCount = await widget.api.toggleLike(widget.post.id);
      if (!mounted) return;
      setState(() {
        likeCount = nextCount;
        message = null;
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> loadComments() async {
    if (widget.post.id == 0) return;
    try {
      final nextComments = await widget.api.fetchComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        comments = nextComments;
        commentsLoaded = true;
        commentCount = nextComments.length;
      });
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  Future<void> addComment() async {
    final body = commentController.text.trim();
    if (body.isEmpty || widget.post.id == 0 || isBusy) return;
    setState(() => isBusy = true);
    try {
      final comment = await widget.api.createComment(widget.post.id, body);
      if (!mounted) return;
      setState(() {
        comments = [comment, ...comments];
        commentCount += 1;
        commentsLoaded = true;
        commentController.clear();
        message = null;
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: 22,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.post.title, style: GlassTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              'by ${widget.post.authorName} • ${formatDateTime(widget.post.createdAt)}',
              style: GlassTextStyles.bodyMuted,
            ),
            const SizedBox(height: 8),
            Text(widget.post.body, style: GlassTextStyles.body),
            if (widget.post.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 14),
              PostPhotoGrid(photoUrls: widget.post.photoUrls),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.favorite_border, size: 18),
                  label: Text('$likeCount likes'),
                  onPressed: likePost,
                ),
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('$commentCount comments'),
                  onPressed: commentsLoaded ? null : loadComments,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    minLines: 1,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Write a helpful comment...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Send comment',
                  onPressed: addComment,
                  icon: const Icon(Icons.send_outlined),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: GlassTextStyles.bodyMuted),
            ],
            if (commentsLoaded) ...[
              const SizedBox(height: 14),
              for (final comment in comments.take(5)) ...[
                Text(
                  '${comment.authorName} • ${formatDateTime(comment.createdAt)}',
                  style: GlassTextStyles.cardTitleSmall,
                ),
                Text(comment.body, style: GlassTextStyles.bodyMuted),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class PostPhotoGrid extends StatelessWidget {
  const PostPhotoGrid({required this.photoUrls, super.key});

  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    final visible = photoUrls.take(4).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final tileWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < visible.length; index++)
              SizedBox(
                width: tileWidth,
                height: compact ? 180 : 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DataOrNetworkImage(url: visible[index]),
                    ),
                    if (index == 3 && photoUrls.length > 4)
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '+${photoUrls.length - 4} more',
                          style: GlassTextStyles.cardTitle,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class DataOrNetworkImage extends StatelessWidget {
  const DataOrNetworkImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image/')) {
      final commaIndex = url.indexOf(',');
      final payload = commaIndex >= 0 ? url.substring(commaIndex + 1) : '';
      try {
        return Image.memory(
          base64Decode(payload),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {
        return const _PhotoFallback(caption: 'Photo preview unavailable');
      }
    }
    return Image.network(
      mediaUrl(url),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          const _PhotoFallback(caption: 'Photo preview unavailable'),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.postsCount,
    required this.spots,
    required this.posts,
    required this.onUpdateName,
    super.key,
  });

  final AppUser user;
  final int postsCount;
  final List<TouristSpot> spots;
  final List<TravelPost> posts;
  final Future<AppUser> Function(String fullName) onUpdateName;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final nameController = TextEditingController(text: widget.user.fullName);
  String? message;

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.fullName != widget.user.fullName) {
      nameController.text = widget.user.fullName;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> saveName() async {
    try {
      await widget.onUpdateName(nameController.text.trim());
      setState(() => message = 'Profile name updated.');
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final topSpots = [...widget.spots]
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassBox(
            borderRadius: 22,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.user.email, style: GlassTextStyles.bodyMuted),
                  Text(
                    '${widget.postsCount} community posts',
                    style: GlassTextStyles.body,
                  ),
                  if (widget.user.isAdmin)
                    const Text(
                      'Admin account',
                      style: GlassTextStyles.bodyMuted,
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: AuthTextField(
                          controller: nameController,
                          hintText: 'Display name',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      GradientButton(label: 'Save Name', onPressed: saveName),
                    ],
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(message!, style: GlassTextStyles.bodyMuted),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassBox(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Rated Places',
                    style: GlassTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final spot in topSpots.take(5))
                        SizedBox(
                          width: 260,
                          child: DestinationTile(
                            icon: '⭐',
                            title: spot.name,
                            subtitle:
                                '${spot.location} • ${spot.rating.toStringAsFixed(1)} rating',
                            accent: const Color(0xffffd166),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassBox(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Feedback',
                    style: GlassTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 14),
                  for (final post in widget.posts.take(4)) ...[
                    Text(post.title, style: GlassTextStyles.cardTitleSmall),
                    Text(
                      'by ${post.authorName}',
                      style: GlassTextStyles.bodyMuted,
                    ),
                    Text(post.body, style: GlassTextStyles.body),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    required this.api,
    required this.onSpotCreated,
    super.key,
  });

  final ApiClient api;
  final Future<void> Function(TouristSpot spot) onSpotCreated;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController(text: 'Nature');
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();
  final imageController = TextEditingController();
  final entranceFeeController = TextEditingController();
  final openingHoursController = TextEditingController();
  final transportGuideController = TextEditingController();
  final emergencyInfoController = TextEditingController();
  final weatherNoteController = TextEditingController();
  Map<String, dynamic> analytics = const {};
  String? message;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    imageController.dispose();
    entranceFeeController.dispose();
    openingHoursController.dispose();
    transportGuideController.dispose();
    emergencyInfoController.dispose();
    weatherNoteController.dispose();
    super.dispose();
  }

  Future<void> loadAnalytics() async {
    final data = await widget.api.fetchAdminAnalytics();
    if (!mounted) return;
    setState(() => analytics = data);
  }

  Future<void> createSpot() async {
    try {
      final spot = await widget.api.createSpot(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        category: categoryController.text.trim(),
        latitude: double.parse(latitudeController.text.trim()),
        longitude: double.parse(longitudeController.text.trim()),
        imageUrl: imageController.text.trim(),
        entranceFee: entranceFeeController.text.trim().isEmpty
            ? 'Check local tourism office'
            : entranceFeeController.text.trim(),
        openingHours: openingHoursController.text.trim().isEmpty
            ? 'Open daily'
            : openingHoursController.text.trim(),
        transportGuide: transportGuideController.text.trim().isEmpty
            ? 'Use local transport or map directions'
            : transportGuideController.text.trim(),
        emergencyInfo: emergencyInfoController.text.trim().isEmpty
            ? 'Call 911 for emergencies'
            : emergencyInfoController.text.trim(),
        weatherNote: weatherNoteController.text.trim().isEmpty
            ? 'Check weather before traveling'
            : weatherNoteController.text.trim(),
      );
      await widget.onSpotCreated(spot);
      await loadAnalytics();
      setState(() => message = 'Tourist spot added.');
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      child: GlassBox(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Dashboard', style: GlassTextStyles.cardTitle),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DestinationTile(
                    icon: '📍',
                    title: '${analytics['spots'] ?? 0}',
                    subtitle: 'Tourist spots',
                    accent: const Color(0xff5eead4),
                  ),
                  DestinationTile(
                    icon: '👤',
                    title: '${analytics['users'] ?? 0}',
                    subtitle: 'Users',
                    accent: const Color(0xffffd166),
                  ),
                  DestinationTile(
                    icon: '⭐',
                    title: '${analytics['reviews'] ?? 0}',
                    subtitle: 'Reviews',
                    accent: const Color(0xffff6b6b),
                  ),
                  DestinationTile(
                    icon: '💬',
                    title: '${analytics['posts'] ?? 0}',
                    subtitle: 'Community posts',
                    accent: const Color(0xff93c5fd),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: AuthTextField(
                      controller: nameController,
                      hintText: 'Spot name',
                      icon: Icons.place_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: AuthTextField(
                      controller: locationController,
                      hintText: 'Location',
                      icon: Icons.map_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: AuthTextField(
                      controller: categoryController,
                      hintText: 'Category',
                      icon: Icons.category_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: AuthTextField(
                      controller: latitudeController,
                      hintText: 'Latitude',
                      icon: Icons.my_location,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: AuthTextField(
                      controller: longitudeController,
                      hintText: 'Longitude',
                      icon: Icons.my_location,
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: AuthTextField(
                      controller: imageController,
                      hintText: 'Image URL',
                      icon: Icons.image_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 520,
                    child: AuthTextField(
                      controller: descriptionController,
                      hintText: 'Description',
                      icon: Icons.description_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: AuthTextField(
                      controller: entranceFeeController,
                      hintText: 'Entrance fee',
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: AuthTextField(
                      controller: openingHoursController,
                      hintText: 'Opening hours',
                      icon: Icons.schedule_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: AuthTextField(
                      controller: transportGuideController,
                      hintText: 'Transport guide',
                      icon: Icons.directions_bus_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AuthTextField(
                      controller: emergencyInfoController,
                      hintText: 'Emergency info',
                      icon: Icons.local_hospital_outlined,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AuthTextField(
                      controller: weatherNoteController,
                      hintText: 'Weather note',
                      icon: Icons.wb_sunny_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Add Tourist Spot',
                icon: Icons.add_location_alt_outlined,
                onPressed: createSpot,
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message!, style: GlassTextStyles.bodyMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ResponsiveGlassGrid extends StatelessWidget {
  const ResponsiveGlassGrid({
    required this.children,
    this.minTileWidth = 260,
    super.key,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / minTileWidth).floor().clamp(1, 4);
        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: 22,
          mainAxisSpacing: 22,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: count == 1 ? 2.75 : 2.25,
          children: children,
        );
      },
    );
  }
}

class GlassFeatureCard extends StatelessWidget {
  const GlassFeatureCard({
    required this.emoji,
    required this.title,
    required this.body,
    super.key,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: 22,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 25)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GlassTextStyles.cardTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(body, style: GlassTextStyles.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPostCard extends StatelessWidget {
  const GlassPostCard({required this.post, super.key});

  final TravelPost post;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: 22,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title, style: GlassTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text('by ${post.authorName}', style: GlassTextStyles.bodyMuted),
            const SizedBox(height: 8),
            Text(post.body, style: GlassTextStyles.body),
            if (post.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              PostPhotoGrid(photoUrls: post.photoUrls),
            ],
          ],
        ),
      ),
    );
  }
}

class GalleryPanel extends StatelessWidget {
  const GalleryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      borderRadius: 22,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📸 Travel Gallery', style: GlassTextStyles.cardTitle),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  for (final id in [1, 2, 3])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            'https://picsum.photos/400/300?$id',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withValues(alpha: .15),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassBox extends StatelessWidget {
  const GlassBox({
    required this.child,
    this.borderRadius = 22,
    this.blur = 12,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PhilippinesMapPainter extends CustomPainter {
  const PhilippinesMapPainter({this.opacity = .22});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: opacity),
          const Color(0xff5eead4).withValues(alpha: opacity * .9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    void island(double x, double y, double w, double h, double rotate) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(rotate);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width * w,
            height: size.height * h,
          ),
          Radius.circular(size.shortestSide * .08),
        ),
        paint,
      );
      canvas.restore();
    }

    island(.56, .25, .12, .34, -.28);
    island(.51, .43, .08, .14, .24);
    island(.58, .53, .10, .20, -.18);
    island(.61, .73, .11, .30, .12);
    island(.36, .55, .12, .38, -.55);
    island(.72, .44, .035, .065, .18);
    island(.74, .62, .04, .06, -.10);
    island(.46, .67, .035, .05, .12);

    final pinPaint = Paint()
      ..color = const Color(0xffffd166).withValues(alpha: opacity * 1.15);
    for (final point in const [
      Offset(.49, .28),
      Offset(.58, .55),
      Offset(.63, .76),
      Offset(.35, .56),
    ]) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        size.shortestSide * .009,
        pinPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PhilippinesMapPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

class GlassSectionTitle extends StatelessWidget {
  const GlassSectionTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: GlassTextStyles.cardTitle);
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final alpha = onPressed == null ? .55 : 1.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xff00c6ff).withValues(alpha: alpha),
            const Color(0xff0072ff).withValues(alpha: alpha),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, letterSpacing: 0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class TravelPost {
  const TravelPost(
    this.title,
    this.body, {
    this.id = 0,
    this.authorName = 'Traveler',
    this.spotName = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.photoUrls = const [],
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String authorName;
  final String spotName;
  final int likeCount;
  final int commentCount;
  final List<String> photoUrls;
  final DateTime? createdAt;

  factory TravelPost.fromJson(Map<String, dynamic> json) {
    return TravelPost(
      json['title'] as String? ?? 'Traveler Update',
      json['body'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      authorName: json['author_name'] as String? ?? 'Traveler',
      spotName: json['spot_name'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      photoUrls:
          (json['photo_urls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      createdAt: parseDateTime(json['created_at']),
    );
  }
}

class GlassTextStyles {
  static const cardTitle = TextStyle(
    color: Colors.white,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: 0,
  );

  static const cardTitleSmall = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: 0,
  );

  static const body = TextStyle(
    color: Colors.white,
    fontSize: 16,
    height: 1.1,
    letterSpacing: 0,
  );

  static const bodyMuted = TextStyle(
    color: Color(0xd9ffffff),
    fontSize: 14,
    height: 1.22,
    letterSpacing: 0,
  );
}
