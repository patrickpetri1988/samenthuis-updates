import 'app_taal.dart';
import 'product_vertaling.dart';
import 'account_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'inlog_pagina.dart';
import 'huishouden_service.dart';
import 'boodschappen_service.dart';
import 'update_service.dart';
import 'gebruikersnaam_service.dart';
import 'huishoudelijke_taken_pagina.dart';
import 'instellingen_pagina.dart';
import 'verjaardagskalender_pagina.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SamenThuisApp());
}

class SamenThuisApp extends StatelessWidget {
  const SamenThuisApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: AppTaal.gekozen,
    builder: (context, taal, _) => MaterialApp(
    title: 'SamenThuis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF23845C)), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF6F9F5), appBarTheme: const AppBarTheme(centerTitle: false), inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const InlogPagina();
        return StreamBuilder<String>(
          stream: AccountService().volgTaal(),
          builder: (context, taalSnapshot) {
            if (taalSnapshot.hasData && AccountTalen.codes.contains(taalSnapshot.data)) {
              if (AppTaal.gekozen.value != taalSnapshot.data) {
                AppTaal.wijzig(taalSnapshot.data!);
              }
            }
            if (snapshot.data!.emailVerified) return const BoodschappenPagina();
            return const EmailVerificatiePagina();
          },
        );
      },
    ),
  ));
}

/// Toegang tot SamenThuis pas na bevestiging van het e-mailadres.
/// Dit verandert geen accounts of gegevens in Firebase.
class EmailVerificatiePagina extends StatefulWidget {
  const EmailVerificatiePagina({super.key});

  @override
  State<EmailVerificatiePagina> createState() => _EmailVerificatiePaginaState();
}

class _EmailVerificatiePaginaState extends State<EmailVerificatiePagina> {
  bool _bezig = false;
  String? _melding;

  Future<void> _controleer() async {
    if (_bezig) return;
    setState(() { _bezig = true; _melding = null; });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final gebruiker = FirebaseAuth.instance.currentUser;
      if (gebruiker?.emailVerified == true) {
        // Een nieuwe token-/authmelding laat het hoofdscherm opnieuw bouwen.
        await gebruiker!.getIdToken(true);
        if (mounted) setState(() {});
      } else if (mounted) {
        setState(() => _melding = 'Je e-mailadres is nog niet bevestigd. Open de link in je mail.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _melding = 'Controleren mislukt: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  Future<void> _opnieuwVersturen() async {
    if (_bezig) return;
    setState(() { _bezig = true; _melding = null; });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) setState(() => _melding = 'Verificatiemail verstuurd. Controleer ook je spammap.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _melding = 'Versturen mislukt: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gebruiker = FirebaseAuth.instance.currentUser;
    if (gebruiker?.emailVerified == true) return const BoodschappenPagina();
    return Scaffold(
      appBar: AppBar(title: Text(AppTaal.scherm('E-mailadres bevestigen'))),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.mark_email_unread_outlined, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(AppTaal.scherm('Bevestig eerst je e-mailadres'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Open de verificatielink in de e-mail voor ${gebruiker?.email ?? 'je account'}. '
              'Controleer ook je spammap.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: _bezig ? null : _controleer,
              child: Text(_bezig ? 'Even wachten...' : 'Ik heb mijn e-mail bevestigd')),
          const SizedBox(height: 8),
          TextButton(onPressed: _bezig ? null : _opnieuwVersturen,
              child: Text(AppTaal.scherm('Verificatiemail opnieuw sturen'))),
          TextButton(onPressed: _bezig ? null : () => FirebaseAuth.instance.signOut(),
              child: Text(AppTaal.scherm('Uitloggen'))),
          if (_melding != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_melding!, textAlign: TextAlign.center),
          ),
        ]),
      )),
    );
  }
}

class BoodschappenPagina extends StatefulWidget {
  const BoodschappenPagina({super.key});
  @override
  State<BoodschappenPagina> createState() => _BoodschappenPaginaState();
}

class _BoodschappenPaginaState extends State<BoodschappenPagina> {
  String _achtergrondModus = 'licht';
  Color _eigenKleur = const Color(0xFFE3F2E7);
  Color? _tekstKleur;
  double _tekstSchaal = 1.0;
  Uint8List? _achtergrondFoto;
  String get _instellingenSleutel => 'uiterlijk_${FirebaseAuth.instance.currentUser?.uid ?? 'gast'}';

  Future<void> _laadUiterlijk() async {
    final prefs = await SharedPreferences.getInstance();
    final sleutel = _instellingenSleutel;
    final modus = prefs.getString('${sleutel}_modus') ?? 'licht';
    final kleur = prefs.getInt('${sleutel}_kleur') ?? 0xFFE3F2E7;
    final foto = prefs.getString('${sleutel}_foto');
    final tekstKleur = prefs.getInt('${sleutel}_tekstkleur');
    final tekstSchaal = prefs.getDouble('${sleutel}_tekstgrootte') ?? 1.0;
    Uint8List? bytes;
    if (foto != null) {
      try { bytes = base64Decode(foto); } catch (_) { bytes = null; }
    }
    if (!mounted) return;
    setState(() {
      _achtergrondModus = modus;
      _eigenKleur = Color(kleur);
      _achtergrondFoto = bytes;
      _tekstKleur = tekstKleur == null ? null : Color(tekstKleur);
      _tekstSchaal = tekstSchaal.clamp(0.85, 1.4);
    });
  }

  Future<void> _bewaarUiterlijk() async {
    final prefs = await SharedPreferences.getInstance();
    final sleutel = _instellingenSleutel;
    await prefs.setString('${sleutel}_modus', _achtergrondModus);
    await prefs.setInt('${sleutel}_kleur', _eigenKleur.toARGB32());
    if (_tekstKleur == null) {
      await prefs.remove('${sleutel}_tekstkleur');
    } else {
      await prefs.setInt('${sleutel}_tekstkleur', _tekstKleur!.toARGB32());
    }
    await prefs.setDouble('${sleutel}_tekstgrootte', _tekstSchaal);
  }

  Future<void> _kiesFoto() async {
    try {
      final bestand = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 60);
      if (bestand == null) return;
      final bytes = await bestand.readAsBytes();
      if (bytes.lengthInBytes > 1500000) {
        _melding('Deze foto is te groot. Kies een kleinere foto.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_instellingenSleutel}_foto', base64Encode(bytes));
      if (!mounted) return;
      setState(() { _achtergrondFoto = bytes; _achtergrondModus = 'foto'; });
      await _bewaarUiterlijk();
    } catch (_) { _melding('Foto kiezen is niet gelukt.'); }
  }

