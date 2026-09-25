import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// User role as defined by `RoleEnum` in the API schema.
enum UserRole {
  superAdmin('super_admin'),
  admin('admin'),
  teacher('teacher'),
  user('user');

  const UserRole(this.value);

  final String value;

  static UserRole fromValue(String? value) {
    for (final role in UserRole.values) {
      if (role.value == value) return role;
    }
    return UserRole.user;
  }

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'سوپر ادمین';
      case UserRole.admin:
        return 'ادمین';
      case UserRole.teacher:
        return 'استاد';
      case UserRole.user:
        return 'کاربر';
    }
  }
}

/// Gender as defined by `GenderEnum` in the API schema.
enum UserGender {
  male('male', 'مرد'),
  female('female', 'زن'),
  other('other', 'سایر');

  const UserGender(this.value, this.label);

  final String value;
  final String label;

  static UserGender? fromValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final gender in UserGender.values) {
      if (gender.value == value) return gender;
    }
    return null;
  }
}

/// Maps `GET /api/v1/accounts/profile/`, `PATCH /api/v1/accounts/profile/`,
/// the `user` object returned by the auth endpoints and `User` in the schema.
class UserModel {
  const UserModel({
    required this.id,
    required this.phoneNumber,
    this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.avatar,
    this.bannerImage,
    this.gender,
    this.birthDate,
    this.bio,
    this.role = UserRole.user,
    this.isVerified = false,
    this.isProfileComplete = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String phoneNumber;
  final String? username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? avatar;
  final String? bannerImage;
  final UserGender? gender;
  final DateTime? birthDate;
  final String? bio;
  final UserRole role;
  final bool isVerified;
  final bool isProfileComplete;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Absolute avatar url ready for `Image.network`.
  String? get avatarUrl {
    final value = avatar;
    if (value == null || value.isEmpty) return null;
    return ApiConfig.mediaUrl(value);
  }

  /// Absolute banner image url ready for `Image.network`.
  String? get bannerImageUrl {
    final value = bannerImage;
    if (value == null || value.isEmpty) return null;
    return ApiConfig.mediaUrl(value);
  }

  /// The best label we can show for this user.
  String get displayName {
    final explicit = fullName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final combined = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (combined.isNotEmpty) return combined;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return phoneNumber;
  }

  /// `0919*******84` – used on the OTP screen.
  String get maskedPhone {
    final value = phoneNumber;
    if (value.length < 8) return value;
    return '${value.substring(0, 4)}*******${value.substring(value.length - 2)}';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final first = Json.asString(json['first_name']);
    final last = Json.asString(json['last_name']);
    final fallbackFullName = [first, last]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(' ')
        .trim();

    return UserModel(
      id: Json.asInt(json['id']) ?? 0,
      phoneNumber: Json.asString(json['phone_number']) ?? '',
      username: _emptyToNull(Json.asString(json['username'])),
      email: _emptyToNull(Json.asString(json['email'])),
      firstName: _emptyToNull(first),
      lastName: _emptyToNull(last),
      fullName: _emptyToNull(Json.asString(json['full_name'])) ??
          (fallbackFullName.isEmpty ? null : fallbackFullName),
      avatar: _emptyToNull(Json.asString(json['avatar'])),
      bannerImage: _emptyToNull(Json.asString(json['banner_image']) ??
          Json.asString(json['banner']) ??
          Json.asString(json['profile_banner'])),
      gender: UserGender.fromValue(Json.asString(json['gender'])),
      birthDate: Json.asDate(json['birth_date']),
      bio: _emptyToNull(Json.asString(json['bio'])),
      role: UserRole.fromValue(Json.asString(json['role'])),
      isVerified: Json.asBool(json['is_verified']),
      isProfileComplete: Json.asBool(json['is_profile_complete']),
      isActive: Json.asBool(json['is_active'], fallback: true),
      createdAt: Json.asDate(json['created_at']),
      updatedAt: Json.asDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone_number': phoneNumber,
    'username': username,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'full_name': fullName,
    'avatar': avatar,
    'banner_image': bannerImage,
    'gender': gender?.value,
    'birth_date': birthDate?.toIso8601String().split('T').first,
    'bio': bio,
    'role': role.value,
    'is_verified': isVerified,
    'is_profile_complete': isProfileComplete,
    'is_active': isActive,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  UserModel copyWith({
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? fullName,
    String? avatar,
    String? bannerImage,
    UserGender? gender,
    DateTime? birthDate,
    String? bio,
    bool? isProfileComplete,
  }) => UserModel(
    id: id,
    phoneNumber: phoneNumber,
    username: username ?? this.username,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    fullName: fullName ?? this.fullName,
    avatar: avatar ?? this.avatar,
    bannerImage: bannerImage ?? this.bannerImage,
    gender: gender ?? this.gender,
    birthDate: birthDate ?? this.birthDate,
    bio: bio ?? this.bio,
    role: role,
    isVerified: isVerified,
    isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
