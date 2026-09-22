import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanctuary/main.dart';
import 'package:sanctuary/data/services/storage_service.dart';
import 'package:sanctuary/data/services/api_service.dart';

void main() {
  testWidgets('Sanctuary App Smoke Test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final api = ApiService(storage: storage);

    await tester.pumpWidget(SanctuaryApp(storage: storage, apiService: api));
    expect(find.textContaining('SANCTUARY'), findsWidgets);
  });
}
