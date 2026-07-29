import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/comment_model.dart';
import '../providers/comment_tree_provider.dart';
import 'comment_node_widget.dart';
import 'loading_indicators.dart';

class CommentTreeWidget extends StatefulWidget {
  final Function(CommentModel) onReply;
  final Function(CommentModel) onEdit;

  const CommentTreeWidget({
    super.key,
    required this.onReply,
    required this.onEdit,
  });

  @override
  State<CommentTreeWidget> createState() => _CommentTreeWidgetState();
}

class _CommentTreeWidgetState extends State<CommentTreeWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Trigger cursor pagination load when within 200px of bottom
    if (maxScroll - currentScroll <= 200) {
      final treeProvider = Provider.of<CommentTreeProvider>(context, listen: false);
      if (treeProvider.hasMore && !treeProvider.isLoadingMore) {
        treeProvider.fetchNextPage();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommentTreeProvider>(
      builder: (context, treeProvider, _) {
        if (treeProvider.isInitialLoading) {
          return const LoadingSkeleton();
        }

        if (treeProvider.error != null && treeProvider.visibleNodes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppConstants.dangerColor),
                  const SizedBox(height: 16),
                  Text(
                    treeProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => treeProvider.fetchInitialComments(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (treeProvider.visibleNodes.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => treeProvider.fetchInitialComments(),
            color: AppConstants.primaryColor,
            backgroundColor: AppConstants.cardColor,
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.forum_outlined, size: 56, color: AppConstants.textSecondary),
                      SizedBox(height: 16),
                      Text(
                        'No comments yet.',
                        style: TextStyle(
                          color: AppConstants.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Be the first to start the conversation!',
                        style: TextStyle(color: AppConstants.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => treeProvider.fetchInitialComments(),
          color: AppConstants.primaryColor,
          backgroundColor: AppConstants.cardColor,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: treeProvider.visibleNodes.length + (treeProvider.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == treeProvider.visibleNodes.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                );
              }

              final node = treeProvider.visibleNodes[index];
              return CommentNodeWidget(
                key: ValueKey(node.id),
                node: node,
                onReply: widget.onReply,
                onEdit: widget.onEdit,
              );
            },
          ),
        );
      },
    );
  }
}
