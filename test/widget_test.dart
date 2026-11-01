import 'package:caffeine_cafe_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app opens on the coffee shop home screen', (tester) async {
    await tester.pumpWidget(const CaffeineCafeApp());
    await tester.pumpAndSettle();

    expect(find.text('CAFFEINE CAFE'), findsOneWidget);
    expect(find.text('GOOD COFFEE,'), findsOneWidget);
    expect(find.text('better days.'), findsOneWidget);
  });
}
