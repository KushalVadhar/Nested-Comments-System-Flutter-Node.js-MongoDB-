import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';
import '../services/websocket_service.dart';
import '../utils/debouncer.dart';
import '../utils/tree_algorithm.dart';

class CommentTreeProvider extends ChangeNotifier {
  final CommentService _commentService;
  final WebSocketService _wsService;
  final TreeBuilder _treeBuilder = TreeBuilder();
  final Uuid _uuid = const Uuid();

  StreamSubscription<WsEvent>? _wsSubscription;
  StreamSubscription<WsConnectionStatus>? _wsStatusSubscription;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _nextCursor;
  bool _hasMore = false;
  String? _error;

  int _lastKnownEventId = 0;
  List<CommentTreeNode> _visibleNodes = [];

  // Debouncers map per comment ID for like interactions (300ms)
  final Map<String, Debouncer> _likeDebouncers = {};

  CommentTreeProvider({
    CommentService? commentService,
    WebSocketService? wsService,
    bool autoConnect = true,
  })  : _commentService = commentService ?? CommentService(),
        _wsService = wsService ?? WebSocketService() {
    if (autoConnect) {
      _initWebSocket();
      fetchInitialComments();
    }
  }

  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  List<CommentTreeNode> get visibleNodes => _visibleNodes;
  int get totalCommentsCount => _treeBuilder.nodeMap.values.where((n) => !n.comment.isDeleted).length;
  int get rawNodeCount => _treeBuilder.nodeMap.length;
  WsConnectionStatus get wsStatus => _wsService.status;

  void _initWebSocket() {
    _wsService.connect();

    _wsSubscription = _wsService.eventStream.listen(_handleWsEvent);
    _wsStatusSubscription = _wsService.statusStream.listen((status) {
      notifyListeners();
      if (status == WsConnectionStatus.connected) {
        _recoverMissedEvents();
      }
    });
  }

  void _handleWsEvent(WsEvent event) {
    if (event.data == null) return;
    try {
      final comment = CommentModel.fromJson(event.data);
      if (comment.eventId > _lastKnownEventId) {
        _lastKnownEventId = comment.eventId;
      }

      switch (event.type) {
        case 'NEW_COMMENT':
        case 'EDIT_COMMENT':
        case 'LIKE_UPDATE':
          _treeBuilder.insertOrUpdate(comment);
          break;
        case 'DELETE_COMMENT':
          _treeBuilder.deleteNode(comment.id);
          break;
      }
      _updateVisibleNodes();
    } catch (e) {
      debugPrint('Error parsing WS Event: $e');
    }
  }

  Future<void> _recoverMissedEvents() async {
    if (_lastKnownEventId == 0) return;
    try {
      final res = await _commentService.fetchMissedEvents(_lastKnownEventId);
      final events = res['events'] as List<CommentModel>;
      final lastId = res['lastEventId'] as int;

      for (final comment in events) {
        _treeBuilder.insertOrUpdate(comment);
      }
      if (lastId > _lastKnownEventId) {
        _lastKnownEventId = lastId;
      }
      _updateVisibleNodes();
    } catch (e) {
      debugPrint('Error recovering missed events: $e');
    }
  }

