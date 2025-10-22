class Kost {
  final String id; // UUID
  final String nama;
  final String alamat;
  final double harga;
  final String fasilitas;
  final String gambar;

  Kost({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.harga,
    required this.fasilitas,
    required this.gambar,
  });

  factory Kost.fromMap(Map<String, dynamic> map) {
    return Kost(
      id: map['id'],
      nama: map['nama_kost'],
      alamat: map['alamat'],
      harga: (map['harga'] as num).toDouble(),
      fasilitas: map['fasilitas'] ?? '',
      gambar: map['gambar'] ?? '',
    );
  }
}
