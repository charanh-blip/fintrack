import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

const brand = Color(0xFF159B68);
const ink = Color(0xFF17213A);
const muted = Color(0xFF7B8499);

bool get firebaseConfigured => true;
String? firebaseStartupError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    firebaseStartupError = e.toString();
  }
  runApp(const FintrackEntryPoint());
}

class FintrackEntryPoint extends StatefulWidget {
  const FintrackEntryPoint({super.key});
  @override
  State<FintrackEntryPoint> createState() => _FintrackEntryPointState();
}

class _FintrackEntryPointState extends State<FintrackEntryPoint> {
  bool guestMode = false;
  @override
  Widget build(BuildContext context) {
    if (guestMode || !firebaseConfigured || firebaseStartupError != null) {
      return guestMode
          ? const FintrackApp()
          : FintrackAuthScreen(
              firebaseAvailable: false,
              onGuest: () => setState(() => guestMode = true));
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
              title: 'Fintrack',
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        final user = snapshot.data;
        return user == null
            ? FintrackAuthScreen(
                firebaseAvailable: true,
                onGuest: () => setState(() => guestMode = true))
            : FintrackApp(user: user);
      },
    );
  }
}

class FintrackAuthScreen extends StatefulWidget {
  const FintrackAuthScreen(
      {super.key, required this.firebaseAvailable, required this.onGuest});
  final bool firebaseAvailable;
  final VoidCallback onGuest;
  @override
  State<FintrackAuthScreen> createState() => _FintrackAuthScreenState();
}

class _FintrackAuthScreenState extends State<FintrackAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  String? _error;
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final credential = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
        await credential.user?.updateDisplayName(_name.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'email-already-in-use' =>
              'An account already exists for this email.',
            'invalid-email' => 'Enter a valid email address.',
            'weak-password' =>
              'Use a stronger password (at least 6 characters).',
            'user-not-found' ||
            'wrong-password' ||
            'invalid-credential' =>
              'Email or password is incorrect.',
            'network-request-failed' =>
              'Network error. Check your connection and try again.',
            _ => e.message ?? 'Authentication failed. Please try again.',
          });
    } catch (_) {
      setState(() => _error = 'Unable to connect. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fintrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: brand),
            useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFF0D1220),
          body: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                              color: const Color(0xFF151B2B),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white12)),
                          child: Form(
                              key: _form,
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                  color: brand,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          13)),
                                              child: const Icon(
                                                  Icons
                                                      .account_balance_wallet_rounded,
                                                  color: Colors.white)),
                                          const SizedBox(width: 12),
                                          const Text('fintrack',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -1))
                                        ]),
                                    const SizedBox(height: 28),
                                    Text(
                                        _register
                                            ? 'Create your account'
                                            : 'Welcome back',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 7),
                                    Text(
                                        _register
                                            ? 'Your personal finances, organised.'
                                            : 'Sign in to access your financial workspace.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Color(0xFF9AA5BD))),
                                    const SizedBox(height: 26),
                                    if (!widget.firebaseAvailable)
                                      Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF352B18),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: const Text(
                                              'Firebase is not configured yet. You can use the guest workspace now, or configure Firebase to enable accounts and cloud sync.',
                                              style: TextStyle(
                                                  color: Color(0xFFFFD58A),
                                                  fontSize: 12,
                                                  height: 1.5))),
                                    if (widget.firebaseAvailable) ...[
                                      if (_register)
                                        TextFormField(
                                            controller: _name,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            decoration: _authDecoration(
                                                'Full name',
                                                Icons.person_outline),
                                            validator: (v) =>
                                                v == null || v.trim().isEmpty
                                                    ? 'Enter your name'
                                                    : null),
                                      if (_register) const SizedBox(height: 12),
                                      TextFormField(
                                          controller: _email,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          decoration: _authDecoration(
                                              'Email address',
                                              Icons.email_outlined),
                                          validator: (v) =>
                                              v == null || !v.contains('@')
                                                  ? 'Enter a valid email'
                                                  : null),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          controller: _password,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          obscureText: _obscure,
                                          decoration: _authDecoration('Password', Icons.lock_outline)
                                              .copyWith(
                                                  suffixIcon: IconButton(
                                                      onPressed: () => setState(
                                                          () => _obscure =
                                                              !_obscure),
                                                      icon: Icon(
                                                          _obscure
                                                              ? Icons
                                                                  .visibility_outlined
                                                              : Icons
                                                                  .visibility_off_outlined,
                                                          color:
                                                              Colors.white60))),
                                          validator: (v) => v == null ||
                                                  v.length < 6
                                              ? 'Password must be at least 6 characters'
                                              : null),
                                      if (_error != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(_error!,
                                                style: const TextStyle(
                                                    color: Color(0xFFFF8585),
                                                    fontSize: 12))),
                                      const SizedBox(height: 18),
                                      FilledButton(
                                          onPressed: _busy ? null : _submit,
                                          style: FilledButton.styleFrom(
                                              backgroundColor: brand,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16)),
                                          child: _busy
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : Text(_register
                                                  ? 'Create account'
                                                  : 'Sign in')),
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => setState(() {
                                                    _register = !_register;
                                                    _error = null;
                                                  }),
                                          child: Text(
                                              _register
                                                  ? 'Already registered? Sign in'
                                                  : 'New to Fintrack? Create an account',
                                              style: const TextStyle(
                                                  color: Color(0xFFB8C4FF)))),
                                    ],
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                        onPressed: widget.onGuest,
                                        icon:
                                            const Icon(Icons.explore_outlined),
                                        label: const Text('Continue as guest'),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Colors.white24),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15))),
                                  ])))))),
        ),
      );
}

