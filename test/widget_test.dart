import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

Future<void> _pumpStoreAfterLogin(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byType(TextFormField).at(0), 'maria@gmail.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'Usuario01');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

Future<void> _pumpAdminStore(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byType(TextFormField).at(0), 'ElecAdmin');
  await tester.enterText(find.byType(TextFormField).at(1), 'Usuari0100*');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('requiere iniciar sesión antes de mostrar el menú', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.text('ElecAdmin'), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.text('Refrigeradora Inox 300 L'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'maria@gmail.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Usuario01');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('ElectroHome Ecuador'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Lavadora EcoWash 18 kg'), findsOneWidget);
    expect(find.text('Televisor Smart 55 pulgadas'), findsOneWidget);
    expect(find.text('Refrigeradora Inox 300 L'), findsOneWidget);
  });

  testWidgets('el cliente puede reservar un producto publicado sin oferta', (
    WidgetTester tester,
  ) async {
    await _pumpStoreAfterLogin(tester);

    await tester.tap(find.byTooltip('Reservar artículo').first);
    await tester.pumpAndSettle();
    expect(find.text('Reservar Refrigeradora Inox 300 L'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
    await tester.pumpAndSettle();

    final refrigeratorCard = find.ancestor(
      of: find.text('Refrigeradora Inox 300 L'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: refrigeratorCard, matching: find.text('Stock: 5')),
      findsOneWidget,
    );
  });

  testWidgets('informa el stock cuando la reserva supera el inventario', (
    WidgetTester tester,
  ) async {
    await _pumpStoreAfterLogin(tester);

    await tester.tap(find.byTooltip('Reservar artículo').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '9');
    await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
    await tester.pumpAndSettle();

    expect(
      find.text('No hay stock suficiente. Disponible: 8'),
      findsNWidgets(2),
    );
    expect(find.text('Reservar Refrigeradora Inox 300 L'), findsOneWidget);
  });

  testWidgets('el cliente solo puede reservar ofertas con stock', (
    WidgetTester tester,
  ) async {
    await _pumpStoreAfterLogin(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Encuesta de satisfacción'), findsOneWidget);
    expect(find.text('Registrar nuevo cliente'), findsNothing);
    expect(find.text('Gestionar clientes'), findsNothing);
    expect(find.text('Administrar productos'), findsNothing);
  });

  testWidgets('permite cerrar sesión y volver al acceso', (
    WidgetTester tester,
  ) async {
    await _pumpStoreAfterLogin(tester);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('permite abrir el acceso al registrar una sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.text('Bienvenido a ElectroHome Ecuador'), findsOneWidget);
  });

  testWidgets('valida el usuario administrador sin distinguir mayúsculas', (
    WidgetTester tester,
  ) async {
    var adminLoginSucceeded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onAdminLogin: () => adminLoginSucceeded = true),
      ),
    );

    expect(find.text('Usuario o correo electrónico'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'ElecAdmin');
    await tester.enterText(find.byType(TextFormField).at(1), 'Usuari0100*');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(adminLoginSucceeded, isTrue);
    expect(find.text('Sesión de administrador iniciada'), findsNothing);
  });

  testWidgets('permite ingresar con la cédula de un cliente registrado', (
    WidgetTester tester,
  ) async {
    Customer? loggedInCustomer;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          customers: [
            Customer(
              cedula: '1234567890',
              name: 'Lucía Pérez',
              address: 'Av. Central 123',
              phone: '0991234567',
              city: 'Quito',
              email: 'lucia@example.com',
              password: 'clave123',
              registeredAt: DateTime(2026),
            ),
          ],
          onCustomerLogin: (customer) => loggedInCustomer = customer,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '1234567890');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(loggedInCustomer?.email, 'lucia@example.com');
  });

  testWidgets('permite ingresar desde la app usando la cédula', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextFormField).at(0), '0102030405');
    await tester.enterText(find.byType(TextFormField).at(1), 'Usuario01');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('Lavadora EcoWash 18 kg'), findsOneWidget);
    expect(find.text('Inicio de sesión'), findsNothing);
  });

  testWidgets('registra e inicia la sesión de un cliente desde el login', (
    WidgetTester tester,
  ) async {
    Customer? registeredCustomer;
    Customer? loggedInCustomer;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onCustomerRegistered: (customer) => registeredCustomer = customer,
          onCustomerLogin: (customer) => loggedInCustomer = customer,
        ),
      ),
    );

    await tester.tap(find.text('¿Nuevo cliente? Regístrate aquí'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '1234567890');
    await tester.enterText(fields.at(1), 'Lucía Pérez');
    await tester.enterText(fields.at(2), 'Av. Central 123');
    await tester.enterText(fields.at(3), '0991234567');
    await tester.enterText(fields.at(4), 'Quito');
    await tester.enterText(fields.at(5), 'lucia@example.com');
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'clave123');
    await tester.tap(find.text('Registrar cliente'));
    await tester.pumpAndSettle();

    expect(registeredCustomer?.email, 'lucia@example.com');
    expect(loggedInCustomer?.email, 'lucia@example.com');
    expect(find.text('Inicio de sesión'), findsOneWidget);
  });

  testWidgets('un cliente recién registrado puede reservar una oferta', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('¿Nuevo cliente? Regístrate aquí'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '1234567890');
    await tester.enterText(fields.at(1), 'Lucía Pérez');
    await tester.enterText(fields.at(2), 'Av. Central 123');
    await tester.enterText(fields.at(3), '0991234567');
    await tester.enterText(fields.at(4), 'Quito');
    await tester.enterText(fields.at(5), 'lucia@example.com');
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'clave123');
    await tester.tap(find.text('Registrar cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Lavadora EcoWash 18 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Reservar artículo').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: 4'), findsOneWidget);
  });

  testWidgets('muestra el formulario de registro de clientes', (
    WidgetTester tester,
  ) async {
    await _pumpAdminStore(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar nuevo cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de clientes'), findsOneWidget);
    expect(find.text('Cédula'), findsOneWidget);
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);
    expect(find.text('Teléfono'), findsOneWidget);
    expect(find.text('Ciudad'), findsOneWidget);
  });

  testWidgets('permite crear y consultar un cliente por cédula', (
    WidgetTester tester,
  ) async {
    await _pumpAdminStore(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestionar clientes'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de clientes'), findsOneWidget);
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '1712345678');
    await tester.enterText(fields.at(1), 'Ana Torres');
    await tester.enterText(fields.at(2), 'Calle Quito 123');
    await tester.enterText(fields.at(3), '0991112233');
    await tester.enterText(fields.at(4), 'Quito');
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    final editorFields = find.byType(TextFormField);
    await tester.enterText(editorFields.at(5), 'ana@gmail.com');
    await tester.enterText(editorFields.at(6), 'anaClave123');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Torres'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1712345678');
    await tester.pump();
    expect(find.text('Ana Torres'), findsOneWidget);
  });

  testWidgets('permite actualizar correo y contraseña del cliente', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Customer? updatedCustomer;
    final customer = Customer(
      cedula: '1234567890',
      name: 'Lucía Pérez',
      address: 'Av. Central 123',
      phone: '0991234567',
      city: 'Quito',
      email: 'lucia@example.com',
      password: 'clave123',
      registeredAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                updatedCustomer = await Navigator.push<Customer>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerEditorScreen(customer: customer),
                  ),
                );
              },
              child: const Text('Editar cliente'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Editar cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(5), 'lucia.nueva@example.com');
    await tester.enterText(fields.at(6), 'nuevaClave456');
    await tester.tap(find.widgetWithText(FilledButton, 'Actualizar cliente'));
    await tester.pumpAndSettle();

    expect(updatedCustomer?.email, 'lucia.nueva@example.com');
    expect(updatedCustomer?.password, 'nuevaClave456');
  });

  testWidgets('muestra el total de encuestas en el panel de gestión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          orders: const [],
          surveys: const [
            SurveyResponse(
              name: 'Ana Torres',
              satisfaction: 'Satisfecho',
              service: 'Buena',
              comments: 'Todo bien',
            ),
          ],
          onOrdersChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Panel de gestión'), findsOneWidget);
    await tester.tap(find.text('Encuestas'));
    await tester.pumpAndSettle();

    expect(find.text('Total de respuestas'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Ana Torres · Satisfecho'), findsOneWidget);
  });

  testWidgets('el administrador puede ver una reserva hecha por un cliente', (
    WidgetTester tester,
  ) async {
    await _pumpStoreAfterLogin(tester);

    await tester.tap(find.byTooltip('Reservar artículo').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mis reservas'));
    await tester.pumpAndSettle();
    expect(find.text('Mis reservas'), findsOneWidget);
    expect(find.text('Lavadora EcoWash 18 kg'), findsOneWidget);
    expect(find.textContaining('Cantidad: 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'ElecAdmin');
    await tester.enterText(find.byType(TextFormField).at(1), 'Usuari0100*');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Reservas (1)'), findsOneWidget);
    expect(find.text('Total de reservas'), findsOneWidget);
    expect(find.text('Producto: Lavadora EcoWash 18 kg'), findsOneWidget);
    expect(find.textContaining('Cliente: maria@gmail.com'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrar productos'));
    await tester.pumpAndSettle();

    final washerCard = find.ancestor(
      of: find.text('Lavadora EcoWash 18 kg'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: washerCard,
        matching: find.textContaining('Stock disponible: 3'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Editar Lavadora EcoWash 18 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(4), '8');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guardar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guardar cambios'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrar productos'));
    await tester.pumpAndSettle();

    final updatedWasherCard = find.ancestor(
      of: find.text('Lavadora EcoWash 18 kg'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: updatedWasherCard,
        matching: find.textContaining('Stock disponible: 8'),
      ),
      findsOneWidget,
    );
  });
}
