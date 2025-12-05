import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

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
      _goToHome(user['id'] as int, user['email'] as String);
    } else {
      _goToLogin();
    }
  }

  void _goToHome(int id, String email) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ExpenseHomePage(userId: id, userEmail: email),
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseHomePage(userId: userId, userEmail: email),
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
// PANTALLA PRINCIPAL (Con Edit y Delete)
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
      'supabase_id': null, // Nuevo, no tiene ID remoto aún
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
                // Actualizamos localmente y marcamos como NO sincronizado para que se suba
                await DatabaseHelper.instance.updateExpense(item['id'], {
                  'description': newDesc,
                  'amount': newAmount,
                  'is_synced': 0,
                });
                if (mounted) {
                  Navigator.pop(context);
                  await _loadLocalExpenses();
                  _syncData(); // Disparar sync para actualizar nube
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
      // 1. Borrar de local
      await DatabaseHelper.instance.deleteExpense(item['id']);

      // 2. Intentar borrar de nube si tiene ID remoto y hay internet
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
            // Si falla, se queda huérfano en la nube (limitación simple)
            // O podrías implementar una cola de borrado.
            debugPrint("Error borrando remoto: $e");
          }
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Borrado local. Conéctate para borrar de la nube.",
                ),
              ),
            );
        }
      }

      await _loadLocalExpenses();
    }
  }

  // --- SYNC MEJORADO ---
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

      // 1. SUBIR CAMBIOS (Insert o Update)
      for (var row in unsynced) {
        final supabaseId = row['supabase_id']; // ¿Ya existe en la nube?

        if (supabaseId == null) {
          // A) Es NUEVO -> Insertar
          final response = await supabase
              .from('expenses')
              .insert({
                'description': row['description'],
                'amount': row['amount'],
                'date': row['date'],
                'user_id': row['user_id'],
              })
              .select()
              .single(); // Pedimos que nos devuelva el dato insertado

          // Guardamos el ID que Supabase le asignó para futuras ediciones
          await DatabaseHelper.instance.updateSupabaseId(
            row['id'],
            response['id'] as int,
          );
        } else {
          // B) Es EDICIÓN -> Update
          await supabase
              .from('expenses')
              .update({
                'description': row['description'],
                'amount': row['amount'],
              })
              .eq('id', supabaseId);
        }

        // Marcar como sincronizado
        await DatabaseHelper.instance.markAsSynced(row['id']);
      }

      // 2. BAJAR DATOS (Solo nuevos para no sobreescribir ediciones locales recientes)
      final remoteData = await supabase
          .from('expenses')
          .select()
          .eq('user_id', widget.userId);
      final dbHelper = DatabaseHelper.instance;
      int newItemsCount = 0;

      for (var remoteItem in remoteData) {
        final rId = remoteItem['id'];

        // Verificamos si ya tenemos este item por su ID de Supabase
        final exists = await dbHelper.checkIfSupabaseIdExists(rId);

        if (!exists) {
          await dbHelper.insertExpense({
            'description': remoteItem['description'],
            'amount': (remoteItem['amount'] as num).toDouble(),
            'date': remoteItem['date'],
            'user_id': widget.userId,
            'is_synced': 1,
            'supabase_id': rId, // Guardamos la referencia
          });
          newItemsCount++;
        }
      }

      if (mounted) {
        await _loadLocalExpenses();
        if (unsynced.isNotEmpty || newItemsCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sincronización completada"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error de conexión al sincronizar")),
        );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _logout() async {
    await DatabaseHelper.instance.logoutLocalUser();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
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
          // HEADER FECHA
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
                  label: const Text("Cambiar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),

          // FORMULARIO AGREGAR
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
                      labelText: "Descripción",
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

          // LISTA DE GASTOS
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
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "Bs. ${(item['amount'] as num).toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
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

          // FOOTER TOTAL
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
                  "TOTAL DÍA:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Bs. ${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
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

// =========================================================================
// GESTOR DE BASE DE DATOS LOCAL (SQLite)
// =========================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(
      'gastos_offline_v2.db',
    ); // Cambié nombre para forzar nueva DB limpia
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Añadimos 'supabase_id' para poder editar/borrar remotamente
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

  // NUEVO: Actualizar gasto
  Future<int> updateExpense(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update('expenses', row, where: 'id = ?', whereArgs: [id]);
  }

  // NUEVO: Eliminar gasto
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // NUEVO: Guardar el ID de Supabase después de subirlo
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

  Future<List<Map<String, dynamic>>> getExpenses(
    int userId,
    String date,
  ) async {
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
}