InputDecoration _authDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60),
    prefixIcon: Icon(icon, color: Colors.white60),
    filled: true,
    fillColor: const Color(0xFF0D1220),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brand)));

class FinanceEntry {
  FinanceEntry(
      {required this.id,
      required this.title,
      required this.category,
      required this.amount,
      required this.currency,
      required this.rateToBase,
      required this.type,
      required this.date,
      this.note = '',
      this.recurring = false});
  final String id, title, category, currency, type, note;
  final double amount, rateToBase;
  final DateTime date;
  final bool recurring;
  double get baseAmount => amount * rateToBase;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'currency': currency,
        'rateToBase': rateToBase,
        'type': type,
        'date': date.toIso8601String(),
        'note': note,
        'recurring': recurring
      };
  factory FinanceEntry.fromJson(Map<String, dynamic> j) => FinanceEntry(
      id: j['id'],
      title: j['title'],
      category: j['category'],
      amount: (j['amount'] as num).toDouble(),
      currency: j['currency'],
      rateToBase: (j['rateToBase'] as num).toDouble(),
      type: j['type'],
      date: DateTime.parse(j['date']),
      note: j['note'] ?? '',
      recurring: j['recurring'] ?? false);
}

class BudgetItem {
  BudgetItem({required this.category, required this.limit});
  final String category;
  final double limit;
  Map<String, dynamic> toJson() => {'category': category, 'limit': limit};
  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
      category: j['category'], limit: (j['limit'] as num).toDouble());
}

class SavingGoal {
  SavingGoal(
      {required this.name,
      required this.target,
      required this.saved,
      required this.deadline});
  final String name;
  final double target, saved;
  final DateTime deadline;
  Map<String, dynamic> toJson() => {
        'name': name,
        'target': target,
        'saved': saved,
        'deadline': deadline.toIso8601String()
      };
  factory SavingGoal.fromJson(Map<String, dynamic> j) => SavingGoal(
      name: j['name'],
      target: (j['target'] as num).toDouble(),
      saved: (j['saved'] as num).toDouble(),
      deadline: DateTime.parse(j['deadline']));
}

