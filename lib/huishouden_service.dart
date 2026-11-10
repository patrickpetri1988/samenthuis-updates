import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HuishoudenService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore database = FirebaseFirestore.instance;

  String? get gebruikerId => auth.currentUser?.uid;

  Future<String?> vindMijnHuishouden() async {
    final uid = gebruikerId;
    if (uid == null) return null;
    final resultaat = await database.collection('huishoudens')
        .where('leden', arrayContains: uid).limit(1).get();
    return resultaat.docs.isEmpty ? null : resultaat.docs.first.id;
  }

  Future<String> maakHuishouden() async {
    final uid = gebruikerId;
    if (uid == null) throw Exception('Log eerst in.');
    final bestaand = await vindMijnHuishouden();
    if (bestaand != null) return bestaand;
    final doc = database.collection('huishoudens').doc();
    await doc.set({
      'naam': 'Ons huishouden',
      'eigenaarId': uid,
      'leden': [uid],
      'aangemaaktOp': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> sluitAan(String code) async {
    final uid = gebruikerId;
    if (uid == null) throw Exception('Log eerst in.');
    if (await vindMijnHuishouden() != null) {
      throw Exception('Je zit al in een huishouden.');
    }
    final id = code.trim();
    if (id.isEmpty) throw Exception('Vul de uitnodigingscode in.');
    final ref = database.collection('huishoudens').doc(id);
    await database.runTransaction((transactie) async {
      final snapshot = await transactie.get(ref);
      if (!snapshot.exists) throw Exception('Code niet gevonden.');
      final leden = List<String>.from(snapshot.data()?['leden'] ?? []);
      if (leden.contains(uid)) return;
      final eigenaar = (snapshot.data()?['eigenaarId'] ?? '').toString();
      if (eigenaar.isEmpty) throw Exception('Huishouden heeft geen eigenaar.');
      final premiumDoc = await transactie.get(
          database.collection('premiumHandmatig').doc(eigenaar));
      final limiet = premiumDoc.data()?['actief'] == true ? 5 : 2;
      if (leden.length >= limiet) {
        throw Exception('Dit huishouden heeft maximaal $limiet leden.');
      }
      transactie.update(ref, {'leden': [...leden, uid]});
    });
  }
}

extension HuishoudenBeheer on HuishoudenService {
  Future<void> verwijderLid(String huishoudenId, String lidUid) async {
    final uid = gebruikerId;
    if (uid == null) throw Exception('Log eerst in.');
    final ref = database.collection('huishoudens').doc(huishoudenId);
    await database.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('Huishouden niet gevonden.');
      final data = doc.data()!;
      final eigenaar = data['eigenaarId'] as String;
      final leden = List<String>.from(data['leden'] ?? []);
      if (lidUid == eigenaar) throw Exception('De eigenaar kan niet worden verwijderd.');
      if (uid != eigenaar && uid != lidUid) throw Exception('Geen toestemming.');
      if (!leden.contains(lidUid)) return;
      tx.update(ref, {'leden': leden.where((lid) => lid != lidUid).toList()});
    });
  }

  Future<void> verwijderLeegHuishouden(String huishoudenId) async {
    final uid = gebruikerId;
    if (uid == null) throw Exception('Log eerst in.');
    final ref = database.collection('huishoudens').doc(huishoudenId);
    await database.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('Huishouden niet gevonden.');
      final data = doc.data()!;
      if (data['eigenaarId'] != uid ||
          (data['leden'] as List).length != 1 ||
          data['leden'][0] != uid) {
        throw Exception('Verwijder eerst alle andere gezinsleden.');
      }
      tx.delete(ref);
    });
  }
}
