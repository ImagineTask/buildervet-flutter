import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/shell/app_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/ai/ai_request_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/network/network_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_detail_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../providers/auth_provider.dart';
import '../../features/detail_screens/task_detail_screen.dart';
import '../../features/home/see_all_screen.dart';
import '../../features/actions/screens/project_task_list_screen.dart';
import '../../features/actions/screens/task_quote_screen.dart';
import '../../features/actions/screens/task_schedule_screen.dart';
import '../../features/actions/screens/task_invoice_screen.dart';
import '../../features/actions/screens/project_photo_screen.dart';
import '../../features/actions/screens/web_view_screen.dart';
import '../../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      final isOnLogin = state.matchedLocation == '/login';

      // Still loading auth state, don't redirect
      if (isLoading) return null;

      // Not logged in and not on login page -> go to login
      if (!isLoggedIn && !isOnLogin) return '/login';
      // Logged in and on login page -> go to home
      if (isLoggedIn && isOnLogin) return '/home';
      // Otherwise stay
      return null;
    },
    routes: [
      // Login
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // AI request screen
      GoRoute(
        path: '/ai-request',
        name: RouteNames.aiRequest,
        builder: (context, state) => const AiRequestScreen(),
      ),
      // ─── Shell with bottom nav ──────────────────────────
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
              child: ChatListScreen(),
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

      // ─── Chat detail screen ─────────────────────────────
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatDetailScreen(
            conversationId: state.pathParameters['conversationId']!,
            title: extra['title'] as String? ?? 'Chat',
          );
        },
      ),

      // ─── Settings screen ────────────────────────────────
      GoRoute(
        path: '/settings',
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ─── Task detail screen ─────────────────────────────
      GoRoute(
        path: '/task/:taskId',
        name: RouteNames.taskDetail,
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),

      // ─── See all screens ────────────────────────────────
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

      // ─── Project action: task list with mode ────────────
      GoRoute(
        path: '/actions/project-tasks/:projectId/detail',
        builder: (context, state) => ProjectTaskListScreen(
          projectId: state.pathParameters['projectId']!,
          mode: TaskListMode.detail,
        ),
      ),
      GoRoute(
        path: '/actions/project-tasks/:projectId/quote',
        builder: (context, state) => ProjectTaskListScreen(
          projectId: state.pathParameters['projectId']!,
          mode: TaskListMode.quote,
        ),
      ),
      GoRoute(
        path: '/actions/project-tasks/:projectId/schedule',
        builder: (context, state) => ProjectTaskListScreen(
          projectId: state.pathParameters['projectId']!,
          mode: TaskListMode.schedule,
        ),
      ),
      GoRoute(
        path: '/actions/project-tasks/:projectId/invoice',
        builder: (context, state) => ProjectTaskListScreen(
          projectId: state.pathParameters['projectId']!,
          mode: TaskListMode.invoice,
        ),
      ),

      // ─── Task-level action screens ──────────────────────
      GoRoute(
        path: '/actions/task-detail/:taskId',
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/actions/task-quote/:taskId',
        builder: (context, state) => TaskQuoteScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/actions/task-schedule/:taskId',
        builder: (context, state) => TaskScheduleScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/actions/task-invoice/:taskId',
        builder: (context, state) => TaskInvoiceScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),

      // ─── Project photo screen ───────────────────────────
      GoRoute(
        path: '/actions/project-photo/:projectId',
        builder: (context, state) => ProjectPhotoScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),

      // ─── Generic web view ───────────────────────────────
      GoRoute(
        path: '/actions/webview',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return WebViewScreen(
            url: extra['url'] as String? ?? '',
            title: extra['title'] as String? ?? 'Web',
          );
        },
      ),
    ],
  );
});