class FinanceStore extends ChangeNotifier {
  FinanceStore({this.user}) {
    load();
  }
  final User? user;
  String? syncError;
  bool dark = true, loaded = false;
  String baseCurrency = 'INR';
  List<FinanceEntry> entries = [];
  List<BudgetItem> budgets = [];
  List<SavingGoal> goals = [];
  final categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Education',
    'Salary',
    'Freelance',
    'Other'
  ];
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    dark = p.getBool('dark') ?? true;
    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('fintrack')
            .doc('workspace')
            .get();
        final data = snap.data();
        if (data != null) {
          baseCurrency = (data['baseCurrency'] as String?) ?? 'INR';
          entries = ((data['entries'] as List?) ?? [])
              .map((e) =>
                  FinanceEntry.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          budgets = ((data['budgets'] as List?) ?? [])
              .map((e) =>
                  BudgetItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          goals = ((data['goals'] as List?) ?? [])
              .map((e) =>
                  SavingGoal.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } else {
          baseCurrency = 'INR';
          entries = [];
          budgets = [
            BudgetItem(category: 'Food', limit: 9000),
            BudgetItem(category: 'Transport', limit: 3500),
            BudgetItem(category: 'Shopping', limit: 5000),
            BudgetItem(category: 'Bills', limit: 4500)
          ];
          goals = [];
          await persist();
        }
      } catch (e) {
        syncError = e.toString();
      }
    } else {
      baseCurrency = p.getString('baseCurrency') ?? 'INR';
      final raw = p.getString('entries');
      if (raw != null) {
        entries = (jsonDecode(raw) as List)
            .map((e) => FinanceEntry.fromJson(e))
            .toList();
      } else {
        _seed();
      }
      final b = p.getString('budgets');
      if (b != null) {
        budgets =
            (jsonDecode(b) as List).map((e) => BudgetItem.fromJson(e)).toList();
      }
      if (budgets.isEmpty) {
        budgets = [
          BudgetItem(category: 'Food', limit: 9000),
          BudgetItem(category: 'Transport', limit: 3500),
          BudgetItem(category: 'Shopping', limit: 5000),
          BudgetItem(category: 'Bills', limit: 4500)
        ];
      }
      final g = p.getString('goals');
      if (g != null) {
        goals =
            (jsonDecode(g) as List).map((e) => SavingGoal.fromJson(e)).toList();
      }
      if (goals.isEmpty) {
        goals = [
          SavingGoal(
              name: 'Emergency fund',
              target: 50000,
              saved: 18500,
              deadline: DateTime(DateTime.now().year, 12, 31)),
          SavingGoal(
              name: 'New laptop',
              target: 85000,
              saved: 32000,
              deadline: DateTime(DateTime.now().year + 1, 3, 1))
        ];
      }
    }
    loaded = true;
    notifyListeners();
  }

  void _seed() {
    final now = DateTime.now();
    entries = [
      FinanceEntry(
          id: 's1',
          title: 'Monthly salary',
          category: 'Salary',
          amount: 58000,
          currency: 'INR',
          rateToBase: 1,
          type: 'income',
          date: DateTime(now.year, now.month, 1),
          note: 'Monthly income'),
      FinanceEntry(
          id: 's2',
          title: 'Grocery shopping',
          category: 'Food',
          amount: 2450,
          currency: 'INR',
          rateToBase: 1,
          type: 'expense',
          date: now.subtract(const Duration(days: 1))),
      FinanceEntry(
          id: 's3',
          title: 'Metro recharge',
          category: 'Transport',
          amount: 800,
          currency: 'INR',
          rateToBase: 1,
          type: 'expense',
          date: now.subtract(const Duration(days: 2))),
      FinanceEntry(
          id: 's4',
          title: 'Freelance project',
          category: 'Freelance',
          amount: 8500,
          currency: 'INR',
          rateToBase: 1,
          type: 'income',
          date: now.subtract(const Duration(days: 4))),
      FinanceEntry(
          id: 's5',
          title: 'Streaming subscription',
          category: 'Entertainment',
          amount: 499,
          currency: 'INR',
          rateToBase: 1,
          type: 'expense',
          date: now.subtract(const Duration(days: 5)),
          recurring: true),
      FinanceEntry(
          id: 's6',
          title: 'Coffee & lunch',
          category: 'Food',
          amount: 620,
          currency: 'INR',
          rateToBase: 1,
          type: 'expense',
          date: now.subtract(const Duration(days: 6))),
      FinanceEntry(
          id: 's7',
          title: 'Online course',
          category: 'Education',
          amount: 1999,
          currency: 'INR',
          rateToBase: 1,
          type: 'expense',
          date: now.subtract(const Duration(days: 8))),
    ];
  }

  double get income => entries
      .where((e) => e.type == 'income')
      .fold<double>(0.0, (s, e) => s + e.baseAmount);
  double get expenses => entries
      .where((e) => e.type == 'expense')
      .fold<double>(0.0, (s, e) => s + e.baseAmount);
  double get balance => income - expenses;
  double get savingsRate =>
      income <= 0 ? 0 : (balance / income).clamp(0.0, 1.0).toDouble();
  double spentFor(String category) => entries
      .where((e) =>
          e.type == 'expense' &&
          e.category == category &&
          e.date.month == DateTime.now().month &&
          e.date.year == DateTime.now().year)
      .fold<double>(0.0, (s, e) => s + e.baseAmount);
  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark', dark);
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('fintrack')
            .doc('workspace')
            .set({
          'baseCurrency': baseCurrency,
          'entries': entries.map((e) => e.toJson()).toList(),
          'budgets': budgets.map((e) => e.toJson()).toList(),
          'goals': goals.map((e) => e.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        syncError = null;
      } catch (e) {
        syncError = e.toString();
        rethrow;
      }
    } else {
      await p.setString('baseCurrency', baseCurrency);
      await p.setString(
          'entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
      await p.setString(
          'budgets', jsonEncode(budgets.map((e) => e.toJson()).toList()));
      await p.setString(
          'goals', jsonEncode(goals.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> toggleTheme() async {
    dark = !dark;
    await persist();
    notifyListeners();
  }

  Future<void> setCurrency(String c) async {
    baseCurrency = c;
    await persist();
    notifyListeners();
  }

  Future<void> addEntry(FinanceEntry e) async {
    entries.insert(0, e);
    await persist();
    notifyListeners();
  }

  Future<void> updateEntry(FinanceEntry e) async {
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i >= 0) entries[i] = e;
    await persist();
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
    await persist();
    notifyListeners();
  }

  Future<void> addBudget(BudgetItem b) async {
    budgets.removeWhere((x) => x.category == b.category);
    budgets.add(b);
    await persist();
    notifyListeners();
  }

  Future<void> addGoal(SavingGoal g) async {
    goals.add(g);
    await persist();
    notifyListeners();
  }

  Future<void> contribute(int index, double amount) async {
    final g = goals[index];
    goals[index] = SavingGoal(
        name: g.name,
        target: g.target,
        saved: g.saved + amount,
        deadline: g.deadline);
    await persist();
    notifyListeners();
  }

  Future<void> resetDemo() async {
    if (user != null) return;
    final p = await SharedPreferences.getInstance();
    await p.remove('entries');
    await p.remove('budgets');
    await p.remove('goals');
    entries = [];
    budgets = [];
    goals = [];
    _seed();
    await persist();
    await load();
  }
}

class FintrackApp extends StatefulWidget {
  const FintrackApp({super.key, this.user});
  final User? user;
  @override
  State<FintrackApp> createState() => _FintrackAppState();
}

class _FintrackAppState extends State<FintrackApp> {
  late final FinanceStore store;
  @override
  void initState() {
    super.initState();
    store = FinanceStore(user: widget.user);
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Fintrack',
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: brand, brightness: Brightness.light),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF1F7F3),
              fontFamily: 'Arial',
              visualDensity: VisualDensity.standard,
              appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFF1F7F3),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0),
              filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF138A5B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13))),
              cardTheme: const CardThemeData(
                  color: Colors.white, elevation: 0, margin: EdgeInsets.zero)),
          darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: brand, brightness: Brightness.dark),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF071A13),
              fontFamily: 'Arial',
              visualDensity: VisualDensity.standard,
              appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF071A13),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0),
              filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF20B47A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13))),
              cardTheme:
                  const CardThemeData(elevation: 0, margin: EdgeInsets.zero)),
          home: FintrackShell(store: store)));
}

