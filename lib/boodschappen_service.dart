import 'package:cloud_firestore/cloud_firestore.dart';


/// Lokale productherkenning. Onbekende producten komen bij Overige.
class ProductCategorie {
  static const categorieen = <String>[
    'Groente en fruit', 'Broodbeleg', 'Brood', 'Koeling',
    'Diepvries', 'Vlees en vis', 'Drinken', 'Huishoudelijk',
    'Snoep en snacks', 'Overige',
  ];

  static String _schoon(String tekst) => tekst.toLowerCase().trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String herken(String naam) {
    final tekst = _schoon(naam);
    if (tekst.isEmpty) return 'Overige';

    // Herkent hele woorden en woordgroepen, niet toevallige stukjes.
    bool heeft(List<String> woorden) => woorden.any((woord) =>
        RegExp(r'(^|\s)' + RegExp.escape(woord) + r'(\s|$)')
            .hasMatch(tekst));

    // Samengestelde namen hebben voorrang: 'snoeptomaatjes' zijn groente,
    // 'chocolademelk' is drinken en 'diepvriespizza' is diepvries.
    if (heeft(['diepvries', 'diepvriespizza', 'diepvriesgroenten',
      'diepvriespatat', 'diepvriesfriet', 'diepvriesmaaltijd',
      'diepvriesmaaltijden', 'diepvriesvis', 'bevroren', 'vries',
      'roomijs', 'waterijs', 'schepijs', 'ijsjes', 'ijsje', 'ijs',
      'pizza', 'pizzas', 'pizza margherita', 'friet', 'patat',
      'ovenfriet', 'airfryerfriet', 'vissticks', 'kroketten',
      'frikandellen', 'loempia'])) {
      return 'Diepvries';
    }

    if (heeft(['snoeptomaatjes', 'snoep tomaatjes', 'cherrytomaten',
      'kerstomaten', 'tomaatjes', 'sperziebonen', 'snijbonen', 'boontjes',
      'sla', 'tomaat', 'tomaten', 'paprika', 'paprikas', 'komkommer',
      'wortel', 'wortels', 'ui', 'uien', 'knoflook', 'broccoli',
      'bloemkool', 'spinazie', 'courgette', 'aubergine', 'champignons',
      'prei', 'aardappel', 'aardappelen', 'avocado', 'banaan',
      'bananen', 'appel', 'appels', 'peer', 'peren', 'druiven',
      'aardbeien', 'mandarijn', 'mandarijnen', 'sinaasappel',
      'citroen', 'limoen', 'kiwi', 'mango', 'ananas', 'watermeloen',
      'meloen', 'frambozen', 'blauwe bessen', 'bosbessen',
      'fruit', 'groente', 'groenten'])) {
      return 'Groente en fruit';
    }

    if (heeft(['taksi', 'taksi drink', 'chocomelk', 'chocomel',
      'chocolademelk', 'choco melk', 'fristi', 'yoki', 'drinkpakjes',
      'pakjes drinken', 'cola', 'coca cola', 'pepsi', 'ice tea',
      'icetea', 'iceatea', 'iceathea', 'ijsthee', 'fanta', 'sprite',
      'frisdrank', 'limonade', 'water', 'spa', 'bier', 'wijn',
      'koffie', 'thee', 'energydrink', 'energy drink', 'red bull',
      'sap', 'appelsap', 'sinaasappelsap', 'ranja', 'tonic',
      'drinken', 'drank', 'drink', 'smoothie', 'smoothies'])) {
      return 'Drinken';
    }

    if (heeft(['wc papier', 'wc papier rollen', 'toiletpapier',
      'keukenpapier', 'zakdoekjes', 'wasmiddel', 'wasverzachter',
      'afwasmiddel', 'vaatwastabletten', 'schoonmaakmiddel',
      'allesreiniger', 'vuilniszakken', 'afvalzakken', 'toiletblok',
      'spons', 'sponzen', 'shampoo', 'tandpasta', 'zeep',
      'deodorant', 'douchegel', 'huishoudfolie', 'aluminiumfolie',
      'luiers'])) {
      return 'Huishoudelijk';
    }

    // Broodbeleg eerst: 'ham' en 'kipfilet' zijn hier beleg.
    if (heeft(['kaas', 'ham', 'tzatziki', 'boter', 'margarine',
      'halvarine', 'pindakaas', 'hagelslag', 'jam', 'chocopasta',
      'leverworst', 'salami', 'kipfilet', 'rookvlees', 'smeerkaas',
      'hummus', 'humus', 'broodbeleg', 'roomkaas', 'achterham',
      'serranoham'])) {
      return 'Broodbeleg';
    }

    if (heeft(['stokbrood', 'brood', 'boterhammen', 'boterham',
      'bolletjes', 'broodjes', 'worstenbroodjes', 'worstenbroodje',
      'croissant', 'croissants', 'pistolet', 'pistolets', 'beschuit',
      'baguette', 'krentenbol', 'krentenbollen', 'tijgerbrood',
      'toast'])) {
      return 'Brood';
    }

    if (heeft(['kip', 'kippenvlees', 'kippenpoten', 'kipdij',
      'kipdijfilet', 'kipfiletblokjes', 'kip vlees', 'biefstuk',
      'rundvlees', 'rundergehakt', 'gehakt', 'vlees', 'varkensvlees',
      'varkenshaas', 'schnitzel', 'schnitzels', 'karbonade',
      'karbonades', 'speklappen', 'spekjes', 'hamburger',
      'hamburgers', 'worst', 'worsten', 'slavink', 'slavinken',
      'vis', 'zalm', 'tonijn', 'kabeljauw', 'garnalen',
      'makreel', 'tilapia', 'pangasius', 'shoarma', 'gyros'])) {
      return 'Vlees en vis';
    }

    if (heeft(['toetje', 'toetjes', 'vla', 'yoghurt', 'kwark',
      'melk', 'karnemelk', 'slagroom', 'creme fraiche', 'creme',
      'pudding', 'dessert', 'kefir', 'sapje', 'sapjes', 'vers sap',
      'koelvers', 'gekoeld', 'koeling', 'fruitsalade'])) {
      return 'Koeling';
    }

    if (heeft(['chips', 'chocolade', 'chocola', 'snoep', 'snoepjes',
      'drop', 'koekjes', 'koek', 'koeken', 'cake', 'gebak',
      'popcorn', 'winegums', 'pepernoten', 'speculaas', 'nootjes',
      'borrelnoten', 'repen'])) {
      return 'Snoep en snacks';
    }

    return 'Overige';
  }
}

