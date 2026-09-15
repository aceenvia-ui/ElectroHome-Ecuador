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
}
