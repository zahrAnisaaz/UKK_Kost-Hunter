import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerProfilePage extends StatefulWidget {
  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  Map? profile;
  File? pickedImage;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() => loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final resp = await supabase.from('users').select().eq('id', user.id).single();
    setState(() {
      profile = resp;
      loading = false;
    });
  }

  Future<void> pickAvatar() async {
    final p = ImagePicker();
    final r = await p.pickImage(source: ImageSource.gallery);
    if (r != null) setState(() => pickedImage = File(r.path));
  }

  Future<void> saveProfile(String name, String phone, String alamat) async {
    final user = supabase.auth.currentUser!;
    String? imageUrl;
    if (pickedImage != null) {
      final fileName = 'owner_${user.id}_${DateTime.now().millisecondsSinceEpoch}_${pickedImage!.path.split('/').last}';
      await supabase.storage.from('kost-images').upload(fileName, pickedImage!);
      imageUrl = supabase.storage.from('kost-images').getPublicUrl(fileName);
    }
    await supabase.from('users').update({
      'nama': name,
      'no_hp': phone,
      'alamat': alamat,
      if (imageUrl != null) 'foto_profil': imageUrl,
    }).eq('id', user.id);
    await loadProfile();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil disimpan')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final user = supabase.auth.currentUser;
    final nama = profile?['nama'] ?? user?.email?.split('@')[0] ?? '';
    final email = profile?['email'] ?? user?.email ?? '';
    final phone = profile?['no_hp'] ?? '';
    final alamat = profile?['alamat'] ?? '';
    final foto = profile?['foto_profil'] ?? null;

    final nameCtrl = TextEditingController(text: nama);
    final phoneCtrl = TextEditingController(text: phone);
    final alamatCtrl = TextEditingController(text: alamat);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(radius: 48, backgroundImage: pickedImage != null ? FileImage(pickedImage!) : (foto != null ? NetworkImage(foto) as ImageProvider : null), child: foto == null && pickedImage == null ? const Icon(Icons.person, size: 48) : null),
          const SizedBox(height: 12),
          Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: pickAvatar, icon: const Icon(Icons.camera_alt), label: const Text('Ubah Foto')),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'No. HP')),
          TextField(controller: alamatCtrl, decoration: const InputDecoration(labelText: 'Alamat')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => saveProfile(nameCtrl.text.trim(), phoneCtrl.text.trim(), alamatCtrl.text.trim()),
            child: const Text('Simpan Profil'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