class CurrencyBackdropPainter extends CustomPainter {
  CurrencyBackdropPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const symbols = ['₹', '\$', '€', '£', '¥', '₩', '₽', '₺', '₫', '₱'];
    final paint = Paint()
      ..color = (dark ? const Color(0xFF6BE6B0) : const Color(0xFF168A5B))
          .withValues(alpha: dark ? .075 : .055);
    final style = TextStyle(
      color: paint.color,
      fontSize: 34,
      fontWeight: FontWeight.w700,
    );
    const stepX = 148.0;
    const stepY = 118.0;
    var index = 0;
    for (double y = 22; y < size.height + stepY; y += stepY) {
      final offset = ((y ~/ stepY).isEven) ? 0.0 : 66.0;
      for (double x = -20 + offset; x < size.width + stepX; x += stepX) {
        final symbol = symbols[index % symbols.length];
        final tp = TextPainter(
          text: TextSpan(text: symbol, style: style),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((index % 5) - 2) * .045);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CurrencyBackdropPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class FintrackShell extends StatefulWidget {
  const FintrackShell({super.key, required this.store});
  final FinanceStore store;
  @override
  State<FintrackShell> createState() => _FintrackShellState();
}

class _FintrackShellState extends State<FintrackShell> {
  int selected = 0;
  bool sidebarExpanded = true;
  final pages = [
    'Overview',
    'Transactions',
    'Budgets',
    'Savings goals',
    'Analytics',
    'Settings'
  ];
  final icons = [
    Icons.grid_view_rounded,
    Icons.swap_horiz_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.flag_outlined,
    Icons.insights_rounded,
    Icons.settings_outlined
  ];
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = [
      DashboardPage(
          store: widget.store, onNavigate: (i) => setState(() => selected = i)),
      TransactionsPage(store: widget.store),
      BudgetsPage(store: widget.store),
      GoalsPage(store: widget.store),
      AnalyticsPage(store: widget.store),
      SettingsPage(store: widget.store)
    ];
    return Scaffold(
        body: Stack(children: [
          Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(
                      painter: CurrencyBackdropPainter(
                          dark: Theme.of(context).brightness == Brightness.dark)))),
          Row(children: [
          if (wide)
            AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                width: sidebarExpanded ? 258 : 76,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Padding(
                          padding: EdgeInsets.fromLTRB(sidebarExpanded ? 24 : 19, 20, 12, 26),
                          child: Row(children: [
                            Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    color: brand,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white)),
                            if (sidebarExpanded) ...[
                              const SizedBox(width: 12),
                              const Flexible(child: Text('fintrack', overflow: TextOverflow.fade, softWrap: false,
                                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.8)))
                            ]
                          ])),
                      if (sidebarExpanded)
                        const Padding(
                            padding: EdgeInsets.fromLTRB(24, 0, 0, 12),
                            child: Text('WORKSPACE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                    color: muted, letterSpacing: 1.4))),
                      for (int i = 0; i < pages.length; i++) _navItem(i),
                      const Spacer(),
                      if (sidebarExpanded) Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: brand.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Row(children: [
                            Icon(Icons.shield_outlined, color: brand),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text('Your finances, in focus.',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)))
                          ])),
                      Padding(
                          padding: EdgeInsets.all(sidebarExpanded ? 18 : 10),
                          child: Row(children: [
                            const CircleAvatar(
                                radius: 17,
                                backgroundColor: Color(0xFFE5E9FF),
                                child:
                                    Icon(Icons.person, color: brand, size: 18)),
                            if (sidebarExpanded) const SizedBox(width: 10),
                            if (sidebarExpanded) Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      widget.store.user?.displayName ??
                                          (widget.store.user?.email ??
                                              'Demo workspace'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      widget.store.user == null
                                          ? 'Local guest data'
                                          : 'Cloud-synced account',
                                      style: const TextStyle(
                                          fontSize: 10, color: muted))
                                ])),
                            if (sidebarExpanded) IconButton(
                                onPressed: widget.store.toggleTheme,
                                icon: Icon(
                                    widget.store.dark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                    size: 19))
                          ]))
                    ]))),
          Expanded(
              child: SafeArea(
                  child: Column(children: [
            if (wide)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: IconButton.filledTonal(
                    tooltip: sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
                    onPressed: () => setState(() => sidebarExpanded = !sidebarExpanded),
                    icon: AnimatedRotation(
                      turns: sidebarExpanded ? 0 : .5,
                      duration: const Duration(milliseconds: 260),
                      child: const Icon(Icons.menu_rounded),
                    ),
                  ),
                ),
              ),
            if (!wide) _mobileHeader(),
            Expanded(
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                        key: ValueKey(selected), child: content[selected])))
          ])))
        ]),
        ]),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected <= 2 ? selected : 3,
                onDestinationSelected: (i) =>
                    setState(() => selected = i == 3 ? 5 : i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded), label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.swap_horiz), label: 'Activity'),
                  NavigationDestination(
                      icon: Icon(Icons.wallet_outlined), label: 'Budgets'),
                  NavigationDestination(
                      icon: Icon(Icons.settings_outlined), label: 'Settings')
                ],
              ));
  }

  Widget _mobileHeader() => Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(children: [
        const Text('fintrack',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const Spacer(),
        PopupMenuButton<int>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (i) => setState(() => selected = i),
            itemBuilder: (_) => const [
                  PopupMenuItem(value: 3, child: Text('Savings goals')),
                  PopupMenuItem(value: 4, child: Text('Analytics')),
                  PopupMenuItem(value: 5, child: Text('Settings'))
                ]),
        IconButton(
            onPressed: widget.store.toggleTheme,
            icon: Icon(widget.store.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined))
      ]));
  Widget _navItem(int i) {
    final active = selected == i;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Tooltip(
          message: sidebarExpanded ? pages[i] : pages[i],
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => selected = i),
            child: Container(
                padding: EdgeInsets.symmetric(horizontal: sidebarExpanded ? 14 : 15, vertical: 13),
                decoration: BoxDecoration(
                    color: active
                        ? brand.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(icons[i], size: 19, color: active ? brand : muted),
                  if (sidebarExpanded) ...[
                    const SizedBox(width: 13),
                    Flexible(child: Text(pages[i], overflow: TextOverflow.fade, softWrap: false,
                        style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? brand : Theme.of(context).colorScheme.onSurface, fontSize: 13)))
                  ]
                ])))));
  }
}

