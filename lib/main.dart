import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICIALIZACIÓN DE SUPABASE
  // REEMPLAZA ESTOS VALORES CON TUS PROPIAS CLAVES DE SUPABASE
  await Supabase.initialize(
    url: 'https://ptadxhhlopvrhsroxdmw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0YWR4aGhsb3B2cmhzcm94ZG13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY3NDUxMjksImV4cCI6MjA2MjMyMTEyOX0.UTmuf00dvfB1ifk9emecUKV-yEdukpQWGAZ6YfUMaEQ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gastos DuQuen v1.0',
      theme: ThemeData(
        // Tema principal en color verde azulado (Teal)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ----------------------------------------------------------------
// 1. PANTALLA DE BIENVENIDA (SPLASH SCREEN)
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
    // Temporizador de 2 segundos antes de ir a la pantalla principal
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ExpenseHomePage()),
        );
      }
    });
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
              "Gastos DuQuen v1.0",
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
// 2. PANTALLA PRINCIPAL
// ----------------------------------------------------------------
class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  // Cliente de Supabase
  final _supabase = Supabase.instance.client;

  // Controladores de texto
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  // Estado
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Formato de fecha para la base de datos (yyyy-MM-dd)
  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  // Formato de fecha para mostrar al usuario (dd/MM/yyyy)
  String get _displayDate => DateFormat('dd/MM/yyyy').format(_selectedDate);

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // --- LÓGICA: SELECCIONAR FECHA ---
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal, // Color de cabecera y selección
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- LÓGICA: GUARDAR GASTO ---
  Future<void> _addExpense() async {
    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();

    if (description.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa descripción y monto')),
      );
      return;
    }

    // Validación básica de número
    final amount = double.tryParse(amountText);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser un número válido')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Insertar en la tabla 'expenses' de Supabase
      await _supabase.from('expenses').insert({
        'description': description,
        'amount': amount,
        'date': _formattedDate, // Guarda con la fecha seleccionada
      });

      // Limpiar campos y cerrar teclado
      _descriptionController.clear();
      _amountController.clear();
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gasto registrado!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos el Stream que escucha cambios en la base de datos
    // Filtramos por la fecha seleccionada (.eq('date', ...))
    final expenseStream = _supabase
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('date', _formattedDate)
        .order('created_at', ascending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos DuQuen v1.0"),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // -------------------------------------------
          // SECCIÓN 1: Selector de Fecha
          // -------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              border: Border(bottom: BorderSide(color: Colors.teal.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Viendo gastos del:",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      _displayDate,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickDate(context),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text("Cambiar fecha"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal,
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------
          // SECCIÓN 2: Formulario de Entrada
          // -------------------------------------------
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (ej. Heladito)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monto',
                          border: OutlineInputBorder(),
                          prefixText: 'Bs. ',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "ADICIONAR NUEVO GASTO",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // -------------------------------------------
          // SECCIÓN 3: Lista de Gastos (StreamBuilder)
          // -------------------------------------------
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: expenseStream,
              builder: (context, snapshot) {
                // Estado de Error
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error al cargar datos: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                // Estado de Carga
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final expenses = snapshot.data!;

                // Calcular el total en tiempo real
                double totalAmount = 0;
                for (var expense in expenses) {
                  // Supabase puede devolver int o double, aseguramos double
                  totalAmount += (expense['amount'] as num).toDouble();
                }

                return Column(
                  children: [
                    // Cabecera de la lista
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.grey.shade100,
                      child: Text(
                        "Lista de movimientos (${expenses.length})",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // La Lista en sí
                    Expanded(
                      child: expenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notes,
                                    size: 60,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "No hay gastos registrados hoy",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: expenses.length,
                              separatorBuilder: (ctx, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = expenses[index];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.teal.shade100,
                                    child: Icon(
                                      Icons.receipt_long,
                                      color: Colors.teal.shade700,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    item['description'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Text(
                                    "Bs. ${(item['amount'] as num).toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // -------------------------------------------
                    // SECCIÓN 4: Footer con Acumulado
                    // -------------------------------------------
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade900,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "TOTAL GASTOS:",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              "Bs. ${totalAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
