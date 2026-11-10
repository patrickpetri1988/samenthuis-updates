import 'app_taal.dart';
import 'account_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InlogPagina extends StatefulWidget {
  const InlogPagina({super.key});

  @override
  State<InlogPagina> createState() => _InlogPaginaState();
}

class _InlogPaginaState extends State<InlogPagina> {
  final emailController = TextEditingController();
  final wachtwoordController = TextEditingController();

  String gekozenTaal = 'nl';
  String tr(String key) => AppTaal.t(key, gekozenTaal);
  bool registreren = false;
  bool taalGekozen = false;
  bool bezig = false;
  bool ingelogdBlijven = true;
  final _formulierSleutel = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _herstelEmail();
  }

  Future<void> _herstelEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    emailController.text = prefs.getString('laatste_inlog_email') ?? '';
  }

  Future<void> aanmelden() async {
    if (bezig) return;
    if (!(_formulierSleutel.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => bezig = true);

    try {
   if (kIsWeb) {
  await FirebaseAuth.instance.setPersistence(
    ingelogdBlijven ? Persistence.LOCAL : Persistence.SESSION,
  );
}
      final email = emailController.text.trim();
      final wachtwoord = wachtwoordController.text;

      if (registreren) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: wachtwoord,
        );
        await AccountService().stelTaalIn(gekozenTaal);
        AppTaal.wijzig(gekozenTaal);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: wachtwoord,
        );
      }
      // Alleen na succesvol aanmelden het laatst gebruikte e-mailadres bewaren.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('laatste_inlog_email', email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String melding = 'Inloggen is niet gelukt.';

      if (e.code == 'email-already-in-use') {
        melding = 'Dit e-mailadres heeft al een account.';
      } else if (e.code == 'weak-password') {
        melding = 'Kies een sterker wachtwoord.';
      } else if (e.code == 'invalid-email') {
        melding = 'Vul een geldig e-mailadres in.';
      } else if (e.code == 'invalid-credential') {
        melding = 'Controleer je e-mailadres en wachtwoord.';
      }

      messenger.showSnackBar(
        SnackBar(content: Text(melding)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppTaal.scherm('Er ging iets mis. Probeer het opnieuw.')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => bezig = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    wachtwoordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (registreren && !taalGekozen) {
      return Scaffold(
        appBar: AppBar(title: const Text('SamenThuis')),
        body: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.language, size: 72, color: Colors.green),
              const SizedBox(height: 20),
              Text(tr('chooseLanguage'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: gekozenTaal,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('language'), border: OutlineInputBorder()),
                items: AccountTalen.namen.entries.map((item) =>
                  DropdownMenuItem(value: item.key, child: Text(item.value))).toList(),
                onChanged: (value) => setState(() { gekozenTaal = value ?? 'nl'; AppTaal.wijzig(gekozenTaal); }),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => setState(() => taalGekozen = true),
                child: Text(tr('continue'))),
              TextButton(onPressed: () => setState(() => registreren = false),
                child: Text(tr('backToLogin'))),
            ]),
          ),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SamenThuis')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Form(
              key: _formulierSleutel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home, size: 70, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    registreren ? tr('createAccount') : tr('welcome'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (registreren) ...[
                    DropdownButtonFormField<String>(
                      initialValue: gekozenTaal,
                      decoration: InputDecoration(
                        labelText: tr('accountLanguage'), border: OutlineInputBorder()),
                      items: AccountTalen.namen.entries.map((item) =>
                        DropdownMenuItem(value: item.key, child: Text(item.value)))
                          .toList(),
                      onChanged: (waarde) => setState(() =>
                        gekozenTaal = waarde ?? 'nl'),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox.shrink(),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    validator: (waarde) => (waarde ?? '').trim().isEmpty
                        ? tr('enterEmail')
                        : null,
                    decoration: InputDecoration(
                      labelText: tr('email'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                        if (!bezig) aanmelden();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextFormField(
                      controller: wachtwoordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (waarde) => (waarde ?? '').isEmpty
                          ? tr('enterPassword')
                          : null,
                      onFieldSubmitted: (_) => aanmelden(),
                      decoration: InputDecoration(
                        labelText: tr('password'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              if (!registreren)
                CheckboxListTile(
                  title: Text(AppTaal.scherm('Ingelogd blijven (op Android standaard aan)')),
                  value: ingelogdBlijven,
                  onChanged: (waarde) {
                    setState(() => ingelogdBlijven = waarde ?? true);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: bezig ? null : () => aanmelden(),
                child: Text(
                  bezig
                      ? tr('pleaseWait')
                      : registreren
                          ? tr('createAccount')
                          : tr('signIn'),
                ),
              ),
              TextButton(
                onPressed: bezig
                    ? null
                    : () => setState(() { registreren = !registreren; taalGekozen = false; }),
                child: Text(
                  registreren
                      ? tr('haveAccount')
                      : tr('register'),
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