String money(double v, String currency) => NumberFormat.currency(
        name: currency,
        symbol: currency == 'INR' ? '₹' : '\$ ',
        decimalDigits: 0)
    .format(v);
String dateLabel(DateTime d) => DateFormat('d MMM yyyy').format(d);
Color categoryColor(String c) => ({
      'Food': const Color(0xFFF59E0B),
      'Transport': const Color(0xFF38BDF8),
      'Shopping': const Color(0xFFB38AF7),
      'Bills': const Color(0xFFFB7185),
      'Health': const Color(0xFF34D399),
      'Entertainment': const Color(0xFF818CF8),
      'Salary': const Color(0xFF22C55E),
      'Freelance': const Color(0xFF14B8A6)
    }[c] ??
    brand);
IconData categoryIcon(String c) => ({
      'Food': Icons.restaurant,
      'Transport': Icons.directions_transit,
      'Shopping': Icons.shopping_bag_outlined,
      'Bills': Icons.receipt_long,
      'Health': Icons.favorite_border,
      'Entertainment': Icons.movie_outlined,
      'Salary': Icons.payments_outlined,
      'Freelance': Icons.laptop_mac
    }[c] ??
    Icons.category_outlined);

class PageFrame extends StatelessWidget {
  const PageFrame(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.child,
      this.action});
  final String title, subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 34,
          vertical: 28),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(color: muted, fontSize: 13, height: 1.4))
                  ])),
              if (action != null) action!
            ]),
            const SizedBox(height: 24),
            child
          ])));
}

class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .32)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .035),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ]),
      child: child);
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.tint,
      required this.caption,
      this.circular = false});
  final String label, value, caption;
  final IconData icon;
  final Color tint;
  final bool circular;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: tint.withValues(alpha: dark ? .20 : .12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: tint, size: 18)),
              const SizedBox(height: 9),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8))),
              const SizedBox(height: 5),
              Text(caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: tint, fontSize: 9.5, fontWeight: FontWeight.w700))
            ]);
        if (!circular) {
          return Panel(padding: const EdgeInsets.all(20), child: content);
        }
        final diameter = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        return Center(
            child: Container(
                width: diameter,
                height: diameter,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                        color: tint.withValues(alpha: dark ? .62 : .48),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: tint.withValues(alpha: dark ? .25 : .14),
                          blurRadius: dark ? 32 : 24,
                          spreadRadius: dark ? 2 : 1),
                      BoxShadow(
                          color: tint.withValues(alpha: dark ? .10 : .06),
                          blurRadius: 48,
                          spreadRadius: 5)
                    ]),
                child: Center(child: content)));
      });
}

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key, required this.store, required this.onNavigate});
  final FinanceStore store;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 420
        ? 1
        : width < 1100
            ? 2
            : 4;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : hour < 21
                ? 'Good evening'
                : 'Good night';
    return PageFrame(
      title: greeting,
      subtitle: 'Here is your financial overview.',
      action: FilledButton.icon(
        onPressed: () => showEntryDialog(context, store),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add transaction'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!store.loaded) const LinearProgressIndicator(),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 13,
            mainAxisSpacing: 13,
            // Give metric cards enough vertical room to avoid a small
            // RenderFlex overflow at desktop and narrower breakpoints.
            childAspectRatio: 1.0,
            children: [
              MetricCard(
                  label: 'Total balance',
                  value: money(store.balance, store.baseCurrency),
                  icon: Icons.account_balance_wallet_outlined,
                  tint: brand,
                  caption: 'Across recorded transactions',
                  circular: true),
              MetricCard(
                  label: 'Total income',
                  value: money(store.income, store.baseCurrency),
                  icon: Icons.trending_up,
                  tint: const Color(0xFF16B981),
                  caption: 'Money received',
                  circular: true),
              MetricCard(
                  label: 'Total expenses',
                  value: money(store.expenses, store.baseCurrency),
                  icon: Icons.trending_down,
                  tint: const Color(0xFFEF5350),
                  caption: 'Money spent',
                  circular: true),
              MetricCard(
                  label: 'Savings rate',
                  value: '${(store.savingsRate * 100).toStringAsFixed(1)}%',
                  icon: Icons.savings_outlined,
                  tint: const Color(0xFFF5B82E),
                  caption: 'Income retained',
                  circular: true),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpandedIf(
                  wide: wide,
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Spending overview',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Income vs. expenses',
                            style: TextStyle(color: muted, fontSize: 11)),
                        const SizedBox(height: 22),
                        SizedBox(
                            height: 180,
                            child: IncomeExpenseChart(
                                income: store.income,
                                expenses: store.expenses)),
                        const SizedBox(height: 10),
                        Row(children: [
                          _legend('Income', const Color(0xFF16B981)),
                          const SizedBox(width: 20),
                          _legend('Expenses', const Color(0xFFEF6B73))
                        ]),
                      ],
                    ),
                  ),
                ),
                ExpandedIf(
                  wide: wide,
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Budget progress',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15))),
                          TextButton(
                              onPressed: () => onNavigate(2),
                              child: const Text('View all')),
                        ]),
                        const SizedBox(height: 8),
                        for (final budget in store.budgets.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: BudgetProgress(
                                item: budget,
                                spent: store.spentFor(budget.category),
                                currency: store.baseCurrency),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('Recent transactions',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15))),
                  TextButton(
                      onPressed: () => onNavigate(1),
                      child: const Text('See all')),
                ]),
                const SizedBox(height: 8),
                if (store.entries.isEmpty)
                  const EmptyState(
                      label: 'No transactions yet. Add your first one.')
                else
                  for (final entry in store.entries.take(5))
                    TransactionTile(
                        entry: entry,
                        currency: store.baseCurrency,
                        onDelete: () => store.deleteEntry(entry.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _legend(String s, Color c) => Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(s, style: const TextStyle(fontSize: 11, color: muted))
    ]);