  Future<void> _openInstellingen() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => InstellingenPagina(
        tekstKleur: _tekstKleur,
        tekstSchaal: _tekstSchaal,
        achtergrondModus: _achtergrondModus,
        achtergrondKleur: _eigenKleur,
        onTekstKleur: (kleur) async {
          setState(() => _tekstKleur = kleur);
          await _bewaarUiterlijk();
        },
        onTekstSchaal: (schaal) async {
          setState(() => _tekstSchaal = schaal);
          await _bewaarUiterlijk();
        },
        onAchtergrondKleur: (kleur) async {
          setState(() {
            _eigenKleur = kleur;
            _achtergrondModus = 'kleur';
          });
          await _bewaarUiterlijk();
        },
      ),
    ));
  }

  Future<void> _toonUiterlijk() async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppTaal.scherm('Uiterlijk en achtergrond'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(leading: const Icon(Icons.light_mode), title: Text(AppTaal.scherm('Licht')), onTap: () async {
            setState(() => _achtergrondModus = 'licht'); await _bewaarUiterlijk();
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          ListTile(leading: const Icon(Icons.dark_mode), title: Text(AppTaal.scherm('Donker')), onTap: () async {
            setState(() => _achtergrondModus = 'donker'); await _bewaarUiterlijk();
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(AppTaal.scherm('Kies een achtergrondkleur:'))),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final kleur in <Color>[
              const Color(0xFFE3F2E7), const Color(0xFFE1F0FF),
              const Color(0xFFFFE8ED), const Color(0xFFFFF1CF),
              const Color(0xFFEDE2FF), const Color(0xFFE8E8E8),
              const Color(0xFFB7E4D2), const Color(0xFFFFD7B5),
            ])
              InkWell(onTap: () async {
                setState(() { _eigenKleur = kleur; _achtergrondModus = 'kleur'; });
                await _bewaarUiterlijk();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              }, child: Container(width: 42, height: 42,
                decoration: BoxDecoration(color: kleur, shape: BoxShape.circle,
                  border: Border.all(color: Colors.black38, width: 1.5)))),
          ]),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.add_photo_alternate_outlined),
            title: Text(AppTaal.scherm('Mijn eigen foto kiezen')),
            subtitle: Text(AppTaal.scherm('Alleen op dit apparaat opgeslagen')),
            onTap: () { Navigator.pop(ctx); _kiesFoto(); }),
          if (_achtergrondFoto != null)
            ListTile(leading: const Icon(Icons.delete_outline), title: Text(AppTaal.scherm('Mijn achtergrondfoto verwijderen')),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('${_instellingenSleutel}_foto');
                if (!mounted) return;
                setState(() { _achtergrondFoto = null; _achtergrondModus = 'licht'; });
                await _bewaarUiterlijk();
                if (ctx.mounted) Navigator.pop(ctx);
              }),
        ]),
      )),
    );
  }

  final invoer = TextEditingController();
  final codeInvoer = TextEditingController();
  final aantalInvoer = TextEditingController(text: '1');
  String? gekozenCategorie; // null = automatisch
  static const categorieen = ProductCategorie.categorieen;
  final huishoudens = HuishoudenService();
  final service = BoodschappenService();
  String? huishoudenId;
  String get _boodschappenId => huishoudenId ??
      'persoonlijk:${FirebaseAuth.instance.currentUser!.uid}';
  bool laden = true;
  bool bezig = false;
  int geselecteerdTabblad = 0;
  bool _toonAanbiedingen = false;
  List<Map<String, dynamic>> lokaleBoodschappen = [];
  bool lokaalOvergezet = false;
  Set<String> geselecteerdeWinkels = {'AH', 'LIDL', 'ALDI', 'JUMBO', 'PLUS', 'KRUIDVAT', 'ETOS'};
  final Map<String, Future<List<Map<String, dynamic>>>> _actieCache = {};
  final Map<String, DateTime> _actieCacheTijd = {};

  @override
  void initState() {
    super.initState();
    _start();
    _laadUiterlijk();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.controleer(context);
    });
  }

  Future<void> _start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final opgeslagenWinkels = prefs.getStringList('geselecteerde_winkels');
      if (opgeslagenWinkels != null && mounted) {
        final gekozen = opgeslagenWinkels.toSet();
        // Eenmalig de twee nieuwe winkels inschakelen bij bestaande installaties.
        if (prefs.getBool('drogisterijen_toegevoegd_v1') != true) {
          gekozen.addAll({'KRUIDVAT', 'ETOS'});
          await prefs.setStringList('geselecteerde_winkels', gekozen.toList());
          await prefs.setBool('drogisterijen_toegevoegd_v1', true);
        }
        setState(() => geselecteerdeWinkels = gekozen);
      }
      final json = prefs.getString('boodschappen');
      final lijst = json == null ? <dynamic>[] : jsonDecode(json) as List;
      final lokaal = lijst.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final overgezet = prefs.getBool('firebase_import_$uid') ?? false;
      final id = await huishoudens.vindMijnHuishouden();
      if (!mounted) return;
      setState(() {
        lokaleBoodschappen = lokaal;
        lokaalOvergezet = overgezet;
        huishoudenId = id;
        laden = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => laden = false);
      _melding('Laden mislukt: $e');
    }
  }

  void _melding(String bericht) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bericht)));
  }

  Future<void> _actie(Future<void> Function() taak) async {
    if (bezig) return;
    setState(() => bezig = true);
    try {
      await taak();
    } catch (e) {
      _melding('Niet gelukt: $e');
    } finally {
      if (mounted) setState(() => bezig = false);
    }
  }

  Future<void> _maakHuishouden() => _actie(() async {
    final id = await huishoudens.maakHuishouden();
    if (mounted) setState(() => huishoudenId = id);
    _melding('Huishouden is klaar!');
  });

  Future<void> _sluitAan() => _actie(() async {
    await huishoudens.sluitAan(codeInvoer.text);
    codeInvoer.clear();
    await _start();
    _melding('Je bent aangesloten bij het huishouden!');
  });

  Future<void> _openHuishouden() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HuishoudenPagina(
        huishoudenId: huishoudenId,
        onMaak: _maakHuishouden,
        onSluitAan: _sluitAan,
        codeInvoer: codeInvoer,
        bezig: () => bezig,
        onVernieuw: _start,
      ),
    ));
    if (mounted) await _start();
  }

  Future<void> _importeer() => _actie(() async {
    final id = _boodschappenId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await service.importeerLokaal(id, uid, lokaleBoodschappen);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firebase_import_$uid', true);
    if (mounted) setState(() => lokaalOvergezet = true);
    _melding('Boodschappen overgezet! Lokale kopie is bewaard.');
  });

  Future<void> _toonGebruikersnaam() async {
    final naamService = GebruikersnaamService();
    try {
      final bestaand = await naamService.huidigeNaam();
      if (!mounted) return;
      if (bestaand != null) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: Text(AppTaal.scherm('Mijn gebruikersnaam')),
          content: Text('Je gebruikersnaam is: $bestaand\nWijzigen? Gebruik Hulp & Support.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ProductVertaling.ui('Sluiten')))],
        ));
        return;
      }
      final controller = TextEditingController();
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(AppTaal.scherm('Kies je gebruikersnaam')),
        content: TextField(controller: controller, maxLength: 20,
          decoration: InputDecoration(hintText: AppTaal.scherm('bijv. patrick1988'),
            helperText: AppTaal.scherm('3-20 tekens, letters/cijfers/underscore'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTaal.scherm('Later'))),
          FilledButton(onPressed: () async {
            final fout = GebruikersnaamService.controleer(controller.text);
            if (fout != null) { _melding(fout); return; }
            try {
              await naamService.kiesNaam(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
              _melding('Gebruikersnaam opgeslagen!');
            } catch (_) {
              _melding('Naam is mogelijk al bezet, of opslaan is niet toegestaan.');
            }
          }, child: Text(AppTaal.scherm('Opslaan'))),
        ],
      ));
      controller.dispose();
    } catch (_) { _melding('Gebruikersnaam ophalen is niet gelukt.'); }
  }

  Future<void> _toonPremium() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SamenThuisPremiumPagina()),
    );
  }

  Future<void> _toonPremiumBeheer() async {
    if (FirebaseAuth.instance.currentUser?.uid !=
        'HhX3KZonPzdluxL0B8RJ42Bpdsf2') {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const SamenThuisPremiumBeheerPagina(),
    ));
  }

  Future<void> _openSupport() async {
    final uri = Uri(scheme: 'mailto', path: 'nlpatrickpetri@gmail.com',
      queryParameters: {'subject': 'SamenThuis - Support'});
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _melding('Geen e-mailapp gevonden. Mail naar nlpatrickpetri@gmail.com');
      }
    } catch (_) {
      _melding('Mail naar nlpatrickpetri@gmail.com');
    }
  }

  Future<void> _voegToe() async {
    final id = _boodschappenId;
    final tekst = invoer.text.trim();
    if (tekst.isEmpty) return;
    final aantal = int.tryParse(aantalInvoer.text.trim());
    if (aantal == null || aantal < 1 || aantal > 999) {
      _melding('Vul een aantal tussen 1 en 999 in.');
      return;
    }
    await _actie(() async {
      await service.voegBoodschapToe(id, tekst, aantal: aantal, categorie: gekozenCategorie);
      invoer.clear();
      aantalInvoer.text = '1';
      if (mounted) setState(() => gekozenCategorie = null);
    });
  }

  @override
  void dispose() {
    invoer.dispose();
    codeInvoer.dispose();
    aantalInvoer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = huishoudenId;
    final boodschappenId = _boodschappenId;
    final donker = _achtergrondModus == 'donker';
    final kleur = donker ? const Color(0xFF20252C) :
      _achtergrondModus == 'kleur' ? _eigenKleur : const Color(0xFFF6F9F5);
    final basisThema = ThemeData(
      useMaterial3: true,
      brightness: donker ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF23845C),
        brightness: donker ? Brightness.dark : Brightness.light,
      ),
    );
    return Theme(
      // Bouw een volledige donkere of lichte ThemeData. Een lichte theme
      // kopiëren en alleen brightness wijzigen laat zwarte tekst achter.
      data: ThemeData(
        useMaterial3: true,
        brightness: donker ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF23845C),
          brightness: donker ? Brightness.dark : Brightness.light,
        ),
        textTheme: basisThema.textTheme.apply(
          fontSizeFactor: _tekstSchaal,
          bodyColor: _tekstKleur,
          displayColor: _tekstKleur,
        ),
        primaryTextTheme: basisThema.primaryTextTheme.apply(fontSizeFactor: _tekstSchaal),
        scaffoldBackgroundColor: kleur,
        cardColor: donker ? const Color(0xFF303943) : Colors.white,
        cardTheme: CardThemeData(
          color: donker ? const Color(0xFF303943) : Colors.white,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: donker ? const Color(0xFF303943) : Colors.green.shade100,
          foregroundColor: donker ? Colors.white : const Color(0xFF172D22),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      child: Builder(builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(AppTaal.scherm('SamenThuis 🏠'), style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: donker ? const Color(0xFF303943) : Colors.green.shade100,
        actions: [
          IconButton(
            tooltip: AppTaal.scherm('Huishouden'),
            icon: const Icon(Icons.home_outlined),
            onPressed: laden ? null : _openHuishouden,
          ),
          if (geselecteerdTabblad == 0 && !_toonAanbiedingen)
            IconButton(
              tooltip: 'Winkelmodus openen',
              icon: const Icon(Icons.shopping_basket_outlined),
              onPressed: () => _openWinkelmodus(boodschappenId),
            ),
          if (id != null) IconButton(
            icon: const Icon(Icons.copy), tooltip: 'Uitnodigingscode kopiëren',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: id));
              _melding('Uitnodigingscode gekopieerd. Deel hem alleen met vertrouwde gezinsleden.');
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu', icon: const Icon(Icons.menu),
            onSelected: (keuze) async {
              switch (keuze) {
                case 'huishouden': await _openHuishouden();
                case 'naam': await _toonGebruikersnaam();
                case 'instellingen': await _openInstellingen();
                case 'uiterlijk': await _toonUiterlijk();
                case 'updates': if (mounted) await UpdateService.controleer(context, toonOokGeenUpdate: true);
                case 'support': await _openSupport();
                case 'premium': await _toonPremium();
                case 'premium_beheer': await _toonPremiumBeheer();
                case 'uitloggen':
                  final email = FirebaseAuth.instance.currentUser?.email;
                  if (email != null && email.isNotEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('laatste_inlog_email', email);
                  }
                  await FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'huishouden', child: ListTile(leading: const Icon(Icons.home_outlined), title: Text(AppTaal.scherm('Huishouden')))),
              PopupMenuItem(value: 'instellingen', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text(AppTaal.scherm('Instellingen')))),
              PopupMenuItem(value: 'naam', child: ListTile(leading: Icon(Icons.person_outline), title: Text(AppTaal.scherm('Mijn gebruikersnaam')))),
              PopupMenuItem(value: 'uiterlijk', child: ListTile(leading: const Icon(Icons.palette_outlined), title: Text(AppTaal.scherm('Uiterlijk en achtergrond')))),
              PopupMenuItem(value: 'updates', child: ListTile(leading: Icon(Icons.system_update_alt), title: Text(AppTaal.scherm('Controleren op updates')))),
              PopupMenuItem(value: 'premium', child: ListTile(leading: Icon(Icons.workspace_premium_outlined), title: Text(AppTaal.scherm('SamenThuis Premium')))),
              if (FirebaseAuth.instance.currentUser?.uid ==
                  'HhX3KZonPzdluxL0B8RJ42Bpdsf2')
                PopupMenuItem(value: 'premium_beheer',
                  child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text(AppTaal.scherm('Premium beheren')))),
              PopupMenuItem(value: 'support', child: ListTile(leading: Icon(Icons.support_agent), title: Text(AppTaal.scherm('Hulp & Support')))),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'uitloggen', child: ListTile(leading: Icon(Icons.logout), title: Text(AppTaal.scherm('Uitloggen')))),
            ],
          ),
        ],
      ),
      body: Builder(builder: (themedContext) => Stack(fit: StackFit.expand, children: [
        if (_achtergrondModus == 'foto' && _achtergrondFoto != null)
          Image.memory(_achtergrondFoto!, fit: BoxFit.cover),
        if (_achtergrondModus == 'foto' && _achtergrondFoto != null)
          Container(color: Colors.white.withValues(alpha: 0.70)),
        laden ? const Center(child: CircularProgressIndicator())
          : (geselecteerdTabblad == 0
              ? Column(children: [
                  // Huishouden staat bewust bovenaan het hoofdscherm.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: laden ? null : _openHuishouden,
                        icon: const Icon(Icons.home_outlined),
                        label: Text(AppTaal.scherm('Huishouden')),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, icon: Icon(Icons.shopping_cart_outlined), label: Text(AppTaal.scherm('Boodschappen'))),
                      ButtonSegment(value: true, icon: Icon(Icons.local_offer_outlined), label: Text(AppTaal.scherm('Aanbiedingen'))),
                    ],
                    selected: {_toonAanbiedingen},
                    onSelectionChanged: (keuze) => setState(() => _toonAanbiedingen = keuze.first),
                  )),
                  Expanded(child: _toonAanbiedingen
                      ? _premiumTab(id ?? '', const Icon(Icons.local_offer_outlined), AppTaal.scherm('Aanbiedingen'), _aanbiedingen(themedContext))
                      : _boodschappen(boodschappenId, themedContext)),
                ])
              : geselecteerdTabblad == 1
                  ? (id == null ? _geenHuishouden() : _premiumTab(id, const Icon(Icons.cleaning_services_outlined), AppTaal.scherm('Taken'),
                      HuishoudelijkeTakenPagina(huishoudenId: id)))
                  : (id == null ? _geenHuishouden() : _premiumTab(id, const Icon(Icons.cake_outlined), AppTaal.scherm('Verjaardagen'),
                      VerjaardagskalenderPagina(huishoudenId: id)))),
      ])),
      bottomNavigationBar: !laden && id != null
          ? NavigationBar(
              selectedIndex: geselecteerdTabblad,
              onDestinationSelected: (index) => setState(() => geselecteerdTabblad = index),
              destinations: [
                NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: AppTaal.scherm('Boodschappen')),
                NavigationDestination(icon: Icon(Icons.cleaning_services_outlined), selectedIcon: Icon(Icons.cleaning_services), label: AppTaal.scherm('Taken')),
                NavigationDestination(icon: Icon(Icons.cake_outlined), selectedIcon: Icon(Icons.cake), label: AppTaal.scherm('Verjaardagen')),
              ],
            )
          : null,
    )));
  }

  Future<void> _openAanbiedingen(String adres) async {
    final uri = Uri.parse(adres);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _melding('De aanbiedingenpagina kon niet worden geopend.');
      }
    } catch (_) {
      _melding('De aanbiedingenpagina kon niet worden geopend.');
    }
  }

  Future<void> _testAanbiedingenApi() async {
    try {
  final uri = Uri.parse('https://samenthuis-aanbiedingen.patrick-petri-1988.workers.dev/aanbiedingen?q=koffie');
      final antwoord = await http.get(uri).timeout(const Duration(seconds: 15));
      if (antwoord.statusCode != 200) {
        _melding('Verbinding mislukt: HTTP ${antwoord.statusCode}');
        return;
      }
      final gegevens = jsonDecode(antwoord.body) as Map<String, dynamic>;
      final totaal = gegevens['total'];
      final resultaten = gegevens['results'];
      if (resultaten is! List) {
        _melding('Verbinding gelukt, maar onverwachte gegevens ontvangen.');
        return;
      }
      _melding('Verbinding gelukt! $totaal koffieaanbiedingen gevonden.');
    } catch (e) {
      _melding('Verbinding niet gelukt: $e');
    }
  }

  // Alleen een zoekhulp: de API kan ook andere productvarianten teruggeven.
  static const _winkels = <String, String>{
    'albert_heijn': 'AH', 'ah': 'AH',
    'lidl': 'LIDL', 'aldi': 'ALDI',
    'jumbo': 'JUMBO', 'plus': 'PLUS',
    'kruidvat': 'KRUIDVAT', 'etos': 'ETOS',
  };

  Future<void> _kiesWinkel(String winkel, bool gekozen) async {
    setState(() {
      if (gekozen) {
        geselecteerdeWinkels.add(winkel);
      } else {
        geselecteerdeWinkels.remove(winkel);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('geselecteerde_winkels', geselecteerdeWinkels.toList());
  }

  String _normaliseer(String tekst) => tekst.toLowerCase().trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  Future<List<Map<String, dynamic>>> _zoekActies(String product) {
    final sleutel = _normaliseer(product);
    if (sleutel.length < 2) return Future.value([]);
    final nu = DateTime.now();
    final tijd = _actieCacheTijd[sleutel];
    if (tijd != null && nu.difference(tijd) < const Duration(minutes: 20)) {
      return _actieCache[sleutel]!;
    }
    _actieCacheTijd[sleutel] = nu;
    final toekomst = _haalActiesOp(sleutel);
    _actieCache[sleutel] = toekomst;
    return toekomst;
  }

  Future<List<Map<String, dynamic>>> _haalActiesOp(String zoekterm) async {
    try {
      final uri = Uri.https(
        'samenthuis-aanbiedingen.patrick-petri-1988.workers.dev',
        '/aanbiedingen', {'q': zoekterm},
      );
      final antwoord = await http.get(uri).timeout(const Duration(seconds: 15));
      if (antwoord.statusCode != 200) return [];
      final data = jsonDecode(antwoord.body);
      if (data is! Map || data['results'] is! List) return [];
      final woorden = zoekterm.split(' ').where((w) => w.length >= 2).toList();
      final vandaag = DateTime.now();
      final dag = DateTime(vandaag.year, vandaag.month, vandaag.day);
      final gevonden = <Map<String, dynamic>>[];
      for (final item in data['results'] as List) {
        if (item is! Map) continue;
        final actie = Map<String, dynamic>.from(item);
        final winkel = _winkels[(actie['retailer'] ?? '').toString().toLowerCase()];
        if (winkel == null || actie['is_promotional'] != true) continue;
        if ((actie['promotion_status'] ?? '').toString().toLowerCase() != 'active') continue;
        final naam = _normaliseer((actie['name'] ?? '').toString());
       if (!woorden.every((woord) =>
    naam.contains(woord) ||
    (woord == 'koffie' &&
        (naam.contains('latte') || naam.contains('cappuccino'))))) {
  continue;
}
        final vanaf = DateTime.tryParse((actie['valid_from'] ?? '').toString());
        final tot = DateTime.tryParse((actie['valid_until'] ?? '').toString());
        if (vanaf == null || tot == null) continue;
        if (dag.isBefore(DateTime(vanaf.year, vanaf.month, vanaf.day)) ||
            dag.isAfter(DateTime(tot.year, tot.month, tot.day))) {
          continue;
        }
        actie['_winkelAfkorting'] = winkel;
        gevonden.add(actie);
      }
      return gevonden;
    } catch (_) {
      return [];
    }
  }

  Widget _titelMetActies(String naam, int aantal, bool gekocht, BuildContext context) {
    final stijl = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      decoration: gekocht ? TextDecoration.lineThrough : null,
    );
    if (gekocht || _normaliseer(naam).length < 2) {
      return Text('$aantal× ${ProductVertaling.product(naam)}', style: stijl);
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _zoekActies(naam),
      builder: (context, snapshot) {
        final acties = (snapshot.data ?? []).where((a) =>
            geselecteerdeWinkels.contains(a['_winkelAfkorting'])).toList();
        if (acties.isEmpty) return Text('$aantal× ${ProductVertaling.product(naam)}', style: stijl);
        final winkels = acties.map((a) => a['_winkelAfkorting'].toString()).toSet().toList()..sort();
        return InkWell(
          onTap: () => _toonActies(naam, acties),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$aantal× ${ProductVertaling.product(naam)}', style:  TextStyle(
              color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            Text('${ProductVertaling.ui('Mogelijke actie')}: ${winkels.join(' · ')}  •  ${ProductVertaling.ui('bekijk prijzen')}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
          ]),
        );
      },
    );
  }

  Future<void> _toonActies(String naam, List<Map<String, dynamic>> acties) async {
    await showDialog<void>(
      context: context,
      builder: (dialoogContext) => AlertDialog(
        title: Text('${ProductVertaling.ui('Mogelijke aanbiedingen voor')} ${ProductVertaling.product(naam)}'),
        content: SizedBox(
          width: 500,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: acties.length,
            itemBuilder: (context, index) {
              final actie = acties[index];
              final prijs = actie['price'];
              final prijsTekst = prijs is num ? '€ ${prijs.toStringAsFixed(2).replaceAll('.', ',')}' : ProductVertaling.ui('Prijs onbekend');
              final url = (actie['product_url'] ?? '').toString();
              return ListTile(
                title: Text(ProductVertaling.aanbieding((actie['name'] ?? '').toString())),
                subtitle: Text('${actie['_winkelAfkorting']} · $prijsTekst · t/m ${actie['valid_until']}'),
                trailing: const Icon(Icons.open_in_new),
                onTap: url.startsWith('https://') ? () => _openAanbiedingen(url) : null,
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialoogContext), child: Text(ProductVertaling.ui('Sluiten')))],
      ),
    );
  }

  // Alleen zichtbaar in de webversie voor het beheerdersaccount.
  bool get _toonBeheerderTest => kIsWeb &&
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ==
          'nlpatrickpetri@gmail.com';

  Widget _aanbiedingen(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(AppTaal.scherm('Reclamefolders van deze week 🏷️'),
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(AppTaal.scherm('Vink de winkels aan die je gaat bezoeken. Tik op de winkelnaam om de actuele folder te openen.')),
      const SizedBox(height: 16),
      if (_toonBeheerderTest) ...[
        FilledButton.icon(
          onPressed: _testAanbiedingenApi,
          icon: const Icon(Icons.wifi_tethering),
          label: Text(AppTaal.scherm('Test automatische aanbiedingen')),
        ),
        const SizedBox(height: 16),
      ],
      _supermarkt('AH', 'Albert Heijn', 'AH · Bonusfolder', 'https://folder.ah.nl', context),
      _supermarkt('LIDL', 'Lidl', 'LIDL · Actuele folders', 'https://www.lidl.nl/c/service-contact-folders/s10008124', context),
      _supermarkt('ALDI', 'Aldi', 'ALDI · Folder van deze week', 'https://www.aldi.nl/folders.html', context),
      _supermarkt('JUMBO', 'Jumbo', 'JUMBO · Weekfolder', 'https://www.jumbo.com/acties/weekaanbiedingen', context),
      _supermarkt('PLUS', 'PLUS', 'PLUS · Weekfolder', 'https://www.plus.nl/folder', context),
      _supermarkt('KRUIDVAT', 'Kruidvat', 'Kruidvat · Actuele folder', 'https://folder.kruidvat.nl/', context),
      _supermarkt('ETOS', 'Etos', 'Etos · Actuele folder', 'https://www.etos.nl/folder/', context),
      const SizedBox(height: 16),
      Text(AppTaal.scherm('De folders openen in je browser. Let op de geldigheidsdatum in de folder; aanbiedingen kunnen per winkel verschillen.'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 10),
      Text(AppTaal.scherm('Kruidvat en Etos worden groen gemarkeerd zodra de aanbiedingenserver hun actuele acties teruggeeft. '),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 10),
      Text(AppTaal.scherm('Groene boodschappen hebben mogelijke aanbiedingen. Tik erop om merken, prijzen en winkels te bekijken. De zoekresultaten zijn niet altijd volledig.'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );

  Widget _supermarkt(String afkorting, String naam, String omschrijving, String url, BuildContext context) => Card(
    color: Theme.of(context).cardColor,
    elevation: 0,
    child: ListTile(
      leading: Checkbox(
        value: geselecteerdeWinkels.contains(afkorting),
        onChanged: (waarde) => _kiesWinkel(afkorting, waarde ?? false),
      
      ),
      title: Text(naam, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(omschrijving),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _openAanbiedingen(url),
    ),
  );

  Widget _premiumTab(String huishouden, Widget icoon, String naam, Widget inhoud) {
    final gebruiker = FirebaseAuth.instance.currentUser?.uid;
    if (gebruiker == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<bool>(
      stream: AccountService().volgPremium(gebruiker),
      builder: (context, premiumSnapshot) {
        if (premiumSnapshot.hasError) {
          return Center(
            child: Text('Premium-status laden mislukt: ${premiumSnapshot.error}'),
          );
        }
        if (!premiumSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Premium wordt gecontroleerd voor de ingelogde gebruiker.
        if (premiumSnapshot.data == true) {
          return inhoud;
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icoon,
                const SizedBox(height: 12),
                Text(
                  '$naam ${AppTaal.scherm('is beschikbaar met Premium')}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _toonPremium,
                  child: Text(AppTaal.scherm('Bekijk Premium')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _geenHuishouden() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(AppTaal.scherm('Jouw gratis boodschappenlijst is direct beschikbaar.')),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: bezig ? null : _maakHuishouden,
        icon: const Icon(Icons.home_outlined),
        label: Text(AppTaal.scherm('Gratis huishouden aanmaken (max. 2 personen)')),
      ),
      const SizedBox(height: 8),
      Text(AppTaal.scherm('Met Premium kun je maximaal 5 gezinsleden toevoegen.')),
      TextButton(onPressed: _toonPremium, child: Text(AppTaal.scherm('Bekijk Premium'))),
      Text(AppTaal.scherm('Uitgenodigd? Sluit aan met een huishoudcode.')),
      TextField(controller: codeInvoer,
          decoration: InputDecoration(labelText: AppTaal.scherm('Uitnodigingscode'))),
      const SizedBox(height: 8),
      FilledButton.tonal(onPressed: bezig ? null : _sluitAan,
          child: Text(AppTaal.scherm('Aansluiten'))),
    ]),
  ));

  Widget _boodschappen(String id, BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ProductVertaling.ui(huishoudenId == null ? 'Mijn boodschappen 🛒' : 'Onze boodschappen 🛒'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 6),
        Text(AppTaal.scherm('Samen plannen, samen boodschappen doen.'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (lokaleBoodschappen.isNotEmpty && !lokaalOvergezet)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            Text('Je hebt nog ${lokaleBoodschappen.length} boodschappen op deze telefoon.'),
            Text(AppTaal.scherm('Zet ze één keer over naar de gedeelde lijst.')),
            FilledButton(onPressed: bezig ? null : _importeer, child: Text(AppTaal.scherm('Bestaande boodschappen overzetten'))),
          ]))),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              TextField(controller: invoer, textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: ProductVertaling.ui('Wat hebben we nodig?'), prefixIcon: const Icon(Icons.shopping_basket_outlined)),
                onSubmitted: (_) => _voegToe()),
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(width: 92, child: TextField(controller: aantalInvoer,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: ProductVertaling.ui('Aantal')))),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(
                  key: ValueKey(gekozenCategorie ?? 'automatisch'),
                  initialValue: gekozenCategorie ?? 'Automatisch',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: ProductVertaling.ui('Categorie'),
                    helperText: gekozenCategorie == null
                        ? ProductVertaling.ui('Wordt automatisch gekozen') : ProductVertaling.ui('Handmatig gekozen'),
                  ),
                  items: ['Automatisch', ...categorieen]
                      .map((c) => DropdownMenuItem(value: c,
                          child: Text(c == 'Automatisch' ? ProductVertaling.ui(c) : ProductVertaling.categorie(c), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (c) => setState(() =>
                      gekozenCategorie = c == 'Automatisch' ? null : c),
                )),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: bezig ? null : _voegToe,
                icon: const Icon(Icons.add), label: Text(ProductVertaling.ui('Toevoegen')))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _boodschappenLijst(id)),
      ],
    ),
  );
  // De winkelmodus gebruikt dezelfde live Firebase-lijst als het hoofdscherm.
  // Daardoor blijven afvinken en verwijderen direct gesynchroniseerd.
  Future<void> _openWinkelmodus(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        appBar: AppBar(
          title: Text(AppTaal.scherm('Winkelmodus 🛒')),
          actions: [
            IconButton(
              tooltip: 'Winkelmodus sluiten',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(routeContext).pop(),
            ),
          ],
        ),
        body: StatefulBuilder(
          builder: (winkelContext, vernieuw) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: _boodschappenLijst(id, naActie: () => vernieuw(() {})),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _boodschappenLijst(String id, {VoidCallback? naActie}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.volgBoodschappen(id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${AppTaal.scherm('Firebase-fout')}: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs.toList();
            if (docs.isEmpty) return Center(child: Text(ProductVertaling.ui('Nog geen boodschappen. Voeg er eentje toe!')));
            // Bestaande boodschappen worden ook ingedeeld, zonder Firestore te wijzigen.
            String categorieVoor(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final data = doc.data();
              final opgeslagen = (data['categorie'] ?? '').toString();
              if (data['categorieHandmatig'] == true &&
                  categorieen.contains(opgeslagen)) {
                return opgeslagen;
              }
              return ProductCategorie.herken((data['naam'] ?? '').toString());
            }
            docs.sort((a, b) {
              final ca = categorieVoor(a);
              final cb = categorieVoor(b);
              final compare = categorieen.indexOf(ca).compareTo(categorieen.indexOf(cb));
              return compare != 0 ? compare : a.id.compareTo(b.id);
            });
            final groepen = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
            for (final doc in docs) {
              final cat = categorieVoor(doc);
              groepen.putIfAbsent(cat, () => []).add(doc);
            }
            return ListView(children: [
              for (final groep in groepen.entries) ...[
                Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Text(ProductVertaling.categorie(groep.key), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Theme.of(context).colorScheme.onSurface))),
                for (final doc in groep.value)
                  Card(elevation: 0, color: Theme.of(context).cardColor, child: ListTile(
                    leading: Checkbox(
                      value: doc.data()['gekocht'] == true,
                      onChanged: bezig ? null : (v) async {
                        await _actie(() => service.vinkAf(id, doc.id, v ?? false));
                        naActie?.call();
                      },
                    ),
                    title: _titelMetActies(
                      (doc.data()['naam'] ?? '').toString(),
                      (doc.data()['aantal'] as num?)?.toInt() ?? 1,
                      doc.data()['gekocht'] == true, context,
                    ),
                    trailing: IconButton(
                      tooltip: ProductVertaling.ui('Verwijderen'), icon: const Icon(Icons.delete_outline),
                      onPressed: bezig ? null : () async {
                        await _actie(() => service.verwijder(id, doc.id));
                        naActie?.call();
                      },
                    ),
                  )),
              ],
            ]);
          },
    );
  }

}


