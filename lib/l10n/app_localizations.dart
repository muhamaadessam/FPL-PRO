import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];
  static const localizationsDelegates = <LocalizationsDelegate<Object>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  bool get isArabic => locale.languageCode == 'ar';

  String get appName => isArabic ? 'فانتازي PL' : 'Fantasy PL';
  String get loginTitle => isArabic ? 'ادخل على فريقك' : 'Open your team';
  String get loginSubtitle => isArabic
      ? 'افتح فريقك برقم الفريق وشاهد التشكيلة والنقاط والمباريات الرسمية.'
      : 'Open your team by its entry ID and view official picks, points, and fixtures.';
  String get officialSignIn =>
      isArabic ? 'تسجيل الدخول الرسمي' : 'Sign in officially';
  String get officialWebViewHint => isArabic
      ? 'ستفتح صفحة Premier League الرسمية داخل التطبيق لإدخال بياناتك بأمان.'
      : 'The official Premier League sign-in page opens inside the app.';
  String get configurationRequired => isArabic
      ? 'يلزم تسجيل OAuth رسمي للتطبيق قبل تفعيل الدخول.'
      : 'An approved OAuth client and mobile redirect URI are required first.';
  String get entryId => isArabic ? 'رقم الفريق' : 'Team entry ID';
  String get entryIdHint => isArabic ? 'مثال: 1234567' : 'Example: 1234567';
  String get entryIdInvalid =>
      isArabic ? 'اكتب رقم فريق صحيحًا.' : 'Enter a valid team entry ID.';
  String get openTeam => isArabic ? 'فتح فريقي' : 'Open my team';
  String get loginCancelled =>
      isArabic ? 'تم إلغاء تسجيل الدخول.' : 'Sign-in was cancelled.';
  String get invalidCallback => isArabic
      ? 'تعذر إكمال الرجوع من صفحة الدخول الرسمية.'
      : 'The official sign-in callback was invalid.';
  String get providerRejected => isArabic
      ? 'مزود الدخول رفض الطلب. تأكد من إعداد رابط الرجوع الرسمي.'
      : 'The sign-in provider rejected the request. Check the registered redirect URI.';
  String get tokenExchangeFailed => isArabic
      ? 'تعذر استبدال رمز الدخول بجلسة رسمية.'
      : 'The authorization code could not be exchanged for an official session.';
  String get sessionMissing => isArabic
      ? 'تم الدخول لكن لم يتم استلام جلسة صالحة.'
      : 'Login succeeded without a usable session.';
  String get publicPreview =>
      isArabic ? 'تصفح المباريات العامة' : 'Browse public matches';
  String get publicPreviewSubtitle => isArabic
      ? 'اعرض بيانات المباريات الرسمية بدون تسجيل دخول.'
      : 'View official fixture data without signing in.';
  String get matches => isArabic ? 'المباريات' : 'Matches';
  String matchesCount(int count) =>
      isArabic ? '$count مباريات' : '$count matches';
  String get homeTeam => isArabic ? 'صاحب الأرض' : 'Home';
  String get awayTeam => isArabic ? 'الضيف' : 'Away';
  String get matchDetails => isArabic ? 'تفاصيل المباراة' : 'Match details';
  String get goals => isArabic ? 'الأهداف' : 'Goals';
  String get assists => isArabic ? 'التمريرات الحاسمة' : 'Assists';
  String get ownGoals => isArabic ? 'أهداف عكسية' : 'Own goals';
  String get penaltiesSaved =>
      isArabic ? 'ركلات جزاء مُنقذة' : 'Penalties saved';
  String get penaltiesMissed =>
      isArabic ? 'ركلات جزاء ضائعة' : 'Penalties missed';
  String get yellowCards => isArabic ? 'بطاقات صفراء' : 'Yellow cards';
  String get redCards => isArabic ? 'بطاقات حمراء' : 'Red cards';
  String get saves => isArabic ? 'التصديات' : 'Saves';
  String get defensiveContribution =>
      isArabic ? 'المساهمة الدفاعية' : 'Defensive contribution';
  String get bonusPoints => isArabic ? 'نقاط البونص' : 'Bonus points';
  String pointImpact(int value) => isArabic
      ? '${value > 0 ? '+' : ''}$value نقطة'
      : '${value > 0 ? '+' : ''}$value pts';
  String get noMatchEvents =>
      isArabic ? 'لا توجد أحداث مسجلة بعد.' : 'No player events recorded yet.';
  String playerName(int id) => isArabic ? 'لاعب $id' : 'Player $id';
  String get myTeam => isArabic ? 'فريقي' : 'My Team';
  String get currentGameweek =>
      isArabic ? 'الأسبوع الحالي' : 'Current gameweek';
  String get gameweek => isArabic ? 'الأسبوع' : 'Gameweek';
  String get teamOverview => isArabic ? 'ملخص الفريق' : 'Team overview';
  String get startingXi => isArabic ? 'التشكيلة الأساسية' : 'Starting XI';
  String get bench => isArabic ? 'البدلاء' : 'Bench';
  String get captain => isArabic ? 'القائد' : 'Captain';
  String get viceCaptain => isArabic ? 'نائب القائد' : 'Vice captain';
  String get points => isArabic ? 'النقاط' : 'Points';
  String get averageScore => isArabic ? 'المتوسط' : 'Avg';
  String get highestScore => isArabic ? 'الأعلى' : 'Highest';
  String get ptsCue => isArabic ? 'نقطة' : 'PTS';
  String get totalPoints => isArabic ? 'الإجمالي' : 'Total points';
  String get kickoff => isArabic ? 'موعد البداية' : 'Kick-off';
  String get finalScore => isArabic ? 'النهاية' : 'Full time';
  String get notStarted => isArabic ? 'لم تبدأ' : 'Not started';
  String get fixtureFinished => isArabic ? 'انتهت' : 'Finished';
  String get fixtureLive => isArabic ? 'مباشر' : 'Live';
  String get fixtureUpcoming => isArabic ? 'قادمة' : 'Upcoming';
  String get noFixtures => isArabic ? 'لا توجد مباريات' : 'No fixtures found';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Sign out';
  String get language => isArabic ? 'English' : 'العربية';
  String get authContractRequired => isArabic
      ? 'بيانات الفريق الخاص تحتاج جلسة من المصادقة الرسمية.'
      : 'Private team data needs an official authenticated session.';
  String get entryIdMissing => isArabic
      ? 'لم يتم إرجاع رقم الفريق من عقد المصادقة.'
      : 'The authentication contract did not return a team id.';
  String get genericError => isArabic
      ? 'حصل خطأ غير متوقع. حاول مرة أخرى.'
      : 'Something went wrong. Please try again.';
  String get networkError => isArabic
      ? 'تعذر الاتصال بالبيانات الرسمية.'
      : 'Could not reach the official data service.';
  String get authExpired => isArabic
      ? 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.'
      : 'Your session expired. Please sign in again.';
  String get rateLimited => isArabic
      ? 'الطلبات كثيرة حاليًا. انتظر قليلًا ثم حاول.'
      : 'Too many requests right now. Wait a moment and try again.';
  String get appDescription => isArabic
      ? 'بيانات رسمية، بدون تعديلات على فريقك.'
      : 'Official data, with no changes to your team.';
  String get pitchView => isArabic ? 'الملعب' : 'Pitch view';
  String get listView => isArabic ? 'القائمة' : 'List view';
  String get recommendations => isArabic ? 'الترشيحات' : 'Recommendations';
  String get recommendationSubtitle => isArabic
      ? 'تقديرات مبنية على الإحصائيات الرسمية والمباريات القادمة.'
      : 'Estimates based on official stats and upcoming fixtures.';
  String get nextGameweekAnalysis =>
      isArabic ? 'تحليل الجولة القادمة' : 'Next Gameweek Analysis';
  String get nextGameweekAnalysisSubtitle => isArabic
      ? 'تقييم التشكيلة واللاعبين من واقع الموسم والمباريات القادمة.'
      : 'Squad and player ratings from season form and upcoming fixtures.';
  String get squadRating => isArabic ? 'تقييم التشكيلة' : 'Squad rating';
  String ratingOutOf100(int rating) => '$rating/100';
  String get expectedStartingPoints =>
      isArabic ? 'متوقع الأساسيين' : 'Starting XI forecast';
  String get expectedBenchPoints => isArabic ? 'متوقع الدكة' : 'Bench forecast';
  String get averagePlayerRating =>
      isArabic ? 'متوسط تقييم الأساسيين' : 'Starting XI average';
  String get bestLegalLineup =>
      isArabic ? 'أفضل تشكيلة قانونية' : 'Best legal XI';
  String get selectionEfficiency =>
      isArabic ? 'كفاءة اختيار الأساسيين' : 'Selection efficiency';
  String get currentForm => isArabic ? 'آخر المباريات' : 'Recent form';
  String get seasonAverage => isArabic ? 'متوسط الموسم' : 'Season average';
  String get previousSeason => isArabic ? 'الموسم السابق' : 'Previous season';
  String get fixtureRating => isArabic ? 'سهولة المباراة' : 'Fixture rating';
  String get reliability => isArabic ? 'ثبات المشاركة' : 'Minutes reliability';
  String get ratingMethod =>
      isArabic ? 'كيف اتحسب التقييم؟' : 'How is this rated?';
  String get ratingMethodDescription => isArabic
      ? 'التقييم يجمع توقع الجولة، آخر 6 مباريات، متوسط الموسم، الأرقام المتوقعة، صعوبة الخصم، الجاهزية وثبات الدقائق. الموسم السابق وزنه 5% فقط عند توفره.'
      : 'The rating combines the next-Gameweek forecast, last six matches, season average, underlying numbers, fixture difficulty, availability and minutes reliability. Previous-season data carries only 5% when available.';
  String get analysisDisclaimer => isArabic
      ? 'التقييم تقديري وليس ضمانًا. أخبار الإصابات والتشكيل قبل الموعد النهائي تظل أهم تحديث.'
      : 'Ratings are estimates, not guarantees. Recheck injuries and line-ups before the deadline.';
  String analysisCoverage(int current, int previous, int total) => isArabic
      ? 'تاريخ الموسم متاح لـ$current من $total لاعب • موسم سابق لـ$previous'
      : 'Current-season history for $current of $total players • previous season for $previous';
  String get rising => isArabic ? 'صاعد' : 'Rising';
  String get steady => isArabic ? 'ثابت' : 'Steady';
  String get falling => isArabic ? 'متراجع' : 'Falling';
  String get homeShort => isArabic ? 'د' : 'H';
  String get awayShort => isArabic ? 'خ' : 'A';
  String get noPreviousSeason => isArabic ? 'غير متاح' : 'Not available';
  String ratingBand(int rating) {
    if (rating >= 85) return isArabic ? 'ممتازة' : 'Excellent';
    if (rating >= 75) return isArabic ? 'قوية' : 'Strong';
    if (rating >= 65) return isArabic ? 'جيدة' : 'Competitive';
    if (rating >= 50) return isArabic ? 'تحتاج تحسين' : 'Needs work';
    return isArabic ? 'مخاطرة عالية' : 'High risk';
  }

  String get captainPick => isArabic ? 'اختيار الكابتن' : 'Captain pick';
  String get transferIdeas => isArabic ? 'اقتراحات التبديل' : 'Transfer ideas';
  String get compareTransfer =>
      isArabic ? 'مقارنة التبديل' : 'Compare transfer';
  String get transferOut => isArabic ? 'خارج' : 'Out';
  String get transferIn => isArabic ? 'داخل' : 'In';
  String get projectedPoints =>
      isArabic ? 'النقاط المتوقعة' : 'Projected points';
  String get nextFixtures => isArabic ? 'المباريات القادمة' : 'Next fixtures';
  String get availability => isArabic ? 'الجاهزية' : 'Availability';
  String get unknown => isArabic ? 'غير معروف' : 'Unknown';
  String get news => isArabic ? 'الأخبار' : 'News';
  String get noNews => isArabic ? 'لا توجد أخبار' : 'No news';
  String get confirmTransfer => isArabic ? 'تأكيد التبديل' : 'Confirm transfer';
  String get selected => isArabic ? 'تم الاختيار' : 'Selected';
  String get transferSubmitted =>
      isArabic ? 'تم إرسال التبديل' : 'Transfer submitted';
  String get actionPlanHint => isArabic
      ? 'اضغط على الاقتراح لمراجعة التفاصيل قبل التنفيذ.'
      : 'Tap a suggestion to review it before submitting.';
  String get confirmChip => isArabic ? 'تفعيل الـChip' : 'Activate chip';
  String chipSelection(String chip) =>
      isArabic ? 'اختيار $chip' : 'Select $chip';
  String get chipSubmitted => isArabic ? 'تم تفعيل الـChip' : 'Chip submitted';
  String get writeAuthRequired => isArabic
      ? 'أعد تسجيل الدخول لتفعيل التغييرات على الفريق.'
      : 'Sign in again to submit team changes.';
  String get topPicks => isArabic ? 'أفضل الاختيارات' : 'Top picks';
  String get chipAdvice => isArabic ? 'قرار الـChip' : 'Chip decision';
  String get noChip => isArabic ? 'بدون Chip' : 'No chip';
  String get projected => isArabic ? 'متوقع' : 'Projected';
  String get projectedGain =>
      isArabic ? 'مكسب متوقع لـ3 جولات' : 'Projected 3-GW gain';
  String get freeTransfers => isArabic ? 'تبديلات مجانية' : 'Free transfers';
  String get bank => isArabic ? 'البنك' : 'Bank';
  String get afterHit => isArabic ? 'بعد خصم الـhit' : 'after hit';
  String get noTransferIdeas => isArabic
      ? 'لا يوجد تبديل واضح يستحق المخاطرة حاليًا.'
      : 'No clear transfer is worth the risk right now.';
  String get recommendationDisclaimer => isArabic
      ? 'دي تقديرات وليست ضمانًا؛ راجع أخبار الإصابات والتشكيل قبل الـdeadline.'
      : 'These are estimates, not guarantees. Recheck injuries and line-ups before the deadline.';
  String get goalkeeper => isArabic ? 'حراس المرمى' : 'Goalkeepers';
  String get defender => isArabic ? 'المدافعون' : 'Defenders';
  String get midfielder => isArabic ? 'لاعبو الوسط' : 'Midfielders';
  String get forward => isArabic ? 'المهاجمون' : 'Forwards';

  String positionName(int id) => switch (id) {
    1 => goalkeeper,
    2 => defender,
    3 => midfielder,
    _ => forward,
  };

  String chipName(String chip) => switch (chip) {
    'wildcard' => isArabic ? 'Wildcard' : 'Wildcard',
    'freeHit' => isArabic ? 'Free Hit' : 'Free Hit',
    'benchBoost' => isArabic ? 'Bench Boost' : 'Bench Boost',
    'tripleCaptain' => isArabic ? 'Triple Captain' : 'Triple Captain',
    'freehit' => isArabic ? 'Free Hit' : 'Free Hit',
    'bboost' => isArabic ? 'Bench Boost' : 'Bench Boost',
    '3xc' => isArabic ? 'Triple Captain' : 'Triple Captain',
    _ => noChip,
  };

  String chipReason(String reason) => switch (reason) {
    'availabilityUnknown' =>
      isArabic
          ? 'حالة الـchips لم ترجع من الحساب؛ راجع الصفحة الرسمية قبل الاستخدام.'
          : 'Chip availability was not returned; verify it on the official page.',
    'missingStarters' =>
      isArabic
          ? 'عدد كبير من الأساسيين بدون مباراة أو مشاركتهم غير مؤكدة.'
          : 'Several starters have no fixture or a major availability risk.',
    'squadOverhaul' =>
      isArabic
          ? 'الفريق محتاج تغييرات متعددة لعدة جولات، وليس تبديلًا واحدًا.'
          : 'The squad needs several multi-week changes, not one transfer.',
    'strongBench' =>
      isArabic
          ? 'الدكة كلها متاحة وتوقع نقاطها مرتفع.'
          : 'All four bench players are available with a strong projection.',
    'captainCeiling' =>
      isArabic
          ? 'أفضل كابتن عنده توقع مرتفع وفرصة مشاركة قوية.'
          : 'The leading captain has a high projection and strong start chance.',
    _ =>
      isArabic
          ? 'لا توجد أفضلية قوية لاستخدام Chip الآن؛ الاحتفاظ بها أفضل.'
          : 'There is no strong chip edge this week; holding is preferred.',
  };

  String gameweekLabel(int id) => '${isArabic ? 'الأسبوع' : 'Gameweek'} $id';

  String pointsLabel(int value) => '$value $points';

  String kickoffLabel(DateTime? dateTime) {
    if (dateTime == null) return kickoff;
    final local = dateTime.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} • ${local.hour}:$minute';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(isSupported(locale) ? locale : const Locale('en'));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