class ExpandedIf extends StatelessWidget {
  const ExpandedIf({super.key, required this.wide, required this.child});
  final bool wide;
  final Widget child;
  @override
  Widget build(BuildContext context) => wide
      ? Expanded(
          child:
              Padding(padding: const EdgeInsets.only(right: 8), child: child))
      : Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
}

class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart(
      {super.key, required this.income, required this.expenses});
  final double income, expenses;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: BarsPainter(income: income, expenses: expenses),
      child: Container());
}

class BarsPainter extends CustomPainter {
  BarsPainter({required this.income, required this.expenses});
  final double income, expenses;
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = muted.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), base);
    }
    final maxV = (income > expenses ? income : expenses);
    final double max = maxV <= 0 ? 1.0 : maxV;
    final values = [income, expenses];
    final colors = [const Color(0xFF16B981), const Color(0xFFEF6B73)];
    for (int i = 0; i < 2; i++) {
      final h = (values[i] / max) * (size.height - 12);
      final x = size.width * (i == 0 ? 0.28 : 0.62);
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h == 0 ? size.height - 3 : size.height - h,
              size.width * .14, h == 0 ? 3 : h),
          const Radius.circular(7));
      final glow = Paint()
        ..color = colors[i].withValues(alpha: .48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRRect(rect, glow);
      final softGlow = Paint()
        ..color = colors[i].withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawRRect(rect, softGlow);
      canvas.drawRRect(rect, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter old) =>
      old.income != income || old.expenses != expenses;
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String query = '', filter = 'all';
  @override
  Widget build(BuildContext context) {
    final list = widget.store.entries
        .where((e) =>
            (filter == 'all' || e.type == filter) &&
            (e.title.toLowerCase().contains(query.toLowerCase()) ||
                e.category.toLowerCase().contains(query.toLowerCase())))
        .toList();
    return PageFrame(
        title: 'Transactions',
        subtitle: 'Review and manage your money activity.',
        action: FilledButton.icon(
            onPressed: () => showEntryDialog(context, widget.store),
            icon: const Icon(Icons.add),
            label: const Text('Add new')),
        child: Column(children: [
          TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search transactions',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (final f in ['all', 'income', 'expense'])
              ChoiceChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f))
          ]),
          const SizedBox(height: 14),
          Panel(
              child: Column(children: [
            if (list.isEmpty)
              const EmptyState(label: 'No matching transactions found.')
            else
              for (final e in list)
                TransactionTile(
                    entry: e,
                    currency: widget.store.baseCurrency,
                    onDelete: () => widget.store.deleteEntry(e.id),
                    onEdit: () =>
                        showEntryDialog(context, widget.store, existing: e))
          ]))
        ]));
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile(
      {super.key,
      required this.entry,
      required this.currency,
      required this.onDelete,
      this.onEdit});
  final FinanceEntry entry;
  final String currency;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: categoryColor(entry.category).withValues(alpha: .13),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(categoryIcon(entry.category),
                color: categoryColor(entry.category), size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
              '${entry.category} · ${dateLabel(entry.date)}${entry.recurring ? ' · Recurring' : ''}',
              style: const TextStyle(fontSize: 10, color: muted))
        ])),
        Text(
            '${entry.type == 'income' ? '+' : '−'}${money(entry.amount, entry.currency)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: entry.type == 'income'
                    ? const Color(0xFF16B981)
                    : Theme.of(context).colorScheme.onSurface)),
        PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: muted),
            onSelected: (v) {
              if (v == 'delete') onDelete();
              if (v == 'edit') onEdit?.call();
            },
            itemBuilder: (_) => [
                  if (onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete'))
                ])
      ]));
}