/// Premium aanvragen bij de beheerder; geen betaling in de app.
class SamenThuisPremiumPagina extends StatelessWidget {
  const SamenThuisPremiumPagina({super.key});

  @override
  Widget build(BuildContext context) {
    final kleuren = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppTaal.scherm('SamenThuis Premium'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(Icons.workspace_premium_outlined, size: 68, color: kleuren.primary),
              const SizedBox(height: 12),
              Text(AppTaal.scherm('SamenThuis Premium'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(AppTaal.scherm('Op aanvraag beschikbaar'), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Card(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(AppTaal.scherm('€ 0,99 per maand'),
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kleuren.primary)),
                  const SizedBox(height: 6),
                  Text(AppTaal.scherm('Geplande prijs voor de hoofdbeheerder')),
                ]),
              )),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.home_outlined),
                title: Text(AppTaal.scherm('Maak je eigen huishouden aan')),
                subtitle: Text(AppTaal.scherm('Gratis tot 2 personen; Premium tot 5.')),
              ),
              ListTile(
                leading: Icon(Icons.group_outlined),
                title: Text(AppTaal.scherm('Maximaal 5 accounts per huishouden')),
                subtitle: Text(AppTaal.scherm('De hoofdbeheerder betaalt; vier gezinsleden doen gratis mee.')),
              ),
              ListTile(
                leading: Icon(Icons.checklist_outlined),
                title: Text(AppTaal.scherm('Samen alles regelen')),
                subtitle: Text(AppTaal.scherm('Boodschappen en taken; later ook budget en agenda.')),
              ),
              const SizedBox(height: 16),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppTaal.scherm('Boodschappen en een huishouden met 2 personen zijn gratis. Voor Premium vraag je handmatig toegang aan via e-mail of WhatsApp. Vermeld je gebruikersnaam. Er wordt niets automatisch afgeschreven.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kleuren.onSurface)),
              )),
              const SizedBox(height: 16),
              FutureBuilder<String?>(
                future: GebruikersnaamService().huidigeNaam(),
                builder: (context, snapshot) {
                  final naam = snapshot.data;
                  final geldig = naam != null && naam.isNotEmpty;
                  final tekst = 'Hallo, ik wil SamenThuis Premium aanvragen. '
                      'Mijn gebruikersnaam is: ${naam ?? '(nog niet ingesteld)'}. ';
                  return Column(children: [
                    if (!geldig) Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(AppTaal.scherm('Stel eerst via het menu je gebruikersnaam in.')),
                    ),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: geldig ? () => launchUrl(
                        Uri(scheme: 'mailto', path: 'nlpatrickpetri@gmail.com',
                          queryParameters: {'subject': 'SamenThuis Premium aanvragen',
                            'body': tekst}),
                        mode: LaunchMode.externalApplication) : null,
                      icon: const Icon(Icons.email_outlined),
                      label: Text(AppTaal.scherm('Aanvragen via e-mail')),
                    )),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: geldig ? () => launchUrl(
                        Uri.https('wa.me', '/31651779506', {'text': tekst}),
                        mode: LaunchMode.externalApplication) : null,
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(AppTaal.scherm('Aanvragen via WhatsApp')),
                    )),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Alleen de app-eigenaar kan handmatige Premium-toekenningen beheren.
