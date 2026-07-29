import '../models/comment_model.dart';

class CommentTreeNode {
  CommentModel comment;
  CommentTreeNode? parent;
  final List<CommentTreeNode> children;
  bool isExpanded;
  int depth;

  CommentTreeNode({
    required this.comment,
    this.parent,
    List<CommentTreeNode>? children,
    this.isExpanded = true,
    this.depth = 0,
  }) : children = children ?? [];

  String get id => comment.id;
  bool get hasChildren => children.isNotEmpty;

  void updateDepth(int newDepth) {
    depth = newDepth;
    for (var child in children) {
      child.updateDepth(newDepth + 1);
    }
  }
}

class TreeBuilderResult {
  final List<CommentTreeNode> rootNodes;
  final Map<String, CommentTreeNode> nodeMap;
  final Map<String, List<CommentTreeNode>> orphanQueue;

  TreeBuilderResult({
    required this.rootNodes,
    required this.nodeMap,
    required this.orphanQueue,
  });
}

class TreeBuilder {
  final Map<String, CommentTreeNode> _nodeMap = {};
  final Map<String, List<CommentTreeNode>> _orphanQueue = {};
  final List<CommentTreeNode> _rootNodes = [];

  Map<String, CommentTreeNode> get nodeMap => _nodeMap;
  Map<String, List<CommentTreeNode>> get orphanQueue => _orphanQueue;
  List<CommentTreeNode> get rootNodes => _rootNodes;

  void clear() {
    _nodeMap.clear();
    _orphanQueue.clear();
    _rootNodes.clear();
  }

  /// O(n) Insertion / Update with Orphan Queue Re-attachment
  CommentTreeNode insertOrUpdate(CommentModel comment) {
    // 1. If comment node already exists in HashMap, update model in place
    if (_nodeMap.containsKey(comment.id)) {
      final existingNode = _nodeMap[comment.id]!;
      existingNode.comment = comment;

      // Handle parent change if parentId updated
      return existingNode;
    }

    // 2. Create new node
    final newNode = CommentTreeNode(comment: comment);
    _nodeMap[comment.id] = newNode;

    // 3. Re-attach any orphaned children that were waiting for this node to arrive
    if (_orphanQueue.containsKey(comment.id)) {
      final waitingOrphans = _orphanQueue.remove(comment.id)!;
      for (final orphan in waitingOrphans) {
        newNode.children.add(orphan);
        orphan.parent = newNode;
        orphan.updateDepth(newNode.depth + 1);
      }
    }

    // 4. Attach newNode to its parent or add to rootNodes or queue as orphan
    if (comment.parentId == null || comment.parentId!.isEmpty) {
      // Top-level root comment
      newNode.depth = 0;
      _rootNodes.add(newNode);
    } else if (_nodeMap.containsKey(comment.parentId)) {
      // Parent exists in nodeMap
      final parentNode = _nodeMap[comment.parentId]!;
      newNode.parent = parentNode;
      newNode.depth = parentNode.depth + 1;
      
      // Avoid duplicate child entry
      if (!parentNode.children.any((child) => child.id == newNode.id)) {
        parentNode.children.add(newNode);
      }
    } else {
      // Parent has not arrived yet! Queue in orphan queue
      newNode.depth = 0; // Temporary depth until parent arrives
      _orphanQueue.putIfAbsent(comment.parentId!, () => []).add(newNode);
    }

    return newNode;
  }

  /// Insert multiple comments (batch processing)
  void buildFromComments(List<CommentModel> comments) {
    for (final comment in comments) {
      insertOrUpdate(comment);
    }
  }

  /// Remove node or tombstone if it has children
  bool deleteNode(String id) {
    if (!_nodeMap.containsKey(id)) return false;

    final node = _nodeMap[id]!;
    if (node.hasChildren || _orphanQueue.containsKey(id)) {
      // Tombstone soft delete (preserve position for descendants)
      node.comment = node.comment.copyWith(
        isDeleted: true,
        message: '[deleted]',
      );
      return true;
    } else {
      // Leaf comment -> Remove completely from parent / root list and map
      if (node.parent != null) {
        node.parent!.children.removeWhere((c) => c.id == id);
      } else {
        _rootNodes.removeWhere((c) => c.id == id);
      }
      _nodeMap.remove(id);
      return true;
    }
  }

  /// Flatten visible nodes for ListViews (O(N_visible))
  List<CommentTreeNode> flattenVisibleNodes() {
    final List<CommentTreeNode> visibleList = [];

    void traverse(CommentTreeNode node) {
      visibleList.add(node);
      if (node.isExpanded && node.hasChildren) {
        for (final child in node.children) {
          traverse(child);
        }
      }
    }

    for (final root in _rootNodes) {
      traverse(root);
    }

    return visibleList;
  }

  /// Find and expand all ancestors for search matching
  void expandAncestorsOf(String commentId) {
    if (!_nodeMap.containsKey(commentId)) return;

    var curr = _nodeMap[commentId]!.parent;
    while (curr != null) {
      curr.isExpanded = true;
      curr = curr.parent;
    }
  }
}
