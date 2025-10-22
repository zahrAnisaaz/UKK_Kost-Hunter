import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  // 🔹 Login user
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Login gagal, user tidak ditemukan.");
      }

      return response;
    } on AuthException catch (e) {
      throw Exception('Login gagal: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // 🔹 Register user + langsung login (tanpa email verifikasi)
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // 1️⃣ Daftar akun ke Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role, // society atau owner
        },
        emailRedirectTo: null, // 🚫 Tidak kirim email verifikasi
      );

      final user = response.user;
      if (user == null) {
        throw Exception("Gagal membuat akun.");
      }

      // 2️⃣ Simpan data user ke tabel users (Supabase)
      await supabase.from('users').insert({
        'id': user.id,
        'name': name,
        'email': email,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3️⃣ Login otomatis setelah daftar
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Registrasi gagal: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // 🔹 Logout user
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw Exception('Gagal logout: $e');
    }
  }

  // 🔹 Ambil user aktif sekarang
  User? get currentUser => supabase.auth.currentUser;

  // 🔹 Ambil role user dari tabel users
  Future<String> getUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 'society';

    final response = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return response?['role'] ?? 'society';
  }
}
