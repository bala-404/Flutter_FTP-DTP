import 'package:flutter_test/flutter_test.dart';
import 'package:ftp_dtp_example/main.dart';

void main() {
  testWidgets('App loads with example title', (tester) async {
    await tester.pumpWidget(const FtpDtpExampleApp());
    expect(find.text('FTP & DTP Example'), findsOneWidget);
  });
}
