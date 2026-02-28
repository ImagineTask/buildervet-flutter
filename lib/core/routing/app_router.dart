import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/network/network_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/detail_screens/task_detail_screen.dart';
import '../../features/detail_screens/project_detail_screen.dart';
import '../../features/home/see_all_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/network',
            name: RouteNames.network,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NetworkScreen(),
            ),
          ),
          GoRoute(
            path: '/calendar',
            name: RouteNames.calendar,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/chat',
            name: RouteNames.chat,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatScreen(),
            ),
          ),
          GoRoute(
            path: '/alerts',
            name: RouteNames.alerts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AlertsScreen(),
            ),
          ),
        ],
      ),
      // Detail screens (pushed on top of shell)
      GoRoute(
        path: '/task/:taskId',
        name: RouteNames.taskDetail,
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/project/:projectId',
        name: RouteNames.projectDetail,
        builder: (context, state) => ProjectDetailScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),
      GoRoute(
        path: '/projects/all',
        name: RouteNames.seeAllProjects,
        builder: (context, state) => const SeeAllScreen(isProjects: true),
      ),
      GoRoute(
        path: '/tasks/all',
        name: RouteNames.seeAllTasks,
        builder: (context, state) => const SeeAllScreen(isProjects: false),
      ),
    ],
  );
});