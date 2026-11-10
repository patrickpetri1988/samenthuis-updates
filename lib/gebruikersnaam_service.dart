import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gebruikersnamen zijn uniek en na vastleggen niet zelf te wijzigen.
/// E-mailadressen staan NIET in de openbare gebruikersnamen-collectie.
class GebruikersnaamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String normaliseer(String naam) => naam.trim().toLowerCase();

  static String? controleer(String naam) {
    final n = normaliseer(naam);
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(n)) {
      return 'Gebruik 3-20 tekens: letters, cijfers of _.';
    }
    return null;
  }

  Future<String?> huidigeNaam() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('gebruikers').doc(user.uid).get();
    return doc.data()?['gebruikersnaam'] as String?;
  }

  Future<void> kiesNaam(String naam) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Log eerst in.');
    final n = normaliseer(naam);
    final fout = controleer(n);
    if (fout != null) throw FormatException(fout);
    final batch = _db.batch();
    // Geen voorafgaande lookup: Firestore-regels bewaken de uniciteit.
    batch.set(_db.collection('gebruikersnamen').doc(n), {'uid': user.uid});
    batch.set(_db.collection('gebruikers').doc(user.uid),
        {'gebruikersnaam': n}, SetOptions(merge: true));
    await batch.commit();
  }
}
