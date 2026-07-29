import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_nested_comments/models/comment_model.dart';
import 'package:flutter_nested_comments/models/user_model.dart';
import 'package:flutter_nested_comments/providers/auth_provider.dart';
import 'package:flutter_nested_comments/providers/comment_tree_provider.dart';
import 'package:flutter_nested_comments/providers/search_provider.dart';
import 'package:flutter_nested_comments/utils/tree_algorithm.dart';
import 'package:flutter_nested_comments/widgets/comment_node_widget.dart';

void main() {
  testWidgets('CommentNodeWidget displays username, message and like counter correctly', (WidgetTester tester) async {
    final comment = CommentModel(
      id: 'c1',
      author: UserModel(id: 'u1', username: 'bob_builder'),
      message: 'Testing Flutter widget rendering',
      likes: 5,
      createdAt: DateTime.now(),
      eventId: 1,
    );

    final node = CommentTreeNode(comment: comment);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SearchProvider()),
          ChangeNotifierProvider(create: (_) => CommentTreeProvider(autoConnect: false)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CommentNodeWidget(
              node: node,
              onReply: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );

    // Verify username and comment message are rendered
    expect(find.text('bob_builder'), findsOneWidget);
    expect(find.text('Testing Flutter widget rendering'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);
  });
}