Future<void> showEntryDialog(BuildContext context, FinanceStore store,
    {FinanceEntry? existing}) async {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(text: existing?.title ?? '');
  final amount = TextEditingController(text: existing?.amount.toString() ?? '');
  final rate =
      TextEditingController(text: existing?.rateToBase.toString() ?? '1');
  final note = TextEditingController(text: existing?.note ?? '');
  String type = existing?.type ?? 'expense';
  String category = existing?.category ?? 'Food';
  String currency = existing?.currency ?? store.baseCurrency;
  bool recurring = existing?.recurring ?? false;
  DateTime date = existing?.date ?? DateTime.now();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Add transaction' : 'Edit transaction'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.arrow_upward)),
                      ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.arrow_downward)),
                    ],
                    selected: {type},
                    onSelectionChanged: (values) =>
                        setDialogState(() => type = values.first),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a description'
                          : null),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || n <= 0
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: store.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: ['INR', 'USD', 'EUR', 'GBP', 'AED', 'CAD', 'AUD']
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => currency = v ?? currency),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                      controller: rate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: '1 $currency = ${store.baseCurrency}'),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || n <= 0 ? 'Invalid rate' : null;
                      },
                    )),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: note,
                      decoration:
                          const InputDecoration(labelText: 'Note (optional)')),
                  CheckboxListTile(
                    value: recurring,
                    onChanged: (v) =>
                        setDialogState(() => recurring = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recurring transaction',
                        style: TextStyle(fontSize: 13)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date', style: TextStyle(fontSize: 13)),
                    subtitle: Text(dateLabel(date)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: date,
                          firstDate: DateTime(2018),
                          lastDate: DateTime(2100));
                      if (picked != null) setDialogState(() => date = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final entry = FinanceEntry(
                id: existing?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                title: title.text.trim(),
                category: category,
                amount: double.parse(amount.text),
                currency: currency,
                rateToBase: double.parse(rate.text),
                type: type,
                date: date,
                note: note.text.trim(),
                recurring: recurring,
              );
              if (existing == null) {
                store.addEntry(entry);
              } else {
                store.updateEntry(entry);
              }
              Navigator.pop(dialogContext);
            },
            child: Text(existing == null ? 'Save transaction' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
}

class BudgetProgress extends StatelessWidget {
  const BudgetProgress(
      {super.key,
      required this.item,
      required this.spent,
      required this.currency});
  final BudgetItem item;
  final double spent;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final double p =
        item.limit <= 0 ? 0.0 : (spent / item.limit).clamp(0.0, 1.0).toDouble();
    final color = p >= 1
        ? const Color(0xFFEF6B73)
        : p >= .8
            ? const Color(0xFFF59E0B)
            : brand;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: categoryColor(item.category), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(item.category,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700))),
        Text('${money(spent, currency)} / ${money(item.limit, currency)}',
            style: const TextStyle(fontSize: 10, color: muted))
      ]),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: p,
              minHeight: 7,
              backgroundColor:
                  Theme.of(context).dividerColor.withValues(alpha: .3),
              color: color)),
      const SizedBox(height: 4),
      Text('${(p * 100).toStringAsFixed(0)}% used',
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700))
    ]);
  }
}

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Budgets',
      subtitle: 'Set spending limits and stay on track.',
      action: FilledButton.icon(
          onPressed: () => showBudgetDialog(context, store),
          icon: const Icon(Icons.add),
          label: const Text('Set budget')),
      child: Column(children: [
        for (final b in store.budgets)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    BudgetProgress(
                        item: b,
                        spent: store.spentFor(b.category),
                        currency: store.baseCurrency),
                    const SizedBox(height: 8),
                    TextButton.icon(
                        onPressed: () =>
                            showBudgetDialog(context, store, existing: b),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit limit'))
                  ]))),
        if (store.budgets.isEmpty)
          const EmptyState(
              label: 'No budgets yet. Create one to start planning.')
      ]));
}

Future<void> showBudgetDialog(BuildContext context, FinanceStore store,
    {BudgetItem? existing}) async {
  String cat = existing?.category ?? store.categories.first;
  final amount = TextEditingController(text: existing?.limit.toString() ?? '');
  await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
              title: Text(existing == null ? 'Create budget' : 'Edit budget'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                    initialValue: cat,
                    items: store.categories
                        .where((c) => !['Salary', 'Freelance'].contains(c))
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => cat = v ?? cat,
                    decoration: const InputDecoration(labelText: 'Category')),
                TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Monthly limit (${store.baseCurrency})'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final v = double.tryParse(amount.text);
                      if (v != null && v > 0) {
                        store.addBudget(BudgetItem(category: cat, limit: v));
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save budget'))
              ]));
}

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Savings goals',
      subtitle: 'Turn your plans into measurable progress.',
      action: FilledButton.icon(
          onPressed: () => showGoalDialog(context, store),
          icon: const Icon(Icons.add),
          label: const Text('New goal')),
      child: Column(children: [
        for (int i = 0; i < store.goals.length; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: GoalCard(
                  goal: store.goals[i],
                  currency: store.baseCurrency,
                  onAdd: () => showContributionDialog(context, store, i))),
        if (store.goals.isEmpty)
          const EmptyState(label: 'Create a savings goal to get started.')
      ]));
}

class GoalCard extends StatelessWidget {
  const GoalCard(
      {super.key,
      required this.goal,
      required this.currency,
      required this.onAdd});
  final SavingGoal goal;
  final String currency;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final p = (goal.saved / goal.target).clamp(0.0, 1.0).toDouble();
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.flag_outlined, color: brand),
        const SizedBox(width: 9),
        Expanded(
            child: Text(goal.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14))),
        Text('${(p * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: brand, fontWeight: FontWeight.w800))
      ]),
      const SizedBox(height: 15),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: p,
              minHeight: 9,
              color: brand,
              backgroundColor: brand.withValues(alpha: .12))),
      const SizedBox(height: 10),
      Row(children: [
        Text(money(goal.saved, currency),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('Target ${money(goal.target, currency)}',
            style: const TextStyle(color: muted, fontSize: 11))
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Text('Target date: ${dateLabel(goal.deadline)}',
            style: const TextStyle(color: muted, fontSize: 10)),
        const Spacer(),
        TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Contribute'))
      ])
    ]));
  }
}