  Future<void> fetchInitialComments() async {
    _isInitialLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all comments to construct complete initial tree
      final allComments = await _commentService.fetchAllComments();
      _treeBuilder.clear();
      _treeBuilder.buildFromComments(allComments);

      for (final c in allComments) {
        if (c.eventId > _lastKnownEventId) {
          _lastKnownEventId = c.eventId;
        }
      }

      // Fetch root cursor info
      final rootRes = await _commentService.fetchRootComments(limit: 20);
      _nextCursor = rootRes['nextCursor'];
      _hasMore = rootRes['hasMore'];

      _isInitialLoading = false;
      _updateVisibleNodes();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextPage() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final res = await _commentService.fetchRootComments(cursor: _nextCursor, limit: 20);
      final newRootComments = res['comments'] as List<CommentModel>;
      _nextCursor = res['nextCursor'];
      _hasMore = res['hasMore'];

      for (final comment in newRootComments) {
        _treeBuilder.insertOrUpdate(comment);
        if (comment.eventId > _lastKnownEventId) {
          _lastKnownEventId = comment.eventId;
        }
      }

      _isLoadingMore = false;
      _updateVisibleNodes();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Optimistic UI Posting & Repliess
  Future<bool> postComment({
    required String message,
    String? parentId,
    required UserModel currentUser,
    required Function(String error) onError,
  }) async {
    final tempId = 'temp_${_uuid.v4()}';
    final tempComment = CommentModel(
      id: tempId,
      parentId: parentId,
      author: currentUser,
      message: message.trim(),
      createdAt: DateTime.now(),
      eventId: 0,
      isOptimistic: true,
    );

    // 1. Instantly insert temp comment into local tree
    _treeBuilder.insertOrUpdate(tempComment);
    _updateVisibleNodes();

    try {
      // 2. Call backend REST API
      final serverComment = await _commentService.createComment(
        message,
        parentId: parentId,
      );

      // 3. Swap temp node with confirmed server comment
      _treeBuilder.deleteNode(tempId);
      _treeBuilder.insertOrUpdate(serverComment);

      if (serverComment.eventId > _lastKnownEventId) {
        _lastKnownEventId = serverComment.eventId;
      }

      _updateVisibleNodes();
      return true;
    } catch (e) {
      // 4. Rollback temp node on failure (without affecting any other nodes)
      _treeBuilder.deleteNode(tempId);
      _updateVisibleNodes();
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Edit Comment (Within 5-minute window)
  Future<bool> editComment({
    required String commentId,
    required String newMessage,
    required Function(String error) onError,
  }) async {
    final existingNode = _treeBuilder.nodeMap[commentId];
    if (existingNode == null) return false;

    final oldMessage = existingNode.comment.message;

    // Optimistic edit
    existingNode.comment = existingNode.comment.copyWith(
      message: newMessage,
      editedAt: DateTime.now(),
    );
    _updateVisibleNodes();

    try {
      final updatedComment = await _commentService.editComment(commentId, newMessage);
      _treeBuilder.insertOrUpdate(updatedComment);
      _updateVisibleNodes();
      return true;
    } catch (e) {
      // Revert edit
      existingNode.comment = existingNode.comment.copyWith(message: oldMessage);
      _updateVisibleNodes();
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Delete Comment (Soft-delete tombstone vs Hard-delete leaf)
  Future<bool> deleteComment({
    required String commentId,
    required Function(String error) onError,
  }) async {
    final existingNode = _treeBuilder.nodeMap[commentId];
    if (existingNode == null) return false;

    final oldComment = existingNode.comment;

    // Optimistic delete
    _treeBuilder.deleteNode(commentId);
    _updateVisibleNodes();

    try {
      final deletedComment = await _commentService.deleteComment(commentId);
      _treeBuilder.insertOrUpdate(deletedComment);
      _updateVisibleNodes();
      return true;
    } catch (e) {
      // Revert deletion
      _treeBuilder.insertOrUpdate(oldComment);
      _updateVisibleNodes();
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Debounced Like / Unlike (300ms)
  void toggleLike({
    required String commentId,
    required String userId,
    required Function(String error) onError,
  }) {
    final node = _treeBuilder.nodeMap[commentId];
    if (node == null || node.comment.isDeleted) return;

    final currentComment = node.comment;
    final isLiked = currentComment.isLikedByUser(userId);

    final updatedLikedBy = List<String>.from(currentComment.likedBy);
    int updatedLikes = currentComment.likes;

    if (isLiked) {
      updatedLikedBy.remove(userId);
      updatedLikes = (updatedLikes > 0) ? updatedLikes - 1 : 0;
    } else {
      updatedLikedBy.add(userId);
      updatedLikes += 1;
    }

    // Optimistic local update
    node.comment = currentComment.copyWith(
      likes: updatedLikes,
      likedBy: updatedLikedBy,
    );
    _updateVisibleNodes();

    // Debounce API call (300ms) to prevent race conditions
    _likeDebouncers.putIfAbsent(commentId, () => Debouncer(milliseconds: 300)).run(() async {
      try {
        final serverComment = await _commentService.toggleLike(commentId);
        _treeBuilder.insertOrUpdate(serverComment);
        _updateVisibleNodes();
      } catch (e) {
        // Revert on failure
        node.comment = currentComment;
        _updateVisibleNodes();
        onError(e.toString().replaceAll('Exception: ', ''));
      }
    });
  }

  // Toggle Collapse / Expand Node
  void toggleExpand(String commentId) {
    final node = _treeBuilder.nodeMap[commentId];
    if (node != null) {
      node.isExpanded = !node.isExpanded;
      _updateVisibleNodes();
    }
  }

  // Expand ancestors when search matches are found
  void expandAncestors(Map<String, List<dynamic>> ancestorMap) {
    ancestorMap.forEach((matchId, parentIds) {
      _treeBuilder.expandAncestorsOf(matchId);
    });
    _updateVisibleNodes();
  }

  void _updateVisibleNodes() {
    _visibleNodes = _treeBuilder.flattenVisibleNodes();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsStatusSubscription?.cancel();
    _wsService.dispose();
    for (final d in _likeDebouncers.values) {
      d.dispose();
    }
    super.dispose();
  }
}
