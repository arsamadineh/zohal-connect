// l10n/strings_fa.dart
// Complete Persian copy for Zohal Connect according to ZOHAL_SPEC Section 14.
// Strict rules: No emoji, no em-dash/en-dash, Persian only except technical proper nouns in LTR isolates.

class StringsFa {
  StringsFa._();

  // App Names
  static const String appName = 'زحل';
  static const String appFullName = 'Zohal Connect | قندشکن زحل';
  static const String appDescription = 'قندشکن زحل';

  // Glossary & Common Actions
  static const String connect = 'اتصال';
  static const String disconnect = 'قطع اتصال';
  static const String connectionMethod = 'روش اتصال';
  static const String routing = 'مسیریابی';
  static const String smart = 'هوشمند';
  static const String custom = 'سفارشی';
  static const String direct = 'مستقیم';
  static const String block = 'مسدود';
  static const String rule = 'قانون';
  static const String appSingular = 'برنامه';
  static const String appPlural = 'برنامهها';
  static const String settings = 'تنظیمات';
  static const String logs = 'گزارشها';
  static const String about = 'درباره';
  static const String gateway = 'دروازه';
  static const String tunnel = 'تونل';
  static const String killSwitch = 'قفل ایمنی';
  static const String download = 'دریافت';
  static const String upload = 'ارسال';
  static const String duration = 'مدت اتصال';
  static const String exitAddress = 'نشانی خروجی';
  static const String exitLocation = 'محل خروج';
  static const String service = 'سرویس';
  static const String permission = 'دسترسی';
  static const String retry = 'تلاش دوباره';
  static const String copy = 'کپی';
  static const String add = 'افزودن';
  static const String remove = 'حذف';
  static const String cancel = 'لغو';
  static const String confirm = 'تأیید';
  static const String later = 'بعداً';
  static const String continueAction = 'ادامه';
  static const String close = 'بستن';
  static const String skip = 'رد کردن';
  static const String search = 'جستجو';

  // States
  static const String stateIdle = 'قطع است';
  static const String statePreparing = 'آمادهسازی';
  static const String stateConnecting = 'در حال اتصال';
  static const String stateConnected = 'متصل است';
  static const String stateReconnecting = 'اتصال دوباره';
  static const String stateDisconnecting = 'در حال قطع';
  static const String stateFailed = 'اتصال برقرار نشد';

  // Hints
  static const String hintTouch = 'برای اتصال لمس کنید';
  static const String hintClick = 'برای اتصال کلیک کنید';
  static const String hintCancelConfirm = 'برای لغو دوباره بزنید';

  // Stages
  static const String stagePrepare = 'آمادهسازی';
  static const String stageFindGateway = 'یافتن دروازه';
  static const String stageBuildTunnel = 'ساخت تونل';
  static const String stageVerifyPath = 'بررسی مسیر';

  // Modes & Transports
  static const String modeAutoTitle = 'خودکار';
  static const String modeAutoDesc =
      'بهترین روش را خودکار پیدا میکند و در صورت قطع، روش دیگری را امتحان میکند.';

  static const String modeMasque3Title = 'MASQUE (HTTP/3)';
  static const String modeMasque3Desc = 'سریع‌ترین روش؛ مناسب بیشتر شبکه‌ها.';

  static const String modeMasque2Title = 'MASQUE (HTTP/2)';
  static const String modeMasque2Desc =
      'برای شبکه‌هایی که UDP را مسدود یا کند می‌کنند.';

  static const String modeWireguardTitle = 'WireGuard';
  static const String modeWireguardDesc =
      'سبک و بسیار سریع؛ مناسب شبکه‌های کم‌محدودیت.';

  static const String modeGoolTitle = 'Gool';
  static const String modeGoolDesc =
      'دو لایه رمزنگاری؛ آخرین راه برای شبکه‌های سخت‌گیر.';

  static const String scopeTun = 'کل سیستم (TUN)';
  static const String scopeProxy = 'پراکسی سیستم';

  // Rule Types
  static const String ruleTypeDomain = 'دامنه (و زیردامنهها)';
  static const String ruleTypeDomainExact = 'دامنه دقیق';
  static const String ruleTypeKeyword = 'شامل کلمه';
  static const String ruleTypeRegex = 'عبارت منظم';
  static const String ruleTypeIpCidr = 'نشانی IP یا شبکه';
  static const String ruleTypePort = 'درگاه';

