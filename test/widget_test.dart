import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('muestra el catálogo con ListView', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('ElectroHome Ecuador'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Refrigeradora Inox 300 L'), findsOneWidget);
  });

  testWidgets('permite cambiar entre categorías con TabBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);

    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();

    expect(find.text('Línea blanca'), findsOneWidget);
  });

  testWidgets('permite acceder al inicio de sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byTooltip('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.text('Bienvenido a ElectroHome Ecuador'), findsOneWidget);
  });

  testWidgets('muestra el formulario de registro de clientes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

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
    await tester.pumpWidget(const MyApp());

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
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Torres'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1712345678');
    await tester.pump();
    expect(find.text('Ana Torres'), findsOneWidget);
  });
}
