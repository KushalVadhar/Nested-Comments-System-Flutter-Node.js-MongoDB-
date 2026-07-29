import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/comment_tree_provider.dart';
import '../providers/search_provider.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppConstants.backgroundColor,
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: AppConstants.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search comments...',
              hintStyle: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.textSecondary, size: 20),
              suffixIcon: searchProvider.isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    )
                  : searchProvider.hasQuery
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppConstants.textSecondary, size: 18),
                          onPressed: () {
                            _controller.clear();
                            searchProvider.clearSearch();
                          },
                        )
                      : null,
              filled: true,
              fillColor: AppConstants.cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
              ),
            ),
            onChanged: (text) {
              final commentTree = Provider.of<CommentTreeProvider>(context, listen: false);
              searchProvider.setQuery(
                text,
                onResultsFound: (ancestorMap) {
                  commentTree.expandAncestors(ancestorMap);
                },
              );
            },
          ),
        );
      },
    );
  }
}
