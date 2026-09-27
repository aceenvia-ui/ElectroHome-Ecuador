import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';

// La aplicación es una tienda local conectada a Firestore.
// Las pantallas modifican el estado de la tienda y el repositorio sincroniza
// esos cambios con las colecciones de Firebase cuando hay conexión configurada.
// Punto de entrada: Flutter ejecuta main y monta la aplicación completa.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } on FirebaseAuthException catch (error) {
    debugPrint('No se pudo autenticar la app en Firebase (${error.code}).');
  } on FirebaseException catch (error) {
    debugPrint('No se pudo inicializar Firebase (${error.code}).');
  } catch (error) {
    debugPrint('No se pudo iniciar Firebase: $error');
  }
  runApp(const MyApp());
}

// Centraliza todas las lecturas y escrituras de la aplicación en Firestore.
// Mantener estas operaciones aquí evita mezclar consultas de base de datos con
// el código visual de las pantallas.
class FirebaseStoreRepository {
  // Constructor privado: esta clase solo expone métodos estáticos.
  FirebaseStoreRepository._();

  // Referencia única a la base de datos Firestore.
  static final _database = FirebaseFirestore.instance;

  // Indica si Firebase se inicializó correctamente.
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  // Devuelve una colección Firestore tipada como mapa de datos.
  static CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _database.collection(name);

  // Convierte un texto en un identificador seguro para un documento Firestore.
  static String _key(String value) => value.replaceAll('/', '_');

  static Future<void> _runWrite(
    String operation,
    Future<void> Function() write,
  ) async {
    try {
      await write();
    } on FirebaseException catch (error) {
      debugPrint('No se pudo $operation en Firestore (${error.code}).');
    }
  }

  static Future<T?> _runRead<T>(
    String operation,
    Future<T> Function() read,
  ) async {
    try {
      return await read();
    } on FirebaseException catch (error) {
      debugPrint('No se pudo cargar $operation de Firestore (${error.code}).');
      return null;
    }
  }

