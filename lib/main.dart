import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cubits/auth_cubit.dart';
import 'cubits/auth_state.dart';
import 'cubits/game_cubit.dart';
import 'cubits/settings_cubit.dart';
import 'views/main_menu.dart';
import 'views/auth/auth_toggle.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MafiosoApp());
}

class MafiosoApp extends StatelessWidget {
  const MafiosoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(create: (context) => GameCubit(settingsCubit: context.read<SettingsCubit>())),
      ],
      child: MaterialApp(
        title: 'مافيوسو',
        theme: ThemeData(
          primarySwatch: Colors.red,
          textTheme: GoogleFonts.cairoTextTheme(
            Theme.of(context).textTheme,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const SplashScreen();
        }
        if (state is AuthSuccess) {
          return const MainMenuScreen();
        }
        return const AuthPage();
      },
    );
  }
}