/// De Firestore-regels controleren dit ook op de server.
class SamenThuisPremiumBeheerPagina extends StatefulWidget {
  const SamenThuisPremiumBeheerPagina({super.key});

  @override
  State<SamenThuisPremiumBeheerPagina> createState() =>
      _SamenThuisPremiumBeheerPaginaState();
}

class _SamenThuisPremiumBeheerPaginaState
    extends State<SamenThuisPremiumBeheerPagina> {
  static const beheerderUid = 'HhX3KZonPzdluxL0B8RJ42Bpdsf2';
  final _naamController = TextEditingController();
  String? _gevondenUid;
  String? _gevondenNaam;
  bool _zoeken = false;
  bool _opslaan = false;
  bool? _actief;
  String? _fout;

  bool get _isBeheerder =>
      FirebaseAuth.instance.currentUser?.uid == beheerderUid;

  @override
  void dispose() {
    _naamController.dispose();
    super.dispose();
  }

  Future<void> _zoekGebruiker() async {
    if (!_isBeheerder || _zoeken || _opslaan) return;
    final naam = GebruikersnaamService.normaliseer(_naamController.text);
    final fout = GebruikersnaamService.controleer(naam);
    if (fout != null) {
      setState(() => _fout = fout);
      return;
    }
    setState(() {
      _zoeken = true;
      _fout = null;
      _gevondenUid = null;
      _gevondenNaam = null;
      _actief = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final gebruiker = await db.collection('gebruikersnamen').doc(naam).get();
      if (!gebruiker.exists || gebruiker.data()?['uid'] is! String) {
        if (mounted) setState(() => _fout = 'Gebruikersnaam niet gevonden.');
        return;
      }
      final uid = gebruiker.data()!['uid'] as String;
      final premium = await db.collection('premiumHandmatig').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _gevondenUid = uid;
        _gevondenNaam = naam;
        _actief = premium.data()?['actief'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _fout = 'Opzoeken mislukt: $e');
    } finally {
      if (mounted) setState(() => _zoeken = false);
    }
  }

  Future<void> _wijzigPremium(bool nieuwActief) async {
    final uid = _gevondenUid;
    final naam = _gevondenNaam;
    if (!_isBeheerder || uid == null || naam == null || _opslaan) return;
    final akkoord = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nieuwActief ? 'Premium toekennen?' : 'Premium intrekken?'),
        content: Text(nieuwActief
            ? 'Wil je Premium activeren voor @$naam?'
            : 'Wil je de handmatig toegekende Premium van @$naam intrekken? '
              'Een eventueel betaald abonnement blijft apart bestaan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(nieuwActief ? 'Toekennen' : 'Intrekken')),
        ],
      ),
    );
    if (akkoord != true || !mounted) return;
    setState(() { _opslaan = true; _fout = null; });
    try {
      await FirebaseFirestore.instance.collection('premiumHandmatig').doc(uid).set({
        'actief': nieuwActief,
        'gewijzigdOp': FieldValue.serverTimestamp(),
        'gewijzigdDoor': beheerderUid,
      });
      if (!mounted) return;
      setState(() => _actief = nieuwActief);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(nieuwActief
            ? 'Premium direct geactiveerd voor @$naam. Geen Firebase-aanpassing nodig.'
            : 'Handmatige Premium ingetrokken voor @$naam.'),
      ));
    } catch (e) {
      if (mounted) setState(() => _fout = 'Opslaan mislukt: $e');
    } finally {
      if (mounted) setState(() => _opslaan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppTaal.scherm('Premium beheren'))),
      body: !_isBeheerder
          ? Center(child: Text(AppTaal.scherm('Alleen de app-beheerder heeft toegang.')))
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 60),
                const SizedBox(height: 12),
                Text(AppTaal.scherm('Handmatig Premium beheren'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Zoek een bestaande gebruiker op via de exacte '
                    'gebruikersnaam. Alleen jij kunt Premium activeren '
                    'of intrekken.'),
                const SizedBox(height: 20),
                TextField(
                  controller: _naamController,
                  maxLength: 20,
                  enabled: !_zoeken && !_opslaan,
                  decoration: InputDecoration(
                    labelText: AppTaal.scherm('Gebruikersnaam'),
                    hintText: AppTaal.scherm('bijvoorbeeld patrick1988'),
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  onSubmitted: (_) => _zoekGebruiker(),
                ),
                FilledButton.icon(
                  onPressed: _zoeken || _opslaan ? null : _zoekGebruiker,
                  icon: const Icon(Icons.search),
                  label: Text(_zoeken ? 'Zoeken...' : 'Gebruiker zoeken'),
                ),
                if (_fout != null) Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(_fout!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                if (_gevondenUid != null && _actief != null) ...[
                  const SizedBox(height: 20),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$_gevondenNaam',
                            style: const TextStyle(fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_actief! ? 'Handmatig Premium: actief'
                            : 'Handmatig Premium: niet actief'),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _opslaan ? null : () => _wijzigPremium(!_actief!),
                          icon: Icon(_actief! ? Icons.remove_circle_outline
                              : Icons.workspace_premium_outlined),
                          label: Text(_opslaan ? 'Opslaan...'
                              : _actief! ? 'Premium intrekken'
                              : 'Gratis Premium geven'),
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 18),
                const Text('Let op: dit beheert alleen handmatig toegekende '
                    'Premium. Betaalde abonnementen komen later. '
                    'Huishoudens zijn gratis tot 2 personen; Premium biedt 5 leden en extra functies.'),
              ]),
            )),
    );
  }
}

