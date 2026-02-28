import 'package:flutter/material.dart';
import '../../../shared/widgets/inputs/app_search_bar.dart';

class SearchSection extends StatelessWidget {
  const SearchSection({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSearchBar(
      hintText: 'Search tasks, projects, people...',
      onChanged: (query) {
        // TODO: Connect to search provider
      },
    );
  }
}
