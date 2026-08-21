import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'grocery_viewmodel.dart';

class GroceryView extends StatefulWidget {
  const GroceryView({super.key});

  @override
  State<GroceryView> createState() => _GroceryViewState();
}

class _GroceryViewState extends State<GroceryView> {
  final GroceryViewModel _viewModel = GroceryViewModel();
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
      });
    }
  }

  String _t(String key) {
    final translations = {
      'en': {
        'title': 'Smart Grocery List',
        'sub': 'AI-optimized weekly shopping checklist',
        'generate': 'Generate List',
        'clearChecked': 'Clear Checked',
        'emptyTitle': 'Your list is empty',
        'emptySub': 'Tap Generate to analyze your targets & recent meals and create a personalized shopping list.',
        'addTitle': 'Add Custom Item',
        'itemName': 'Item Name (e.g. Spinach)',
        'quantity': 'Quantity (e.g. 250g)',
        'category': 'Category',
        'cancel': 'Cancel',
        'add': 'Add',
        'required': 'Required',
        'generating': 'Generating list...',
      },
      'ur': {
        'title': 'اسمارٹ گروسری لسٹ',
        'sub': 'اے آئی کے ذریعے تیار کردہ ہفتہ وار خریداری کی فہرست',
        'generate': 'فہرست بنائیں',
        'clearChecked': 'چیک شدہ حذف کریں',
        'emptyTitle': 'گروسری لسٹ خالی ہے',
        'emptySub': 'اپنے اہداف اور حالیہ کھانوں کی بنیاد پر خریداری کی فہرست بنانے کے لیے فہرست بنائیں پر کلک کریں۔',
        'addTitle': 'نئی چیز شامل کریں',
        'itemName': 'چیز کا نام (مثال کے طور پر، پالک)',
        'quantity': 'مقدار (مثال کے طور پر، 250 گرام)',
        'category': 'کیٹیگری',
        'cancel': 'منسوخ کریں',
        'add': 'شامل کریں',
        'required': 'لازمی',
        'generating': 'فہرست تیار ہو رہی ہے...',
      }
    };
    return translations[_language]?[key] ?? key;
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    String selectedCategory = 'Produce';
    final formKey = GlobalKey<FormState>();

    final categories = ['Produce', 'Proteins', 'Dairy & Alternatives', 'Grains & Pantry', 'Healthy Snacks', 'Other'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161A22),
              title: Text(_t('addTitle'), style: const TextStyle(color: Colors.white)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _t('itemName'),
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? _t('required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _t('quantity'),
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF161A22),
                      initialValue: selectedCategory,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _t('category'),
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t('cancel'), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      _viewModel.addItem(selectedCategory, nameController.text, qtyController.text);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(_t('add'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _t('title'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 1.2,
            colors: [Color(0xFF1A2420), Color(0xFF0D0F14)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('sub'),
                style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
              ),
              const SizedBox(height: 20),
              
              // Top Action Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _viewModel.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _viewModel.isLoading ? _t('generating') : _t('generate'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _viewModel.isLoading ? null : _viewModel.fetchGroceryList,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: Text(
                      _t('clearChecked'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _viewModel.categories.isEmpty ? null : _viewModel.clearCheckedItems,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Grocery Categories List
              Expanded(
                child: _viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _viewModel.categories.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _viewModel.categories.length,
                            padding: const EdgeInsets.only(bottom: 100),
                            itemBuilder: (context, catIdx) {
                              final cat = _viewModel.categories[catIdx];
                              final String categoryName = cat['category'];
                              final List<Map<String, dynamic>> items = cat['items'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161A22),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withAlpha(15)),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    initiallyExpanded: true,
                                    title: Text(
                                      '$categoryName (${items.length})',
                                      style: const TextStyle(
                                        color: Color(0xFF00E676),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    children: items.asMap().entries.map((entry) {
                                      final itemIdx = entry.key;
                                      final item = entry.value;
                                      final bool isChecked = item['checked'] ?? false;

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        leading: Checkbox(
                                          activeColor: const Color(0xFF00E676),
                                          checkColor: Colors.black,
                                          side: const BorderSide(color: Colors.grey),
                                          value: isChecked,
                                          onChanged: (_) {
                                            _viewModel.toggleItemChecked(catIdx, itemIdx);
                                          },
                                        ),
                                        title: Text(
                                          item['name'],
                                          style: TextStyle(
                                            color: isChecked ? Colors.grey : Colors.white,
                                            decoration: isChecked ? TextDecoration.lineThrough : null,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item['quantity'] ?? '',
                                          style: TextStyle(
                                            color: isChecked ? Colors.grey.withAlpha(100) : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                          onPressed: () {
                                            _viewModel.removeItem(catIdx, itemIdx);
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161A22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              size: 60,
              color: Color(0xFF00E676),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _t('emptyTitle'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _t('emptySub'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
