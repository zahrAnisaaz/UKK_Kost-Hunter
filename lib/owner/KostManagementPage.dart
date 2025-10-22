import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KostManagementPage extends StatefulWidget {
  @override
  State<KostManagementPage> createState() => _KostManagementPageState();
}

class _KostManagementPageState extends State<KostManagementPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> kosts = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchKosts();
  }

  Future<void> fetchKosts() async {
    setState(() => loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }
    final resp = await supabase.from('kost').select().eq('owner_id', user.id);
    setState(() {
      kosts = resp;
      loading = false;
    });
  }

  Future<void> showKostForm({Map? edit}) async {
    final namaCtrl = TextEditingController(text: edit?['nama_kost'] ?? '');
    final alamatCtrl = TextEditingController(text: edit?['alamat'] ?? '');
    final descCtrl = TextEditingController(text: edit?['deskripsi'] ?? '');
    final hargaCtrl = TextEditingController(text: edit?['harga']?.toString() ?? '');
    File? pickedImage;

    Future<void> pickImage() async {
      final p = ImagePicker();
      final r = await p.pickImage(source: ImageSource.gallery);
      if (r != null) pickedImage = File(r.path);
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? 'Tambah Kost' : 'Edit Kost'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Kost')),
              TextField(controller: alamatCtrl, decoration: const InputDecoration(labelText: 'Alamat')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi')),
              TextField(controller: hargaCtrl, decoration: const InputDecoration(labelText: 'Harga'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo),
                label: const Text('Pilih Gambar (opsional)'),
                onPressed: () async {
                  await pickImage();
                  if (pickedImage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gambar dipilih')));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final nama = namaCtrl.text.trim();
              if (nama.isEmpty) return;
              Navigator.pop(context);
              final user = supabase.auth.currentUser!;
              try {
                String? imageUrl;
                if (pickedImage != null) {
                  final fileName = 'kost_${DateTime.now().millisecondsSinceEpoch}_${pickedImage!.path.split('/').last}';
                  await supabase.storage.from('kost-images').upload(fileName, pickedImage!);
                  imageUrl = supabase.storage.from('kost-images').getPublicUrl(fileName);
                }
                if (edit == null) {
                  await supabase.from('kost').insert({
                    'owner_id': user.id,
                    'nama_kost': nama,
                    'alamat': alamatCtrl.text,
                    'deskripsi': descCtrl.text,
                    'harga': double.tryParse(hargaCtrl.text) ?? 0,
                    'gambar': imageUrl,
                  });
                } else {
                  await supabase.from('kost').update({
                    'nama_kost': nama,
                    'alamat': alamatCtrl.text,
                    'deskripsi': descCtrl.text,
                    'harga': double.tryParse(hargaCtrl.text) ?? 0,
                    if (imageUrl != null) 'gambar': imageUrl,
                  }).eq('id', edit['id']);
                }
                await fetchKosts();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sukses menyimpan kost')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteKost(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kost'),
        content: const Text('Apakah kamu yakin ingin menghapus kost ini? Semua kamar & data terkait akan terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('kost').delete().eq('id', id);
      await fetchKosts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kost dihapus')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Daftar Kost Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(
                onPressed: () => showKostForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Kost'),
              )
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : kosts.isEmpty
                    ? const Center(child: Text('Belum ada kost'))
                    : ListView.builder(
                        itemCount: kosts.length,
                        itemBuilder: (_, i) {
                          final k = kosts[i];
                          return Card(
                            child: ListTile(
                              leading: k['gambar'] != null ? Image.network(k['gambar'], width: 64, fit: BoxFit.cover) : const Icon(Icons.home_work, size: 48),
                              title: Text(k['nama_kost'] ?? '-'),
                              subtitle: Text('${k['alamat'] ?? '-'}\nRp ${k['harga'] ?? '-'}'),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') showKostForm(edit: k);
                                  if (v == 'delete') deleteKost(k['id']);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}