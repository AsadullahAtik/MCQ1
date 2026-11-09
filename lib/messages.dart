/// Bengali texts for the error codes the server sends (same wording as the web app).
const _messages = <String, String>{
  'INVALID_CREDENTIALS': 'প্রতিষ্ঠান কোড, রোল বা পাসওয়ার্ড ঠিক নয়',
  'TOO_MANY_ATTEMPTS': 'অনেকবার ভুল চেষ্টা হয়েছে। কিছুক্ষণ (প্রায় ১০ মিনিট) পরে আবার চেষ্টা করুন',
  'INSTITUTION_SUSPENDED': 'এই প্রতিষ্ঠানের অ্যাকাউন্ট বন্ধ করা আছে। প্ল্যাটফর্মের মালিকের সাথে যোগাযোগ করুন',
  'CURRENT_PASSWORD_WRONG': 'বর্তমান পাসওয়ার্ড ঠিক নয়',
  'PASSWORD_TOO_SHORT': 'পাসওয়ার্ড অন্তত ৪ অক্ষরের হতে হবে',
  'PASSWORD_TOO_LONG': 'পাসওয়ার্ড খুব বড়',
  'PASSWORD_UNCHANGED': 'নতুন পাসওয়ার্ড বর্তমানটির থেকে আলাদা হতে হবে',
  'EXAM_NOT_FOUND': 'পরীক্ষাটি পাওয়া যায়নি',
  'ALREADY_SUBMITTED': 'এই পরীক্ষা আপনি আগেই দিয়েছেন',
  'NOT_OPEN_YET': 'পরীক্ষা এখনও শুরু হয়নি',
  'WINDOW_CLOSED': 'পরীক্ষার সময় শেষ হয়ে গেছে',
  'TIME_UP': 'সময় শেষ হয়ে গেছে',
  'NOT_SUPPORTED_ROLE': 'এই অ্যাকাউন্ট অ্যাপে চলে না। প্ল্যাটফর্ম মালিক ওয়েবসাইট ব্যবহার করুন',
  'CLASS_EXISTS': 'এই নামে শ্রেণি আগেই আছে',
  'SECTION_EXISTS': 'এই নামে শাখা আগেই আছে',
  'ROLL_TAKEN': 'এই রোল আগেই ব্যবহার হয়েছে',
  'ROLL_INVALID': 'রোল ২–৮ অঙ্কের সংখ্যা হতে হবে',
  'PHONE_INVALID': 'ফোন নম্বর ৬–১৫ অঙ্কের হতে হবে',
  'LOGIN_ID_INVALID': 'লগইন আইডি ৩–২০ অক্ষরের: ইংরেজি অক্ষর, সংখ্যা, ডট, ড্যাশ বা আন্ডারস্কোর',
  'LOGIN_ID_TAKEN': 'এই লগইন আইডি আগেই ব্যবহার হয়েছে',
  'CANNOT_DELETE_SELF': 'নিজের অ্যাকাউন্ট মোছা যায় না',
  'CANNOT_CHANGE_SELF': 'নিজের ভূমিকা নিজে বদলানো যায় না',
  'USE_ACCOUNT_PAGE': 'নিজের পাসওয়ার্ড বদলাতে প্রোফাইল পেজ ব্যবহার করুন',
  'EXAM_PUBLISHED': 'ফলাফল প্রকাশ হয়ে গেছে, এটা আর বদলানো যাবে না',
  'EXAM_HAS_ATTEMPTS': 'শিক্ষার্থীরা পরীক্ষা দিয়ে ফেলেছে, তাই এটা আর বদলানো বা মোছা যাবে না',
  'FORBIDDEN': 'এই কাজের অনুমতি আপনার নেই',
  'NETWORK': 'সার্ভারের সাথে যোগাযোগ করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন',
};

String errorMessage(Object error) {
  if (error is ApiException) {
    return _messages[error.code] ?? 'কিছু একটা ভুল হয়েছে (${error.code})';
  }
  return _messages['NETWORK']!;
}

class ApiException implements Exception {
  ApiException(this.status, this.code, {this.detail});
  final int status;
  final String code;

  /// The technical reason (for example "Connection refused"), shown small under the message so a failure can be diagnosed.
  final String? detail;

  @override
  String toString() => 'ApiException($status, $code)';
}
