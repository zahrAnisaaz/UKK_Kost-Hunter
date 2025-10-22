import 'package:flutter/material.dart';
import 'package:kost_hunter/SplashScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jgybnfzcnwpsyjarcmhq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpneWJuZnpjbndwc3lqYXJjbWhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyMTIyOTUsImV4cCI6MjA3NTc4ODI5NX0.poroF-FRyQ2BLS9uS-DvaTnd2HLmEA8VuqnDO0ocQIo', // ganti dengan anon key dari Supabase
  );

  runApp(const KostHunterApp());
}

class KostHunterApp extends StatelessWidget {
  const KostHunterApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kost Hunter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue[400],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          primary: Colors.blue[400]!,
          secondary: Colors.yellow[600]!,
        ),
        scaffoldBackgroundColor: const Color(0xfffefefe),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.blue[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}





// import 'package:flutter/material.dart';
// import 'package:kost_hunter/LoginPage.dart';
// import 'package:kost_hunter/OwnerDashboard.dart';
// import 'package:kost_hunter/SocietyDashboard.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';


// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Supabase.initialize(
//     url: 'https://jgybnfzcnwpsyjarcmhq.supabase.co', 
//     anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpneWJuZnpjbndwc3lqYXJjbWhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyMTIyOTUsImV4cCI6MjA3NTc4ODI5NX0.poroF-FRyQ2BLS9uS-DvaTnd2HLmEA8VuqnDO0ocQIo', 
//   );

//   runApp(const KostHunterApp());
// }

// class KostHunterApp extends StatelessWidget {
//   const KostHunterApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Kost Hunter',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
//         useMaterial3: true,
//       ),
//       home: AuthCheck(),
//     );
//   }
// }

// class AuthCheck extends StatefulWidget {
//   @override
//   _AuthCheckState createState() => _AuthCheckState();
// }

// class _AuthCheckState extends State<AuthCheck> {
//   final supabase = Supabase.instance.client;

//   @override
//   Widget build(BuildContext context) {
//     final session = supabase.auth.currentSession;

//     if (session == null) {
//       // belum login
//       return LoginPage();
//     } else {
//       // sudah login → ambil role user
//       return FutureBuilder(
//         future: supabase
//             .from('users')
//             .select('role')
//             .eq('id', session.user!.id)
//             .single(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Scaffold(
//               body: Center(child: CircularProgressIndicator()),
//             );
//           }

//           final role = snapshot.data?['role'];

//           if (role == 'owner') {
//             return OwnerDashboard();
//           } else {
//             return SocietyDashboard();
//           }
//         },
//       );
//     }
//   }
// }
