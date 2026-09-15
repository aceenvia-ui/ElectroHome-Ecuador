import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Punto de entrada: Flutter ejecuta main y monta la aplicación completa.
void main() {
  runApp(const MyApp());
}

// Configuración global de la aplicación: tema, título y pantalla inicial.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp crea la navegación, el tema y el contexto de Material Design.
    return MaterialApp(
      title: 'ElectroHome Ecuador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const StoreHomeScreen(),
    );
  }
}

// Modelo inmutable que contiene toda la información visible de un producto.
class Product {
  const Product({
    required this.name,
    required this.type,
    required this.category,
    required this.price,
    required this.icon,
    required this.description,
    this.imageUrl = '',
    this.imagePath = '',
    this.offerEnabled = false,
    this.offerPrice = '',
  });

  final String name;
  final String type;
  final String category;
  final String price;
  final IconData icon;
  final String description;
  final String imageUrl;
  final String imagePath;
  // Indica si el producto aparece dentro de la pestaña Ofertas.
  final bool offerEnabled;
  // Precio promocional que se muestra cuando la oferta está activa.
  final String offerPrice;

  // Permite cambiar únicamente los datos de la oferta sin perder el resto.
  Product copyWith({bool? offerEnabled, String? offerPrice}) {
    return Product(
      name: name,
      type: type,
      category: category,
      price: price,
      icon: icon,
      description: description,
      imageUrl: imageUrl,
      imagePath: imagePath,
      offerEnabled: offerEnabled ?? this.offerEnabled,
      offerPrice: offerPrice ?? this.offerPrice,
    );
  }
}

const products = [
  // Catálogo inicial que se copia al estado de StoreHomeScreen.
  Product(
    name: 'Refrigeradora Inox 300 L',
    type: 'Refrigeradora',
    category: 'Cocina',
    price: 'USD 899.00',
    icon: Icons.kitchen,
    description: 'Amplio espacio y bajo consumo de energía.',
  ),
  Product(
    name: 'Lavadora EcoWash 18 kg',
    type: 'Lavadora',
    category: 'Línea blanca',
    price: 'USD 749.00',
    icon: Icons.local_laundry_service,
    description: 'Programas inteligentes para el cuidado de tu ropa.',
    offerEnabled: true,
    offerPrice: 'USD 679.00',
  ),
  Product(
    name: 'Televisor Smart 55 pulgadas',
    type: 'Televisor',
    category: 'Tecnología',
    price: 'USD 699.00',
    icon: Icons.tv,
    description: 'Imagen 4K y entretenimiento para toda la familia.',
    offerEnabled: true,
    offerPrice: 'USD 599.00',
  ),
  Product(
    name: 'Microondas Digital 30 L',
    type: 'Microondas',
    category: 'Cocina',
    price: 'USD 299.00',
    icon: Icons.microwave,
    description: 'Cocina y calienta tus alimentos de forma práctica.',
  ),
  Product(
    name: 'Aire acondicionado 12 000 BTU',
    type: 'Aire acondicionado',
    category: 'Climatización',
    price: 'USD 899.00',
    icon: Icons.ac_unit,
    description: 'Confort y temperatura ideal durante todo el año.',
  ),
];

// Lista inicial que se puede ampliar, renombrar o eliminar desde administración.
const defaultCategories = [
  'Línea blanca',
  'Cocina',
  'Tecnología',
  'Climatización',
];

class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  // Esta lista cambia cuando se agrega o edita un producto.
  List<Product> _products = List<Product>.from(products);
  // Esta lista alimenta la pestaña Categorías y los formularios de productos.
  List<String> _categories = List<String>.from(defaultCategories);

  @override
  Widget build(BuildContext context) {
    // DefaultTabController permite cambiar entre Inicio, Categorías y Ofertas.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ElectroHome Ecuador'),
          actions: [
            IconButton(
              tooltip: 'Iniciar sesión',
              icon: const Icon(Icons.person_outline),
              onPressed: () => _openLogin(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Inicio'),
              Tab(icon: Icon(Icons.category_outlined), text: 'Categorías'),
              Tab(icon: Icon(Icons.local_offer_outlined), text: 'Ofertas'),
            ],
          ),
        ),
        drawer: StoreDrawer(
          onManageProducts: () => _openProductManager(context),
        ),
        body: TabBarView(
          children: [
            ProductList(products: _products),
            CategoryList(categories: _categories),
            ProductList(products: _products, showOffer: true),
          ],
        ),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    // Push coloca la pantalla de inicio de sesión encima de la pantalla actual.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openProductManager(BuildContext context) async {
    // Primero se cierra el menú lateral.
    Navigator.pop(context);
    // La pantalla de administración devuelve la lista cuando se presiona atrás.
    final updatedProducts = await Navigator.push<List<Product>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductManagerScreen(
          products: _products,
          categories: _categories,
          onCategoriesChanged: (categories) {
            setState(() => _categories = categories);
          },
        ),
      ),
    );
    if (updatedProducts != null) {
      // setState redibuja las tres pestañas usando los productos actualizados.
      setState(() => _products = updatedProducts);
    }
  }
}

