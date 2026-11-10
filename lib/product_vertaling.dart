import 'app_taal.dart';

/// Offline productwoordenboek. De oorspronkelijke Firestore-tekst blijft intact.
/// Onbekende vrije tekst wordt bewust niet als 'vertaald' voorgesteld.
class ProductVertaling {
  static const _woorden = <String, Map<String, String>>{
    'brood': {'tr':'Ekmek','en':'Bread','de':'Brot','fr':'Pain'},
    'ei': {'tr':'Yumurta','en':'Egg','de':'Ei','fr':'Œuf'},
    'eieren': {'tr':'Yumurtalar','en':'Eggs','de':'Eier','fr':'Œufs'},
    'pizza': {'tr':'Pizza','en':'Pizza','de':'Pizza','fr':'Pizza'},
    'snoep': {'tr':'Şekerleme','en':'Candy','de':'Süßigkeiten','fr':'Bonbons'},
    'toetjes': {'tr':'Tatlılar','en':'Desserts','de':'Nachtisch','fr':'Desserts'},
    'toetje': {'tr':'Tatlı','en':'Dessert','de':'Nachtisch','fr':'Dessert'},
    'melk': {'tr':'Süt','en':'Milk','de':'Milch','fr':'Lait'},
    'kaas': {'tr':'Peynir','en':'Cheese','de':'Käse','fr':'Fromage'},
    'boter': {'tr':'Tereyağı','en':'Butter','de':'Butter','fr':'Beurre'},
    'water': {'tr':'Su','en':'Water','de':'Wasser','fr':'Eau'},
    'koffie': {'tr':'Kahve','en':'Coffee','de':'Kaffee','fr':'Café'},
    'thee': {'tr':'Çay','en':'Tea','de':'Tee','fr':'Thé'},
    'suiker': {'tr':'Şeker','en':'Sugar','de':'Zucker','fr':'Sucre'},
    'zout': {'tr':'Tuz','en':'Salt','de':'Salz','fr':'Sel'},
    'appel': {'tr':'Elma','en':'Apple','de':'Apfel','fr':'Pomme'},
    'appels': {'tr':'Elmalar','en':'Apples','de':'Äpfel','fr':'Pommes'},
    'banaan': {'tr':'Muz','en':'Banana','de':'Banane','fr':'Banane'},
    'bananen': {'tr':'Muzlar','en':'Bananas','de':'Bananen','fr':'Bananes'},
    'tomaat': {'tr':'Domates','en':'Tomato','de':'Tomate','fr':'Tomate'},
    'tomaten': {'tr':'Domatesler','en':'Tomatoes','de':'Tomaten','fr':'Tomates'},
    'aardappelen': {'tr':'Patates','en':'Potatoes','de':'Kartoffeln','fr':'Pommes de terre'},
    'rijst': {'tr':'Pirinç','en':'Rice','de':'Reis','fr':'Riz'},
    'pasta': {'tr':'Makarna','en':'Pasta','de':'Nudeln','fr':'Pâtes'},
    'kip': {'tr':'Tavuk','en':'Chicken','de':'Hähnchen','fr':'Poulet'},
    'vis': {'tr':'Balık','en':'Fish','de':'Fisch','fr':'Poisson'},
    'chocolade': {'tr':'Çikolata','en':'Chocolate','de':'Schokolade','fr':'Chocolat'},
    'ijs': {'tr':'Dondurma','en':'Ice cream','de':'Eis','fr':'Glace'},
    'yoghurt': {'tr':'Yoğurt','en':'Yogurt','de':'Joghurt','fr':'Yaourt'},
  };
  static const _categorieen = <String, Map<String, String>>{
    'Groente en fruit': {'tr':'Sebze ve meyve','en':'Fruit and vegetables','de':'Obst und Gemüse'},
    'Broodbeleg': {'tr':'Ekmek üstü ürünler','en':'Sandwich fillings','de':'Brotbelag'},
    'Brood': {'tr':'Ekmek','en':'Bread','de':'Brot'},
    'Koeling': {'tr':'Soğutulmuş ürünler','en':'Chilled','de':'Kühlprodukte'},
    'Diepvries': {'tr':'Dondurulmuş ürünler','en':'Frozen','de':'Tiefkühlprodukte'},
    'Vlees en vis': {'tr':'Et ve balık','en':'Meat and fish','de':'Fleisch und Fisch'},
    'Drinken': {'tr':'İçecekler','en':'Drinks','de':'Getränke'},
    'Huishoudelijk': {'tr':'Ev ihtiyaçları','en':'Household','de':'Haushalt'},
    'Snoep en snacks': {'tr':'Şekerleme ve atıştırmalıklar','en':'Sweets and snacks','de':'Süßes und Snacks'},
    'Overige': {'tr':'Diğer','en':'Other','de':'Sonstiges'},
  };
  static const _ui = <String, Map<String, String>>{
    'Mogelijke actie': {'tr':'Olası indirim','en':'Possible offer','de':'Mögliches Angebot'},
    'bekijk prijzen': {'tr':'fiyatları gör','en':'view prices','de':'Preise ansehen'},
    'Mogelijke aanbiedingen voor': {'tr':'Olası indirimler:','en':'Possible offers for','de':'Mögliche Angebote für'},
    'Prijs onbekend': {'tr':'Fiyat bilinmiyor','en':'Price unknown','de':'Preis unbekannt'},
    'Sluiten': {'tr':'Kapat','en':'Close','de':'Schließen'},
    'Verwijderen': {'tr':'Sil','en':'Delete','de':'Löschen'},
    'Mijn boodschappen 🛒': {'tr':'Alışveriş listem 🛒','en':'My groceries 🛒','de':'Meine Einkäufe 🛒'},
    'Onze boodschappen 🛒': {'tr':'Alışveriş listemiz 🛒','en':'Our groceries 🛒','de':'Unsere Einkäufe 🛒'},
    'Wat hebben we nodig?': {'tr':'Neye ihtiyacımız var?','en':'What do we need?','de':'Was brauchen wir?'},
    'Aantal': {'tr':'Adet','en':'Quantity','de':'Anzahl'},
    'Categorie': {'tr':'Kategori','en':'Category','de':'Kategorie'},
    'Automatisch': {'tr':'Otomatik','en':'Automatic','de':'Automatisch'},
    'Toevoegen': {'tr':'Ekle','en':'Add','de':'Hinzufügen'},
    'Wordt automatisch gekozen': {'tr':'Otomatik seçilir','en':'Selected automatically','de':'Automatisch ausgewählt'},
    'Handmatig gekozen': {'tr':'Elle seçildi','en':'Selected manually','de':'Manuell ausgewählt'},
    'Nog geen boodschappen. Voeg er eentje toe!': {'tr':'Henüz ürün yok. Bir ürün ekleyin!','en':'No groceries yet. Add one!','de':'Noch keine Einkäufe. Füge etwas hinzu!'},
  };
  static String _taal([String? taal]) => (taal ?? AppTaal.gekozen.value).split('-').first;
  static String product(String origineel, [String? taal]) {
    final woord = origineel.trim().toLowerCase();
    final vertaald = _woorden[woord]?[_taal(taal)];
    if (vertaald == null) return origineel;
    return origineel.isNotEmpty && origineel[0] == origineel[0].toUpperCase()
        ? '${vertaald[0].toUpperCase()}${vertaald.substring(1)}' : vertaald;
  }
  static String categorie(String origineel) => _categorieen[origineel]?[_taal()] ?? origineel;
  static String ui(String origineel) => _ui[origineel]?[_taal()] ?? origineel;

  /// Bij highlights wordt alleen een herkend productwoord vertaald;
  /// merknamen en onbekende beschrijvingen blijven origineel.
  static String aanbieding(String origineel) {
    final woorden = origineel.split(RegExp(r'(\s+)'));
    return woorden.map((woord) => product(woord)).join();
  }
}
