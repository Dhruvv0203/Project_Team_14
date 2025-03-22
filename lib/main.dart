import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'DBHelper.dart';

void main() {
  runApp(FinanceManagerApp());
}

class FinanceManagerApp extends StatefulWidget {
  @override
  _FinanceManagerAppState createState() => _FinanceManagerAppState();
}

class _FinanceManagerAppState extends State<FinanceManagerApp> {
  bool _isDarkMode = false;

  void toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Finance Manager',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(toggleTheme: toggleTheme, isDarkMode: _isDarkMode),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;

  const MainScreen({required this.toggleTheme, required this.isDarkMode, Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // <-- CHANGE HERE
        index: _selectedIndex,
        children: [
          HomeScreen(key: UniqueKey()), // <-- Forces HomeScreen to reload
          AddTransactionScreen(key: UniqueKey()),
          ReportsScreen(),
          // Pass updated value every time
          SettingsScreen(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        backgroundColor: widget.isDarkMode ? Colors.grey[850] : Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
//////////////////////////////////////////////////////////
// -------------------- HOME SCREEN --------------------
//////////////////////////////////////////////////////////

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key); // <-- Accepts key now

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final tx = await DBHelper().getAllTransactions();
    final goals = await DBHelper().getAllGoals();
    setState(() {
      _transactions = tx;
      _goals = goals;
    });
  }

  void _editTransaction(Map<String, dynamic> tx) {
    final _amountController = TextEditingController(text: tx['amount'].abs().toString());
    final _descController = TextEditingController(text: tx['description']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: _descController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              double amt = double.parse(_amountController.text);
              if (tx['type'] == 'Expense') amt = -amt;
              await DBHelper().updateTransaction(tx['id'], {
                'amount': amt,
                'date': tx['date'],
                'type': tx['type'],
                'category': tx['category'],
                'description': _descController.text,
              });
              Navigator.of(ctx).pop();
              _loadData();
            },
          )
        ],
      ),
    );
  }

  void _deleteTransaction(int id) async {
    await DBHelper().deleteTransaction(id);
    _loadData();
  }

  void _showGoalOptions(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(goal['goal_name'] +
            (goal['current_amount'] >= goal['target_amount'] ? ' ✅ Completed' : '')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (goal['current_amount'] < goal['target_amount'])
              ElevatedButton(
                child: Text('Add Saved Amount'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showAddAmountDialog(goal);
                },
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete Goal'),
              onPressed: () async {
                await DBHelper().deleteGoal(goal['id']);
                Navigator.of(ctx).pop();
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAmountDialog(Map<String, dynamic> goal) {
    final _amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Saved Amount'),
        content: TextField(
          controller: _amountController,
          decoration: InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              double addAmount = double.parse(_amountController.text);
              double newAmount = goal['current_amount'] + addAmount;
              await DBHelper().updateGoal(goal['id'], {
                'goal_name': goal['goal_name'],
                'target_amount': goal['target_amount'],
                'current_amount': newAmount,
              });
              Navigator.of(ctx).pop();
              _loadData();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double income = 0, expenses = 0;
    for (var t in _transactions) {
      double amt = t['amount'];
      if (t['type'] == 'Income') income += amt;
      else expenses += amt;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Income: \$${income.toStringAsFixed(2)}'),
            Text('Expenses: \$${expenses.abs().toStringAsFixed(2)}'),
            Divider(),
            Text('Savings Goals:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._goals.map((g) => ListTile(
              title: Text(g['goal_name'] +
                  (g['current_amount'] >= g['target_amount'] ? ' ✅ Completed' : '')),
              subtitle: Text('Progress: \$${g['current_amount']} / \$${g['target_amount']}'),
              onTap: () => _showGoalOptions(g),
            )),
            Divider(),
            Text('Recent Transactions:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
  itemCount: _transactions.length,
  itemBuilder: (ctx, idx) {
    final t = _transactions[idx];
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t['category']),
          Text(
            '\$${t['amount'].abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: t['type'] == 'Income' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${DateFormat.yMMMd().format(DateTime.parse(t['date']))}\n${t['description']}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _editTransaction(t),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _deleteTransaction(t['id']),
          ),
        ],
      ),
    );
  },
)
,
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////
// -------------------- ADD TRANSACTION SCREEN --------------------
//////////////////////////////////////////////////////////

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({Key? key}) : super(key: key); // <-- Add key

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedCategory;
  String _selectedType = 'Expense';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCategories(); // <-- Reload categories every time
  }

  void _loadCategories() async {
    final cat = await DBHelper().getAllCategories();
    setState(() {
      _categories = cat;
      if (cat.isNotEmpty) _selectedCategory = cat.first['name'];
    });
  }

  void _saveTransaction() async {
    double amount = double.parse(_amountController.text);
    if (_selectedType == 'Expense') amount = -amount;

    await DBHelper().insertTransaction({
      'amount': amount,
      'date': _selectedDate.toIso8601String(),
      'type': _selectedType,
      'category': (_selectedType == 'Income') ? 'Income' : _selectedCategory,
      'description': _descController.text,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved')));
    _amountController.clear();
    _descController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Transaction')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField(
              value: _selectedType,
              items: ['Income', 'Expense'].map((t) {
                return DropdownMenuItem(value: t, child: Text(t));
              }).toList(),
              onChanged: (val) => setState(() => _selectedType = val as String),
            ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            if (_selectedType == 'Expense')
              DropdownButtonFormField(
                value: _selectedCategory,
                items: _categories.map((c) {
                  return DropdownMenuItem(value: c['name'], child: Text(c['name']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val as String),
              ),
            TextField(
              controller: _descController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            ElevatedButton(onPressed: _saveTransaction, child: Text('Save')),
          ],
        ),
      ),
    );
  }
}
//////////////////////////////////////////////////////////
// -------------------- REPORTS SCREEN --------------------
//////////////////////////////////////////////////////////


class ReportsScreen extends StatelessWidget {
  final Map<String, Color> categoryColors = {
    'Food': Colors.blue,
    'Rent': Colors.red,
    'Entertainment': Colors.green,
    'Utilities': Colors.orange,
    'Other': Colors.purple
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBHelper().getAllTransactions(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final transactions = snapshot.data!;
        Map<String, double> categoryTotals = {};
        double incomeTotal = 0, expenseTotal = 0;

        for (var t in transactions) {
          if (t['type'] == 'Income') {
            incomeTotal += t['amount'];
          } else {
            categoryTotals[t['category']] = (categoryTotals[t['category']] ?? 0) + t['amount'].abs();
            expenseTotal += t['amount'].abs();
          }
        }

        return Scaffold(
          appBar: AppBar(title: Text('Reports')),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expense Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: categoryTotals.entries.map((entry) {
                        final color = categoryColors[entry.key] ?? Colors.grey;
                        return PieChartSectionData(
                          color: color,
                          title: entry.key,
                          value: entry.value,
                          radius: 50,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Divider(),
                SizedBox(height: 20), // Space before title
                Text('Income vs Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 100), // Additional spacing
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: incomeTotal,
                              width: 40, // Thicker bar
                              color: Colors.blue,
                              borderRadius: BorderRadius.zero, // Flat tips
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: expenseTotal,
                              width: 40, // Thicker bar
                              color: Colors.red,
                              borderRadius: BorderRadius.zero, // Flat tips
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false), // Remove side numbering
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              return Text(val == 0 ? 'Income' : 'Expenses');
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: false), // Remove dotted gridlines
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.grey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '\$${rod.toY}',
                              TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

//////////////////////////////////////////////////////////
// -------------------- SETTINGS SCREEN --------------------
//////////////////////////////////////////////////////////

class SettingsScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;

  SettingsScreen({required this.toggleTheme, required this.isDarkMode});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _goalNameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _categoryNameController = TextEditingController();

  late bool _localDarkMode; // <-- NEW LOCAL VARIABLE

  @override
  void initState() {
    super.initState();
    _localDarkMode = widget.isDarkMode; // Initialize from parent
  }

  void _addGoal() async {
    await DBHelper().insertGoal({
      'goal_name': _goalNameController.text,
      'target_amount': double.parse(_targetAmountController.text),
      'current_amount': 0.0,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Goal Added')));
  }

  void _addCategory() async {
    await DBHelper().addCategory(_categoryNameController.text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Category Added')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: Text('Dark Mode'),
              value: _localDarkMode, // <-- USE LOCAL VARIABLE
              onChanged: (val) {
                setState(() {
                  _localDarkMode = val;
                });
                widget.toggleTheme(val);
              },
            ),
            Divider(),
            Text('Add Savings Goal', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _goalNameController, decoration: InputDecoration(labelText: 'Goal Name')),
            TextField(controller: _targetAmountController, decoration: InputDecoration(labelText: 'Target Amount')),
            ElevatedButton(onPressed: _addGoal, child: Text('Add Goal')),
            Divider(),
            Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _categoryNameController, decoration: InputDecoration(labelText: 'Category Name')),
            ElevatedButton(onPressed: _addCategory, child: Text('Add Category')),
          ],
        ),
      ),
    );
  }
}
