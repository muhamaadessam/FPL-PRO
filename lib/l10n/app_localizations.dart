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

  String get appName => isArabic ? 'FPL Pro' : 'FPL Pro';
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
  String get leagues => isArabic ? 'الليجات' : 'Leagues';
  String get leaguesSubtitle => isArabic
      ? 'كل الليجات اللي فريقك مشترك فيها وترتيبك الحالي.'
      : 'Every league your team has joined, with live ranks.';
  String get invitationClassicLeagues =>
      isArabic ? 'ليجات كلاسيك بالدعوة' : 'Invitational Classic Leagues';
  String get generalLeagues => isArabic ? 'الليجات العامة' : 'General Leagues';
  String get broadcasterLeagues =>
      isArabic ? 'ليجات المذيعين' : 'Broadcaster Leagues';
  String get publicClassicLeagues =>
      isArabic ? 'ليجات كلاسيك العامة' : 'Public Classic Leagues';
  String get invitationHeadToHeadLeagues =>
      isArabic ? 'ليجات مواجهة بالدعوة' : 'Invitational Head-to-Head Leagues';
  String get publicHeadToHeadLeagues =>
      isArabic ? 'ليجات مواجهة عامة' : 'Public Head-to-Head Leagues';
  String get league => isArabic ? 'الليجة' : 'League';
  String leagueName(int id) => isArabic ? 'ليجة $id' : 'League $id';
  String managerCount(String count) =>
      isArabic ? '$count مدير' : '$count managers';
  String get fplManager => isArabic ? 'مدير FPL' : 'FPL Manager';
  String get currentRank => isArabic ? 'الترتيب الحالي' : 'Current rank';
  String get lastRank => isArabic ? 'الترتيب السابق' : 'Last rank';
  String get leagueDetails => isArabic ? 'تفاصيل الليجة' : 'League details';
  String get standings => isArabic ? 'الترتيب' : 'Standings';
  String get manager => isArabic ? 'المدير' : 'Manager';
  String get gameweekPointsShort => isArabic ? 'الجولة' : 'GW';
  String get totalPointsShort => isArabic ? 'الإجمالي' : 'Total';
  String get classicScoring => isArabic ? 'كلاسيك' : 'Classic';
  String get headToHeadScoring => isArabic ? 'مواجهة' : 'Head-to-head';
  String get you => isArabic ? 'أنت' : 'You';
  String get noStandings =>
      isArabic ? 'لا يوجد ترتيب متاح' : 'No standings available';
  String get noStandingsHint => isArabic
      ? 'الخدمة الرسمية لم ترجع لاعبين لهذه الليجة.'
      : 'The official service returned no managers for this league.';
  String leagueCount(int count) => isArabic ? '$count ليجات' : '$count leagues';
  String get noLeagues => isArabic ? 'لا توجد ليجات بعد' : 'No leagues yet';
  String get noLeaguesHint => isArabic
      ? 'لم ترجع بيانات الليجات من الخدمة الرسمية.'
      : 'The official service returned no league data.';
  String get rankImproved => isArabic ? 'الترتيب اتحسن' : 'Rank improved';
  String get rankDropped => isArabic ? 'الترتيب اتراجع' : 'Rank dropped';
  String get rankUnchanged => isArabic ? 'الترتيب ثابت' : 'Rank unchanged';
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
  String get cleanSheets => isArabic ? 'الشباك النظيفة' : 'Clean sheets';
  String get defensiveContribution =>
      isArabic ? 'المساهمة الدفاعية' : 'Defensive contribution';
  String get bonusPoints => isArabic ? 'نقاط البونص' : 'Bonus points';
  String pointImpact(int value) => isArabic
      ? '${value > 0 ? '+' : ''}$value نقطة'
      : '${value > 0 ? '+' : ''}$value pts';
  String get noMatchEvents =>
      isArabic ? 'لا توجد أحداث مسجلة بعد.' : 'No player events recorded yet.';
  String get matchPrediction => isArabic ? 'توقع المباراة' : 'Match prediction';
  String get predictedScore =>
      isArabic ? 'النتيجة المتوقعة' : 'Predicted score';
  String get likelyScorers =>
      isArabic ? 'الأقرب للتسجيل' : 'Most likely scorers';
  String get likelyAssists =>
      isArabic ? 'الأقرب لصناعة هدف' : 'Most likely assists';
  String get cleanSheetChance =>
      isArabic ? 'فرصة الشباك النظيفة' : 'Clean-sheet chance';
  String predictionConfidence(int value) =>
      isArabic ? 'ثقة $value٪' : '$value% confidence';
  String get predictionDisclaimer => isArabic
      ? 'توقع إحصائي مبني على xG وxA والفورمة والدقائق وصعوبة المباراة؛ وليس ضمانًا للنتيجة الفعلية.'
      : 'Statistical estimate using xG, xA, form, minutes and fixture difficulty; it is not a guarantee.';
  String get predictionWindowHint => isArabic
      ? 'التوقعات متاحة لمباريات الجولات الثلاث القادمة.'
      : 'Predictions are available for fixtures in the next three gameweeks.';
  String get notEnoughPredictionData => isArabic
      ? 'لا توجد بيانات كافية لتحديد لاعب.'
      : 'Not enough data to name a player.';
  String playerName(int id) => isArabic ? 'لاعب $id' : 'Player $id';
  String get myTeam => isArabic ? 'فريقي' : 'My Team';
  String get currentGameweek =>
      isArabic ? 'الأسبوع الحالي' : 'Current gameweek';
  String get gameweek => isArabic ? 'الأسبوع' : 'Gameweek';
  String get previousGameweek =>
      isArabic ? 'الأسبوع السابق' : 'Previous gameweek';
  String get nextGameweek => isArabic ? 'الأسبوع التالي' : 'Next gameweek';
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
  String get loadingData =>
      isArabic ? 'جاري تحميل البيانات...' : 'Loading data...';
  String get errorLoadingData =>
      isArabic ? 'فشل تحميل البيانات' : 'Failed to load data';
  String get authenticating =>
      isArabic ? 'جاري التحقق من الهوية...' : 'Authenticating...';
  String get themeSystem => isArabic ? 'تلقائي' : 'System';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get themeDark => isArabic ? 'داكن' : 'Dark';
  String get themeTitle => isArabic ? 'المظهر' : 'Theme';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
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
  String get tips => isArabic ? 'نصائح' : 'Tips';
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
  String get playerDirectory => isArabic ? 'كل اللاعبين' : 'All players';
  String get playerDirectorySubtitle => isArabic
      ? 'ابحث في كل اللاعبين وقارن بينهم قبل الجولة القادمة.'
      : 'Search every player and compare them before the next gameweek.';
  String get comparePlayers => isArabic ? 'مقارنة اللاعبين' : 'Compare players';
  String get samePositionAlternatives => isArabic
      ? 'اختار لاعبًا آخر من نفس المركز للمقارنة.'
      : 'Choose another player from the same position to compare.';
  String get searchPlayersHint =>
      isArabic ? 'ابحث باسم اللاعب أو الفريق' : 'Search by player or team';
  String get allPositions => isArabic ? 'كل المراكز' : 'All positions';
  String get allTeams => isArabic ? 'كل الفرق' : 'All teams';
  String get compareSelected =>
      isArabic ? 'قارن المختارين' : 'Compare selected';
  String get selectOneMorePlayer => isArabic
      ? 'اختار لاعبًا آخر للمقارنة'
      : 'Select one more player to compare';
  String get maxTwoPlayers =>
      isArabic ? 'المقارنة بين لاعبين فقط' : 'Compare two players at a time';
  String get expectedNextGameweekPoints =>
      isArabic ? 'المتوقع في الجولة القادمة' : 'Expected next GW points';
  String get projectedThreeGameweeks =>
      isArabic ? 'المتوقع لـ3 جولات' : 'Projected 3-GW points';
  String get fixtureDifficulty =>
      isArabic ? 'صعوبة المباريات' : 'Fixture difficulty';
  String get playerPrice => isArabic ? 'السعر' : 'Price';
  String get selectedBy => isArabic ? 'نسبة الاختيار' : 'Selected by';
  String get minutesPlayed => isArabic ? 'الدقائق' : 'Minutes';
  String get starts => isArabic ? 'بدأ أساسيًا' : 'Starts';
  String get expectedGoalInvolvements => isArabic ? 'xGI' : 'xGI';
  String get expectedGoalsConceded => isArabic ? 'xGC' : 'xGC';
  String get noPlayersFound =>
      isArabic ? 'لا يوجد لاعبون مطابقون' : 'No matching players';
  String get comparisonDisclaimer => isArabic
      ? 'التوقعات تقديرية مبنية على الإحصائيات الرسمية وليست ضمانًا.'
      : 'Projections use official statistics and are not guarantees.';
  String get compareData => isArabic ? 'بيانات المقارنة' : 'Comparison data';
  String get nextGameweekAlerts =>
      isArabic ? 'تنبيهات الجولة القادمة' : 'Next gameweek alerts';
  String get nextGameweekAlertsSubtitle => isArabic
      ? 'لاعبون من فريقك قد لا يشاركوا الجولة القادمة'
      : 'Players in your squad who may miss the next gameweek';
  String get injured => isArabic ? 'مصاب' : 'Injured';
  String get suspended => isArabic ? 'موقوف' : 'Suspended';
  String get doubtful => isArabic ? 'مشكوك في مشاركته' : 'Doubtful';
  String get unavailable => isArabic ? 'غير متاح' : 'Unavailable';
  String chanceOfPlaying(int chance) =>
      isArabic ? '$chance٪ احتمال المشاركة' : '$chance% chance of playing';
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
  String get invalidFormation => isArabic
      ? 'التشكيلة لازم تضم حارس واحد، و3-5 مدافعين، و2-5 لاعبي وسط، و1-3 مهاجمين.'
      : 'Use 1 goalkeeper, 3-5 defenders, 2-5 midfielders, and 1-3 forwards.';
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

  String kickoffTimeOnly(DateTime? dateTime) {
    if (dateTime == null) return kickoff;
    final local = dateTime.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.hour}:$minute';
  }

  String matchDayHeader(DateTime? dateTime) {
    if (dateTime == null) return isArabic ? 'يحدد لاحقاً' : 'To be decided';
    final local = dateTime.toLocal();
    final weekday = _weekdayName(local.weekday);
    final month = _monthName(local.month);
    return '$weekday ${local.day} $month';
  }

  String _weekdayName(int weekday) {
    if (isArabic) {
      return switch (weekday) {
        DateTime.monday => 'الاثنين',
        DateTime.tuesday => 'الثلاثاء',
        DateTime.wednesday => 'الأربعاء',
        DateTime.thursday => 'الخميس',
        DateTime.friday => 'الجمعة',
        DateTime.saturday => 'السبت',
        DateTime.sunday => 'الأحد',
        _ => '',
      };
    }
    return switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => '',
    };
  }

  String _monthName(int month) {
    if (isArabic) {
      return switch (month) {
        1 => 'يناير',
        2 => 'فبراير',
        3 => 'مارس',
        4 => 'أبريل',
        5 => 'مايو',
        6 => 'يونيو',
        7 => 'يوليو',
        8 => 'أغسطس',
        9 => 'سبتمبر',
        10 => 'أكتوبر',
        11 => 'نوفمبر',
        12 => 'ديسمبر',
        _ => '',
      };
    }
    return switch (month) {
      1 => 'January',
      2 => 'February',
      3 => 'March',
      4 => 'April',
      5 => 'May',
      6 => 'June',
      7 => 'July',
      8 => 'August',
      9 => 'September',
      10 => 'October',
      11 => 'November',
      12 => 'December',
      _ => '',
    };
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
