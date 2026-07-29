import 'user_model.dart';

class CommentModel {
  final String id;
  final String? parentId;
  final UserModel author;
  final String message;
  final int likes;
  final List<String> likedBy;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int eventId;

  // Client-side transient states
  final bool isOptimistic;
  final bool isSendingFailed;

  CommentModel({
    required this.id,
    this.parentId,
    required this.author,
    required this.message,
    this.likes = 0,
    this.likedBy = const [],
    this.isDeleted = false,
    required this.createdAt,
    this.editedAt,
    required this.eventId,
    this.isOptimistic = false,
    this.isSendingFailed = false,
  });

  bool isLikedByUser(String? userId) {
    if (userId == null) return false;
    return likedBy.contains(userId);
  }

  CommentModel copyWith({
    String? id,
    String? parentId,
    UserModel? author,
    String? message,
    int? likes,
    List<String>? likedBy,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? editedAt,
    int? eventId,
    bool? isOptimistic,
    bool? isSendingFailed,
  }) {
    return CommentModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      author: author ?? this.author,
      message: message ?? this.message,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      eventId: eventId ?? this.eventId,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      isSendingFailed: isSendingFailed ?? this.isSendingFailed,
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? json['_id'] ?? '',
      parentId: json['parentId'],
      author: UserModel.fromJson(json['author'] ?? {}),
      message: json['message'] ?? '',
      likes: json['likes'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      isDeleted: json['isDeleted'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
      eventId: json['eventId'] ?? 0,
      isOptimistic: false,
      isSendingFailed: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'author': author.toJson(),
      'message': message,
      'likes': likes,
      'likedBy': likedBy,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'eventId': eventId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          message == other.message &&
          likes == other.likes &&
          isDeleted == other.isDeleted &&
          editedAt == other.editedAt &&
          isOptimistic == other.isOptimistic &&
          isSendingFailed == other.isSendingFailed;

  @override
  int get hashCode =>
      id.hashCode ^
      message.hashCode ^
      likes.hashCode ^
      isDeleted.hashCode ^
      isOptimistic.hashCode;
}
