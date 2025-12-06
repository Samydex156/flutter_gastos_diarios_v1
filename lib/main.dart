import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_chart/fl_chart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ptadxhhlopvrhsroxdmw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0YWR4aGhsb3B2cmhzcm94ZG13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY3NDUxMjksImV4cCI6MjA2MjMyMTEyOX0.UTmuf00dvfB1ifk9emecUKV-yEdukpQWGAZ6YfUMaEQ',
  );

  await DatabaseHelper.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gastos DuQuen',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ----------------------------------------------------------------
// SPLASH SCREEN
// ----------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLocalSession();
  }

  Future<void> _checkLocalSession() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final db = await DatabaseHelper.instance.database;
    final users = await db.query('usuarios_local');

    if (users.isNotEmpty) {
      final user = users.first;
      _goToMain(user['id'] as int, user['email'] as String);
    } else {
      _goToLogin();
    }
  }

  // AHORA VAMOS A LA MAIN SCREEN, NO DIRECTO A EXPENSES
  void _goToMain(int id, String email) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(userId: id, userEmail: email),
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.account_balance_wallet, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "Gastos DuQuen\nCargando...",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// LOGIN PAGE
// ----------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _supabase = Supabase.instance.client;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> _login() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;

    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Necesitas internet para el primer inicio de sesión."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim();
      final hash = _hashPassword(_passCtrl.text.trim());

      final data = await _supabase
          .from('usuarios2')
          .select()
          .eq('email', email)
          .eq('password', hash)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        final userId = data['id'] as int;
        await DatabaseHelper.instance.saveLocalUser(userId, email);

        if (mounted) {
          // CAMBIO: Navegar a MainScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainScreen(userId: userId, userEmail: email),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Credenciales incorrectas")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final hash = _hashPassword(password);

      final existing = await _supabase
          .from('usuarios2')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (existing != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Correo ya registrado")));
        return;
      }

      await _supabase.from('usuarios2').insert({
        'email': email,
        'password': hash,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registrado. Inicia sesión."),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_circle, size: 60, color: Colors.teal),
                  const SizedBox(height: 20),
                  const Text(
                    "Bienvenido",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Contraseña",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text("ENTRAR"),
                            ),
                            TextButton(
                              onPressed: _register,
                              child: const Text("Crear cuenta nueva"),
                            ),
                          ],
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

// ----------------------------------------------------------------
// NUEVA CLASE PRINCIPAL: MAIN SCREEN (Con BottomNavigation)
// ----------------------------------------------------------------
class MainScreen extends StatefulWidget {
  final int userId;
  final String userEmail;
  const MainScreen({super.key, required this.userId, required this.userEmail});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Usamos IndexedStack para mantener el estado de las páginas (que no se recarguen al cambiar)
    final List<Widget> pages = [
      ExpenseHomePage(userId: widget.userId, userEmail: widget.userEmail),
      DashboardPage(userId: widget.userId),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Reporte',
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// PANTALLA DE GASTOS (Ya no es la "Home" principal, sino una pestaña)
// ----------------------------------------------------------------
class ExpenseHomePage extends StatefulWidget {
  final int userId;
  final String userEmail;
  const ExpenseHomePage({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _displayDate => DateFormat('dd/MM/yyyy').format(_selectedDate);

  List<Map<String, dynamic>> _localExpenses = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadLocalExpenses();
    _syncData();
  }

  Future<void> _loadLocalExpenses() async {
    final data = await DatabaseHelper.instance.getExpenses(
      widget.userId,
      _dateStr,
    );
    if (mounted) setState(() => _localExpenses = data);
  }

  // --- AGREGAR ---
  Future<void> _addExpense() async {
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (desc.isEmpty || amount == null) return;

    await DatabaseHelper.instance.insertExpense({
      'description': desc,
      'amount': amount,
      'date': _dateStr,
      'user_id': widget.userId,
      'is_synced': 0,
      'supabase_id': null,
    });

    if (!mounted) return;
    _descCtrl.clear();
    _amountCtrl.clear();
    FocusScope.of(context).unfocus();
    await _loadLocalExpenses();
    _syncData();
  }

  // --- EDITAR ---
  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final editDescCtrl = TextEditingController(text: item['description']);
    final editAmountCtrl = TextEditingController(
      text: (item['amount'] as num).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Gasto"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editDescCtrl,
              decoration: const InputDecoration(labelText: "Descripción"),
            ),
            TextField(
              controller: editAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Monto"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newDesc = editDescCtrl.text.trim();
              final newAmount = double.tryParse(editAmountCtrl.text.trim());
              if (newDesc.isNotEmpty && newAmount != null) {
                await DatabaseHelper.instance.updateExpense(item['id'], {
                  'description': newDesc,
                  'amount': newAmount,
                  'is_synced': 0,
                });
                if (mounted) {
                  Navigator.pop(context);
                  await _loadLocalExpenses();
                  _syncData();
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // --- ELIMINAR ---
  Future<void> _deleteExpense(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Gasto"),
        content: Text("¿Seguro que quieres borrar '${item['description']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteExpense(item['id']);
      final supabaseId = item['supabase_id'];
      if (supabaseId != null) {
        var connectivity = await Connectivity().checkConnectivity();
        if (connectivity != ConnectivityResult.none) {
          try {
            await Supabase.instance.client
                .from('expenses')
                .delete()
                .eq('id', supabaseId);
          } catch (e) {
            debugPrint("Error borrando remoto: $e");
          }
        }
      }
      await _loadLocalExpenses();
    }
  }

  // --- SYNC ---
  Future<void> _syncData() async {
    if (_isSyncing) return;
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (!mounted) return;
    if (connectivityResult == ConnectivityResult.none) return;

    setState(() => _isSyncing = true);

    try {
      final supabase = Supabase.instance.client;
      final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses(
        widget.userId,
      );

      for (var row in unsynced) {
        final supabaseId = row['supabase_id'];

        if (supabaseId == null) {
          final response = await supabase
              .from('expenses')
              .insert({
                'description': row['description'],
                'amount': row['amount'],
                'date': row['date'],
                'user_id': row['user_id'],
              })
              .select()
              .single();

          await DatabaseHelper.instance.updateSupabaseId(
            row['id'],
            response['id'] as int,
          );
        } else {
          await supabase
              .from('expenses')
              .update({
                'description': row['description'],
                'amount': row['amount'],
              })
              .eq('id', supabaseId);
        }
        await DatabaseHelper.instance.markAsSynced(row['id']);
      }

      final remoteData = await supabase
          .from('expenses')
          .select()
          .eq('user_id', widget.userId);
      final dbHelper = DatabaseHelper.instance;
      int newItemsCount = 0;

      for (var remoteItem in remoteData) {
        final rId = remoteItem['id'];
        final exists = await dbHelper.checkIfSupabaseIdExists(rId);

        if (!exists) {
          await dbHelper.insertExpense({
            'description': remoteItem['description'],
            'amount': (remoteItem['amount'] as num).toDouble(),
            'date': remoteItem['date'],
            'user_id': widget.userId,
            'is_synced': 1,
            'supabase_id': rId,
          });
          newItemsCount++;
        }
      }

      if (mounted) {
        await _loadLocalExpenses();
        if (unsynced.isNotEmpty || newItemsCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sync Ok"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Silenciar error común
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _logout() async {
    await DatabaseHelper.instance.logoutLocalUser();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = _localExpenses.fold(
      0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Gastos DuQuen", style: TextStyle(fontSize: 18)),
            Text(
              widget.userEmail,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // HEMOS QUITADO EL BOTÓN DE REPORTE AQUÍ
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncData,
            tooltip: "Sincronizar",
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Fecha:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      _displayDate,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (!mounted) return;
                    if (d != null) {
                      setState(() => _selectedDate = d);
                      _loadLocalExpenses();
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Cambiar Fecha"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: "Ingresa Descripción",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Monto",
                      border: OutlineInputBorder(),
                      prefixText: "Bs. ",
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          ),
          const Text(
            "Lista de Movimientos:",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Expanded(
            child: _localExpenses.isEmpty
                ? const Center(
                    child: Text(
                      "Sin gastos en esta fecha",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _localExpenses.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _localExpenses[index];
                      final synced = item['is_synced'] == 1;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: synced
                              ? Colors.teal.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            synced ? Icons.cloud_done : Icons.cloud_upload,
                            color: synced ? Colors.teal : Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item['description'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Color.fromARGB(255, 114, 114, 114),
                          ),
                        ),
                        subtitle: Text(
                          "Bs. ${(item['amount'] as num).toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color.fromARGB(221, 48, 48, 48),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueGrey,
                              ),
                              onPressed: () => _showEditDialog(item),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteExpense(item),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade900,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ACUMULADO DEL DÍA:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Bs. ${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// DASHBOARD / REPORTE (MODIFICADO)
// ----------------------------------------------------------------
class DashboardPage extends StatefulWidget {
  final int userId;
  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  double _totalWeek = 0;
  double _totalMonth = 0;
  List<double> _dailyTotals = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadReportData(); // Se cargará cuando se construya la primera vez
  }
  
  // Agregamos un método público para refrescar si se desea
  Future<void> refresh() => _loadReportData();

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final db = DatabaseHelper.instance;
    final fmt = DateFormat('yyyy-MM-dd');

    final weekExpenses = await db.getExpensesInDateRange(
      widget.userId,
      fmt.format(startOfWeek),
      fmt.format(endOfWeek),
    );

    final monthExpenses = await db.getExpensesInDateRange(
      widget.userId,
      fmt.format(startOfMonth),
      fmt.format(endOfMonth),
    );

    double sumWeek = 0;
    List<double> days = [0, 0, 0, 0, 0, 0, 0];

    for (var item in weekExpenses) {
      final amount = (item['amount'] as num).toDouble();
      final date = DateTime.parse(item['date']);
      sumWeek += amount;
      int dayIndex = date.weekday - 1;
      if (dayIndex >= 0 && dayIndex < 7) {
        days[dayIndex] += amount;
      }
    }

    double sumMonth = monthExpenses.fold(
      0,
      (prev, item) => prev + (item['amount'] as num).toDouble(),
    );

    if (mounted) {
      setState(() {
        _totalWeek = sumWeek;
        _totalMonth = sumMonth;
        _dailyTotals = days;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte de Gastos"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
            IconButton(
                icon: const Icon(Icons.refresh), 
                onPressed: _loadReportData
            )
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TARJETAS
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          "Esta Semana",
                          _totalWeek,
                          Icons.calendar_view_week,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          "Este Mes",
                          _totalMonth,
                          Icons.calendar_month,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Gastos por Día (Gráfico)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // GRÁFICO (Altura reducida a 220)
                  Container(
                    height: 220, 
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _getMaxY(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            // getTooltipColor: (_) => Colors.blueGrey, 
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                'Bs. ${rod.toY.toStringAsFixed(1)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                                final index = value.toInt();
                                if (index >= 0 && index < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      days[index],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: _generateBars(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // --- NUEVA LISTA DE DETALLE POR DÍA ---
                  const Text(
                    "Detalle Diario",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDailyList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Widget para construir la lista Lunes...Domingo
  Widget _buildDailyList() {
    final daysNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    
    return Container(
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
       ),
       child: Column(
         children: List.generate(7, (index) {
           final amount = _dailyTotals[index];
           return Column(
             children: [
               ListTile(
                 dense: true,
                 leading: CircleAvatar(
                   backgroundColor: Colors.teal.shade50,
                   child: Text(daysNames[index][0], style: TextStyle(color: Colors.teal)),
                 ),
                 title: Text(daysNames[index]),
                 trailing: Text(
                   "Bs. ${amount.toStringAsFixed(2)}", 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                 ),
               ),
               if (index < 6) const Divider(height: 1, indent: 16, endIndent: 16),
             ],
           );
         }),
       ),
    );
  }

  double _getMaxY() {
    double max = 0;
    for (var val in _dailyTotals) {
      if (val > max) max = val;
    }
    return max == 0 ? 100 : max * 1.2;
  }

  List<BarChartGroupData> _generateBars() {
    List<BarChartGroupData> bars = [];
    for (int i = 0; i < 7; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _dailyTotals[i],
              color: Colors.teal,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _getMaxY(),
                color: Colors.grey.shade200,
              ),
            ),
          ],
        ),
      );
    }
    return bars;
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Bs. ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800 // Corrección del error de shade
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// GESTOR DE BASE DE DATOS LOCAL (SQLite)
// =========================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // OJO: Mantenemos el nombre que ya usabas para no perder tus datos de prueba
    _database = await _initDB('gastos_offline_v2.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      description TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      is_synced INTEGER DEFAULT 0,
      supabase_id INTEGER
    )
    ''');

    await db.execute('''
    CREATE TABLE usuarios_local (
      id INTEGER PRIMARY KEY,
      email TEXT NOT NULL
    )
    ''');
  }

  Future<void> saveLocalUser(int id, String email) async {
    final db = await instance.database;
    await db.delete('usuarios_local');
    await db.insert('usuarios_local', {'id': id, 'email': email});
  }

  Future<void> logoutLocalUser() async {
    final db = await instance.database;
    await db.delete('usuarios_local');
  }

  Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('expenses', row);
  }

  Future<int> updateExpense(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update('expenses', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateSupabaseId(int localId, int supabaseId) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      {'supabase_id': supabaseId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<bool> checkIfSupabaseIdExists(int supabaseId) async {
    final db = await instance.database;
    final res = await db.query(
      'expenses',
      where: 'supabase_id = ?',
      whereArgs: [supabaseId],
    );
    return res.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getExpenses(int userId, String date) async {
    final db = await instance.database;
    return await db.query(
      'expenses',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses(int userId) async {
    final db = await instance.database;
    return await db.query(
      'expenses',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
  }

  Future<int> markAsSynced(int id) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getExpensesInDateRange(
    int userId,
    String startDate,
    String endDate,
  ) async {
    final db = await instance.database;
    return await db.query(
      'expenses',
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }
}