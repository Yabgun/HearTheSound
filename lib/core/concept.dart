/// Bir dersin "kavram kartı" — o derste neyin ne anlama geldiğini anlatan kısa
/// öğretici içerik.
///
/// Pedagoji ilkesi: **test'ten önce öğret.** Kullanıcı derse gelince (öğren
/// ekranındaki kart) ya da ana ekrandaki bilgi simgesinden dilediği zaman okur.
///
/// Kural: eklenen HER içerik tipinin (nota, akor, aralık, yedili, işlev…) bir
/// kavram kartı olmalı — kullanıcı neyi neden çalıştığını bilmeli.
class Concept {
  final String title;
  final List<ConceptSection> sections;
  const Concept({required this.title, required this.sections});
}

/// Kavram kartının bir bölümü — opsiyonel küçük başlık + gövde metni.
class ConceptSection {
  final String? heading;
  final String body;
  const ConceptSection(this.body, {this.heading});
}
