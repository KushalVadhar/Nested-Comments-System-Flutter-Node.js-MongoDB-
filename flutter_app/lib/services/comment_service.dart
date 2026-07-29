import '../constants/api_constants.dart';
import '../models/comment_model.dart';
import 'http_service.dart';

class CommentService {
  final HttpService _httpService;

  CommentService({HttpService? httpService})
      : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> fetchRootComments({String? cursor, int limit = 20}) async {
    final query = <String, String>{'limit': limit.toString()};
    if (cursor != null) {
      query['cursor'] = cursor;
    }

    final response = await _httpService.get(
      ApiConstants.comments,
      queryParameters: query,
      requireAuth: false,
    );

    final commentsJson = response['comments'] as List;
    final comments = commentsJson.map((c) => CommentModel.fromJson(c)).toList();
    final nextCursor = response['nextCursor'] as String?;
    final hasMore = response['hasMore'] as bool? ?? false;

    return {
      'comments': comments,
      'nextCursor': nextCursor,
      'hasMore': hasMore,
    };
  }

  Future<List<CommentModel>> fetchAllComments() async {
    final response = await _httpService.get(
      ApiConstants.allComments,
      requireAuth: false,
    );

    final commentsJson = response['comments'] as List;
    return commentsJson.map((c) => CommentModel.fromJson(c)).toList();
  }

  Future<CommentModel> createComment(String message, {String? parentId}) async {
    final response = await _httpService.post(
      ApiConstants.comments,
      body: {
        'message': message,
        if (parentId != null) 'parentId': parentId,
      },
      requireAuth: true,
    );

    return CommentModel.fromJson(response);
  }

  Future<CommentModel> editComment(String id, String message) async {
    final response = await _httpService.put(
      ApiConstants.editComment(id),
      body: {'message': message},
      requireAuth: true,
    );

    return CommentModel.fromJson(response);
  }

  Future<CommentModel> deleteComment(String id) async {
    final response = await _httpService.delete(
      ApiConstants.deleteComment(id),
      requireAuth: true,
    );

    return CommentModel.fromJson(response);
  }

  Future<CommentModel> toggleLike(String id) async {
    final response = await _httpService.post(
      ApiConstants.likeComment(id),
      body: {},
      requireAuth: true,
    );

    return CommentModel.fromJson(response);
  }

  Future<Map<String, dynamic>> searchComments(String query) async {
    final response = await _httpService.get(
      ApiConstants.searchComments,
      queryParameters: {'q': query},
      requireAuth: false,
    );

    final matchesJson = response['matches'] as List;
    final matches = matchesJson.map((c) => CommentModel.fromJson(c)).toList();
    final ancestorMap = Map<String, List<dynamic>>.from(response['ancestorMap'] ?? {});

    return {
      'matches': matches,
      'ancestorMap': ancestorMap,
    };
  }

  Future<Map<String, dynamic>> fetchMissedEvents(int sinceEventId) async {
    final response = await _httpService.get(
      ApiConstants.missedEvents,
      queryParameters: {'since': sinceEventId.toString()},
      requireAuth: false,
    );

    final eventsJson = response['events'] as List;
    final events = eventsJson.map((c) => CommentModel.fromJson(c)).toList();
    final lastEventId = response['lastEventId'] as int? ?? sinceEventId;

    return {
      'events': events,
      'lastEventId': lastEventId,
    };
  }
}
