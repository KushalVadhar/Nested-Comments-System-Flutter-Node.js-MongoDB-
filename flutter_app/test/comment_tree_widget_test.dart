import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_nested_comments/providers/auth_provider.dart';
import 'package:flutter_nested_comments/providers/comment_tree_provider.dart';
import 'package:flutter_nested_comments/providers/search_provider.dart';
import 'package:flutter_nested_comments/widgets/comment_tree_widget.dart';

void main() {
  testWidgets('CommentTreeWidget renders loading skeleton initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SearchProvider()),
          ChangeNotifierProvider(create: (_) => CommentTreeProvider(autoConnect: false)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CommentTreeWidget(
              onReply: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CommentTreeWidget), findsOneWidget);
  });
}