  // Lee todos los productos y transforma cada documento en un objeto Product.
  static Future<List<Product>> loadProducts() async {
    if (!isAvailable) return [];
    final snapshot = await _collection('products').get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return Product(
        name: data['name'] as String? ?? document.id,
        type: data['type'] as String? ?? '',
        category: data['category'] as String? ?? '',
        price: data['price'] as String? ?? '',
        icon: Icons.devices_other,
        description: data['description'] as String? ?? '',
        stock: (data['stock'] as num?)?.toInt() ?? 0,
        imageUrl: data['imageUrl'] as String? ?? '',
        imagePath: data['imagePath'] as String? ?? '',
        offerEnabled: data['offerEnabled'] as bool? ?? false,
        offerPrice: data['offerPrice'] as String? ?? '',
      );
    }).toList();
  }

  // Guarda el catálogo completo en una operación por lotes.
  static Future<void> saveProducts(List<Product> products) async {
    if (!isAvailable) return;
    await _runWrite('guardar productos', () async {
      final batch = _database.batch();
      for (final product in products) {
        final reference = _collection('products').doc(_key(product.name));
        batch.set(reference, {
          'name': product.name,
          'type': product.type,
          'category': product.category,
          'price': product.price,
          'description': product.description,
          'stock': product.stock,
          'imageUrl': product.imageUrl,
          'imagePath': product.imagePath,
          'offerEnabled': product.offerEnabled,
          'offerPrice': product.offerPrice,
        });
      }
      await batch.commit();
    });
  }

  // Persiste las categorías disponibles para la administración.
  static Future<void> saveCategories(List<String> categories) async {
    if (!isAvailable) return;
    await _runWrite('guardar categorías', () async {
      final batch = _database.batch();
      for (final category in categories) {
        batch.set(_collection('categories').doc(_key(category)), {
          'name': category,
        });
      }
      await batch.commit();
    });
  }

  // Recupera las categorías almacenadas en Firestore.
  static Future<List<String>> loadCategories() async {
    if (!isAvailable) return [];
    final snapshot = await _collection('categories').get();
    return snapshot.docs
        .map((document) => document.data()['name'] as String? ?? document.id)
        .toList();
  }

  // Crea o actualiza un cliente usando su correo como identificador.
  static Future<void> saveCustomer(Customer customer) async {
    if (!isAvailable) return;
    await _runWrite('guardar cliente', () async {
      await _collection('customers').doc(_key(customer.email)).set({
        'cedula': customer.cedula,
        'name': customer.name,
        'address': customer.address,
        'phone': customer.phone,
        'city': customer.city,
        'email': customer.email,
        'password': customer.password,
        'registeredAt': customer.registeredAt.toIso8601String(),
      });
    });
  }

  static Future<void> saveCustomers(List<Customer> customers) async {
    if (!isAvailable || customers.isEmpty) return;
    await _runWrite('guardar clientes iniciales', () async {
      final batch = _database.batch();
      for (final customer in customers) {
        final reference = _collection('customers').doc(_key(customer.email));
        batch.set(reference, {
          'cedula': customer.cedula,
          'name': customer.name,
          'address': customer.address,
          'phone': customer.phone,
          'city': customer.city,
          'email': customer.email,
          'password': customer.password,
          'registeredAt': customer.registeredAt.toIso8601String(),
        });
      }
      await batch.commit();
    });
  }

  static Future<void> replaceCustomers(List<Customer> customers) async {
    if (!isAvailable) return;
    await _runWrite('actualizar todos los clientes', () async {
      final snapshot = await _collection('customers').get();
      final batch = _database.batch();
      final newDocumentIds = customers
          .map((customer) => _key(customer.email))
          .toSet();
      for (final document in snapshot.docs) {
        if (!newDocumentIds.contains(document.id)) {
          batch.delete(document.reference);
        }
      }
      for (final customer in customers) {
        final reference = _collection('customers').doc(_key(customer.email));
        batch.set(reference, {
          'cedula': customer.cedula,
          'name': customer.name,
          'address': customer.address,
          'phone': customer.phone,
          'city': customer.city,
          'email': customer.email,
          'password': customer.password,
          'registeredAt': customer.registeredAt.toIso8601String(),
        });
      }
      await batch.commit();
    });
  }

  // Registra un nuevo pedido con estado inicial solicitado.
  static Future<void> saveOrder(Order order) async {
    if (!isAvailable) return;
    await _runWrite('guardar pedido', () async {
      await _collection('orders').add({
        'customerEmail': order.customerEmail,
        'productName': order.productName,
        'quantity': order.quantity,
        'createdAt': order.createdAt.toIso8601String(),
        'status': order.status.name,
      });
    });
  }

  static Future<String?> saveReservation(Product product, Order order) async {
    if (!isAvailable) return null;
    final productReference = _collection('products').doc(_key(product.name));
    final orderReference = _collection('orders').doc();
    try {
      await _database.runTransaction<void>((transaction) async {
        final productSnapshot = await transaction.get(productReference);
        if (!productSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'No existe el producto ${product.name}.',
          );
        }
        final currentStock =
            (productSnapshot.data()?['stock'] as num?)?.toInt() ?? 0;
        if (order.quantity <= 0 || order.quantity > currentStock) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'El stock disponible cambió.',
          );
        }
        transaction.update(productReference, {
          'stock': currentStock - order.quantity,
        });
        transaction.set(orderReference, {
          'customerEmail': order.customerEmail,
          'productName': order.productName,
          'quantity': order.quantity,
          'createdAt': order.createdAt.toIso8601String(),
          'status': order.status.name,
        });
      });
      return orderReference.id;
    } on FirebaseException catch (error) {
      debugPrint('No se pudo guardar la reserva en Firestore (${error.code}).');
      return null;
    }
  }

  // Actualiza únicamente el estado de un pedido existente.
  static Future<void> updateOrder(String orderId, Order order) async {
    if (!isAvailable) return;
    await _runWrite('actualizar pedido', () async {
      await _collection('orders')
          .doc(orderId)
          .update({'status': order.status.name});
    });
  }

  // Guarda las respuestas de la encuesta para consultarlas como administrador.
  static Future<void> saveSurvey(SurveyResponse survey) async {
    if (!isAvailable) return;
    await _runWrite('guardar encuesta', () async {
      await _collection('surveys').add({
        'name': survey.name,
        'satisfaction': survey.satisfaction,
        'service': survey.service,
        'comments': survey.comments,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Recupera los clientes registrados.
  static Future<List<Customer>> loadCustomers() async {
    if (!isAvailable) return [];
    final snapshot = await _collection('customers').get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return Customer(
        cedula: data['cedula'] as String? ?? '',
        name: data['name'] as String? ?? '',
        address: data['address'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        city: data['city'] as String? ?? '',
        email: data['email'] as String? ?? '',
        password: data['password'] as String? ?? '',
        registeredAt:
            DateTime.tryParse(data['registeredAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  // Recupera pedidos y convierte el texto de estado al enum de Dart.
  static Future<List<Order>> loadOrders() async {
    if (!isAvailable) return [];
    final snapshot = await _collection('orders').get();
    return snapshot.docs.map((document) {
      final data = document.data();
      final statusName =
          data['status'] as String? ?? OrderStatus.solicitado.name;
      return Order(
        id: document.id,
        customerEmail: data['customerEmail'] as String? ?? '',
        productName: data['productName'] as String? ?? '',
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(data['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: OrderStatus.values.firstWhere(
          (status) => status.name == statusName,
          orElse: () => OrderStatus.solicitado,
        ),
      );
    }).toList();
  }

  // Recupera las encuestas recibidas.
  static Future<List<SurveyResponse>> loadSurveys() async {
    if (!isAvailable) return [];
    final snapshot = await _collection('surveys').get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return SurveyResponse(
        name: data['name'] as String? ?? '',
        satisfaction: data['satisfaction'] as String? ?? '',
        service: data['service'] as String? ?? '',
        comments: data['comments'] as String? ?? '',
      );
    }).toList();
  }
}

// Configuración global de la aplicación: tema, título y pantalla inicial.
// Widget raíz: configura el tema, el título y la primera pantalla.
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
        splashFactory: NoSplash.splashFactory,
      ),
      home: const StoreHomeScreen(),
    );
  }
}

// Modelo inmutable que contiene toda la información visible de un producto.
// Representa un producto del catálogo y su inventario disponible.
class Product {
  const Product({
    required this.name,
    required this.type,
    required this.category,
    required this.price,
    required this.icon,
    required this.description,
    this.stock = 0,
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
  final int stock;
  final String imageUrl;
  final String imagePath;
  // Indica si el producto aparece dentro de la pestaña Ofertas.
  final bool offerEnabled;
  // Precio promocional que se muestra cuando la oferta está activa.
  final String offerPrice;

  // Permite cambiar únicamente los datos de la oferta sin perder el resto.
  Product copyWith({bool? offerEnabled, String? offerPrice, int? stock}) {
    return Product(
      name: name,
      type: type,
      category: category,
      price: price,
      icon: icon,
      description: description,
      stock: stock ?? this.stock,
      imageUrl: imageUrl,
      imagePath: imagePath,
      offerEnabled: offerEnabled ?? this.offerEnabled,
      offerPrice: offerPrice ?? this.offerPrice,
    );
  }
}

// Representa una cuenta de cliente y sus datos de contacto.
class Customer {
  const Customer({
    required this.cedula,
    required this.name,
    required this.address,
    required this.phone,
    required this.city,
    required this.registeredAt,
    required this.email,
    required this.password,
  });

  final String cedula;
  final String name;
  final String address;
  final String phone;
  final String city;
  final DateTime registeredAt;
  final String email;
  final String password;

  Customer copyWith({String? email, String? password}) => Customer(
    cedula: cedula,
    name: name,
    address: address,
    phone: phone,
    city: city,
    registeredAt: registeredAt,
    email: email ?? this.email,
    password: password ?? this.password,
  );
}

// Estados posibles de un pedido dentro del flujo de venta.
enum OrderStatus { solicitado, despachado, ventaRealizada }

// Representa una solicitud de compra hecha por un cliente.
class Order {
  const Order({
    required this.customerEmail,
    required this.productName,
    required this.quantity,
    required this.createdAt,
    this.status = OrderStatus.solicitado,
    this.id,
  });

  final String customerEmail;
  final String productName;
  final int quantity;
  final DateTime createdAt;
  final OrderStatus status;
  final String? id;

  Order copyWith({OrderStatus? status, String? id}) => Order(
    customerEmail: customerEmail,
    productName: productName,
    quantity: quantity,
    createdAt: createdAt,
    status: status ?? this.status,
    id: id ?? this.id,
  );
}

// Contiene las respuestas enviadas desde la encuesta de satisfacción.
class SurveyResponse {
  const SurveyResponse({
    required this.name,
    required this.satisfaction,
    required this.service,
    required this.comments,
  });

  final String name;
  final String satisfaction;
  final String service;
  final String comments;
}

final defaultCustomers = <Customer>[
  Customer(
    cedula: '0102030405',
    name: 'María González',
    address: 'Av. 12 de Abril y Loja',
    phone: '0991234567',
    city: 'Cuenca',
    registeredAt: DateTime(2026, 1, 15),
    email: 'maria@gmail.com',
    password: 'Usuario01',
  ),
  Customer(
    cedula: '0912345678',
    name: 'Carlos Mendoza',
    address: 'Av. Francisco de Orellana',
    phone: '0987654321',
    city: 'Guayaquil',
    registeredAt: DateTime(2026, 2, 8),
    email: 'carlos@gmail.com',
    password: 'Usuario01',
  ),
  Customer(
    cedula: '0109876543',
    name: 'Ana Torres',
    address: 'Av. Loja y Remigio Crespo',
    phone: '0998765432',
    city: 'Cuenca',
    registeredAt: DateTime(2026, 3, 12),
    email: 'ana@gmail.com',
    password: 'Usuario01',
  ),
  Customer(
    cedula: '0923456789',
    name: 'Diego Cárdenas',
    address: 'Av. 9 de Octubre 450',
    phone: '0976543210',
    city: 'Guayaquil',
    registeredAt: DateTime(2026, 4, 5),
    email: 'diego@gmail.com',
    password: 'Usuario01',
  ),
  Customer(
    cedula: '1712345678',
    name: 'Sofía Andrade',
    address: 'Av. República y Amazonas',
    phone: '0965432109',
    city: 'Quito',
    registeredAt: DateTime(2026, 5, 21),
    email: 'sofia@gmail.com',
    password: 'Usuario01',
  ),
];

String _customerEmailFromName(String name) {
  final firstName = name.trim().split(RegExp(r'\s+')).first.toLowerCase();
  final normalizedName = firstName
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');
  return '$normalizedName@gmail.com';
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
    stock: 8,
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
    stock: 5,
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
    stock: 3,
  ),
  Product(
    name: 'Microondas Digital 30 L',
    type: 'Microondas',
    category: 'Cocina',
    price: 'USD 299.00',
    icon: Icons.microwave,
    description: 'Cocina y calienta tus alimentos de forma práctica.',
    stock: 10,
  ),
  Product(
    name: 'Aire acondicionado 12 000 BTU',
    type: 'Aire acondicionado',
    category: 'Climatización',
    price: 'USD 899.00',
    icon: Icons.ac_unit,
    description: 'Confort y temperatura ideal durante todo el año.',
    stock: 4,
  ),
  Product(
    name: 'Cocina a gas 6 quemadores',
    type: 'Cocina',
    category: 'Cocina',
    price: 'USD 529.00',
    icon: Icons.countertops,
    description: 'Superficie resistente y horno de gran capacidad.',
    stock: 6,
  ),
  Product(
    name: 'Licuadora TurboMix 1.5 L',
    type: 'Licuadora',
    category: 'Cocina',
    price: 'USD 89.00',
    icon: Icons.blender,
    description: 'Motor potente para preparar bebidas y alimentos.',
    stock: 12,
    offerEnabled: true,
    offerPrice: 'USD 74.00',
  ),
  Product(
    name: 'Laptop UltraBook 14 pulgadas',
    type: 'Laptop',
    category: 'Tecnología',
    price: 'USD 1,199.00',
    icon: Icons.laptop_mac,
    description: 'Rendimiento ágil para trabajo, estudio y entretenimiento.',
    stock: 5,
  ),
  Product(
    name: 'Extractor de aire 90 cm',
    type: 'Extractor',
    category: 'Cocina',
    price: 'USD 249.00',
    icon: Icons.air,
    description: 'Reduce humo y olores para mantener tu cocina limpia.',
    stock: 7,
  ),
  Product(
    name: 'Cámara de seguridad WiFi',
    type: 'Cámara',
    category: 'Tecnología',
    price: 'USD 129.00',
    icon: Icons.videocam_outlined,
    description: 'Monitoreo remoto con visión nocturna y alerta móvil.',
    stock: 15,
    offerEnabled: true,
    offerPrice: 'USD 109.00',
  ),
];

// Lista inicial que se puede ampliar, renombrar o eliminar desde administración.
const defaultCategories = [
  'Línea blanca',
  'Cocina',
  'Tecnología',
  'Climatización',
];

// Pantalla principal con catálogo, categorías, ofertas y menú lateral.
class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

// Estado compartido durante la sesión actual de la tienda.
class _StoreHomeScreenState extends State<StoreHomeScreen> {
  // Esta lista cambia cuando se agrega o edita un producto.
  List<Product> _products = List<Product>.from(products);
  // Esta lista alimenta la pestaña Categorías y los formularios de productos.
  List<String> _categories = List<String>.from(defaultCategories);
  List<Customer> _customers = List<Customer>.from(defaultCustomers);
  List<Order> _orders = [];
  final List<SurveyResponse> _surveys = [];
  Customer? _loggedCustomer;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedData();
  }

  // Carga los datos existentes de Firestore y conserva los datos iniciales
  // cuando la base aún está vacía o Firebase no está disponible.
  Future<void> _loadPersistedData() async {
    if (!FirebaseStoreRepository.isAvailable) return;
    final results = await Future.wait<Object?>([
      FirebaseStoreRepository._runRead(
        'productos',
        FirebaseStoreRepository.loadProducts,
      ),
      FirebaseStoreRepository._runRead(
        'categorías',
        FirebaseStoreRepository.loadCategories,
      ),
      FirebaseStoreRepository._runRead(
        'clientes',
        FirebaseStoreRepository.loadCustomers,
      ),
      FirebaseStoreRepository._runRead(
        'reservas',
        FirebaseStoreRepository.loadOrders,
      ),
      FirebaseStoreRepository._runRead(
        'encuestas',
        FirebaseStoreRepository.loadSurveys,
      ),
    ]);
    final savedProducts = results[0] as List<Product>? ?? [];
    final savedCategories = results[1] as List<String>? ?? [];
    final savedCustomers = results[2] as List<Customer>? ?? [];
    final savedOrders = results[3] as List<Order>? ?? [];
    final savedSurveys = results[4] as List<SurveyResponse>? ?? [];
    final customersToPersist = (savedCustomers.isEmpty
            ? _customers
            : savedCustomers)
        .map(
          (customer) => customer.copyWith(
            email: _customerEmailFromName(customer.name),
            password: 'Usuario01',
          ),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      if (savedProducts.isNotEmpty) _products = savedProducts;
      if (savedCategories.isNotEmpty) _categories = savedCategories;
      _customers = customersToPersist;
      _orders = savedOrders;
      _surveys
        ..clear()
        ..addAll(savedSurveys);
    });
    if (savedProducts.isEmpty) {
      await FirebaseStoreRepository.saveProducts(_products);
    }
    if (savedCategories.isEmpty) {
      await FirebaseStoreRepository.saveCategories(_categories);
    }
    await FirebaseStoreRepository.replaceCustomers(customersToPersist);
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedCustomer == null && !_isAdmin) {
      return LoginScreen(
        customers: _customers,
        onCustomerRegistered: (customer) => setState(() {
          _customers.add(customer);
          FirebaseStoreRepository.saveCustomer(customer);
        }),
        onCustomerLogin: (customer) =>
            setState(() => _loggedCustomer = customer),
        onAdminLogin: () {
          setState(() => _isAdmin = true);
          _openAdmin(context);
        },
      );
    }

    if (_loggedCustomer != null && !_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ElectroHome Ecuador'),
          actions: [
            IconButton(
              tooltip: 'Mis reservas',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerReservationsScreen(
                    customer: _loggedCustomer!,
                    orders: _orders,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => setState(() => _loggedCustomer = null),
            ),
          ],
        ),
        drawer: StoreDrawer(
          isAdmin: false,
          customer: _loggedCustomer,
          onManageProducts: () {},
          onManageCustomers: () {},
          onManageOrders: () {},
          onCustomerRegistered: (_) {},
          onSurveySubmitted: (survey) => setState(() {
            _surveys.add(survey);
            FirebaseStoreRepository.saveSurvey(survey);
          }),
        ),
        body: ProductList(
          products: _products.where((product) => product.stock > 0).toList(),
          showOffer: true,
          filterOffers: false,
          customer: _loggedCustomer,
          onOrder: _createOrder,
        ),
      );
    }

    // DefaultTabController permite cambiar entre Inicio, Categorías y Ofertas.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ElectroHome Ecuador'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => setState(() {
                _loggedCustomer = null;
                _isAdmin = false;
              }),
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
          isAdmin: true,
          customer: null,
          onManageProducts: () => _openProductManager(context),
          onManageCustomers: () => _openCustomerManager(context),
          onManageOrders: () => _openAdmin(context),
          onCustomerRegistered: (customer) => setState(() {
            _customers.add(customer);
            FirebaseStoreRepository.saveCustomer(customer);
          }),
          onSurveySubmitted: (survey) => setState(() {
            _surveys.add(survey);
            FirebaseStoreRepository.saveSurvey(survey);
          }),
        ),
        body: TabBarView(
          children: [
            ProductList(
              products: _products,
              customer: _loggedCustomer,
              onOrder: _isAdmin ? null : _createOrder,
            ),
            CategoryList(categories: _categories),
            ProductList(
              products: _products,
              showOffer: true,
              customer: _loggedCustomer,
              onOrder: _isAdmin ? null : _createOrder,
            ),
          ],
        ),
      ),
    );
  }

  // Verifica el stock, descuenta las unidades y crea el pedido persistente.
  void _createOrder(Product product, int quantity) {
    final customer = _loggedCustomer;
    if (customer == null) return;
    final productIndex = _products.indexWhere(
      (item) => item.name == product.name,
    );
    if (productIndex < 0 ||
        quantity <= 0 ||
        quantity > _products[productIndex].stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad supera el stock disponible')),
      );
      return;
    }

    setState(() {
      _products = _products
          .map(
            (item) => item.name == product.name
                ? item.copyWith(stock: item.stock - quantity)
                : item,
          )
          .toList();
      _orders.add(
        Order(
          customerEmail: customer.email,
          productName: product.name,
          quantity: quantity,
          createdAt: DateTime.now(),
        ),
      );
    });
    final orderIndex = _orders.length - 1;
    FirebaseStoreRepository.saveReservation(product, _orders.last).then((id) {
      if (id == null || !mounted || orderIndex >= _orders.length) return;
      setState(() {
        _orders[orderIndex] = _orders[orderIndex].copyWith(id: id);
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reserva solicitada: ${product.name}')),
    );
  }

  // Abre el panel donde el administrador gestiona pedidos y encuestas.
  void _openAdmin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardScreen(
          orders: _orders,
          surveys: _surveys,
          onOrdersChanged: (orders) {
            setState(() => _orders = orders);
            for (final order in orders) {
              if (order.id != null) {
                FirebaseStoreRepository.updateOrder(order.id!, order);
              }
            }
          },
        ),
      ),
    );
  }

  // Abre la administración de productos y aplica los cambios al catálogo.
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
      await FirebaseStoreRepository.saveProducts(_products);
    }
  }

  // Abre la administración de clientes y actualiza la lista local al regresar.
  Future<void> _openCustomerManager(BuildContext context) async {
    Navigator.pop(context);
    final updatedCustomers = await Navigator.push<List<Customer>>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerManagerScreen(customers: _customers),
      ),
    );
    if (updatedCustomers != null) {
      setState(() => _customers = updatedCustomers);
      for (final customer in _customers) {
        await FirebaseStoreRepository.saveCustomer(customer);
      }
    }
  }
}