  // Toasts
  static const String toastCopied = 'کپی شد';
  static const String toastSaved = 'ذخیره شد';
  static const String toastModeChanged =
      'روش اتصال تغییر کرد؛ اتصال دوباره برقرار میشود';
  static const String toastDirectInternet =
      'اتصال قطع شد؛ اینترنت مستقیم فعال است';

  // Dialogs
  static const String dialogCancelConnectTitle = 'لغو اتصال؟';
  static const String dialogCancelConnectBody =
      'اتصال هنوز برقرار نشده است. اگر لغو کنید، فرایند از ابتدا شروع میشود.';
  static const String dialogCancelConnectContinue = 'ادامه اتصال';
  static const String dialogCancelConnectCancel = 'لغو';

  static const String dialogExitTitle = 'خروج از برنامه؟';
  static const String dialogExitBody = 'اتصال فعال میماند.';
  static const String dialogExitLeave = 'خروج از برنامه';
  static const String dialogExitDisconnectLeave = 'قطع و خروج';

  static const String dialogResetIdentityTitle = 'ثبت دوباره دستگاه؟';
  static const String dialogResetIdentityBody =
      'دستگاه با حساب جدیدی ثبت میشود. این کار چند ثانیه طول میکشد.';
  static const String dialogResetIdentityConfirm = 'تأیید';
  static const String dialogResetIdentityCancel = 'لغو';

  // Routing
  static const String routingSmartTitle = 'مسیریابی هوشمند';
  static const String routingSmartDesc =
      'سایتهای ایرانی (.ir) و شبکه محلی بدون عبور از فیلترشکن باز میشوند.';
  static const String routingLanTitle = 'شبکه محلی مستقیم';
  static const String routingLanDesc =
      'دستگاههای شبکه خانگی یا اداری مستقیم در دسترس باشند.';
  static const String routingDirectSection = 'مستقیم';
  static const String routingBlockSection = 'مسدود';
  static const String routingAppsSection = 'برنامهها';
  static const String routingAddRule = 'افزودن قانون';
  static const String routingRuleValue = 'مقدار قانون';
  static const String routingRuleType = 'نوع قانون';
  static const String routingAppModeAll = 'همه برنامهها';
  static const String routingAppModeOnly = 'فقط انتخابشدهها';
  static const String routingAppModeExcept = 'همه به جز انتخابشدهها';
  static const String routingDomainDirectWindowsNotice =
      'مسیریابی دامنهای در ویندوز پشتیبانی نمیشود؛ از نشانی IP استفاده کنید.';

  // Settings
  static const String settingsGroupConnection = 'اتصال';
  static const String settingsAutoLaunch = 'اتصال خودکار هنگام باز شدن';
  static const String settingsRestoreState = 'بازیابی آخرین وضعیت';
  static const String settingsAutoBoot = 'اتصال خودکار هنگام روشن شدن سیستم';
  static const String settingsKillSwitchDesc =
      'در صورت قطع تونل، ارتباط اینترنت تا اتصال مجدد مسدود میماند.';
  static const String settingsScope = 'دامنه اتصال';

  static const String settingsGroupSystem = 'سیستم';
  static const String settingsStartWithSystem = 'اجرای همراه سیستم';
  static const String settingsMinimizeToTray = 'کوچک شدن به ناحیه اعلان';
  static const String settingsVpnSystemSettings = 'تنظیمات VPN سیستم';

  static const String settingsGroupNetwork = 'شبکه';
  static const String settingsDnsServers = 'سرورهای DNS';
  static const String settingsIpVersion = 'نسخه پروتکل IP';

  static const String settingsGroupAdvanced = 'پیشرفته';
  static const String settingsAdvancedSection = 'پیشرفته';
  static const String settingsDiagnosticLog = 'گزارش تشخیصی';
  static const String settingsResetIdentity = 'ثبت دوباره دستگاه';
  static const String settingsScanProfile = 'پروفایل اسکن';
  static const String settingsNoiseProfile = 'پروفایل اختلال (Noise)';
  static const String settingsFragment = 'تکهتکهسازی بستهها (Fragment)';
  static const String settingsEch = 'رمزنگاری نام سرور (ECH)';
  static const String settingsExportDiagnostics = 'خروجی گزارش تشخیصی';
  static const String settingsCopyAll = 'کپی همه';