/// Huishoudbeheer is voor alle gebruikers bereikbaar via het huis-icoon.
class HuishoudenPagina extends StatefulWidget {
  final String? huishoudenId;
  final Future<void> Function() onMaak;
  final Future<void> Function() onSluitAan;
  final TextEditingController codeInvoer;
  final bool Function() bezig;
  final Future<void> Function() onVernieuw;

  const HuishoudenPagina({super.key, required this.huishoudenId,
    required this.onMaak, required this.onSluitAan, required this.codeInvoer,
    required this.bezig, required this.onVernieuw});

  @override
  State<HuishoudenPagina> createState() => _HuishoudenPaginaState();
}

class _HuishoudenPaginaState extends State<HuishoudenPagina> {
  String? _id;
  bool _bezig = false;
  String? _fout;
  final Map<String, String> _namen = {};

  Future<void> _laadNamen(List<String> leden) async {
    final id = _id;
    if (id == null) return;
    final ontbrekend = leden.where((lid) => !_namen.containsKey(lid)).toList();
    if (ontbrekend.isEmpty) return;
    final docs = await Future.wait(ontbrekend.map((lid) =>
      FirebaseFirestore.instance.collection('huishoudens').doc(id)
        .collection('ledenNamen').doc(lid).get()));
    if (!mounted || _id != id) return;
    setState(() {
      for (var i = 0; i < ontbrekend.length; i++) {
        _namen[ontbrekend[i]] = (docs[i].data()?['naam'] as String?) ?? '';
      }
    });
  }