class ProductList extends StatelessWidget {
  const ProductList({
    required this.products,
    this.showOffer = false,
    super.key,
  });

  final List<Product> products;
  final bool showOffer;

  @override
  Widget build(BuildContext context) {
    // Se filtran los productos para que Ofertas no muestre artículos normales.
    final visibleProducts = showOffer
        ? products.where((product) => product.offerEnabled).toList()
        : products;

    if (visibleProducts.isEmpty) {
      return const Center(child: Text('No hay ofertas activas'));
    }

    // Cada producto se dibuja como una tarjeta dentro de una lista desplazable.
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visibleProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        // index identifica el producto actual dentro de la lista.
        final product = visibleProducts[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: ProductImage(product: product, radius: 28),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${product.description}\n${product.type} · ${product.category}',
              ),
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showOffer)
                  // La etiqueta muestra el precio promocional cuando existe.
                  Text(
                    product.offerPrice.isEmpty
                        ? 'OFERTA'
                        : 'OFERTA ${product.offerPrice}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
                Text(
                  product.price,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryList extends StatelessWidget {
  const CategoryList({this.categories = defaultCategories, super.key});

  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    // Estas categorías son las opciones visibles de navegación del catálogo.
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: Icon(categoryIcon(categories[index])),
          title: Text(categories[index]),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

// El ícono ayuda a reconocer una categoría; las nuevas usan un ícono genérico.
IconData categoryIcon(String category) {
  switch (category) {
    case 'Línea blanca':
      return Icons.local_laundry_service;
    case 'Cocina':
      return Icons.kitchen;
    case 'Tecnología':
      return Icons.tv;
    case 'Climatización':
      return Icons.ac_unit;
    default:
      return Icons.category_outlined;
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({required this.product, this.radius = 28, super.key});

  final Product product;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // Se intenta mostrar primero el archivo local, luego la URL y finalmente el ícono.
    final fallback = Icon(product.icon);
    Widget image;
    if (product.imagePath.isNotEmpty) {
      image = Image.file(
        File(product.imagePath),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (product.imageUrl.isNotEmpty) {
      image = Image.network(
        product.imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: ClipOval(child: image),
    );
  }
}

class StoreDrawer extends StatelessWidget {
  const StoreDrawer({required this.onManageProducts, super.key});

  final VoidCallback onManageProducts;

  @override
  Widget build(BuildContext context) {
    // El Drawer concentra las pantallas secundarias y la administración.
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.electrical_services, color: Colors.white, size: 32),
                SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ElectroHome Ecuador',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Tu hogar, mejor equipado',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Inicio de sesión'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1),
            title: const Text('Registrar nuevo cliente'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerRegistrationScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Administrar productos'),
            onTap: onManageProducts,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: const Text('Encuesta de satisfacción'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SurveyScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.touch_app_outlined),
            title: const Text('Actividad de gestos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GestureScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProductManagerScreen extends StatefulWidget {
  const ProductManagerScreen({
    required this.products,
    required this.categories,
    required this.onCategoriesChanged,
    super.key,
  });

  final List<Product> products;
  final List<String> categories;
  final ValueChanged<List<String>> onCategoriesChanged;

  @override
  State<ProductManagerScreen> createState() => _ProductManagerScreenState();
}

class _ProductManagerScreenState extends State<ProductManagerScreen> {
  // Copia temporal: los cambios se confirman al volver a la pantalla principal.
  late List<Product> _products;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    // Se evita modificar directamente la lista que recibió la pantalla.
    _products = List<Product>.from(widget.products);
    _categories = List<String>.from(widget.categories);
  }

  Future<void> _editProduct([Product? product]) async {
    // product nulo significa crear uno; con producto significa editarlo.
    final result = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductEditorScreen(product: product, categories: _categories),
      ),
    );
    if (result == null) return;
    setState(() {
      // Se busca el original para reemplazarlo; si no existe, se agrega al final.
      final index = product == null ? -1 : _products.indexOf(product);
      if (index == -1) {
        _products.add(result);
      } else {
        _products[index] = result;
      }
    });
  }

  Future<void> _manageCategories() async {
    final result = await Navigator.push<CategoryChange>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagerScreen(categories: _categories),
      ),
    );
    if (result == null) return;

    setState(() {
      _categories = result.categories;
      // Los productos conservan una categoría válida después de un cambio.
      _products = _products.map((product) {
        final renamedCategory = result.renamed[product.category];
        final category = renamedCategory ?? product.category;
        final validCategory = _categories.contains(category)
            ? category
            : _categories.first;
        return Product(
          name: product.name,
          type: product.type,
          category: validCategory,
          price: product.price,
          icon: product.icon,
          description: product.description,
          imageUrl: product.imageUrl,
          imagePath: product.imagePath,
          offerEnabled: product.offerEnabled,
          offerPrice: product.offerPrice,
        );
      }).toList();
    });
    widget.onCategoriesChanged(_categories);
  }

  Future<void> _manageOffers() async {
    // Se abre la pantalla de ofertas y se espera la lista actualizada.
    final updatedProducts = await Navigator.push<List<Product>>(
      context,
      MaterialPageRoute(
        builder: (_) => OfferManagerScreen(products: _products),
      ),
    );
    if (updatedProducts != null) {
      // Los cambios quedan disponibles para Inicio y Ofertas.
      setState(() => _products = updatedProducts);
    }
  }

  @override
  Widget build(BuildContext context) {
    // La pantalla muestra todos los productos y un botón de edición por fila.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar productos'),
        leading: IconButton(
          tooltip: 'Guardar cambios',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _products),
        ),
        actions: [
          IconButton(
            tooltip: 'Administrar ofertas',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: _manageOffers,
          ),
          IconButton(
            tooltip: 'Administrar categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: _manageCategories,
          ),
          IconButton(
            tooltip: 'Agregar producto',
            icon: const Icon(Icons.add),
            onPressed: () => _editProduct(),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final product = _products[index];
          return Card(
            child: ListTile(
              leading: ProductImage(product: product, radius: 20),
              title: Text(product.name),
              subtitle: Text('${product.type} · ${product.category}'),
              trailing: IconButton(
                tooltip: 'Editar ${product.name}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editProduct(product),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Pantalla para activar/desactivar ofertas y cambiar sus precios promocionales.
class OfferManagerScreen extends StatefulWidget {
  const OfferManagerScreen({required this.products, super.key});

  final List<Product> products;

  @override
  State<OfferManagerScreen> createState() => _OfferManagerScreenState();
}

class _OfferManagerScreenState extends State<OfferManagerScreen> {
  // Copia temporal de productos mientras se administran las ofertas.
  late List<Product> _products;

  @override
  void initState() {
    super.initState();
    _products = List<Product>.from(widget.products);
  }

  void _toggleOffer(int index, bool enabled) {
    // copyWith conserva nombre, imagen, categoría y demás datos del producto.
    setState(() {
      _products[index] = _products[index].copyWith(offerEnabled: enabled);
    });
  }

  Future<void> _editOfferPrice(int index) async {
    // Se edita el precio en un diálogo para no abandonar la lista de ofertas.
    final product = _products[index];
    final controller = TextEditingController(text: product.offerPrice);
    final price = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Precio de oferta'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Precio promocional',
            hintText: 'USD 599.00',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (price != null && price.isNotEmpty) {
      // El nuevo precio se guarda solo cuando el usuario confirma.
      setState(() {
        _products[index] = product.copyWith(offerPrice: price);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cada tarjeta permite activar la oferta y editar su precio promocional.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar ofertas'),
        leading: IconButton(
          tooltip: 'Guardar cambios',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _products),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final product = _products[index];
          return Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: ProductImage(product: product, radius: 22),
                  title: Text(product.name),
                  subtitle: Text('Precio normal: ${product.price}'),
                  value: product.offerEnabled,
                  onChanged: (enabled) => _toggleOffer(index, enabled),
                ),
                if (product.offerEnabled)
                  ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: Text(
                      product.offerPrice.isEmpty
                          ? 'Definir precio de oferta'
                          : product.offerPrice,
                    ),
                    trailing: IconButton(
                      tooltip: 'Editar precio de oferta',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editOfferPrice(index),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Resultado que devuelve la pantalla de categorías al guardar sus cambios.
class CategoryChange {
  const CategoryChange({required this.categories, required this.renamed});

  final List<String> categories;
  // Relaciona el nombre anterior con el nuevo al renombrar una categoría.
  final Map<String, String> renamed;
}

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({required this.categories, super.key});

  final List<String> categories;

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  // Copia local para confirmar las categorías al regresar.
  late List<String> _categories;
  // Se usa para actualizar también los productos que tenían el nombre anterior.
  final Map<String, String> _renamed = {};

  @override
  void initState() {
    super.initState();
    _categories = List<String>.from(widget.categories);
  }

  Future<void> _addCategory() async {
    // El diálogo devuelve el nombre y se agrega a la lista si no fue cancelado.
    final category = await _askForCategory();
    if (category == null) return;
    setState(() => _categories.add(category));
  }

  Future<void> _editCategory(int index) async {
    // Al renombrar se registra la relación para actualizar productos existentes.
    final oldCategory = _categories[index];
    final newCategory = await _askForCategory(initialValue: oldCategory);
    if (newCategory == null || newCategory == oldCategory) return;
    setState(() {
      _categories[index] = newCategory;
      _renamed[oldCategory] = newCategory;
    });
  }

  Future<void> _deleteCategory(int index) async {
    // Se conserva al menos una categoría para que los productos puedan asignarse.
    if (_categories.length == 1) return;
    // Se pide confirmación antes de eliminar una categoría.
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${_categories[index]}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      // Los productos que usaban esta categoría pasarán a la primera disponible.
      setState(() => _categories.removeAt(index));
    }
  }

  Future<String?> _askForCategory({String initialValue = ''}) async {
    // Un solo diálogo sirve tanto para crear como para editar una categoría.
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          initialValue.isEmpty ? 'Nueva categoría' : 'Editar categoría',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de categoría',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // La lista permite editar o eliminar cada categoría y agregar nuevas.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar categorías'),
        leading: IconButton(
          tooltip: 'Guardar cambios',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(
            context,
            CategoryChange(categories: _categories, renamed: _renamed),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Agregar categoría',
            icon: const Icon(Icons.add),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: Icon(categoryIcon(_categories[index])),
            title: Text(_categories[index]),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar categoría',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editCategory(index),
                ),
                IconButton(
                  tooltip: 'Eliminar categoría',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteCategory(index),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({
    required this.categories,
    this.product,
    super.key,
  });

  final Product? product;
  final List<String> categories;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  // Los controllers mantienen sincronizado cada campo del formulario.
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  String _imagePath = '';
  late String _category;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Al editar se cargan los datos existentes; al crear se dejan vacíos.
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name);
    _typeController = TextEditingController(text: product?.type);
    _priceController = TextEditingController(text: product?.price);
    _descriptionController = TextEditingController(text: product?.description);
    _imageUrlController = TextEditingController(text: product?.imageUrl);
    _imagePath = product?.imagePath ?? '';
    _category = widget.categories.contains(product?.category)
        ? product!.category
        : widget.categories.first;
  }

  @override
  void dispose() {
    // Se liberan los controllers cuando la pantalla sale del árbol de widgets.
    _nameController.dispose();
    _typeController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _save() {
    // No se guarda hasta que todos los campos obligatorios sean válidos.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final oldProduct = widget.product;
    Navigator.pop(
      context,
      // Navigator.pop devuelve el producto editado a ProductManagerScreen.
      Product(
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        category: _category,
        price: _priceController.text.trim(),
        icon: oldProduct?.icon ?? Icons.devices_other,
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        imagePath: _imagePath,
        offerEnabled: oldProduct?.offerEnabled ?? false,
        offerPrice: oldProduct?.offerPrice ?? '',
      ),
    );
  }

  Future<void> _pickImage() async {
    // image_picker abre la galería nativa de Android.
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedImage != null) {
      // La ruta queda guardada y la interfaz muestra la previsualización.
      setState(() => _imagePath = pickedImage.path);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;

  @override
  Widget build(BuildContext context) {
    // El mismo formulario sirve para crear y editar según widget.product.
    final isEditing = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          IconButton(
            tooltip: 'Guardar producto',
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Tipo de producto',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: widget.categories.contains(_category)
                  ? _category
                  : widget.categories.first,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.account_tree_outlined),
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL de la imagen',
                hintText: 'https://ejemplo.com/producto.jpg',
                prefixIcon: Icon(Icons.image_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir imagen del dispositivo'),
            ),
            if (_imagePath.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: Image.file(File(_imagePath), fit: BoxFit.contain),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Puedes usar una URL pública o elegir un archivo de la galería. El archivo elegido tiene prioridad.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de acceso: valida correo y contraseña antes de mostrar confirmación.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // La llave permite ejecutar la validación de todos los campos del formulario.
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Cada controller debe liberarse cuando la pantalla se destruye.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    // validate ejecuta los validators definidos en los campos.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Si todo es válido, se informa al usuario con un SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión iniciada correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Form agrupa los campos y permite validarlos como una sola unidad.
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio de sesión')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.account_circle,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Bienvenido a ElectroHome Ecuador',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Ingresa un correo válido'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.length < 6
                  ? 'Mínimo 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _login,
              icon: const Icon(Icons.login),
              label: const Text('Ingresar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerRegistrationScreen(),
                ),
              ),
              child: const Text('¿Nuevo cliente? Regístrate aquí'),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla para capturar los datos básicos de un nuevo cliente.
class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  // Cada campo tiene su propio controller para leer y liberar su contenido.
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void dispose() {
    // Se recorren todos los controllers para liberar sus recursos.
    for (final controller in [
      _cedulaController,
      _nameController,
      _addressController,
      _phoneController,
      _cityController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label es obligatorio' : null;

  void _register() {
    // El registro solo continúa si todos los campos obligatorios tienen datos.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente registrado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ListView permite que el formulario se desplace en pantallas pequeñas.
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de clientes')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Crea tu cuenta en ElectroHome Ecuador',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Completa tus datos para recibir atención personalizada.',
            ),
            const SizedBox(height: 24),
            _field(_cedulaController, 'Cédula', Icons.badge_outlined),
            _field(_nameController, 'Nombre completo', Icons.person_outline),
            _field(_addressController, 'Dirección', Icons.home_outlined),
            _field(
              _phoneController,
              'Teléfono',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _field(_cityController, 'Ciudad', Icons.location_city_outlined),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _register,
              icon: const Icon(Icons.person_add),
              label: const Text('Registrar cliente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    // Método reutilizable para construir los cinco campos del registro.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: (value) => _required(value, label),
      ),
    );
  }
}

class PinkStarLogo extends StatelessWidget {
  const PinkStarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // Logo decorativo usado en la cabecera de la encuesta.
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.pink.shade300, Colors.pink.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.star_rounded, size: 70, color: Colors.white),
    );
  }
}

// Pantalla de encuesta de satisfacción del servicio.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  // La llave valida los campos de texto y las selecciones del formulario.
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  String? _satisfaction;
  String? _service;

  @override
  void dispose() {
    // Se liberan los controllers de nombre, correo, contraseña y comentarios.
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  void _submitSurvey() {
    // Primero se validan textos y luego se comprueba que existan ambas opciones.
    final formValido = _formKey.currentState?.validate() ?? false;
    final tieneSatisfaccion = _satisfaction != null;
    final tieneServicio = _service != null;

    if (!formValido || !tieneSatisfaccion || !tieneServicio) {
      // Si falta una selección, se avisa sin enviar la encuesta.
      if (!tieneSatisfaccion || !tieneServicio) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe responder la encuesta completa')),
        );
      }
      return;
    }

    final nombre = _nameController.text.trim();
    // Cuando todo está completo se confirma el envío al usuario.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gracias $nombre, tu encuesta fue enviada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView evita desbordamientos cuando aparece el teclado.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuesta de Satisfacción'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: PinkStarLogo()),
                const SizedBox(height: 20),
                const Text(
                  'Encuesta de satisfacción',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (value.trim().length < 2) {
                      return 'Debe ingresar un nombre válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El correo electrónico es obligatorio';
                    }
                    if (!RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    ).hasMatch(value)) {
                      return 'Ingrese un correo válido (ej: usuario@direccion.com)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es obligatoria';
                    }
                    if (value.length <= 6) {
                      return 'La contraseña debe ser mayor a 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  '¿Qué tan satisfecho te sentiste con el servicio?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                RadioListTile<String>(
                  title: const Text('Muy satisfecho'),
                  value: 'Muy satisfecho',
                  groupValue: _satisfaction,
                  onChanged: (value) => setState(() => _satisfaction = value),
                ),
                RadioListTile<String>(
                  title: const Text('Satisfecho'),
                  value: 'Satisfecho',
                  groupValue: _satisfaction,
                  onChanged: (value) => setState(() => _satisfaction = value),
                ),
                RadioListTile<String>(
                  title: const Text('Neutral'),
                  value: 'Neutral',
                  groupValue: _satisfaction,
                  onChanged: (value) => setState(() => _satisfaction = value),
                ),
                RadioListTile<String>(
                  title: const Text('Insatisfecho'),
                  value: 'Insatisfecho',
                  groupValue: _satisfaction,
                  onChanged: (value) => setState(() => _satisfaction = value),
                ),
                if (_satisfaction == null)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      'Debe seleccionar una opción',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 20),

                const Text(
                  '¿Cómo calificarías la atención recibida?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _service,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.grade),
                    labelText: 'Selecciona una calificación',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Excelente',
                      child: Text('Excelente'),
                    ),
                    DropdownMenuItem(value: 'Buena', child: Text('Buena')),
                    DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                    DropdownMenuItem(value: 'Mala', child: Text('Mala')),
                  ],
                  onChanged: (value) => setState(() => _service = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Debes seleccionar una calificación';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _commentsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Comentarios o sugerencias',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe un comentario';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Enviar encuesta',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // Botón para navegar a la Actividad 2
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GestureScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.touch_app),
                  label: const Text('Ir a Actividad 2: Manejo de Gestos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.pink),
                    foregroundColor: Colors.pink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla que demuestra eventos de toque y desplazamiento.
class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen> {
  // Estos valores cambian después de cada gesto detectado.
  String _gestureMessage = 'Toca o desliza sobre el cuadro';
  Color _containerColor = Colors.pink.shade50;

  @override
  Widget build(BuildContext context) {
    // GestureDetector convierte las interacciones del usuario en eventos.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manejo de Eventos'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Interactúa con el cuadro inferior:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Widget principal para detectar gestos.
              GestureDetector(
                // 1. Toque simple: cambia el mensaje y el color del cuadro.
                onTap: () {
                  setState(() {
                    _gestureMessage = '¡Toque simple detectado! 👆';
                    _containerColor = Colors.teal.shade100;
                  });
                },
                // 2. Doble toque: ejecuta una respuesta diferente.
                onDoubleTap: () {
                  setState(() {
                    _gestureMessage = '¡Doble toque detectado! ✌️';
                    _containerColor = Colors.orange.shade100;
                  });
                },
                // 3. Toque prolongado: detecta presión mantenida.
                onLongPress: () {
                  setState(() {
                    _gestureMessage = '¡Toque prolongado! ⏱️';
                    _containerColor = Colors.purple.shade100;
                  });
                },
                // 4. Deslizamiento horizontal: determina izquierda o derecha.
                onHorizontalDragEnd: (details) {
                  setState(() {
                    if (details.primaryVelocity! > 0) {
                      _gestureMessage = '¡Deslizaste a la Derecha! ➡️';
                    } else if (details.primaryVelocity! < 0) {
                      _gestureMessage = '¡Deslizaste a la Izquierda! ⬅️';
                    }
                    _containerColor = Colors.blue.shade100;
                  });
                },
                // 5. Deslizamiento vertical: determina arriba o abajo.
                onVerticalDragEnd: (details) {
                  setState(() {
                    if (details.primaryVelocity! > 0) {
                      _gestureMessage = '¡Deslizaste hacia Abajo! ⬇️';
                    } else if (details.primaryVelocity! < 0) {
                      _gestureMessage = '¡Deslizaste hacia Arriba! ⬆️';
                    }
                    _containerColor = Colors.green.shade100;
                  });
                },

                // El área visual donde el usuario debe interactuar
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: _containerColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.pink, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _gestureMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
