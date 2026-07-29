import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/comment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_tree_provider.dart';
import '../providers/search_provider.dart';
import '../utils/date_formatter.dart';
import '../utils/tree_algorithm.dart';

class CommentNodeWidget extends StatelessWidget {
  final CommentTreeNode node;
  final Function(CommentModel) onReply;
  final Function(CommentModel) onEdit;

  const CommentNodeWidget({
    super.key,
    required this.node,
    required this.onReply,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final comment = node.comment;
    final depth = node.depth;
    final visualDepth = depth > AppConstants.maxVisualDepth ? AppConstants.maxVisualDepth : depth;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final isAuthor = currentUserId != null && currentUserId == comment.author.id;
    final canEdit = isAuthor && !comment.isDeleted && DateFormatter.isWithinEditWindow(comment.createdAt, minutes: 5);

    return Container(
      margin: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Visual Indentation Lines (Custom left border lines per depth level)
          for (int i = 0; i < visualDepth; i++)
            Container(
              width: AppConstants.indentWidth,
              margin: const EdgeInsets.only(left: 4.0),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppConstants.indentLineColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),

          // 2. Main Comment Node Card
          Expanded(
            child: AnimatedSize(
              duration: AppConstants.expandAnimationDuration,
              curve: Curves.easeInOut,
              child: Card(
                elevation: 0,
                color: comment.isDeleted ? AppConstants.backgroundColor.withOpacity(0.5) : AppConstants.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: comment.isOptimistic
                        ? AppConstants.primaryColor.withOpacity(0.5)
                        : AppConstants.borderLineColor,
                    width: 1,
                  ),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Avatar, Author Username, Time Ago, Edited badge, Optimistic spinner
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: comment.isDeleted
                                ? AppConstants.textSecondary.withOpacity(0.3)
                                : AppConstants.primaryColor.withOpacity(0.2),
                            child: Text(
                              comment.isDeleted
                                  ? '?'
                                  : comment.author.username.isNotEmpty
                                      ? comment.author.username[0].toUpperCase()
                                      : 'U',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: comment.isDeleted ? AppConstants.textSecondary : AppConstants.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            comment.isDeleted ? '[deleted]' : comment.author.username,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: comment.isDeleted ? AppConstants.textSecondary : AppConstants.textPrimary,
                              fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.timeAgo(comment.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                          if (comment.editedAt != null && !comment.isDeleted) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '(edited)',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppConstants.textSecondary,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (comment.isOptimistic)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppConstants.primaryColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Message Body with Search Text Highlighting
                      Consumer<SearchProvider>(
                        builder: (context, searchProvider, _) {
                          return _buildHighlightedMessage(
                            comment.message,
                            searchProvider.query,
                            comment.isDeleted,
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Action Bar: Like, Reply, Edit, Delete, Collapse/Expand
                      if (!comment.isDeleted)
                        Row(
                          children: [
                            // Like Button
                            InkWell(
                              onTap: () {
                                if (currentUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please log in to like comments.')),
                                  );
                                  return;
                                }
                                Provider.of<CommentTreeProvider>(context, listen: false).toggleLike(
                                  commentId: comment.id,
                                  userId: currentUserId,
                                  onError: (err) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err), backgroundColor: AppConstants.dangerColor),
                                    );
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      comment.isLikedByUser(currentUserId)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 16,
                                      color: comment.isLikedByUser(currentUserId)
                                          ? AppConstants.dangerColor
                                          : AppConstants.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.likes}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: comment.isLikedByUser(currentUserId)
                                            ? AppConstants.dangerColor
                                            : AppConstants.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Reply Button
                            InkWell(
                              onTap: () => onReply(comment),
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.reply_rounded, size: 16, color: AppConstants.textSecondary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Reply',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Edit Button (if author & within 5-min window)
                            if (canEdit) ...[
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () => onEdit(comment),
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 15, color: AppConstants.textSecondary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Edit',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppConstants.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // Delete Button (if author)
                            if (isAuthor) ...[
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () => _confirmDelete(context, comment.id),
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Icon(Icons.delete_outline_rounded, size: 15, color: AppConstants.dangerColor),
                                ),
                              ),
                            ],

                            const Spacer(),

                            // Expand / Collapse Child Branch Button
                            if (node.hasChildren)
                              InkWell(
                                onTap: () {
                                  Provider.of<CommentTreeProvider>(context, listen: false).toggleExpand(comment.id);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        node.isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                        size: 16,
                                        color: AppConstants.primaryColor,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${node.children.length}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Inline Search Text Match Highlighting
  Widget _buildHighlightedMessage(String message, String query, bool isDeleted) {
    if (isDeleted) {
      return Text(
        '[deleted]',
        style: const TextStyle(
          color: AppConstants.textSecondary,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
      );
    }

    if (query.trim().isEmpty) {
      return Text(
        message,
        style: const TextStyle(
          color: AppConstants.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
      );
    }

    final String lowerMsg = message.toLowerCase();
    final String lowerQuery = query.toLowerCase();

    final List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      final int index = lowerMsg.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: message.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: message.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: message.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: AppConstants.warningColor,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppConstants.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  void _confirmDelete(BuildContext context, String commentId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppConstants.cardColor,
          title: const Text('Delete Comment?', style: TextStyle(color: AppConstants.textPrimary)),
          content: const Text(
            'Are you sure you want to delete this comment?',
            style: TextStyle(color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Provider.of<CommentTreeProvider>(context, listen: false).deleteComment(
                  commentId: commentId,
                  onError: (err) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err), backgroundColor: AppConstants.dangerColor),
                    );
                  },
                );
              },
              child: const Text('Delete', style: TextStyle(color: AppConstants.dangerColor)),
            ),
          ],
        );
      },
    );
  }
}
