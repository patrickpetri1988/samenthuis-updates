import 'app_taal.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Gedeelde verjaardagen van één huishouden.
class VerjaardagskalenderPagina extends StatefulWidget {
  final String huishoudenId;
  const VerjaardagskalenderPagina({super.key, required this.huishoudenId});

  @override
  State<VerjaardagskalenderPagina> createState() => _VerjaardagskalenderPaginaState();
}

class _VerjaardagskalenderPaginaState extends State<VerjaardagskalenderPagina> {
  late DateTime _maand;
  DateTime _nu = DateTime.now();
  Timer? _klok;
  int? _geselecteerdeDag;

  CollectionReference<Map<String, dynamic>> get _verjaardagen =>
      FirebaseFirestore.instance.collection('huishoudens')
          .doc(widget.huishoudenId).collection('verjaardagen');

  static const _maanden = [
    'januari', 'februari', 'maart', 'april', 'mei', 'juni',
    'juli', 'augustus', 'september', 'oktober', 'november', 'december',
  ];

  @override
  void initState() {
    super.initState();
    _maand = DateTime(_nu.year, _nu.month);
    // Ververs ook als het scherm open blijft staan rond 00:01.
    _klok = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _nu = DateTime.now());
    });
  }

  @override
  void dispose() {
    _klok?.cancel();
    super.dispose();
  }

  void _wisselMaand(int verschil) => setState(() {
    _maand = DateTime(_maand.year, _maand.month + verschil);
    _geselecteerdeDag = null;
    _nu = DateTime.now();
  });

  bool _isVandaag(int dag) => _maand.year == _nu.year &&
      _maand.month == _nu.month && dag == _nu.day;

  bool get _naMiddernacht => _nu.hour > 0 || _nu.minute >= 1;

  DateTime? _volgendeDatum(int dag, int maand) {
    final vandaag = DateTime(_nu.year, _nu.month, _nu.day);
    for (int jaar = _nu.year; jaar <= _nu.year + 8; jaar++) {
      final datum = DateTime(jaar, maand, dag);
      if (datum.month == maand && datum.day == dag && !datum.isBefore(vandaag)) {
        return datum;
      }
    }
    return null;
  }


  Future<void> _bewerk({QueryDocumentSnapshot<Map<String, dynamic>>? bestaand,
      int? dagVooraf}) async {
    final data = bestaand?.data();
    final naam = TextEditingController(text: (data?['naam'] ?? '').toString());
    int dag = (data?['dag'] as num?)?.toInt() ?? dagVooraf ?? _nu.day;
    int maand = (data?['maand'] as num?)?.toInt() ?? _maand.month;
    bool opslaan = false;
    String? fout;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialoog) => StatefulBuilder(builder: (ctx, wijzig) => AlertDialog(
          title: Text(bestaand == null ? 'Verjaardag toevoegen 🎂' : 'Verjaardag aanpassen'),
          content: SizedBox(width: 360, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: naam, maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: AppTaal.scherm('Naam'))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  key: ValueKey('dag-$maand-$dag'),
                  initialValue: dag,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: AppTaal.scherm('Dag')),
                  items: List.generate(31, (i) => DropdownMenuItem(
                    value: i + 1, child: Text('${i + 1}'))),
                  onChanged: opslaan ? null : (v) { if (v != null) wijzig(() => dag = v); },
                )),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<int>(
                  initialValue: maand,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: AppTaal.scherm('Maand')),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1, child: Text(_maanden[i]))),
                  onChanged: opslaan ? null : (v) { if (v != null) wijzig(() => maand = v); },
                )),
              ]),
              if (fout != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(fout!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: opslaan ? null : () => Navigator.pop(ctx),
                child: Text(AppTaal.scherm('Annuleren'))),
            FilledButton(onPressed: opslaan ? null : () async {
              final waarde = naam.text.trim();
              final geldigeDatum = DateTime(2024, maand, dag);
              if (waarde.isEmpty || waarde.length > 80 ||
                  geldigeDatum.month != maand || geldigeDatum.day != dag) {
                wijzig(() => fout = 'Vul een naam en geldige datum in.');
                return;
              }
              wijzig(() { opslaan = true; fout = null; });
              try {
                final velden = {'naam': waarde, 'dag': dag, 'maand': maand};
                if (bestaand == null) {
                  await _verjaardagen.add({...velden,
                    'aangemaaktOp': FieldValue.serverTimestamp()});
                } else {
                  await _verjaardagen.doc(bestaand.id).update(velden);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  wijzig(() { opslaan = false;
                    fout = 'Opslaan mislukt: $e'; });
                }
              }
            }, child: Text(opslaan ? 'Opslaan...' : 'Opslaan')),
          ],
        )),
      );
    } finally {
      // De dialooganimatie moet klaar zijn voordat de controller weg kan.
      Future.delayed(const Duration(milliseconds: 400), naam.dispose);
    }
  }

  Future<void> _verwijder(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final akkoord = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTaal.scherm('Verjaardag verwijderen?')),
        content: Text('Wil je de verjaardag van ${doc.data()['naam']} verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppTaal.scherm('Verwijderen'))),
        ],
      ));
    if (akkoord != true) return;
    try {
      await _verjaardagen.doc(doc.id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppTaal.scherm('Verwijderen mislukt')}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _verjaardagen.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('${AppTaal.scherm('Verjaardagen laden mislukt')}: ${snapshot.error}')));
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs.where((d) {
        final x = d.data();
        return x['naam'] is String && x['dag'] is num && x['maand'] is num;
      }).toList();
      final vandaagJarig = docs.where((d) =>
          (d.data()['dag'] as num).toInt() == _nu.day &&
          (d.data()['maand'] as num).toInt() == _nu.month).toList();
      final aankomend = <({String naam, DateTime datum})>[];
      for (final doc in docs) {
        final x = doc.data();
        final datum = _volgendeDatum((x['dag'] as num).toInt(), (x['maand'] as num).toInt());
        if (datum != null) aankomend.add((naam: x['naam'] as String, datum: datum));
      }
      aankomend.sort((a, b) => a.datum.compareTo(b.datum));
      final eerstvolgende = aankomend.isEmpty ? null : aankomend.first;
      final dagenTot = eerstvolgende?.datum
          .difference(DateTime(_nu.year, _nu.month, _nu.day)).inDays;
      final eersteWeekdag = DateTime(_maand.year, _maand.month, 1).weekday - 1;
      final aantalDagen = DateTime(_maand.year, _maand.month + 1, 0).day;
      final aantalVakjes = ((eersteWeekdag + aantalDagen + 6) ~/ 7) * 7;
      final gekozen = _geselecteerdeDag;
      final lijst = docs.where((d) =>
          (d.data()['maand'] as num).toInt() == _maand.month &&
          (gekozen == null || (d.data()['dag'] as num).toInt() == gekozen)).toList()
        ..sort((a, b) => (a.data()['dag'] as num).compareTo(b.data()['dag'] as num));
      return ListView(padding: const EdgeInsets.all(10), children: [
        Row(children: [
          Expanded(child: Text(AppTaal.scherm('Verjaardagskalender 🎂'),
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
          IconButton(tooltip: 'Verjaardag toevoegen',
            onPressed: () => _bewerk(dagVooraf: _geselecteerdeDag),
            icon: const Icon(Icons.add_circle_outline)),
        ]),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_naMiddernacht && vandaagJarig.isNotEmpty
                  ? '🎉 Vandaag jarig!'
                  : '🎁 Eerstvolgende verjaardag',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              if (_naMiddernacht && vandaagJarig.isNotEmpty)
                for (final d in vandaagJarig)
                  Text('🎂 Hoera, ${d.data()['naam']} is vandaag jarig!')
              else if (eerstvolgende != null)
                Text('🎂 ${eerstvolgende.naam} — ${eerstvolgende.datum.day} '
                    '${_maanden[eerstvolgende.datum.month - 1]} '
                    '(${dagenTot == 0 ? 'vandaag' : dagenTot == 1 ? 'morgen' : 'over $dagenTot dagen'})')
              else
                Text(AppTaal.scherm('Nog geen verjaardagen toegevoegd.')),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: () => _wisselMaand(-1),
              tooltip: 'Vorige maand', icon: const Icon(Icons.chevron_left)),
            Text('${_maanden[_maand.month - 1]} ${_maand.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => _wisselMaand(1),
              tooltip: 'Volgende maand', icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (final dagNaam in const ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'])
              Expanded(child: Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(dagNaam, style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
              ))),
          ]),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisExtent: 48,
              crossAxisSpacing: 3, mainAxisSpacing: 3),
            itemCount: aantalVakjes,
            itemBuilder: (context, i) {
              final dag = i - eersteWeekdag + 1;
              if (dag < 1 || dag > aantalDagen) return const SizedBox.shrink();
              final jarig = docs.any((d) =>
                  (d.data()['dag'] as num).toInt() == dag &&
                  (d.data()['maand'] as num).toInt() == _maand.month);
              final gekozenDag = _geselecteerdeDag == dag;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _geselecteerdeDag = gekozenDag ? null : dag),
                child: Container(
                  decoration: BoxDecoration(
                    color: gekozenDag ? Theme.of(context).colorScheme.primaryContainer
                      : _isVandaag(dag) ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: _isVandaag(dag) ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2) : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$dag', style: TextStyle(fontSize: 12, fontWeight:
                      _isVandaag(dag) ? FontWeight.bold : FontWeight.normal)),
                    if (jarig) Text(AppTaal.scherm('🎂'), style: TextStyle(fontSize: 12)),
                  ]),
                ),
              );
            },
          ),
        ]))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(gekozen == null ? 'Verjaardagen deze maand'
              : 'Verjaardagen op $gekozen ${_maanden[_maand.month - 1]}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          if (gekozen != null) TextButton(
            onPressed: () => setState(() => _geselecteerdeDag = null),
            child: Text(AppTaal.scherm('Toon alles'))),
        ]),
        if (lijst.isEmpty) Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text(AppTaal.scherm('Geen verjaardagen gevonden. Tik op + om er één toe te voegen.'))),
        for (final doc in lijst) Card(child: ListTile(dense: true,
          leading: Text(AppTaal.scherm('🎂'), style: TextStyle(fontSize: 25)),
          title: Text((doc.data()['naam'] as String)),
          subtitle: Text('${doc.data()['dag']} ${_maanden[(doc.data()['maand'] as num).toInt() - 1]}'),
          onTap: () => _bewerk(bestaand: doc),
          trailing: IconButton(icon: const Icon(Icons.delete_outline),
            tooltip: 'Verwijderen', onPressed: () => _verwijder(doc)),
        )),
      ]);
    },
  );
}
