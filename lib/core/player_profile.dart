// -----------------------------------------------------------------------------
// OYUNCU PROFİLİ — kullanıcının kendi belirlediği kimlik
//
// İlerleme JSON'unun içinde `profile` alt-nesnesi olarak yaşar (AYRI TABLO YOK).
// Böylece bulut senkronu, kayıpsız birleştirme, şema göçü ve "verimi indir"
// dışa aktarımı tek boru hattından geçer — profil için ikinci bir yol kurmayız.
//
// Burada YALNIZCA kullanıcının değiştirebildiği alanlar var. E-posta bilerek
// YOK: onun tek doğru kaynağı oturumun kendisidir (`CloudSync.user?.email`);
// kopyasını tutmak, e-posta değişince yalan söyleyen bir alan yaratırdı.
// -----------------------------------------------------------------------------

class PlayerProfile {
  /// Kullanıcının seçtiği görünen ad; null/boş = henüz belirlemedi.
  final String? displayName;

  /// Avatar (Eko renk varyantı) kimliği — çözümü UI'da (`eko_mascot.dart`).
  ///
  /// Burada sadece STRING tutulur: core katmanı renk bilmez, ayrıca ileride
  /// eklenen bir varyantı tanımayan eski sürüm sessizce varsayılana düşer.
  final String? avatarId;

  /// Uygulamanın ilk açıldığı an ("üyelik tarihi").
  ///
  /// Birleştirmede EN ERKEN olan kazanır (bkz. mergeProfile) — iki cihazdan
  /// hangisi daha önce başladıysa gerçek tarih odur.
  final DateTime? joinedAt;

  const PlayerProfile({this.displayName, this.avatarId, this.joinedAt});

  static const empty = PlayerProfile();

  /// Gösterilecek bir ad var mı? (boşluk-only girişler ad sayılmaz)
  bool get hasDisplayName => (displayName?.trim().isNotEmpty) ?? false;

  PlayerProfile copyWith({
    String? displayName,
    String? avatarId,
    DateTime? joinedAt,
  }) => PlayerProfile(
    displayName: displayName ?? this.displayName,
    avatarId: avatarId ?? this.avatarId,
    joinedAt: joinedAt ?? this.joinedAt,
  );

  Map<String, dynamic> toMap() => {
    if (displayName != null) 'displayName': displayName,
    if (avatarId != null) 'avatarId': avatarId,
    if (joinedAt != null) 'joinedAt': joinedAt!.toUtc().toIso8601String(),
  };

  factory PlayerProfile.fromMap(Map<String, dynamic> map) => PlayerProfile(
    displayName: map['displayName'] as String?,
    avatarId: map['avatarId'] as String?,
    joinedAt: DateTime.tryParse(map['joinedAt'] as String? ?? '')?.toLocal(),
  );
}

/// İki profili KAYIPSIZ birleştirir (bkz. merge_progress.dart felsefesi).
///
///   displayName / avatarId .... dolu olan kazanır; ikisi de doluysa [a]
///                               (çağıran YERELİ a olarak verir → kullanıcının
///                               bu cihazda az önce yazdığı ad kaybolmaz)
///   joinedAt .................. EN ERKEN (üyelik tarihi geriye gitmez)
PlayerProfile mergeProfile(PlayerProfile a, PlayerProfile b) {
  DateTime? earliest(DateTime? x, DateTime? y) {
    if (x == null) return y;
    if (y == null) return x;
    return x.isBefore(y) ? x : y;
  }

  return PlayerProfile(
    displayName: a.hasDisplayName ? a.displayName : b.displayName,
    avatarId: a.avatarId ?? b.avatarId,
    joinedAt: earliest(a.joinedAt, b.joinedAt),
  );
}
