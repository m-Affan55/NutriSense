import 'package:flutter/material.dart';
import '../../../data/models/family_member.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../../../core/language_controller.dart';
import 'family_viewmodel.dart';

class FamilyView extends StatefulWidget {
  const FamilyView({super.key});

  @override
  State<FamilyView> createState() => _FamilyViewState();
}

class _FamilyViewState extends State<FamilyView> {
  final FamilyViewModel _viewModel = FamilyViewModel.instance;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_loadLanguage);
    _loadLanguage();
    _viewModel.loadMembers();
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_loadLanguage);
    super.dispose();
  }

  void _loadLanguage() {
    if (mounted) {
      setState(() {
        _language = LanguageController.instance.currentLanguage;
      });
    }
  }

  Future<void> _deleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        title: Text(_language == 'ur' ? 'کیا آپ حذف کرنا چاہتے ہیں؟' : 'Delete Member?'),
        content: Text(_language == 'ur'
            ? 'کیا آپ واقعی ${member.name} کا پروفائل حذف کرنا چاہتے ہیں؟'
            : 'Are you sure you want to remove ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_language == 'ur' ? 'منسوخ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_language == 'ur' ? 'حذف کریں' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _viewModel.deleteMember(member.id);
      if (!mounted) return;
      CustomToast.show(context, _language == 'ur' ? 'پروفائل حذف کر دی گئی' : 'Member deleted', isError: false);
    }
  }

  void _showAddEditMemberDialog([FamilyMember? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final ageController = TextEditingController(text: existing?.age != null ? '${existing!.age}' : '10');
    final calController = TextEditingController(text: '${existing?.dailyCalorieTarget ?? 1800}');
    final proteinController = TextEditingController(text: '${existing?.dailyProteinG ?? 100}');
    final carbsController = TextEditingController(text: '${existing?.dailyCarbsG ?? 200}');
    final fatController = TextEditingController(text: '${existing?.dailyFatG ?? 50}');

    String relationship = existing?.relationship ?? 'child';
    String gender = existing?.gender ?? 'male';
    List<String> conditions = List<String>.from(existing?.medicalConditions ?? []);
    List<String> restrictions = List<String>.from(existing?.dietaryRestrictions ?? []);

    final availableConditions = [
      'Diabetes',
      'Hypertension',
      'High Cholesterol',
      'Lactose Intolerance',
      'Gluten Intolerance',
    ];

    final availableRestrictions = [
      'Halal',
      'Vegetarian',
      'No Sugar',
      'Low Sodium',
      'Peanut Allergy',
      'Dairy Free',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void updateAutoCalculatedTargets() {
              final age = int.tryParse(ageController.text) ?? 25;
              final targets = FamilyMember.calculateRecommendedTargets(
                age: age,
                gender: gender,
                relationship: relationship,
                conditions: conditions,
              );
              calController.text = '${targets['calories']}';
              proteinController.text = '${targets['protein_g']}';
              carbsController.text = '${targets['carbs_g']}';
              fatController.text = '${targets['fat_g']}';
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null
                              ? (_language == 'ur' ? 'نیا فیملی ممبر شامل کریں' : 'Add Family Member')
                              : (_language == 'ur' ? 'پروفائل میں ترمیم کریں' : 'Edit Member Profile'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _language == 'ur' ? 'نام' : 'Full Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF0D0F14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Relationship & Gender Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: relationship,
                            dropdownColor: const Color(0xFF1E232E),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: _language == 'ur' ? 'رشتہ' : 'Relationship',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: const Color(0xFF0D0F14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: [
                              DropdownMenuItem(value: 'child', child: Text(_language == 'ur' ? 'بچہ (Child)' : 'Child')),
                              DropdownMenuItem(value: 'parent', child: Text(_language == 'ur' ? 'والد/والدہ (Parent)' : 'Parent')),
                              DropdownMenuItem(value: 'spouse', child: Text(_language == 'ur' ? 'شریک حیات (Spouse)' : 'Spouse')),
                              DropdownMenuItem(value: 'sibling', child: Text(_language == 'ur' ? 'بھائی/بہن (Sibling)' : 'Sibling')),
                              DropdownMenuItem(value: 'other', child: Text(_language == 'ur' ? 'دیگر (Other)' : 'Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  relationship = val;
                                  updateAutoCalculatedTargets();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gender,
                            dropdownColor: const Color(0xFF1E232E),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: _language == 'ur' ? 'جنس' : 'Gender',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: const Color(0xFF0D0F14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: [
                              DropdownMenuItem(value: 'male', child: Text(_language == 'ur' ? 'مرد' : 'Male')),
                              DropdownMenuItem(value: 'female', child: Text(_language == 'ur' ? 'عورت' : 'Female')),
                              DropdownMenuItem(value: 'other', child: Text(_language == 'ur' ? 'دیگر' : 'Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  gender = val;
                                  updateAutoCalculatedTargets();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Age
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _language == 'ur' ? 'عمر (سال)' : 'Age (years)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF0D0F14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) {
                        setModalState(() {
                          updateAutoCalculatedTargets();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Medical Conditions Chips
                    Text(
                      _language == 'ur' ? 'طبی کیفیت / بیماریاں' : 'Medical Conditions',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: availableConditions.map((c) {
                        final isSelected = conditions.contains(c);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(c, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white)),
                          selectedColor: const Color(0xFFFFD166),
                          backgroundColor: const Color(0xFF0D0F14),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                conditions.add(c);
                              } else {
                                conditions.remove(c);
                              }
                              updateAutoCalculatedTargets();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Dietary Restrictions Chips
                    Text(
                      _language == 'ur' ? 'غذائی ترجیحات اور الرجی' : 'Dietary Restrictions & Allergens',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: availableRestrictions.map((r) {
                        final isSelected = restrictions.contains(r);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(r, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white)),
                          selectedColor: const Color(0xFF00E676),
                          backgroundColor: const Color(0xFF0D0F14),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                restrictions.add(r);
                              } else {
                                restrictions.remove(r);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Auto-calculated Daily Targets
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0F14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _language == 'ur' ? '🎯 روزانہ کا غذائی ہدف' : '🎯 Daily Macro Targets',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                _language == 'ur' ? 'خودکار تجویز کردہ' : 'Auto-Calculated',
                                style: const TextStyle(color: Color(0xFF00E676), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: calController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'Calories (kcal)',
                                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: proteinController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'Protein (g)',
                                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: carbsController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'Carbs (g)',
                                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: fatController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'Fat (g)',
                                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: const Color(0xFF0B101B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            CustomToast.show(context, _language == 'ur' ? 'براہ کرم نام درج کریں' : 'Please enter member name');
                            return;
                          }

                          final member = FamilyMember(
                            id: existing?.id ?? '',
                            userId: existing?.userId ?? '',
                            name: name,
                            relationship: relationship,
                            age: int.tryParse(ageController.text) ?? 25,
                            gender: gender,
                            dailyCalorieTarget: int.tryParse(calController.text) ?? 1800,
                            dailyProteinG: int.tryParse(proteinController.text) ?? 100,
                            dailyCarbsG: int.tryParse(carbsController.text) ?? 200,
                            dailyFatG: int.tryParse(fatController.text) ?? 50,
                            medicalConditions: conditions,
                            dietaryRestrictions: restrictions,
                            avatarColor: relationship == 'child' ? '#00D2FF' : (relationship == 'parent' ? '#FFD166' : '#00E676'),
                          );

                          Navigator.pop(ctx);
                          if (existing == null) {
                            await _viewModel.addMember(member);
                            if (mounted) {
                              CustomToast.show(context, _language == 'ur' ? 'فیملی ممبر شامل کر دیا گیا' : 'Family member added!', isError: false);
                            }
                          } else {
                            await _viewModel.updateMember(member);
                            if (mounted) {
                              CustomToast.show(context, _language == 'ur' ? 'پروفائل اپ ڈیٹ ہو گئی' : 'Profile updated!', isError: false);
                            }
                          }
                        },
                        child: Text(
                          _language == 'ur' ? 'محفوظ کریں' : 'Save Profile',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([_viewModel, LanguageController.instance]),
      builder: (context, _) {
        _language = LanguageController.instance.currentLanguage;
        final members = _viewModel.members;
        final activeMember = _viewModel.activeMember;

        return Scaffold(
          appBar: AppBar(
            title: Text(_language == 'ur' ? 'خاندانی پروفائلز' : 'Family Profiles'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                tooltip: _language == 'ur' ? 'ممبر شامل کریں' : 'Add Member',
                onPressed: () => _showAddEditMemberDialog(),
              ),
            ],
          ),
          body: RamadanBackgroundWrapper(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Context Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: activeMember != null
                            ? [activeMember.color.withAlpha(50), const Color(0xFF161A22)]
                            : [const Color(0xFF00E676).withAlpha(40), const Color(0xFF161A22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeMember != null ? activeMember.color.withAlpha(90) : const Color(0xFF00E676).withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: activeMember != null ? activeMember.color : const Color(0xFF00E676),
                          child: Text(
                            activeMember != null ? activeMember.relationshipEmoji : '🧑',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeMember != null
                                    ? (_language == 'ur' ? 'فعال پروفائل: ${activeMember.name}' : 'Active View: ${activeMember.name}')
                                    : (_language == 'ur' ? 'فعال پروفائل: میں (ذاتی اکاؤنٹ)' : 'Active View: Me (Self)'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeMember != null
                                    ? (_language == 'ur' ? 'ڈیش بورڈ اور لاگز اس ممبر کے مطابق ہیں' : 'Dashboard and meal logs are mapped to ${activeMember.name}')
                                    : (_language == 'ur' ? 'آپ اپنے ذاتی غذائی اہداف دیکھ رہے ہیں' : 'Showing your primary health targets'),
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (activeMember != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF00E676),
                              backgroundColor: Colors.black26,
                            ),
                            onPressed: () => _viewModel.setActiveMember(null),
                            child: Text(_language == 'ur' ? 'میری پروفائل' : 'Switch to Me'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Family Members Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _language == 'ur' ? 'تمام زیر کفالت افراد (${members.length})' : 'All Family Dependents (${members.length})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(_language == 'ur' ? 'نیا ممبر' : 'Add Dependent'),
                        onPressed: () => _showAddEditMemberDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (members.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.family_restroom_rounded, size: 64, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            _language == 'ur' ? 'کوئی فیملی ممبر شامل نہیں ہے' : 'No family members added yet',
                            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _language == 'ur'
                                ? 'بچوں یا والدین کو شامل کریں تاکہ ان کے لیے الگ میکروز اور غذا ٹریک کی جا سکے!'
                                : 'Add your children or elderly parents to manage custom macro targets and diets!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: const Color(0xFF0B101B),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(_language == 'ur' ? 'پہلا ممبر شامل کریں' : 'Add First Member'),
                            onPressed: () => _showAddEditMemberDialog(),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      itemBuilder: (_, index) {
                        final member = members[index];
                        final isCurrentActive = activeMember?.id == member.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161A22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentActive ? member.color : Colors.white.withAlpha(15),
                              width: isCurrentActive ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Info Row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: member.color.withAlpha(40),
                                    child: Text(member.relationshipEmoji, style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              member.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: member.color.withAlpha(30),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: member.color.withAlpha(80)),
                                              ),
                                              child: Text(
                                                member.getLocalizedRelationship(_language),
                                                style: TextStyle(
                                                  color: member.color,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${member.age} ${_language == 'ur' ? 'سال' : 'years old'} • ${member.gender.toUpperCase()}',
                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                                    color: const Color(0xFF1E232E),
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _showAddEditMemberDialog(member);
                                      } else if (action == 'delete') {
                                        _deleteMember(member);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit, size: 16, color: Colors.white70),
                                            const SizedBox(width: 8),
                                            Text(_language == 'ur' ? 'ترمیم کریں' : 'Edit'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                            const SizedBox(width: 8),
                                            Text(_language == 'ur' ? 'حذف کریں' : 'Delete', style: const TextStyle(color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Target Macros Row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0F14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildTargetMacroBadge('Calories', '${member.dailyCalorieTarget}', 'kcal', Colors.orangeAccent),
                                    _buildTargetMacroBadge('Protein', '${member.dailyProteinG}g', 'Prot', Colors.greenAccent),
                                    _buildTargetMacroBadge('Carbs', '${member.dailyCarbsG}g', 'Carb', Colors.lightBlueAccent),
                                    _buildTargetMacroBadge('Fat', '${member.dailyFatG}g', 'Fat', Colors.redAccent),
                                  ],
                                ),
                              ),

                              // Tags for Medical & Dietary
                              if (member.medicalConditions.isNotEmpty || member.dietaryRestrictions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    ...member.medicalConditions.map((c) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withAlpha(25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.amber.withAlpha(80)),
                                          ),
                                          child: Text('⚠️ $c', style: const TextStyle(color: Colors.amber, fontSize: 10)),
                                        )),
                                    ...member.dietaryRestrictions.map((r) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00E676).withAlpha(25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF00E676).withAlpha(80)),
                                          ),
                                          child: Text('🥗 $r', style: const TextStyle(color: Color(0xFF00E676), fontSize: 10)),
                                        )),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Switch Profile Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isCurrentActive ? member.color : Colors.white,
                                    side: BorderSide(
                                      color: isCurrentActive ? member.color : Colors.white24,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: Icon(isCurrentActive ? Icons.check_circle_rounded : Icons.swap_horiz_rounded, size: 16),
                                  label: Text(
                                    isCurrentActive
                                        ? (_language == 'ur' ? 'فعال پروفائل' : 'Currently Active')
                                        : (_language == 'ur' ? '${member.name} کے طور پر لاگ کریں' : 'Switch Dashboard to ${member.name}'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: isCurrentActive
                                      ? null
                                      : () {
                                          _viewModel.setActiveMember(member);
                                          CustomToast.show(
                                            context,
                                            _language == 'ur' ? 'ڈیش بورڈ ${member.name} پر منتقل ہو گیا' : 'Dashboard switched to ${member.name}',
                                            isError: false,
                                          );
                                        },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTargetMacroBadge(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
