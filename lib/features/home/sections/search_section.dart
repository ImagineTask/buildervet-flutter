import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/inputs/app_search_bar.dart';

class SearchSection extends StatelessWidget {
  const SearchSection({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSearchBar(
      hintText: 'What do you need done?',
      readOnly: true,
      onTap: () => context.push('/ai-request'),
    );
  }
}