  Future<void> _publiceerEigenNaam() async {
    final id = _id;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;
    final profiel = await FirebaseFirestore.instance.collection('gebruikers').doc(uid).get();
    final naam = profiel.data()?['gebruikersnaam'];
    if (naam is! String || naam.isEmpty) return;
    await FirebaseFirestore.instance.collection('huishoudens').doc(id)
      .collection('ledenNamen').doc(uid).set({'naam': naam});
  }


  @override
  void initState() {
    super.initState();
    _id = widget.huishoudenId;
    _publiceerEigenNaam().catchError((Object _) {});
  }

  Future<void> _actie(Future<void> Function() taak) async {
    if (_bezig) return;
    setState(() { _bezig = true; _fout = null; });
    try {
      await taak();
      await widget.onVernieuw();
      _id = await HuishoudenService().vindMijnHuishouden();
      await _publiceerEigenNaam();
    } catch (e) {
      _fout = e.toString();
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  Future<void> _verwijder(String uid, {required bool isZelf}) async {
    final akkoord = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: Text(AppTaal.scherm(isZelf ? 'Huishouden verlaten?' : 'Gezinslid verwijderen?')),
        content: Text(AppTaal.scherm(isZelf
          ? 'Je verliest toegang tot de gedeelde gegevens van dit huishouden.'
          : 'Dit gezinslid verliest toegang tot de gedeelde gegevens.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTaal.scherm('Annuleren'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppTaal.scherm('Bevestigen'))),
        ],
      ));
    if (akkoord != true || _id == null) return;
    await _actie(() => HuishoudenService().verwijderLid(_id!, uid));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text(AppTaal.scherm('Huishouden'))),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_fout != null) Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Text(_fout!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_id == null) ...[
            Text(AppTaal.scherm('Huishouden maken of deelnemen'),
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _bezig ? null : () => _actie(widget.onMaak),
              icon: const Icon(Icons.add_home_outlined),
              label: Text(AppTaal.scherm('Huishouden aanmaken'))),
            const SizedBox(height: 18),
            TextField(controller: widget.codeInvoer,
              decoration: InputDecoration(labelText: AppTaal.scherm('Uitnodigingscode'))),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: _bezig ? null : () => _actie(widget.onSluitAan),
              child: Text(AppTaal.scherm('Aansluiten'))),
          ] else StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('huishoudens').doc(_id).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('${snapshot.error}');
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (!snapshot.data!.exists) {
                return Text(AppTaal.scherm('Huishouden niet gevonden.'));
              }
              final data = snapshot.data!.data() ?? {};
              final eigenaar = data['eigenaarId']?.toString() ?? '';
              final leden = List<String>.from(data['leden'] ?? []);
              final isEigenaar = uid == eigenaar;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _laadNamen(leden).catchError((Object _) {});
              });
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text((data['naam'] ?? AppTaal.scherm('Huishouden')).toString(),
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('${AppTaal.scherm('Gezinsleden')}: ${leden.length}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _id!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppTaal.scherm('Uitnodigingscode gekopieerd'))),
                    );
                  }
                }, icon: const Icon(Icons.copy),
                  label: Text(AppTaal.scherm('Uitnodigingscode kopiëren'))),
                const SizedBox(height: 12),
                for (final lid in leden) Card(child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(lid == uid ? AppTaal.scherm('Jij') :
                    (_namen[lid]?.isNotEmpty == true ? _namen[lid]! :
                    '${AppTaal.scherm('Gezinslid')} ${lid.substring(0, lid.length < 8 ? lid.length : 8)}')),
                  subtitle: Text(lid == eigenaar ? AppTaal.scherm('Eigenaar') : AppTaal.scherm('Gezinslid')),
                  trailing: _bezig || lid == eigenaar || (!isEigenaar && lid != uid)
                    ? null : IconButton(
                        tooltip: AppTaal.scherm(lid == uid ? 'Huishouden verlaten' : 'Gezinslid verwijderen'),
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => _verwijder(lid, isZelf: lid == uid)),
                )),
                if (isEigenaar && leden.length == 1) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _bezig ? null : () async {
                    final akkoord = await showDialog<bool>(context: context, builder: (ctx) =>
                      AlertDialog(title: Text(AppTaal.scherm('Huishouden verwijderen?')),
                        content: Text(AppTaal.scherm('Dit kan niet ongedaan worden gemaakt.')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppTaal.scherm('Annuleren'))),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppTaal.scherm('Verwijderen'))),
                        ]));
                    if (akkoord == true && _id != null) {
                      await _actie(() => HuishoudenService().verwijderLeegHuishouden(_id!));
                    }
                  }, icon: const Icon(Icons.delete_outline),
                    label: Text(AppTaal.scherm('Huishouden verwijderen'))),
                ],
              ]);
            },
          ),
        ]),
      )),
    );
  }
}
