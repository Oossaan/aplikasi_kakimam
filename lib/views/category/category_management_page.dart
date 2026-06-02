import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../controllers/category_controller.dart';
import '../../models/category_model.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryController>().loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CategoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9fafb),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.tag(PhosphorIconsStyle.bold), size: 22),
            const SizedBox(width: 10),
            const Text(
              'Manajemen Kategori',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari kategori...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          PhosphorIcons.x(PhosphorIconsStyle.bold),
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          controller.loadCategories();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (query) {
                setState(() {});
                if (query.isEmpty) {
                  controller.loadCategories();
                } else {
                  controller.searchCategories(query);
                }
              },
            ),
          ),

          // Category count badge
          if (controller.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${controller.categories.length} kategori',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Category List
          Expanded(
            child: controller.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF667eea),
                    ),
                  )
                : controller.categories.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF667eea),
                        onRefresh: () => controller.loadCategories(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: controller.categories.length,
                          itemBuilder: (context, index) {
                            final category = controller.categories[index];
                            return _buildCategoryCard(
                                context, category, controller);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showCategoryDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            PhosphorIcons.plus(PhosphorIconsStyle.bold),
            color: Colors.white,
            size: 28,
          ),
        ),
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
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.tag(PhosphorIconsStyle.bold),
              size: 56,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum ada kategori',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambah kategori baru untuk memulai',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, Category category, CategoryController controller) {
    final categoryColor = _parseColor(category.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCategoryDialog(context, category: category),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getIconData(category.icon),
                    color: categoryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF1f2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!category.isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nonaktif',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (category.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (category.productCount != null &&
                          category.productCount! > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.package(PhosphorIconsStyle.bold),
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${category.productCount} produk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Menu
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
                      color: Colors.grey.shade600,
                      size: 18,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  itemBuilder: (context) => [
                    _buildPopupItem(
                      'edit',
                      PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold),
                      'Edit',
                      const Color(0xFF667eea),
                    ),
                    if (category.parentId == null)
                      _buildPopupItem(
                        'add_sub',
                        PhosphorIcons.plus(PhosphorIconsStyle.bold),
                        'Tambah Subkategori',
                        const Color(0xFF10b981),
                      ),
                    _buildPopupItem(
                      category.isActive ? 'deactivate' : 'activate',
                      category.isActive
                          ? PhosphorIcons.minusCircle(PhosphorIconsStyle.bold)
                          : PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                      category.isActive ? 'Nonaktifkan' : 'Aktifkan',
                      const Color(0xFFf59e0b),
                    ),
                    _buildPopupItem(
                      'delete',
                      PhosphorIcons.trash(PhosphorIconsStyle.bold),
                      'Hapus',
                      const Color(0xFFef4444),
                      isDestructive: true,
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showCategoryDialog(context, category: category);
                        break;
                      case 'add_sub':
                        _showCategoryDialog(context, parentId: category.id);
                        break;
                      case 'activate':
                      case 'deactivate':
                        controller.toggleCategoryStatus(category);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(context, category);
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    PhosphorIconData icon,
    String label,
    Color color, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDestructive ? color : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context,
      {Category? category, int? parentId}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController =
        TextEditingController(text: category?.description ?? '');
    String selectedColor = category?.color ?? '#667eea';
    String selectedIcon = category?.icon ?? 'folder';
    final formKey = GlobalKey<FormState>();

    final colors = [
      '#667eea',
      '#764ba2',
      '#f093fb',
      '#f5576c',
      '#4facfe',
      '#00f2fe',
      '#43e97b',
      '#38f9d7',
      '#fa709a',
      '#fee140',
      '#fa709a',
      '#ff0844',
    ];

    final icons = [
      'folder',
      'box',
      'tag',
      'shopping-cart',
      'utensils',
      'coffee',
      'wine-glass',
      'burger',
      'pizza',
      'gift',
      'store',
      'truck',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing
                                ? PhosphorIcons.pencilSimple(
                                    PhosphorIconsStyle.bold)
                                : PhosphorIcons.plus(
                                    PhosphorIconsStyle.bold),
                            color: const Color(0xFF667eea),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          isEditing ? 'Edit Kategori' : 'Tambah Kategori',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1f2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Name Field
                    Text(
                      'Nama Kategori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama kategori',
                        hintStyle: TextStyle(color: Colors.grey.shade300),
                        filled: true,
                        fillColor: const Color(0xFFF9fafb),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF667eea), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    Text(
                      'Deskripsi (opsional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Masukkan deskripsi kategori',
                        hintStyle: TextStyle(color: Colors.grey.shade300),
                        filled: true,
                        fillColor: const Color(0xFFF9fafb),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF667eea), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color Picker
                    Text(
                      'Warna',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colors.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            selectedColor = color;
                            selectedIcon = icons.firstWhere(
                              (i) => i == selectedIcon,
                              orElse: () => 'folder',
                            );
                          }),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _parseColor(color),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _parseColor(color)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    PhosphorIcons.check(PhosphorIconsStyle.bold),
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Icon Picker
                    Text(
                      'Icon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: icons.map((icon) {
                        final isSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _parseColor(selectedColor)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: _parseColor(selectedColor)
                                          .withValues(alpha: 0.5),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              _getIconData(icon),
                              size: 22,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final controller =
                                    context.read<CategoryController>();

                                if (isEditing) {
                                  controller.updateCategory(
                                    category.copyWith(
                                      name: nameController.text,
                                      description: descController.text,
                                      color: selectedColor,
                                      icon: selectedIcon,
                                    ),
                                  );
                                } else {
                                  controller.createCategory(
                                    Category(
                                      name: nameController.text,
                                      description: descController.text,
                                      color: selectedColor,
                                      icon: selectedIcon,
                                      parentId: parentId,
                                    ),
                                  );
                                }

                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          PhosphorIcons.checkCircle(
                                              PhosphorIconsStyle.bold),
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(isEditing
                                            ? 'Kategori diperbarui'
                                            : 'Kategori ditambahkan'),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF10b981),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Simpan',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(
      BuildContext context, Category category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.trash(PhosphorIconsStyle.bold),
                  color: Colors.red.shade700,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hapus Kategori?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1f2937),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Kategori "${category.name}" akan dihapus. Tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && context.mounted) {
      context.read<CategoryController>().deleteCategory(category.id!);
    }

    return result ?? false;
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF667eea);
    }
  }

  PhosphorIconData _getIconData(String iconName) {
    switch (iconName) {
      case 'box':
        return PhosphorIcons.package(PhosphorIconsStyle.bold);
      case 'tag':
        return PhosphorIcons.tag(PhosphorIconsStyle.bold);
      case 'shopping-cart':
        return PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold);
      case 'utensils':
        return PhosphorIcons.forkKnife(PhosphorIconsStyle.bold);
      case 'coffee':
        return PhosphorIcons.coffee(PhosphorIconsStyle.bold);
      case 'wine-glass':
        return PhosphorIcons.wine(PhosphorIconsStyle.bold);
      case 'burger':
        return PhosphorIcons.hamburger(PhosphorIconsStyle.bold);
      case 'pizza':
        return PhosphorIcons.pizza(PhosphorIconsStyle.bold);
      case 'gift':
        return PhosphorIcons.gift(PhosphorIconsStyle.bold);
      case 'store':
        return PhosphorIcons.storefront(PhosphorIconsStyle.bold);
      case 'truck':
        return PhosphorIcons.truck(PhosphorIconsStyle.bold);
      default:
        return PhosphorIcons.folder(PhosphorIconsStyle.bold);
    }
  }
}