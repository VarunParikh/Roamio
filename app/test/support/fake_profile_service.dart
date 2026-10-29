import 'package:roamio/features/profile/data/profile_service.dart';

class FakeProfileService implements ProfileService {
  new([this.currency = 'INR']);

  final String currency;

  @override
  Stream<String> profileCurrency() => Stream.value(currency);
}
