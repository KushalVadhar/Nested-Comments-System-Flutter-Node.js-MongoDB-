import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../utils/debouncer.dart';

class SearchProvider extends ChangeNotifier {
  final CommentService _commentService;
  final Debouncer _debouncer = Debouncer(milliseconds: 400);

  String _query = '';
  bool _isSearching = false;
  List<CommentModel> _searchResults = [];
  Map<String, List<dynamic>> _ancestorMap = {};

  SearchProvider({CommentService? commentService})
      : _commentService = commentService ?? CommentService();

  String get query => _query;
  bool get isSearching => _isSearching;
  bool get hasQuery => _query.trim().isNotEmpty;
  List<CommentModel> get searchResults => _searchResults;
  Map<String, List<dynamic>> get ancestorMap => _ancestorMap;

  void setQuery(String newQuery, {Function(Map<String, List<dynamic>>)? onResultsFound}) {
    _query = newQuery;

    if (newQuery.trim().isEmpty) {
      _searchResults = [];
      _ancestorMap = {};
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _debouncer.run(() async {
      try {
        final res = await _commentService.searchComments(newQuery);
        _searchResults = res['matches'] as List<CommentModel>;
        _ancestorMap = res['ancestorMap'] as Map<String, List<dynamic>>;
        _isSearching = false;
        notifyListeners();

        if (onResultsFound != null) {
          onResultsFound(_ancestorMap);
        }
      } catch (e) {
        _isSearching = false;
        notifyListeners();
      }
    });
  }

  void clearSearch() {
    _query = '';
    _searchResults = [];
    _ancestorMap = {};
    _isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
