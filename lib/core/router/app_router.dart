import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/sign_in_screen.dart';
import '../../features/circles/circle_detail_screen.dart';
import '../../features/circles/circles_screen.dart';
import '../../features/circles/join_circle_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/map/map_screen.dart';
import '../../features/sharing/share_screen.dart';
import '../providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/map',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isSignedIn = ref.read(currentUserIdProvider) != null;
      final isSignInRoute = state.matchedLocation == '/sign-in';
      if (!isSignedIn && !isSignInRoute) return '/sign-in';
      if (isSignedIn && isSignInRoute) return '/map';
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/join', builder: (context, state) => const JoinCircleScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
          GoRoute(
            path: '/circles',
            builder: (context, state) => const CirclesScreen(),
            routes: [
              GoRoute(
                path: ':circleId',
                builder: (context, state) => CircleDetailScreen(
                  circleId: state.pathParameters['circleId']!,
                ),
              ),
            ],
          ),
          GoRoute(path: '/share', builder: (context, state) => const ShareScreen()),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's authStateProvider stream into a Listenable so go_router
/// re-evaluates its redirect whenever the user signs in or out.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
