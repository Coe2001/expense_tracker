// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ------------------
// Models & Storage
// ------------------

class Expense {
  String id;
  double amount;
  String category;
  DateTime date;
  String? notes;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        notes: json['notes'] as String?,
      );
}

class ExpenseRepository {
  static const _expensesKey = 'expenses_v1';
  static const _categoriesKey = 'categories_v1';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<List<Expense>> loadExpenses() async {
    final p = await _prefs;
    final s = p.getString(_expensesKey);
    if (s == null || s.isEmpty) return [];
    final List list = jsonDecode(s) as List;
    return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveExpenses(List<Expense> items) async {
    final p = await _prefs;
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await p.setString(_expensesKey, encoded);
  }

  Future<List<String>> loadCategories() async {
    final p = await _prefs;
    final list = p.getStringList(_categoriesKey);
    if (list == null || list.isEmpty) {
      final defaults = ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
      await saveCategories(defaults);
      return defaults;
    }
    return list;
  }

  Future<void> saveCategories(List<String> categories) async {
    final p = await _prefs;
    await p.setStringList(_categoriesKey, categories);
  }
}

// ------------------
// App
// ------------------

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF052968), // Navy blue
        scaffoldBackgroundColor: Colors.white, // Keep content background bright
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001F54), // Dark navy
          foregroundColor: Colors.white, // Makes AppBar text & icons white
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black), // Main text readable
          bodyLarge: TextStyle(color: Colors.black),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}


enum PeriodFilter { all, today, thisWeek, thisMonth, custom }

enum SortBy { dateDesc, dateAsc, amountDesc, amountAsc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repo = ExpenseRepository();
  List<Expense> _expenses = [];
  List<String> _categories = [];

  PeriodFilter _filter = PeriodFilter.all;
  DateTime? _customStart;
  DateTime? _customEnd;

  SortBy _sortBy = SortBy.dateDesc;

