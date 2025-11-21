class ContactModel {
  final String pubKey; // Kunci Identitas (ID Unik)
  final String initials; // Nama Samaran (Max 2 Huruf)
  final int colorCode; // Kode Warna (biar beda-beda tiap orang)

  ContactModel({
    required this.pubKey,
    required this.initials,
    required this.colorCode,
  });

  // Ubah dari Map (Database) ke Object
  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      pubKey: map['pub_key'],
      initials: map['initials'],
      colorCode: map['color_code'],
    );
  }

  // Ubah dari Object ke Map (Database)
  Map<String, dynamic> toMap() {
    return {
      'pub_key': pubKey,
      'initials': initials,
      'color_code': colorCode,
    };
  }
}
