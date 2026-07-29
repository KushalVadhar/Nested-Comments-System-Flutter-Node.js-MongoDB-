import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/comment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_tree_provider.dart';
import '../services/websocket_service.dart';
import '../widgets/comment_tree_widget.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/reply_input_widget.dart';
import '../widgets/search_bar_widget.dart';
import 'login_screen.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  CommentModel? _replyingToComment;
  CommentModel? _editingComment;

  void _handleReply(CommentModel comment) {
    setState(() {
      _replyingToComment = comment;
      _editingComment = null;
    });
  }

  void _handleEdit(CommentModel comment) {
    setState(() {
      _editingComment = comment;
      _replyingToComment = null;
    });
  }

  void _cancelMode() {
    setState(() {
      _replyingToComment = null;
      _editingComment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final commentTree = Provider.of<CommentTreeProvider>(context);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.cardColor,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.forum_rounded, color: AppConstants.primaryColor, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Nested Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            // Live WS indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: commentTree.wsStatus == WsConnectionStatus.connected
                    ? AppConstants.accentColor
                    : AppConstants.warningColor,
              ),
            ),
          ],
        ),
        actions: [
          // Total Count Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${commentTree.totalCommentsCount} msgs',
                style: const TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Login / Profile Account Button
          if (authProvider.isAuthenticated)
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 14,
                backgroundColor: AppConstants.primaryColor,
                child: Text(
                  authProvider.currentUser!.username[0].toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              color: AppConstants.cardColor,
              onSelected: (val) {
                if (val == 'logout') {
                  authProvider.logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Signed in as @${authProvider.currentUser!.username}',
                    style: const TextStyle(color: AppConstants.textSecondary, fontSize: 12),
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: AppConstants.dangerColor),
                      SizedBox(width: 8),
                      Text('Log Out', style: TextStyle(color: AppConstants.dangerColor, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            )
          else
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
              ),
              child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Connectivity Status Banner
          const ConnectivityBanner(),

          // Search Bar
          const SearchBarWidget(),

          // Main Comment Tree (ListView.builder)
          Expanded(
            child: CommentTreeWidget(
              onReply: _handleReply,
              onEdit: _handleEdit,
            ),
          ),

          // Bottom Reply / Edit Dock Widget
          ReplyInputWidget(
            replyingToComment: _replyingToComment,
            editingComment: _editingComment,
            onCancelMode: _cancelMode,
          ),
        ],
      ),
    );
  }
}