  // Logs
  static const String logsFilterAll = 'همه';
  static const String logsFilterErrors = 'خطاها';
  static const String logsEmpty = 'هیچ گزارشی ثبت نشده است.';

  // About
  static const String aboutSourceCode = 'کد منبع';
  static const String aboutOpenSourceLicenses = 'مجوزهای متنباز';
  static const String aboutCreditLine = 'بر پایه Aether';
  static const String aboutAgplNotice =
      'این نرمافزار آزاد است و تحت مجوز AGPL-3.0 منتشر میشود.';
  static const String aboutVersion = 'نسخه';
  static const String aboutEngineVersion = 'نسخه موتور';

  // Onboarding
  static const String onboardingIntro =
      'زحل ارتباط اینترنت را با گذر از موانع شبکه برقرار میکند.';
  static const String onboardingPermissionsTitle = 'دسترسیها';
  static const String onboardingVpnPermission = 'مجوز ایجاد اتصال امن (VPN)';
  static const String onboardingNotificationPermission =
      'مجوز نمایش اعلان وضعیت اتصال';
  static const String onboardingBatteryPermission =
      'معافیت از بهینهسازی باتری (جهت حفظ اتصال)';
  static const String onboardingServiceRunning = 'سرویس زحل فعال است.';
  static const String onboardingServiceNotRunning =
      'سرویس زحل نصب نیست یا اجرا نشده است.';
  static const String onboardingInstallService = 'نصب سرویس';
  static const String onboardingModeRecommend =
      'پیشنهاد ما خودکار است. بعداً هم میتوانید عوض کنید.';
  static const String onboardingFirstConnectTesting =
      'در حال ثبت دستگاه و آزمایش مسیر';
  static const String onboardingFirstConnectReady = 'آماده است';

  // Tray
  static const String trayShow = 'نمایش زحل';
  static const String trayExit = 'خروج';

  // Errors: E100 to E400
  static const Map<String, (String title, String hint)> errors = {
    'E100': ('اینترنت در دسترس نیست', 'اتصال شبکه دستگاه را بررسی کنید.'),
    'E110': (
      'ساعت دستگاه نادرست است',
      'تاریخ و ساعت را روی حالت خودکار بگذارید.',
    ),
    'E120': (
      'هیچ روشی موفق نبود',
      'چند دقیقه بعد دوباره امتحان کنید یا روش اتصال را دستی انتخاب کنید.',
    ),
    'E130': ('حساب دستگاه تازهسازی شد', 'اتصال دوباره برقرار میشود.'),
    'E140': (
      'ثبت دستگاه ممکن نشد',
      'شبکه دیگری را امتحان کنید؛ ثبت فقط یک بار لازم است.',
    ),
    'E200': (
      'سرویس زحل در دسترس نیست',
      'سرویس را راهاندازی کنید یا برنامه را دوباره نصب کنید.',
    ),
    'E210': (
      'ساخت رابط شبکه ناموفق بود',
      'آنتیویروس یا دیواره آتش ممکن است مانع شده باشد.',
    ),
    'E220': ('مجوز لازم داده نشد', 'مجوز VPN را در تنظیمات تأیید کنید.'),
    'E230': ('اتصال توسط برنامه دیگر قطع شد', 'اتصال دیگری جایگزین زحل شد.'),
    'E250': ('نسخه پروتکل ناسازگار است', 'برنامه و سرویس را بهروزرسانی کنید.'),
    'E300': (
      'سامانه مشغول است',
      'اتصال دیگری روی این رایانه در حال استفاده است.',
    ),
    'E400': ('خطای داخلی موتور', 'سامانه دوباره راهاندازی میشود.'),
  };

  static String getErrorTitle(String code) =>
      errors[code]?.$1 ?? 'خطای نامشخص ($code)';
  static String getErrorHint(String code) =>
      errors[code]?.$2 ?? 'لطفاً وضعیت را بررسی نمایید.';
}
