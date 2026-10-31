import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:roamio/features/banners/data/banner_service.dart';

class FirebaseBannerService implements BannerService {
  new(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<BannerPhoto?> bannerFor(String countryCode) async {
    try {
      final cached = await _db.doc('banners/$countryCode').get();
      final data = cached.exists
          ? cached.data()!
          : Map<String, dynamic>.from(
              (await _functions.httpsCallable('getBanner').call<Object?>({
                        'countryCode': countryCode,
                      })).data
                      as Map? ??
                  const {},
            );
      // The function's answer isn't kept on the phone; reading the record it
      // wrote is what makes this banner available offline next time.
      if (!cached.exists) {
        unawaited(
          _db
              .doc('banners/$countryCode')
              .get()
              .then<void>((_) {})
              .catchError((Object _) {}),
        );
      }
      final url = data['url'] as String?;
      if (url == null) return null;
      return BannerPhoto(
        url: url,
        photographer: data['photographer'] as String,
        photographerUrl: data['photographerUrl'] as String,
      );
    } on FirebaseException {
      return null; // offline or not allowed yet: the fallback is fine
    }
  }
}
