import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/identity_setup_screen.dart';
import 'screens/interest_picker_screen.dart';
import 'screens/city_pulse_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/circles_meetups_screen.dart';
import 'screens/create_meetup_screen.dart';
import 'screens/meetup_chat_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/safe_chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_saved_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/ai_create_bottom_sheet.dart';

class AppRouter {
  // Screens
  static const String splash = '/';
  static const String login = '/login';
  static const String identitySetup = '/identity-setup';
  static const String interestPicker = '/interest-picker';
  static const String cityPulse = '/city-pulse';
  static const String postDetail = '/post-detail';
  static const String aiCreateSheet = '/ai-create-sheet';
  static const String circlesMeetups = '/circles-meetups';
  static const String createMeetup = '/create-meetup';
  static const String meetupChat = '/meetup-chat';
  static const String inbox = '/inbox';
  static const String safeChat = '/safe-chat';
  static const String notifications = '/notifications';
  static const String profileSaved = '/profile-saved';
  static const String settings = '/settings';

  // Bottom sheets
  static const String aiCreateBottomSheet = '/ai-create-bottom-sheet';
  static const String meetupJoinBottomSheet = '/meetup-join-bottom-sheet';
  static const String profileMenuBottomSheet = '/profile-menu-bottom-sheet';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    identitySetup: (_) => const IdentitySetupScreen(),
    interestPicker: (_) => const InterestPickerScreen(),
    cityPulse: (_) => const CityPulseScreen(),
    postDetail: (_) => const PostDetailScreen(),
    aiCreateSheet: (_) => const AICreateBottomSheet(),
    circlesMeetups: (_) => const CirclesMeetupsScreen(),
    createMeetup: (_) => const CreateMeetupScreen(),
    meetupChat: (_) => const MeetupChatScreen(),
    inbox: (_) => const InboxScreen(),
    safeChat: (_) => const SafeChatScreen(),
    notifications: (_) => const NotificationsScreen(),
    profileSaved: (_) => const ProfileSavedScreen(),
    settings: (_) => const SettingsScreen(),
  };
}
