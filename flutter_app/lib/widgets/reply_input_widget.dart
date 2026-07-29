import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/comment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/comment_tree_provider.dart';

class ReplyInputWidget extends StatefulWidget {
  final CommentModel? replyingToComment;
  final CommentModel? editingComment;
  final VoidCallback onCancelMode;

  const ReplyInputWidget({
    super.key,
    this.replyingToComment,
    this.editingComment,
    required this.onCancelMode,
  });

  @override
  State<ReplyInputWidget> createState() => _ReplyInputWidgetState();
}

class _ReplyInputWidgetState extends State<ReplyInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.editingComment != null) {
      _controller.text = widget.editingComment!.message;
    }
  }

  @override
  void didUpdateWidget(covariant ReplyInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyingToComment != oldWidget.replyingToComment && widget.replyingToComment != null) {
      _focusNode.requestFocus();
    }
    if (widget.editingComment != oldWidget.editingComment) {
      if (widget.editingComment != null) {
        _controller.text = widget.editingComment!.message;
        _focusNode.requestFocus();
      } else {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to post or reply to comments.'),
          backgroundColor: AppConstants.warningColor,
        ),
      );
      return;
    }

    final commentTreeProvider = Provider.of<CommentTreeProvider>(context, listen: false);
    setState(() => _isSubmitting = true);

    if (widget.editingComment != null) {
      // Edit existing comment
      final success = await commentTreeProvider.editComment(
        commentId: widget.editingComment!.id,
        newMessage: text,
        onError: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppConstants.dangerColor),
          );
        },
      );
      if (success) {
        _controller.clear();
        widget.onCancelMode();
      }
    } else {
      // Post new root or reply comment
      final success = await commentTreeProvider.postComment(
        message: text,
        parentId: widget.replyingToComment?.id,
        currentUser: authProvider.currentUser!,
        onError: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppConstants.dangerColor),
          );
        },
      );

      if (success) {
        _controller.clear();
        widget.onCancelMode();
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isReplying = widget.replyingToComment != null;
    final isEditing = widget.editingComment != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: const BoxDecoration(
        color: AppConstants.cardColor,
        border: Border(top: BorderSide(color: AppConstants.borderLineColor, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReplying || isEditing)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEditing ? Icons.edit_rounded : Icons.reply_rounded,
                    size: 14,
                    color: AppConstants.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isEditing
                        ? 'Editing comment'
                        : 'Replying to @${widget.replyingToComment?.author.username}',
                    style: const TextStyle(
                      color: AppConstants.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      _controller.clear();
                      widget.onCancelMode();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close_rounded, size: 14, color: AppConstants.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_isSubmitting,
                  style: const TextStyle(color: AppConstants.textPrimary, fontSize: 14),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: !authProvider.isAuthenticated
                        ? 'Log in to join the discussion...'
                        : isReplying
                            ? 'Write a reply...'
                            : isEditing
                                ? 'Update comment...'
                                : 'Add a comment...',
                    hintStyle: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
                    filled: true,
                    fillColor: AppConstants.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        isEditing ? Icons.check_rounded : Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                style: IconButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  disabledBackgroundColor: AppConstants.borderLineColor,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