  final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);
  final dateFormat = DateFormat.yMMMd();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _categories = await repo.loadCategories();
    _expenses = await repo.loadExpenses();
    _sortExpenses();
    setState(() => _loading = false);
  }

  Future<void> _addOrUpdateExpense(Expense e, {bool isNew = true}) async {
    if (isNew) {
      _expenses.insert(0, e);
    } else {
      final idx = _expenses.indexWhere((x) => x.id == e.id);
      if (idx != -1) _expenses[idx] = e;
    }
    await repo.saveExpenses(_expenses);
    _sortExpenses();
    setState(() {});
  }

  Future<void> _deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await repo.saveExpenses(_expenses);
    setState(() {});
  }

  Future<void> _addCategory(String name) async {
    name = name.trim();
    if (name.isEmpty) return;
    if (!_categories.contains(name)) {
      _categories.add(name);
      await repo.saveCategories(_categories);
      setState(() {});
    }
  }

  void _sortExpenses() {
    switch (_sortBy) {
      case SortBy.dateDesc:
        _expenses.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortBy.dateAsc:
        _expenses.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortBy.amountDesc:
        _expenses.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortBy.amountAsc:
        _expenses.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
  }

  List<Expense> _applyFilterAndSort() {
    final now = DateTime.now();
    DateTime start, end;

    switch (_filter) {
      case PeriodFilter.all:
        start = DateTime(1970);
        end = DateTime(2100);
        break;
      case PeriodFilter.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        break;
      case PeriodFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
        break;
      case PeriodFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
        break;
      case PeriodFilter.custom:
        start = _customStart ?? DateTime(1970);
        end = _customEnd ?? DateTime(2100);
        break;
    }

    final filtered = _expenses.where((e) {
      return (e.date.isAtSameMomentAs(start) || e.date.isAfter(start)) &&
          (e.date.isAtSameMomentAs(end) || e.date.isBefore(end));
    }).toList();

    return filtered;
  }

  double _sum(List<Expense> list) => list.fold(0.0, (p, e) => p + e.amount);

  Map<String, double> _categoryTotals(List<Expense> list) {
    final Map<String, double> map = {};
    for (var c in _categories) {
      map[c] = 0.0;
    }
    for (var e in list) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final first = await showDatePicker(
        context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (first == null) return;
    final second = await showDatePicker(
        context: context, initialDate: first, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (second == null) return;
    setState(() {
      _customStart = DateTime(first.year, first.month, first.day);
      _customEnd = DateTime(second.year, second.month, second.day, 23, 59, 59);
      _filter = PeriodFilter.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilterAndSort();
    final total = _sum(filtered);
    final catTotals = _categoryTotals(filtered);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/logo.jpg',
                height: 32,
              ),
              const SizedBox(width: 8),
              const Text('Simple Expense Tracker'),
            ],
          ),
          bottom: const TabBar(
            tabs: [Tab(text: 'Dashboard'), Tab(text: 'Expenses')],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final newExpense = await Navigator.push<Expense?>(
                  context,
                  MaterialPageRoute(builder: (_) => AddExpensePage(categories: _categories)),
                );
                if (newExpense != null) await _addOrUpdateExpense(newExpense, isNew: true);
              },
              tooltip: 'Add expense',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Dashboard Tab
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filters & sort
                        Row(
                          children: [
                            Expanded(child: _buildFilterMenu()),
                            const SizedBox(width: 12),
                            _buildSortMenu(),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Text(currencyFormat.format(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Count: ${filtered.length}'),
                                    const SizedBox(height: 6),
                                    Text('Avg: ${filtered.isEmpty ? "0" : currencyFormat.format(total / filtered.length)}'),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Text('By Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: catTotals.entries.map((entry) {
                              final cat = entry.key;
                              final val = entry.value;
                              final pct = total == 0 ? 0.0 : (val / total);
                              return ListTile(
                                title: Text(cat),
                                subtitle: LinearProgressIndicator(value: pct),
                                trailing: Text(currencyFormat.format(val)),
                              );
                            }).toList(),
                          ),
                        ),

                        // Quick category add
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final text = await showDialog<String>(context: context, builder: (_) => _AddCategoryDialog());
                                  if (text != null && text.trim().isNotEmpty) await _addCategory(text.trim());
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add category'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  // Expenses Tab
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(child: _buildFilterMenu()),
                            const SizedBox(width: 8),
                            _buildSortMenu(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No expenses yet. Tap + to add.'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final e = filtered[i];
                                  return Dismissible(
                                    key: ValueKey(e.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    onDismissed: (_) async => await _deleteExpense(e.id),
                                    child: ListTile(
                                      title: Text('${e.category} — ${currencyFormat.format(e.amount)}'),
                                      subtitle: Text('${dateFormat.format(e.date)}${e.notes != null ? ' • ${e.notes}' : ''}'),
                                      onTap: () async {
                                        final edited = await Navigator.push<Expense?>(
                                          context,
                                          MaterialPageRoute(builder: (_) => AddExpensePage(categories: _categories, existing: e)),
                                        );
                                        if (edited != null) await _addOrUpdateExpense(edited, isNew: false);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterMenu() {
    String label;
    switch (_filter) {
      case PeriodFilter.all:
        label = 'All';
        break;
      case PeriodFilter.today:
        label = 'Today';
        break;
      case PeriodFilter.thisWeek:
        label = 'This week';
        break;
      case PeriodFilter.thisMonth:
        label = 'This month';
        break;
      case PeriodFilter.custom:
        final s = _customStart != null ? DateFormat.yMd().format(_customStart!) : '?';
        final e = _customEnd != null ? DateFormat.yMd().format(_customEnd!) : '?';
        label = 'Custom: $s - $e';
        break;
    }

    return PopupMenuButton<PeriodFilter>(
      itemBuilder: (context) => [
        const PopupMenuItem(value: PeriodFilter.all, child: Text('All')),
        const PopupMenuItem(value: PeriodFilter.today, child: Text('Today')),
        const PopupMenuItem(value: PeriodFilter.thisWeek, child: Text('This week')),
        const PopupMenuItem(value: PeriodFilter.thisMonth, child: Text('This month')),
        const PopupMenuItem(value: PeriodFilter.custom, child: Text('Custom range')),
      ],
      child: ElevatedButton.icon(onPressed: null, icon: const Icon(Icons.filter_list), label: Text(label)),
      onSelected: (v) async {
        if (v == PeriodFilter.custom) {
          await _pickCustomRange(context);
        } else {
          setState(() {
            _filter = v;
            _customStart = null;
            _customEnd = null;
          });
        }
      },
    );
  }

  Widget _buildSortMenu() {
    return DropdownButton<SortBy>(
      value: _sortBy,
      items: const [
        DropdownMenuItem(value: SortBy.dateDesc, child: Text('Date ↓')),
        DropdownMenuItem(value: SortBy.dateAsc, child: Text('Date ↑')),
        DropdownMenuItem(value: SortBy.amountDesc, child: Text('Amount ↓')),
        DropdownMenuItem(value: SortBy.amountAsc, child: Text('Amount ↑')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _sortBy = v;
          _sortExpenses();
        });
      },
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _ctl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add category'),
      content: TextField(
        controller: _ctl,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _ctl.text.trim()), child: const Text('Add')),
      ],
    );
  }
}

// ------------------
// Add / Edit Expense Page
// ------------------

class AddExpensePage extends StatefulWidget {
  final List<String> categories;
  final Expense? existing;

  const AddExpensePage({super.key, required this.categories, this.existing});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _amountCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String? _category;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _amountCtl.text = ex.amount.toString();
      _category = ex.category;
      _date = ex.date;
      _notesCtl.text = ex.notes ?? '';
    } else {
      _category = widget.categories.isNotEmpty ? widget.categories[0] : 'Other';
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _save() {
    final amt = double.tryParse(_amountCtl.text.trim());
    if (amt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid amount')));
      return;
    }
    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final e = Expense(id: id, amount: amt, category: _category ?? 'Other', date: _date, notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim());
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add expense' : 'Edit expense')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            TextField(
              controller: _amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add category',
                  onPressed: () async {
                    final text = await showDialog<String>(context: context, builder: (_) => _AddCategoryDialog());
                    if (text != null && text.trim().isNotEmpty) {
                      // Save category immediately to SharedPreferences
                      final p = await SharedPreferences.getInstance();
                      const key = ExpenseRepository._categoriesKey;
                      final list = p.getStringList(key) ?? [];
                      if (!list.contains(text.trim())) {
                        list.add(text.trim());
                        await p.setStringList(key, list);
                        setState(() {
                          _category = text.trim();
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: Text('Date: ${DateFormat.yMMMd().format(_date)}'),
              trailing: TextButton(onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              }, child: const Text('Pick')),
            ),
            TextField(controller: _notesCtl, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}