// Lista reutilizable para el catálogo general y la pestaña de ofertas.
class ProductList extends StatelessWidget {
  const ProductList({
    required this.products,
    this.showOffer = false,
    this.filterOffers = true,
    this.customer,
    this.onOrder,
    super.key,
  });

  final List<Product> products;
  final bool showOffer;
  final bool filterOffers;
  final Customer? customer;
  final void Function(Product product, int quantity)? onOrder;

  @override
  Widget build(BuildContext context) {
    // Se filtran los productos para que Ofertas no muestre artículos normales.
    final visibleProducts = showOffer && filterOffers
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
            minVerticalPadding: 12,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showOffer && product.offerEnabled)
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
                      showOffer &&
                              product.offerEnabled &&
                              product.offerPrice.isNotEmpty
                          ? product.offerPrice
                          : product.price,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Stock: ${product.stock}'),
                  ],
                ),
                if (product.stock > 0 && onOrder != null)
                  IconButton(
                    tooltip: 'Reservar artículo',
                    onPressed: () => _askQuantity(context, product),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pide una cantidad válida antes de enviar la solicitud de compra.
  Future<void> _askQuantity(BuildContext context, Product product) async {
    var quantityText = '1';
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reservar ${product.name}'),
        content: TextFormField(
          initialValue: quantityText,
          keyboardType: TextInputType.number,
          onChanged: (value) => quantityText = value,
          decoration: InputDecoration(
            labelText: 'Cantidad (máximo ${product.stock})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(quantityText) ?? 0;
              if (value > 0 && value <= product.stock) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Reservar'),
          ),
        ],
      ),
    );
    if (quantity != null) onOrder?.call(product, quantity);
  }
}

