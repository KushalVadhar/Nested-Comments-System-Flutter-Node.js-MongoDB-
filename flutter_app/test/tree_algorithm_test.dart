import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nested_comments/models/comment_model.dart';
import 'package:flutter_nested_comments/models/user_model.dart';
import 'package:flutter_nested_comments/utils/tree_algorithm.dart';

void main() {
  group('TreeBuilder Algorithm Tests', () {
    late TreeBuilder treeBuilder;
    final testUser = UserModel(id: 'u1', username: 'alice');

    setUp(() {
      treeBuilder = TreeBuilder();
    });

    test('1. Should construct tree with unlimited depth correctly', () {
      final root = CommentModel(
        id: 'c1',
        parentId: null,
        author: testUser,
        message: 'Root comment',
        createdAt: DateTime.now(),
        eventId: 1,
      );

      final child = CommentModel(
        id: 'c2',
        parentId: 'c1',
        author: testUser,
        message: 'Level 1 child',
        createdAt: DateTime.now(),
        eventId: 2,
      );

      final grandChild = CommentModel(
        id: 'c3',
        parentId: 'c2',
        author: testUser,
        message: 'Level 2 grandchild',
        createdAt: DateTime.now(),
        eventId: 3,
      );

      treeBuilder.insertOrUpdate(root);
      treeBuilder.insertOrUpdate(child);
      treeBuilder.insertOrUpdate(grandChild);

      expect(treeBuilder.rootNodes.length, equals(1));
      expect(treeBuilder.nodeMap.length, equals(3));

      final rootNode = treeBuilder.nodeMap['c1']!;
      expect(rootNode.children.length, equals(1));
      expect(rootNode.children.first.id, equals('c2'));

      final childNode = treeBuilder.nodeMap['c2']!;
      expect(childNode.depth, equals(1));
      expect(childNode.children.length, equals(1));
      expect(childNode.children.first.id, equals('c3'));

      final grandChildNode = treeBuilder.nodeMap['c3']!;
      expect(grandChildNode.depth, equals(2));
    });

    test('2. Should handle orphan comments that arrive before their parent and re-attach in single pass', () {
      final orphanChild = CommentModel(
        id: 'child_1',
        parentId: 'parent_1', // Parent hasn't arrived yet!
        author: testUser,
        message: 'I am an orphan child',
        createdAt: DateTime.now(),
        eventId: 1,
      );

      // Insert orphan first
      treeBuilder.insertOrUpdate(orphanChild);

      expect(treeBuilder.rootNodes.length, equals(0));
      expect(treeBuilder.orphanQueue.containsKey('parent_1'), isTrue);
      expect(treeBuilder.orphanQueue['parent_1']!.length, equals(1));

      // Now insert parent
      final parent = CommentModel(
        id: 'parent_1',
        parentId: null,
        author: testUser,
        message: 'I am the parent',
        createdAt: DateTime.now(),
        eventId: 2,
      );

      treeBuilder.insertOrUpdate(parent);

      // Parent arrived! Orphan queue should be cleared and child re-attached
      expect(treeBuilder.rootNodes.length, equals(1));
      expect(treeBuilder.orphanQueue.containsKey('parent_1'), isFalse);
      
      final parentNode = treeBuilder.nodeMap['parent_1']!;
      expect(parentNode.children.length, equals(1));
      expect(parentNode.children.first.id, equals('child_1'));
      expect(parentNode.children.first.depth, equals(1));
    });

    test('3. Should tombstone soft-delete nodes with children and hard-delete leaf nodes', () {
      final root = CommentModel(
        id: 'c1',
        parentId: null,
        author: testUser,
        message: 'Root',
        createdAt: DateTime.now(),
        eventId: 1,
      );

      final child = CommentModel(
        id: 'c2',
        parentId: 'c1',
        author: testUser,
        message: 'Leaf Child',
        createdAt: DateTime.now(),
        eventId: 2,
      );

      treeBuilder.insertOrUpdate(root);
      treeBuilder.insertOrUpdate(child);

      // Delete parent 'c1' (has child 'c2') -> Should Tombstone
      treeBuilder.deleteNode('c1');

      final rootNode = treeBuilder.nodeMap['c1']!;
      expect(rootNode.comment.isDeleted, isTrue);
      expect(rootNode.comment.message, equals('[deleted]'));
      expect(rootNode.children.length, equals(1)); // Descendant remains attached!

      // Delete leaf 'c2' (no children) -> Should Hard Delete
      treeBuilder.deleteNode('c2');

      expect(treeBuilder.nodeMap.containsKey('c2'), isFalse);
      expect(rootNode.children.isEmpty, isTrue);
    });

    test('4. Should correctly flatten visible nodes respecting expand/collapse state', () {
      final root = CommentModel(
        id: 'c1',
        parentId: null,
        author: testUser,
        message: 'Root',
        createdAt: DateTime.now(),
        eventId: 1,
      );

      final child = CommentModel(
        id: 'c2',
        parentId: 'c1',
        author: testUser,
        message: 'Child',
        createdAt: DateTime.now(),
        eventId: 2,
      );

      treeBuilder.insertOrUpdate(root);
      treeBuilder.insertOrUpdate(child);

      // When expanded -> 2 visible nodes
      var visible = treeBuilder.flattenVisibleNodes();
      expect(visible.length, equals(2));

      // Collapse root -> Only 1 visible node
      treeBuilder.nodeMap['c1']!.isExpanded = false;
      visible = treeBuilder.flattenVisibleNodes();
      expect(visible.length, equals(1));
      expect(visible.first.id, equals('c1'));
    });
  });
}