class BoodschappenService {
  final FirebaseFirestore database = FirebaseFirestore.instance;

  // Een persoonlijk ID begint met 'persoonlijk:'. Het is geen huishouden.
  CollectionReference<Map<String, dynamic>> _collectie(String huishoudenId) {
    if (huishoudenId.startsWith('persoonlijk:')) {
      final uid = huishoudenId.substring('persoonlijk:'.length);
      if (uid.isEmpty || uid.contains('/')) {
        throw ArgumentError('Ongeldige persoonlijke lijst.');
      }
      return database.collection('gebruikers').doc(uid).collection('boodschappen');
    }
    return database.collection('huishoudens').doc(huishoudenId).collection('boodschappen');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> volgBoodschappen(String huishoudenId) =>
      _collectie(huishoudenId).snapshots();

  Future<void> voegBoodschapToe(String huishoudenId, String naam, {int aantal = 1, String? categorie}) async {
    if (aantal < 1 || aantal > 999) throw Exception('Aantal moet tussen 1 en 999 liggen.');
    final tekst = naam.trim();
    if (tekst.isEmpty || tekst.length > 150) throw Exception('Gebruik 1 tot 150 tekens.');
    await _collectie(huishoudenId).add({
      'naam': tekst,
      'gekocht': false,
      'aantal': aantal,
      'categorie': categorie ?? ProductCategorie.herken(tekst),
      'categorieHandmatig': categorie != null,
      'aangemaaktOp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> vinkAf(String huishoudenId, String id, bool gekocht) =>
      _collectie(huishoudenId).doc(id).update({'gekocht': gekocht});

  Future<void> verwijder(String huishoudenId, String id) =>
      _collectie(huishoudenId).doc(id).delete();

  Future<void> importeerLokaal(String huishoudenId, String gebruikerId,
      List<Map<String, dynamic>> lokaal) async {
    // Eén atomische batch, met vaste IDs: opnieuw proberen maakt geen dubbelen.
    if (lokaal.length > 400) {
      throw Exception('Meer dan 400 lokale boodschappen: neem eerst contact op.');
    }
    final batch = database.batch();
    for (var i = 0; i < lokaal.length; i++) {
      final naam = (lokaal[i]['naam'] ?? '').toString().trim();
      if (naam.isEmpty || naam.length > 150) continue;
      final doc = _collectie(huishoudenId).doc('import_${gebruikerId}_$i');
      batch.set(doc, {
        'naam': naam,
        'gekocht': lokaal[i]['gekocht'] == true,
        'categorie': ProductCategorie.herken(naam),
        'categorieHandmatig': false,
        'aangemaaktOp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
