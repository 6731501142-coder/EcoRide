import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:ecoride_app/core/colors.dart';
import 'package:ecoride_app/data/models.dart';
import 'package:ecoride_app/widgets/bars.dart';
import 'package:ecoride_app/widgets/basic.dart';
import 'package:ecoride_app/widgets/form.dart';
import 'package:ecoride_app/widgets/station_pic.dart';

import 'fake_backend.dart';

final _samplePng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  group('bars.dart', () {
    testWidgets('TopBar displays title, trailing widget, and handles back tap', (tester) async {
      var backed = false;
      await pumpApp(
        tester,
        Scaffold(
          body: TopBar(
            title: 'Select Bike',
            trailing: const Icon(TablerIcons.help),
            onBack: () => backed = true,
          ),
        ),
      );

      expect(find.text('Select Bike'), findsOneWidget);
      expect(find.byIcon(TablerIcons.help), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      expect(backed, isTrue);
    });

    testWidgets('RedHeader renders child inside red container', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: RedHeader(child: Text('EcoRide Header')),
        ),
      );

      expect(find.text('EcoRide Header'), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(RedHeader),
        matching: find.byType(Container),
      ));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, C.red);
    });

    testWidgets('AppNavBar renders 3 tabs and notifies on tap', (tester) async {
      int? tapped;
      await pumpApp(
        tester,
        Scaffold(
          bottomNavigationBar: AppNavBar(
            index: 0,
            onTap: (i) => tapped = i,
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_1')));
      expect(tapped, 1);

      await tester.tap(find.byKey(const Key('nav_2')));
      expect(tapped, 2);
    });
  });

  group('basic.dart', () {
    testWidgets('Ic, TintIc, and SquareIc display icons', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Row(
            children: [
              Ic(TablerIcons.bike),
              Ic(TablerIcons.alertTriangle, red: true),
              TintIc(TablerIcons.bolt, Tint.ready),
              SquareIc(TablerIcons.settings, C.red),
            ],
          ),
        ),
      );

      expect(find.byIcon(TablerIcons.bike), findsOneWidget);
      expect(find.byIcon(TablerIcons.alertTriangle), findsOneWidget);
      expect(find.byIcon(TablerIcons.bolt), findsOneWidget);
      expect(find.byIcon(TablerIcons.settings), findsOneWidget);
    });

    testWidgets('Pill renders all kinds', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Row(
            children: [
              Pill('Gold', kind: PillKind.gold),
              Pill('Red', kind: PillKind.red),
              Pill('Gray', kind: PillKind.gray),
              Pill('Solid', kind: PillKind.solid),
            ],
          ),
        ),
      );

      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Gray'), findsOneWidget);
      expect(find.text('Solid'), findsOneWidget);
    });

    testWidgets('AppCard renders children and handles tap', (tester) async {
      var tapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: AppCard(
            onTap: () => tapped = true,
            children: const [Text('Station A'), Text('5 bikes')],
          ),
        ),
      );

      expect(find.text('Station A'), findsOneWidget);
      expect(find.text('5 bikes'), findsOneWidget);

      await tester.tap(find.byType(AppCard));
      expect(tapped, isTrue);
    });

    testWidgets('Bar clamps widthFactor between 0.0 and 1.0', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Column(
            children: [
              Bar(-20),
              Bar(50),
              Bar(150, red: true),
            ],
          ),
        ),
      );

      final boxes = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .toList();
      expect(boxes[0].widthFactor, 0.0);
      expect(boxes[1].widthFactor, 0.5);
      expect(boxes[2].widthFactor, 1.0);//if u want to expect error test, change 1.0 to 1.5 and run test
    });

    testWidgets('Kpi displays value, label, and optional icon', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Kpi('12', 'Ready vehicles', tone: KpiTone.green, icon: TablerIcons.bolt),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Ready vehicles'), findsOneWidget);
      expect(find.byIcon(TablerIcons.bolt), findsOneWidget);
    });

    testWidgets('Chips selects item on tap', (tester) async {
      var selected = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Chips(
            const ['All', 'E-bike', 'Scooter'],
            selected: selected,
            onSelect: (i) => selected = i,
          ),
        ),
      );

      await tester.tap(find.text('Scooter'));
      expect(selected, 2);
    });

    testWidgets('SearchField displays hint and search icon', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SearchField('Search station...')),
      );

      expect(find.text('Search station...'), findsOneWidget);
      expect(find.byIcon(TablerIcons.search), findsOneWidget);
    });

    testWidgets('Btn handles enabled and disabled states', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              Btn('Confirm', icon: TablerIcons.check, onTap: () => taps++),
              const Btn('Disabled', kind: BtnKind.outlined, onTap: null),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Confirm'));
      expect(taps, 1);

      final disabledOpacity = tester.widget<Opacity>(find.ancestor(
        of: find.text('Disabled'),
        matching: find.byType(Opacity),
      ));
      expect(disabledOpacity.opacity, 0.45);
    });
  });

  group('form.dart', () {
    testWidgets('AppInput displays label, accepts text, and toggles password visibility', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        Scaffold(
          body: AppInput(
            controller: controller,
            label: 'Password',
            hint: 'Enter password',
            icon: TablerIcons.lock,
            obscure: true,
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'secret123');
      expect(controller.text, 'secret123');

      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump(); // add // to test fails
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    });

    testWidgets('SectionLabel, InfoRow, Panel, and MonthHeader render properly', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Column(
            children: [
              SectionLabel('Personal info'),
              MonthHeader('November 2026'),
              Panel(
                child: Column(
                  children: [
                    InfoRow('Vehicle', 'EB-012'),
                    InfoRow('Cost', '฿50', last: true, bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Personal info'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('EB-012'), findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('฿50'), findsOneWidget);
    });

    testWidgets('toast shows SnackBar message', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => toast(ctx, 'Saved successfully', error: true),
              child: const Text('Trigger'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Saved successfully'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, C.red);
    });

    testWidgets('confirmDialog returns false on Cancel and true on confirm', (tester) async {
      bool? result;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await confirmDialog(
                  ctx,
                  title: 'Delete item?',
                  message: 'This action cannot be undone.',
                  ok: 'Delete',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete item?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('station_pic.dart', () {
    test('stationIcon returns matching icon and defaults to building', () {
      expect(stationIcon('books'), TablerIcons.books);
      expect(stationIcon('canteen'), TablerIcons.toolsKitchen2);
      expect(stationIcon('unknown_key'), TablerIcons.building);
    });

    testWidgets('StationPic and StationBanner handle station without photo', (tester) async {
      final station = Station(
        stationId: 1,
        name: 'Library',
        totalDocks: 10,
        iconKey: 'books',
      );

      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              StationPic(station, Tint.ready),
              StationBanner(station),
            ],
          ),
        ),
      );

      expect(find.byType(TintIc), findsOneWidget);
      expect(find.byIcon(TablerIcons.books), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('StationPic and StationBanner render photo when available', (tester) async {
      final station = Station(
        stationId: 2,
        name: 'Building 1',
        totalDocks: 10,
        photo: _samplePng,
      );

      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              StationPic(station, Tint.ready),
              StationBanner(station),
            ],
          ),
        ),
      );

      expect(find.byType(TintIc), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}