import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moble_app/podcast.dart';

// Robust Http Mock using noSuchMethod to bypass abstract method gaps across SDK versions
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      return Future.value(MockHttpClientRequest());
    }
    return null;
  }
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(MockHttpClientResponse());
    }
    if (invocation.memberName == #headers) {
      return MockHttpHeaders();
    }
    return null;
  }
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse implements HttpClientResponse {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #statusCode) return 200;
    if (invocation.memberName == #contentLength) return _transparentPixel.length;
    if (invocation.memberName == #compressionState) return HttpClientResponseCompressionState.notCompressed;
    if (invocation.memberName == #listen) {
      final Function onData = invocation.positionalArguments[0];
      return Stream<List<int>>.fromIterable([_transparentPixel]).listen(
        (data) => onData(data),
      );
    }
    return null;
  }
}

final List<int> _transparentPixel = [
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
  0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
  0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
  0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
];

void main() {
  setUpAll(() {
    HttpOverrides.global = MockHttpOverrides();
  });

  testWidgets('Podcast Screen and Detail Screen Navigation Test', (WidgetTester tester) async {
    // Build PodcastScreen inside a MaterialApp
    await tester.pumpWidget(
      const MaterialApp(
        home: PodcastScreen(),
      ),
    );

    // Verify listing screen elements are present
    expect(find.text('Level Up Your Tribe'), findsOneWidget);
    expect(find.text('Available Courses'), findsOneWidget);

    // Verify the course cards exist in the listing
    expect(find.text('Mastering Drip Marketing'), findsOneWidget);
    expect(find.text('Digital Marketing Excellence'), findsOneWidget);

    // Tap on the first course card to open player detail page
    await tester.tap(find.text('Mastering Drip Marketing'));
    // Pump and settle navigation transition completely
    await tester.pumpAndSettle();

    // Verify that the dynamic player detail page is loaded
    expect(find.text('MASTERING DRIP MARKETING'), findsOneWidget);
    expect(find.text('MARKETING'), findsOneWidget);
  });
}