// Muestra las categorías disponibles para navegar visualmente el catálogo.
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
// Selecciona un icono representativo para cada categoría.
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

// Muestra la imagen local, la imagen remota o el icono de respaldo del producto.
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

// Menú lateral para acceder a login, registros y herramientas administrativas.
class StoreDrawer extends StatelessWidget {
  const StoreDrawer({
    required this.isAdmin,
    this.customer,
    required this.onManageProducts,
    required this.onManageCustomers,
    required this.onManageOrders,
    required this.onCustomerRegistered,
    required this.onSurveySubmitted,
    super.key,
  });

  final bool isAdmin;
  final Customer? customer;
  final VoidCallback onManageProducts;
  final VoidCallback onManageCustomers;
  final VoidCallback onManageOrders;
  final ValueChanged<Customer> onCustomerRegistered;
  final ValueChanged<SurveyResponse> onSurveySubmitted;

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
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Panel de gestión'),
              onTap: () {
                Navigator.pop(context);
                onManageOrders();
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
                    builder: (_) => CustomerRegistrationScreen(
                      onRegistered: onCustomerRegistered,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Gestionar clientes'),
              onTap: onManageCustomers,
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Administrar productos'),
              onTap: onManageProducts,
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: const Text('Encuesta de satisfacción'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SurveyScreen(
                      customer: customer,
                      onSubmitted: onSurveySubmitted,
                    ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Pantalla administrativa que lista, crea y edita productos.
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

// Estado temporal de productos y categorías mientras se administra el catálogo.
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
          stock: product.stock,
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
              subtitle: Text(
                '${product.type} · ${product.category}\n'
                'Stock disponible: ${product.stock}',
              ),
              isThreeLine: true,
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
// Pantalla para activar ofertas y definir precios promocionales.
class OfferManagerScreen extends StatefulWidget {
  const OfferManagerScreen({required this.products, super.key});

  final List<Product> products;

  @override
  State<OfferManagerScreen> createState() => _OfferManagerScreenState();
}

// Copia editable del catálogo usada por la administración de ofertas.
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
// Resultado de la pantalla de categorías: lista final y nombres renombrados.
class CategoryChange {
  const CategoryChange({required this.categories, required this.renamed});

  final List<String> categories;
  // Relaciona el nombre anterior con el nuevo al renombrar una categoría.
  final Map<String, String> renamed;
}

// Pantalla para crear, renombrar y eliminar categorías.
class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({required this.categories, super.key});

  final List<String> categories;

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

// Estado temporal de categorías hasta que el administrador confirma el regreso.
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

// Formulario para crear o actualizar los datos de un producto.
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

// Controla validación, campos, stock e imagen del producto editado.
class _ProductEditorScreenState extends State<ProductEditorScreen> {
  // Los controllers mantienen sincronizado cada campo del formulario.
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _stockController;
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
    _stockController = TextEditingController(text: '${product?.stock ?? 0}');
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
    _stockController.dispose();
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
        stock: int.tryParse(_stockController.text.trim()) ?? 0,
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
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock disponible',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final stock = int.tryParse(value ?? '');
                if (stock == null) return 'Ingresa una cantidad válida';
                if (stock < 0) return 'El stock no puede ser negativo';
                return null;
              },
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

// Panel privado del administrador con las pestañas de pedidos y encuestas.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.orders,
    required this.surveys,
    required this.onOrdersChanged,
    super.key,
  });

  final List<Order> orders;
  final List<SurveyResponse> surveys;
  final ValueChanged<List<Order>> onOrdersChanged;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

// Mantiene los estados de pedidos visibles mientras el panel está abierto.
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late List<Order> _orders;

  @override
  void initState() {
    super.initState();
    _orders = List<Order>.from(widget.orders);
  }

  void _changeStatus(int index, OrderStatus status) {
    // Actualiza localmente y notifica a la tienda para sincronizar Firestore.
    setState(() => _orders[index] = _orders[index].copyWith(status: status));
    widget.onOrdersChanged(_orders);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de gestión'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Reservas (${widget.orders.length})'),
              const Tab(text: 'Encuestas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                ListTile(
                  title: const Text('Total de reservas'),
                  trailing: Text('${_orders.length}'),
                ),
                Expanded(
                  child: _orders.isEmpty
                      ? const Center(child: Text('No hay reservas recibidas'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return Card(
                              child: ListTile(
                                title: Text('Producto: ${order.productName}'),
                                subtitle: Text(
                                  'Cliente: ${order.customerEmail}\n'
                                  'Cantidad: ${order.quantity}\n'
                                  'Estado: ${_orderStatusLabel(order.status)}',
                                ),
                                isThreeLine: true,
                                trailing: DropdownButton<OrderStatus>(
                                  value: order.status,
                                  onChanged: (value) {
                                    if (value != null) {
                                      _changeStatus(index, value);
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: OrderStatus.solicitado,
                                      child: Text('Solicitado'),
                                    ),
                                    DropdownMenuItem(
                                      value: OrderStatus.despachado,
                                      child: Text('Despachado'),
                                    ),
                                    DropdownMenuItem(
                                      value: OrderStatus.ventaRealizada,
                                      child: Text('Venta realizada'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Column(
              children: [
                ListTile(
                  title: const Text('Total de respuestas'),
                  trailing: Text('${widget.surveys.length}'),
                ),
                Expanded(
                  child: widget.surveys.isEmpty
                      ? const Center(child: Text('No hay encuestas recibidas'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: widget.surveys.length,
                          itemBuilder: (context, index) {
                            final survey = widget.surveys[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${survey.name} · ${survey.satisfaction}',
                                ),
                                subtitle: Text(
                                  '${survey.service}: ${survey.comments}',
                                ),
                                isThreeLine: true,
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
}

// Pantalla de acceso: valida correo y contraseña antes de mostrar confirmación.
// Pantalla de acceso para clientes registrados y administrador.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.customers = const [],
    this.onCustomerRegistered,
    this.onCustomerLogin,
    this.onAdminLogin,
    super.key,
  });

  final List<Customer> customers;
  final ValueChanged<Customer>? onCustomerRegistered;
  final ValueChanged<Customer>? onCustomerLogin;
  final VoidCallback? onAdminLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Controla validación y comparación de credenciales de acceso.
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
    // El administrador usa credenciales fijas; los clientes se buscan en la lista
    // cargada desde Firestore o creada durante la sesión.
    // validate ejecuta los validators definidos en los campos.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if ((user == 'elecadmin' || user == 'administrador elecadmin') &&
        password.trim() == 'Usuari0100*') {
      _emailController.clear();
      _passwordController.clear();
      widget.onAdminLogin?.call();
      return;
    }
    final customer = widget.customers
        .where(
          (item) =>
              (item.email.trim().toLowerCase() == user ||
                  item.cedula.trim() == user) &&
              item.password == password,
        )
        .firstOrNull;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario, correo o contraseña incorrectos'),
        ),
      );
      return;
    }
    widget.onCustomerLogin?.call(customer);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión iniciada correctamente')),
    );
  }

  Future<void> _registerNewCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerRegistrationScreen()),
    );
    if (customer == null || !mounted) return;
    widget.onCustomerRegistered?.call(customer);
    widget.onCustomerLogin?.call(customer);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta registrada e ingreso iniciado')),
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
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Usuario o correo electrónico',
                hintText: 'Ingresa tu usuario o correo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa tu usuario o correo'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
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
              onPressed: _registerNewCustomer,
              child: const Text('¿Nuevo cliente? Regístrate aquí'),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla para capturar los datos básicos de un nuevo cliente.
// Formulario público para registrar una nueva cuenta de cliente.
class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({this.onRegistered, super.key});

  final ValueChanged<Customer>? onRegistered;

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

// Estado y controladores del formulario de registro público.
class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  // Cada campo tiene su propio controller para leer y liberar su contenido.
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Se recorren todos los controllers para liberar sus recursos.
    for (final controller in [
      _cedulaController,
      _nameController,
      _addressController,
      _phoneController,
      _cityController,
      _emailController,
      _passwordController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label es obligatorio' : null;

  void _register() {
    // Construye el cliente, lo devuelve a la tienda y dispara su persistencia.
    // El registro solo continúa si todos los campos obligatorios tienen datos.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final customer = Customer(
      cedula: _cedulaController.text.trim(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      registeredAt: DateTime.now(),
    );
    widget.onRegistered?.call(customer);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente registrado correctamente')),
    );
    Navigator.pop(context, customer);
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
            _field(
              _emailController,
              'Correo electrónico',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            _field(
              _passwordController,
              'Contraseña',
              Icons.lock_outline,
              obscureText: true,
            ),
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
    bool obscureText = false,
  }) {
    // Método reutilizable para construir los cinco campos del registro.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
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

// Pantalla administrativa de búsqueda, edición y eliminación de clientes.
class CustomerManagerScreen extends StatefulWidget {
  const CustomerManagerScreen({required this.customers, super.key});

  final List<Customer> customers;

  @override
  State<CustomerManagerScreen> createState() => _CustomerManagerScreenState();
}

// Estado de filtros y lista editable de clientes.
class _CustomerManagerScreenState extends State<CustomerManagerScreen> {
  late List<Customer> _customers;
  final _cedulaSearchController = TextEditingController();
  DateTime? _registeredDate;

  @override
  void initState() {
    super.initState();
    _customers = List<Customer>.from(widget.customers);
    _cedulaSearchController.addListener(_refreshResults);
  }

  @override
  void dispose() {
    _cedulaSearchController
      ..removeListener(_refreshResults)
      ..dispose();
    super.dispose();
  }

  void _refreshResults() => setState(() {});

  List<Customer> get _visibleCustomers {
    final cedula = _cedulaSearchController.text.trim();
    return _customers.where((customer) {
      final matchesCedula = cedula.isEmpty || customer.cedula.contains(cedula);
      final matchesDate =
          _registeredDate == null ||
          _sameDate(customer.registeredAt, _registeredDate!);
      return matchesCedula && matchesDate;
    }).toList();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _registeredDate ?? DateTime.now(),
      helpText: 'Filtrar fecha de registro',
    );
    if (selected != null) setState(() => _registeredDate = selected);
  }

  Future<void> _editCustomer([Customer? customer]) async {
    final result = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerEditorScreen(customer: customer),
      ),
    );
    if (result == null) return;
    setState(() {
      final index = customer == null ? -1 : _customers.indexOf(customer);
      if (index == -1) {
        _customers.add(result);
      } else {
        _customers[index] = result;
      }
    });
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar a ${customer.name}?'),
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
      setState(() => _customers.remove(customer));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleCustomers = _visibleCustomers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de clientes'),
        leading: IconButton(
          tooltip: 'Guardar cambios',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _customers),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _cedulaSearchController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Consultar por cédula',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _cedulaSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: _cedulaSearchController.clear,
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _registeredDate == null
                          ? 'Filtrar por fecha'
                          : 'Registro: ${_formatDate(_registeredDate!)}',
                    ),
                  ),
                ),
                if (_registeredDate != null)
                  IconButton(
                    tooltip: 'Quitar filtro de fecha',
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    onPressed: () => setState(() => _registeredDate = null),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visibleCustomers.isEmpty
                ? const Center(child: Text('No hay clientes para mostrar'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleCustomers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = visibleCustomers[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(customer.name.substring(0, 1)),
                          ),
                          title: Text(customer.name),
                          subtitle: Text(
                            'Cédula: ${customer.cedula} · ${customer.email}\n'
                            '${customer.city} · Registrado: '
                            '${_formatDate(customer.registeredAt)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar cliente',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editCustomer(customer),
                              ),
                              IconButton(
                                tooltip: 'Eliminar cliente',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteCustomer(customer),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Formulario interno para crear o modificar un cliente desde administración.
class CustomerEditorScreen extends StatefulWidget {
  const CustomerEditorScreen({this.customer, super.key});

  final Customer? customer;

  @override
  State<CustomerEditorScreen> createState() => _CustomerEditorScreenState();
}

// Controla los campos y validaciones del editor de clientes.
class _CustomerEditorScreenState extends State<CustomerEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cedulaController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _cedulaController = TextEditingController(text: customer?.cedula);
    _nameController = TextEditingController(text: customer?.name);
    _addressController = TextEditingController(text: customer?.address);
    _phoneController = TextEditingController(text: customer?.phone);
    _cityController = TextEditingController(text: customer?.city);
    _emailController = TextEditingController(text: customer?.email);
    _passwordController = TextEditingController(text: customer?.password);
  }

  @override
  void dispose() {
    for (final controller in [
      _cedulaController,
      _nameController,
      _addressController,
      _phoneController,
      _cityController,
      _emailController,
      _passwordController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label es obligatorio' : null;

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final customer = Customer(
      cedula: _cedulaController.text.trim(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      registeredAt: widget.customer?.registeredAt ?? DateTime.now(),
    );
    Navigator.pop(context, customer);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Actualizar cliente' : 'Crear cliente'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              isEditing ? 'Actualizar datos del cliente' : 'Nuevo cliente',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _field(
              _cedulaController,
              'Cédula',
              Icons.badge_outlined,
              keyboardType: TextInputType.number,
            ),
            _field(_nameController, 'Nombre completo', Icons.person_outline),
            _field(_addressController, 'Dirección', Icons.home_outlined),
            _field(
              _phoneController,
              'Teléfono',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _field(_cityController, 'Ciudad', Icons.location_city_outlined),
            _field(
              _emailController,
              'Correo electrónico',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            _field(
              _passwordController,
              'Contraseña',
              Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(isEditing ? 'Actualizar cliente' : 'Crear cliente'),
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
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
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

// Pantalla privada donde el cliente consulta únicamente sus reservas.
class CustomerReservationsScreen extends StatelessWidget {
  const CustomerReservationsScreen({
    required this.customer,
    required this.orders,
    super.key,
  });

  final Customer customer;
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final customerOrders = orders
        .where((order) => order.customerEmail == customer.email)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: customerOrders.isEmpty
          ? const Center(child: Text('Todavía no tienes reservas'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: customerOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = customerOrders[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: Text(order.productName),
                    subtitle: Text(
                      'Cantidad: ${order.quantity}\n'
                      'Estado: ${_orderStatusLabel(order.status)}\n'
                      'Fecha: ${_formatDate(order.createdAt)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

// Compara fechas ignorando la hora para el filtro de registros.
bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

// Convierte una fecha a formato corto día/mes/año.
String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.solicitado:
      return 'Solicitado';
    case OrderStatus.despachado:
      return 'Despachado';
    case OrderStatus.ventaRealizada:
      return 'Venta realizada';
  }
}

// Elemento visual de la cabecera de la encuesta.
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
// Aquí se recopila la opinión del cliente sobre el servicio recibido.
// Formulario para recopilar y guardar opiniones de los clientes.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({this.customer, this.onSubmitted, super.key});

  final Customer? customer;
  final ValueChanged<SurveyResponse>? onSubmitted;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

// Estado de respuestas seleccionadas y textos de la encuesta.
class _SurveyScreenState extends State<SurveyScreen> {
  // La llave valida los campos de texto y las selecciones del formulario.
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  String? _satisfaction;
  String? _service;

  @override
  void dispose() {
    // Se liberan los controllers de nombre y comentarios.
    _nameController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  void _submitSurvey() {
    // Valida campos y selecciones antes de enviar la respuesta a Firestore.
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

    final nombre = widget.customer?.name ??
      (_nameController.text.trim().isEmpty
        ? 'Anónimo'
        : _nameController.text.trim());
    widget.onSubmitted?.call(
      SurveyResponse(
        name: nombre,
        satisfaction: _satisfaction!,
        service: _service!,
        comments: _commentsController.text.trim(),
      ),
    );
    // Cuando se completa, se guarda y se regresa al menú o pantalla anterior.
    Navigator.pop(context, true);
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

                if (widget.customer == null)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre o Anónimo (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Nombre del cliente'),
                    subtitle: Text(widget.customer!.name),
                  ),
                const SizedBox(height: 20),

                const Text(
                  '¿Qué tan satisfecho te sentiste con el servicio?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                // La respuesta se guarda como una sola opción seleccionada.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Muy satisfecho'),
                      selected: _satisfaction == 'Muy satisfecho',
                      onSelected: (_) =>
                          setState(() => _satisfaction = 'Muy satisfecho'),
                    ),
                    ChoiceChip(
                      label: const Text('Satisfecho'),
                      selected: _satisfaction == 'Satisfecho',
                      onSelected: (_) =>
                          setState(() => _satisfaction = 'Satisfecho'),
                    ),
                    ChoiceChip(
                      label: const Text('Neutral'),
                      selected: _satisfaction == 'Neutral',
                      onSelected: (_) =>
                          setState(() => _satisfaction = 'Neutral'),
                    ),
                    ChoiceChip(
                      label: const Text('Insatisfecho'),
                      selected: _satisfaction == 'Insatisfecho',
                      onSelected: (_) =>
                          setState(() => _satisfaction = 'Insatisfecho'),
                    ),
                  ],
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
                // Esta lista desplegable representa la valoración general del servicio.
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla que demuestra eventos de toque y desplazamiento.
// Pantalla heredada que demuestra eventos táctiles; no se muestra en el menú.
class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

// Guarda el mensaje y color resultantes del último gesto detectado.
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