Future<void> showGoalDialog(BuildContext context, FinanceStore store) async {
  final name = TextEditingController(), target = TextEditingController();
  DateTime deadline = DateTime.now().add(const Duration(days: 90));
  await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
                  title: const Text('Create savings goal'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Goal name')),
                    TextField(
                        controller: target,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Target (${store.baseCurrency})')),
                    ListTile(
                        title: const Text('Deadline'),
                        subtitle: Text(dateLabel(deadline)),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: ctx,
                              initialDate: deadline,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100));
                          if (d != null) set(() => deadline = d);
                        })
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          final v = double.tryParse(target.text);
                          if (name.text.trim().isNotEmpty &&
                              v != null &&
                              v > 0) {
                            store.addGoal(SavingGoal(
                                name: name.text.trim(),
                                target: v,
                                saved: 0,
                                deadline: deadline));
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Create'))
                  ])));
}

Future<void> showContributionDialog(
    BuildContext context, FinanceStore store, int i) async {
  final amount = TextEditingController();
  await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
              title: Text('Contribute to ${store.goals[i].name}'),
              content: TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Amount (${store.baseCurrency})')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final v = double.tryParse(amount.text);
                      if (v != null && v > 0) store.contribute(i, v);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add contribution'))
              ]));
}

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final e in store.entries.where((e) => e.type == 'expense')) {
      map[e.category] = (map[e.category] ?? 0) + e.baseAmount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return PageFrame(
        title: 'Analytics',
        subtitle: 'Understand your spending patterns.',
        child: Column(children: [
          GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width < 650 ? 1 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
                  MediaQuery.sizeOf(context).width < 650 ? 1.8 : 2.2,
              children: [
                MetricCard(
                    label: 'Income',
                    value: money(store.income, store.baseCurrency),
                    icon: Icons.trending_up,
                    tint: const Color(0xFF16B981),
                    caption: 'Recorded income'),
                MetricCard(
                    label: 'Expenses',
                    value: money(store.expenses, store.baseCurrency),
                    icon: Icons.trending_down,
                    tint: const Color(0xFFEF6B73),
                    caption: 'Recorded expenses')
              ]),
          const SizedBox(height: 14),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Spending by category',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 20),
                if (sorted.isEmpty)
                  const EmptyState(label: 'Add expenses to see your breakdown.')
                else
                  for (final e in sorted)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: BudgetProgress(
                            item: BudgetItem(
                                category: e.key,
                                limit:
                                    store.expenses == 0 ? 1 : store.expenses),
                            spent: e.value,
                            currency: store.baseCurrency))
              ])),
          const SizedBox(height: 14),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Financial health',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 14),
                _stat('Savings rate',
                    '${(store.savingsRate * 100).toStringAsFixed(1)}%'),
                _stat(
                    'Net cash flow', money(store.balance, store.baseCurrency)),
                _stat('Transactions recorded', '${store.entries.length}')
              ]))
        ]));
  }
}

Widget _stat(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Expanded(
          child: Text(a, style: const TextStyle(color: muted, fontSize: 12))),
      Text(b, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))
    ]));

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Settings',
      subtitle: 'Personalise your Fintrack workspace.',
      child: Column(children: [
        Panel(
            child: Column(children: [
          _settingRow(
              Icons.palette_outlined,
              'Appearance',
              'Switch between light and dark themes',
              Switch(value: store.dark, onChanged: (_) => store.toggleTheme())),
          const Divider(height: 24),
          _settingRow(
              Icons.currency_exchange,
              'Base currency',
              'Used for consolidated totals',
              DropdownButton<String>(
                  value: store.baseCurrency,
                  underline: const SizedBox(),
                  items: ['INR', 'USD', 'EUR', 'GBP', 'AED', 'CAD', 'AUD']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) store.setCurrency(v);
                  })),
          const Divider(height: 24),
          _settingRow(
              Icons.storage_outlined,
              'Data storage',
              store.user == null
                  ? 'Saved in this browser only'
                  : 'Synced to your private cloud account',
              Chip(
                  label: Text(
                      store.user == null ? 'Guest mode' : 'Firebase cloud')))
        ])),
        const SizedBox(height: 14),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('About Fintrack',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
              'A personal finance workspace for tracking income, expenses, budgets and savings goals.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.verified_user_outlined, color: brand, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    store.user == null
                        ? 'Guest data stays in this browser. No bank account is connected.'
                        : 'Your workspace syncs to your private account. No bank account is connected.',
                    style: const TextStyle(fontSize: 11, color: muted)))
          ]),
          const SizedBox(height: 12),
          if (store.user != null)
            OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out')),
          if (store.user == null)
            OutlinedButton.icon(
                onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                            title: const Text('Reset demo data?'),
                            content: const Text(
                                'This will replace your local entries, budgets and goals with the sample workspace.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () {
                                    store.resetDemo();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Reset data'))
                            ])),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset demo data'))
        ]))
      ]));
}

Widget _settingRow(
        IconData icon, String title, String subtitle, Widget trailing) =>
    Row(children: [
      Icon(icon, color: brand, size: 20),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 10))
      ])),
      trailing
    ]);

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
          child: Column(children: [
        Icon(Icons.inbox_outlined,
            size: 30, color: muted.withValues(alpha: .6)),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12))
      ])));
}
