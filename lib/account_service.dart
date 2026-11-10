import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Accountvoorkeuren en bestaande handmatige Premium-toekenningen.
class AccountService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id == null) throw StateError('Log eerst in.');
    return id;
  }

  Stream<bool> volgPremium(String userId) => _db
      .collection('premiumHandmatig').doc(userId).snapshots()
      .map((doc) => doc.data()?['actief'] == true);

  Future<bool> isPremium(String userId) async =>
      (await _db.collection('premiumHandmatig').doc(userId).get())
          .data()?['actief'] == true;

  Future<void> stelTaalIn(String taal) async {
    if (!AccountTalen.codes.contains(taal)) {
      throw ArgumentError('Deze taal wordt nog niet ondersteund.');
    }
    await _db.collection('gebruikers').doc(uid)
        .set({'taal': taal}, SetOptions(merge: true));
  }

  Stream<String> volgTaal() => _db.collection('gebruikers').doc(uid)
      .snapshots().map((doc) => (doc.data()?['taal'] as String?) ?? 'nl');
}

/// Voeg alleen talen toe waarvoor ook alle interfacevertalingen beschikbaar zijn.
class AccountTalen {
  static const namen = <String, String>{
    'nl': 'Nederlands', 'en': 'English', 'de': 'Deutsch',
    'es': 'Español', 'fr': 'Français',
  };  static Set<String> get codes => namen.keys.toSet();
}
