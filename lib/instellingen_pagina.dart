import 'app_taal.dart';
import 'account_service.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InstellingenPagina extends StatefulWidget {
  const InstellingenPagina({super.key, required this.tekstKleur,
    required this.tekstSchaal, required this.achtergrondModus,
    required this.achtergrondKleur, required this.onTekstKleur,
    required this.onTekstSchaal, required this.onAchtergrondKleur});
  final Color? tekstKleur;
  final double tekstSchaal;
  final String achtergrondModus;
  final Color achtergrondKleur;
  final Future<void> Function(Color?) onTekstKleur;
  final Future<void> Function(double) onTekstSchaal;
  final Future<void> Function(Color) onAchtergrondKleur;

  @override
  State<InstellingenPagina> createState() => _InstellingenPaginaState();
}

class _InstellingenPaginaState extends State<InstellingenPagina> {
  late Color? tekstKleur = widget.tekstKleur;
  late double tekstSchaal = widget.tekstSchaal;
  late Color achtergrondKleur = widget.achtergrondKleur;
  String accountTaal = 'nl';
  bool taalOpslaan = false;

  @override
  void initState() {
    super.initState();
    AccountService().volgTaal().first.then((taal) {
      if (mounted) setState(() => accountTaal = AccountTalen.codes.contains(taal) ? taal : 'nl');
    }).catchError((Object _) {});
  }

  static const kleuren = <Color>[
    Color(0xFF172D22), Color(0xFF000000), Color(0xFF164EA6),
    Color(0xFF8C2463), Color(0xFFB34312), Color(0xFFFFFFFF),
  ];
  static const achtergronden = <Color>[
    Color(0xFFE3F2E7), Color(0xFFE1F0FF), Color(0xFFFFE8ED),
    Color(0xFFFFF1CF), Color(0xFFEDE2FF), Color(0xFFE8E8E8),
    Color(0xFFB7E4D2), Color(0xFFFFD7B5),
  ];

  Widget kleurKnoppen(List<Color> opties, Color? geselecteerd,
      Future<void> Function(Color) kiezen) => Wrap(
    spacing: 12, runSpacing: 12,
    children: [for (final kleur in opties)
      Tooltip(message: '#${kleur.toARGB32().toRadixString(16).substring(2)}',
        child: InkWell(
          onTap: () async { await kiezen(kleur); if (mounted) setState(() {}); },
          child: CircleAvatar(backgroundColor: kleur, radius: 23,
            child: geselecteerd?.toARGB32() == kleur.toARGB32()
                ? Icon(Icons.check_circle, color: kleur.computeLuminance() < 0.4
                    ? Colors.white : Colors.black) : null),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppTaal.t('settings'))),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Text(AppTaal.t('accountLanguage'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      DropdownButtonFormField<String>(
        key: ValueKey(accountTaal),
        initialValue: accountTaal,
        items: AccountTalen.namen.entries.map((item) =>
          DropdownMenuItem(value: item.key, child: Text(item.value))).toList(),
        onChanged: taalOpslaan ? null : (waarde) {
          if (waarde != null) setState(() => accountTaal = waarde);
        },
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: taalOpslaan ? null : () async {
          setState(() => taalOpslaan = true);
          try {
            await AccountService().stelTaalIn(accountTaal);
            AppTaal.wijzig(accountTaal);
           if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppTaal.t('languageSaved'))));
          } catch (fout) {
           if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${AppTaal.scherm('Taal opslaan niet gelukt')}: $fout')));
          } finally {
            if (mounted) setState(() => taalOpslaan = false);
          }
        },
        icon: taalOpslaan ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.check),
        label: Text(AppTaal.t('apply')),
      ),
      Text(AppTaal.t('languageHelp')),
      const Divider(height: 32),
      Text(AppTaal.scherm('Tekstkleur'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      kleurKnoppen(kleuren, tekstKleur, (kleur) async {
        tekstKleur = kleur;
        await widget.onTekstKleur(kleur);
      }),
      TextButton.icon(onPressed: () async {
        tekstKleur = null;
        await widget.onTekstKleur(null);
        if (mounted) setState(() {});
      }, icon: const Icon(Icons.restart_alt), label: Text(AppTaal.scherm('Standaard tekstkleur'))),
      const Divider(height: 32),
      Text(AppTaal.scherm('Achtergrondkleur'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      kleurKnoppen(achtergronden, achtergrondKleur, (kleur) async {
        achtergrondKleur = kleur;
        await widget.onAchtergrondKleur(kleur);
      }),
      const Divider(height: 32),
      Text('${AppTaal.scherm('Tekstgrootte')}: ${(tekstSchaal * 100).round()}%',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Slider(min: 0.85, max: 1.4, divisions: 11, value: tekstSchaal,
        label: '${(tekstSchaal * 100).round()}%',
        onChanged: (waarde) => setState(() => tekstSchaal = waarde),
        onChangeEnd: widget.onTekstSchaal),
      TextButton(onPressed: () async {
        setState(() => tekstSchaal = 1.0);
        await widget.onTekstSchaal(1.0);
      }, child: Text(AppTaal.scherm('Normale tekstgrootte'))),
      const Divider(height: 32),
      Text(AppTaal.scherm('Help SamenThuis verbeteren'),
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ListTile(leading: const Icon(Icons.chat_bubble_outline),
        title: Text(AppTaal.scherm('Feedback geven')), trailing: const Icon(Icons.chevron_right),
        onTap: () => _openFormulier('feedback')),
      ListTile(leading: const Icon(Icons.lightbulb_outline),
        title: Text(AppTaal.scherm('Idee insturen')), trailing: const Icon(Icons.chevron_right),
        onTap: () => _openFormulier('idee')),
      ListTile(leading: const Icon(Icons.bug_report_outlined),
        title: Text(AppTaal.scherm('Bug melden')), trailing: const Icon(Icons.chevron_right),
        onTap: () => _openFormulier('bug')),
      const SizedBox(height: 12),
      Text(AppTaal.scherm('Feedback, ideeën en bugmeldingen worden via Formspree verstuurd.')),
    ]),
  );

  void _openFormulier(String soort) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _BerichtFormulier(soort: soort)));
}

class _BerichtFormulier extends StatefulWidget {
  const _BerichtFormulier({required this.soort});
  final String soort;
  @override
  State<_BerichtFormulier> createState() => _BerichtFormulierState();
}

class _BerichtFormulierState extends State<_BerichtFormulier> {
  final _formKey = GlobalKey<FormState>();
  final _onderwerp = TextEditingController();
  final _bericht = TextEditingController();
  bool _bezig = false;
  String? _fout;
  static const _endpoint = 'https://formspree.io/f/xwllrjbr';

