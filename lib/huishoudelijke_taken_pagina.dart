import 'app_taal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Gezinsleden zonder account worden alleen binnen het huishouden opgeslagen.
/// Ingelogde leden kunnen hun eigen profiel aanmaken.
class HuishoudelijkeTakenPagina extends StatefulWidget {
  final String huishoudenId;
  const HuishoudelijkeTakenPagina({super.key, required this.huishoudenId});

  @override
  State<HuishoudelijkeTakenPagina> createState() => _HuishoudelijkeTakenPaginaState();
}

class _HuishoudelijkeTakenPaginaState extends State<HuishoudelijkeTakenPagina> {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get taken =>
      db.collection('huishoudens').doc(widget.huishoudenId).collection('taken');
  DocumentReference<Map<String, dynamic>> get huishouden =>
      db.collection('huishoudens').doc(widget.huishoudenId);
  CollectionReference<Map<String, dynamic>> get gezinsnamen =>
      huishouden.collection('gezinsnamen');
  Map<String, String> _namen = {};

  Future<void> verwijderGezinslid(String lidId, String naam) async {
    if (lidId == uid) {
      bericht('De hoofdbeheerder kan zichzelf niet verwijderen.');
      return;
    }
    final akkoord = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTaal.scherm('Gezinslid verwijderen?')),
        content: Text('$naam verliest toegang tot dit huishouden. Het account, de taken en het logboek blijven bestaan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppTaal.scherm('Uit huishouden verwijderen'))),
        ],
      ),
    );
    if (akkoord != true) return;
    try {
      await db.runTransaction((transactie) async {
        final snapshot = await transactie.get(huishouden);
        final data = snapshot.data();
        if (data == null || data['eigenaarId'] != uid) {
          throw Exception('Alleen de hoofdbeheerder mag leden verwijderen.');
        }
        final leden = List<String>.from(data['leden'] ?? []);
        if (!leden.contains(lidId)) throw Exception('Dit account is geen lid meer.');
        transactie.update(huishouden, {'leden': FieldValue.arrayRemove([lidId])});
      });
      bericht('$naam is uit het huishouden verwijderd.');
    } catch (e) {
      bericht('Gezinslid verwijderen mislukt: $e');
    }
  }

  Future<void> beheerNamen(List<String> leden) async {
    final eigenaar = (await huishouden.get()).data()?['eigenaarId'];
    if (!mounted) return;
    if (eigenaar != uid) { bericht('Alleen de beheerder kan namen wijzigen.'); return; }
    final controllers = {for (final lid in leden) lid: TextEditingController(text: _namen[lid] ?? '')};
    try {
      final opslaan = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text(AppTaal.scherm('Gezinsleden beheren')),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
          for (final lid in leden) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(child: TextField(
                controller: controllers[lid], maxLength: 40,
                decoration: InputDecoration(labelText: lid == uid ? 'Jouw naam' : 'Naam gezinslid ${leden.indexOf(lid) + 1}'),
              )),
              if (lid != uid) IconButton(
                tooltip: 'Uit huishouden verwijderen',
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () {
                  final naam = controllers[lid]!.text.trim().isEmpty ? naamVoor(lid) : controllers[lid]!.text.trim();
                  Navigator.pop(ctx, false);
                  verwijderGezinslid(lid, naam);
                },
              ),
            ]),
          ),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppTaal.scherm('Opslaan')))],
      ));
      if (opslaan != true) return;
      final batch = db.batch();
      for (final lid in leden) {
        final naam = controllers[lid]!.text.trim();
        if (naam.isEmpty) { bericht('Vul voor ieder gezinslid een naam in.'); return; }
        batch.set(gezinsnamen.doc(lid), {'naam': naam, 'gewijzigdDoor': uid,
          'gewijzigdOp': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      bericht('Gezinsnamen opgeslagen!');
    } catch (e) { bericht('Namen opslaan mislukt: $e'); }
    finally { for (final c in controllers.values) { c.dispose(); } }
  }

  CollectionReference<Map<String, dynamic>> get logboek =>
      db.collection('huishoudens').doc(widget.huishoudenId).collection('takenlog');

  void bericht(String tekst) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tekst)));
  }

  Future<void> voegTaakToe(List<String> gezinsleden) async {
    final titel = TextEditingController();
    String? persoonId;
    final resultaat = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialoog) => AlertDialog(
        title: Text(AppTaal.scherm('Nieuwe huishoudelijke taak')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titel, maxLength: 100,
            decoration: InputDecoration(labelText: AppTaal.scherm('Bijvoorbeeld: stofzuigen'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(labelText: AppTaal.scherm('Toewijzen aan')),
            initialValue: persoonId,
            items: [
              DropdownMenuItem(value: '', child: Text(AppTaal.scherm('Nog niemand'))),
              ...gezinsleden.map((p) => DropdownMenuItem(value: p,
                child: Text(naamVoor(p)))),
            ],
            onChanged: (v) => setDialoog(() => persoonId = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () {
            if (titel.text.trim().isEmpty) return;
            Navigator.pop(ctx, {'titel': titel.text.trim(), 'persoon': persoonId ?? ''});
          }, child: Text(AppTaal.scherm('Opslaan'))),
        ],
      )),
    );
    titel.dispose();
    if (resultaat == null) return;
    final id = resultaat['persoon']!;
    final toegewezen = gezinsleden.contains(id);
    try {
      final taakRef = taken.doc();
      final batch = db.batch();
      batch.set(taakRef, {
        'titel': resultaat['titel'], 'toegewezenId': id,
        'toegewezenNaam': toegewezen ? naamVoor(id) : '',
        'klaar': false, 'aangemaaktDoor': uid,
        'aangemaaktOp': FieldValue.serverTimestamp(),
      });
      batch.set(logboek.doc(), {
        'taakId': taakRef.id, 'taak': resultaat['titel'],
        'actie': 'toegevoegd', 'uitgevoerdDoorUid': uid,
        'namensGezinslid': '', 'tijd': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) { bericht('Taak opslaan mislukt: $e'); }
  }

  Future<void> vinkAf(QueryDocumentSnapshot<Map<String, dynamic>> taak,
      List<String> gezinsleden) async {
    final data = taak.data();
    final klaar = data['klaar'] == true;
    // Alle vijf leden mogen elke taak afvinken of opnieuw openen.
    try {
      final batch = db.batch();
      batch.update(taak.reference, {
        'klaar': !klaar,
        'laatstGewijzigdDoor': uid,
        'laatstGewijzigdOp': FieldValue.serverTimestamp(),
      });
      batch.set(logboek.doc(), {
        'taakId': taak.id, 'taak': data['titel'],
        'actie': klaar ? 'opnieuw geopend' : 'afgevinkt',
        'uitgevoerdDoorUid': uid,
        'namensGezinslid': '',
        'tijd': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) { bericht('Afvinken mislukt: $e'); }
  }

  String naamVoor(String id) {
    if ((_namen[id] ?? '').isNotEmpty) return _namen[id]!;
    if (id == uid) return 'Jij';
    return 'Gezinslid ${id.length > 6 ? id.substring(0, 6) : id}';
  }

  Future<void> verwijderTaak(QueryDocumentSnapshot<Map<String, dynamic>> taak) async {
    final bevestiging = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTaal.scherm('Taak verwijderen?')),
        content: Text('De taak "${taak.data()['titel']}" verdwijnt. De geschiedenis blijft bewaard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppTaal.scherm('Verwijderen'))),
        ],
      ));
    if (bevestiging != true) return;
    try {
      final batch = db.batch();
      batch.delete(taak.reference);
      batch.set(logboek.doc(), {
        'taakId': taak.id, 'taak': taak.data()['titel'],
        'actie': 'verwijderd', 'uitgevoerdDoorUid': uid,
        'namensGezinslid': '', 'tijd': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) { bericht('Verwijderen mislukt: $e'); }
  }

  String tijd(Timestamp? t) {
    if (t == null) return 'Zojuist';
    final d = t.toDate().toLocal();
    String twee(int n) => n.toString().padLeft(2, '0');
    return '${twee(d.day)}-${twee(d.month)}-${d.year} ${twee(d.hour)}:${twee(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: huishouden.snapshots(),
    builder: (context, mensenSnapshot) {
      if (mensenSnapshot.hasError) return Center(child: Text('${AppTaal.scherm('Huishouden laden mislukt')}: ${mensenSnapshot.error}'));
      if (!mensenSnapshot.hasData) return const Center(child: CircularProgressIndicator());
      final mensen = List<String>.from(mensenSnapshot.data!.data()?['leden'] ?? []);
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: gezinsnamen.snapshots(),
        builder: (context, namenSnapshot) {
          if (namenSnapshot.hasError) return Center(child: Text('${AppTaal.scherm('Namen laden mislukt')}: ${namenSnapshot.error}'));
          if (!namenSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          _namen = {for (final doc in namenSnapshot.data!.docs) doc.id: (doc.data()['naam'] ?? '').toString()};
          final beheerder = mensenSnapshot.data!.data()?['eigenaarId'] == uid;
          return DefaultTabController(length: 2, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
          Expanded(child: Text(AppTaal.scherm('Huishoudelijke taken 🧹'),
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold))),
          if (beheerder) IconButton(tooltip: 'Gezinsleden beheren',
            icon: const Icon(Icons.manage_accounts_outlined), onPressed: () => beheerNamen(mensen)),
          IconButton(tooltip: 'Taak toevoegen', icon: const Icon(Icons.add_circle_outline),
            onPressed: () => voegTaakToe(mensen)),
        ])),
        if (mensen.isEmpty)
          Padding(padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(AppTaal.scherm('Er zijn nog geen gekoppelde accounts.'))),
        const TabBar(tabs: [Tab(text: 'Taken'), Tab(text: 'Logboek')]),
        Expanded(child: TabBarView(children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: taken.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('${AppTaal.scherm('Taken laden mislukt')}: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final lijst = snapshot.data!.docs.toList()
                ..sort((a, b) => (a.data()['klaar'] == true ? 1 : 0)
                    .compareTo(b.data()['klaar'] == true ? 1 : 0));
              if (lijst.isEmpty) return Center(child: Text(AppTaal.scherm('Nog geen taken. Tik op + om te beginnen.')));
              return ListView.builder(padding: const EdgeInsets.all(12), itemCount: lijst.length,
                itemBuilder: (context, i) {
                  final taak = lijst[i];
                  final data = taak.data();
                  final klaar = data['klaar'] == true;
                  final naam = (data['toegewezenNaam'] ?? '').toString();
                  return Card(child: Row(children: [
                    Expanded(child: CheckboxListTile(
                    value: klaar, onChanged: (_) => vinkAf(taak, mensen),
                    title: Text((data['titel'] ?? '').toString(),
                      style: TextStyle(decoration: klaar ? TextDecoration.lineThrough : null)),
                    subtitle: Text(naam.isEmpty ? 'Nog niet toegewezen' : 'Voor: $naam'),
                    secondary: Icon(klaar ? Icons.task_alt : Icons.cleaning_services_outlined),
                  )),
                    IconButton(tooltip: 'Taak verwijderen', icon: const Icon(Icons.delete_outline),
                      onPressed: () => verwijderTaak(taak)),
                  ]));
                });
            },
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: logboek.orderBy('tijd', descending: true).limit(50).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('${AppTaal.scherm('Logboek laden mislukt')}: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final regels = snapshot.data!.docs;
              if (regels.isEmpty) return Center(child: Text(AppTaal.scherm('Er zijn nog geen activiteiten.')));
              return ListView.builder(itemCount: regels.length, itemBuilder: (context, i) {
                final d = regels[i].data();
                final namens = (d['namensGezinslid'] ?? '').toString();
                final actor = (d['uitgevoerdDoorUid'] ?? '').toString() == uid
                    ? 'Jij' : naamVoor((d['uitgevoerdDoorUid'] ?? '').toString());
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${d['taak']} — ${d['actie']}'),
                  subtitle: Text('$actor${namens.isEmpty ? '' : ' namens $namens'} · ${tijd(d['tijd'] as Timestamp?)}'),
                );
              });
            },
          ),
        ])),
      ]));
        },
      );
    },
  );
}