  @override
  void dispose() {
    _onderwerp.dispose();
    _bericht.dispose();
    super.dispose();
  }

  Future<void> _verstuur() async {
    if (_bezig || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _bezig = true; _fout = null; });
    try {
      final gebruiker = FirebaseAuth.instance.currentUser;
      if (gebruiker == null) throw Exception('Log eerst in.');
      final antwoord = await http.post(Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'type': widget.soort,
          'subject': _onderwerp.text.trim(),
          '_subject': 'SamenThuis ${widget.soort}: ${_onderwerp.text.trim()}',
          'email': gebruiker.email ?? '',
          'message': _bericht.text.trim()}),
      ).timeout(const Duration(seconds: 20));
      if (antwoord.statusCode != 200 && antwoord.statusCode != 201) {
        throw Exception(antwoord.statusCode == 429
          ? 'Te veel berichten. Probeer het later opnieuw.'
          : 'Versturen niet gelukt (HTTP ${antwoord.statusCode}).');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTaal.scherm('Bedankt! Je bericht is verstuurd.'))));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _fout = '$e');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titel = switch (widget.soort) {
      'feedback' => 'Feedback geven', 'idee' => 'Idee insturen', _ => 'Bug melden',
    };
    return Scaffold(appBar: AppBar(title: Text(titel)),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _onderwerp, maxLength: 100,
          decoration: InputDecoration(labelText: AppTaal.scherm('Onderwerp')),
          validator: (v) => (v ?? '').trim().length < 3 ? 'Vul een onderwerp in.' : null),
        const SizedBox(height: 16),
        TextFormField(controller: _bericht, maxLength: 3000, maxLines: 8,
          decoration: InputDecoration(labelText: AppTaal.scherm('Jouw bericht'), alignLabelWithHint: true),
          validator: (v) => (v ?? '').trim().length < 10 ? 'Schrijf minimaal 10 tekens.' : null),
        if (_fout != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_fout!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _bezig ? null : _verstuur,
          icon: const Icon(Icons.send_outlined),
          label: Text(_bezig ? 'Versturen...' : 'Versturen')),
      ])));
  }
}
