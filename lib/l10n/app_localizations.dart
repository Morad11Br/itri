import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'عطري'**
  String get appTitle;

  /// No description provided for @homeTab.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get homeTab;

  /// No description provided for @collectionTab.
  ///
  /// In ar, this message translates to:
  /// **'مجموعتي'**
  String get collectionTab;

  /// No description provided for @occasionTab.
  ///
  /// In ar, this message translates to:
  /// **'مناسبات'**
  String get occasionTab;

  /// No description provided for @finderTab.
  ///
  /// In ar, this message translates to:
  /// **'كاشف'**
  String get finderTab;

  /// No description provided for @profileTab.
  ///
  /// In ar, this message translates to:
  /// **'أنا'**
  String get profileTab;

  /// No description provided for @goodMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In ar, this message translates to:
  /// **'نهارك سعيد'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير'**
  String get goodEvening;

  /// No description provided for @goodNight.
  ///
  /// In ar, this message translates to:
  /// **'ليلة سعيدة'**
  String get goodNight;

  /// No description provided for @user.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get user;

  /// No description provided for @discoverNow.
  ///
  /// In ar, this message translates to:
  /// **'اكتشف الآن'**
  String get discoverNow;

  /// No description provided for @categories.
  ///
  /// In ar, this message translates to:
  /// **'الفئات'**
  String get categories;

  /// No description provided for @trending.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر رواجاً'**
  String get trending;

  /// No description provided for @deals.
  ///
  /// In ar, this message translates to:
  /// **'عروض اليوم'**
  String get deals;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'+ أضف'**
  String get add;

  /// No description provided for @addPerfume.
  ///
  /// In ar, this message translates to:
  /// **'أضف عطراً'**
  String get addPerfume;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن اسم العطر أو الماركة...'**
  String get searchHint;

  /// No description provided for @searchPerfumeHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن عطر (مثل: Aventus, Baccarat…)'**
  String get searchPerfumeHint;

  /// No description provided for @searchSimilarHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن عطر مشابه بسعر أقل'**
  String get searchSimilarHint;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get scanBarcode;

  /// No description provided for @manualEntry.
  ///
  /// In ar, this message translates to:
  /// **'إدخال يدوي'**
  String get manualEntry;

  /// No description provided for @enterBarcode.
  ///
  /// In ar, this message translates to:
  /// **'أو أدخل الباركود يدوياً'**
  String get enterBarcode;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get signup;

  /// No description provided for @signin.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get signin;

  /// No description provided for @newAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب جديد'**
  String get newAccount;

  /// No description provided for @googleSignIn.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة عبر Google'**
  String get googleSignIn;

  /// No description provided for @appleSignIn.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة عبر Apple'**
  String get appleSignIn;

  /// No description provided for @or.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get or;

  /// No description provided for @enterValidEmailPassword.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريد صحيح وكلمة مرور من 8 أحرف على الأقل.'**
  String get enterValidEmailPassword;

  /// No description provided for @enterName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمك.'**
  String get enterName;

  /// No description provided for @loginToSave.
  ///
  /// In ar, this message translates to:
  /// **'ادخل لحفظ مجموعتك ومزامنتها'**
  String get loginToSave;

  /// No description provided for @verifyEmail.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من بريدك الإلكتروني'**
  String get verifyEmail;

  /// No description provided for @verificationSent.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رابط التأكيد إلى'**
  String get verificationSent;

  /// No description provided for @verifyInstructions.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الرابط في البريد لتفعيل حسابك، ثم عد لتسجيل الدخول.'**
  String get verifyInstructions;

  /// No description provided for @backToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة لتسجيل الدخول'**
  String get backToLogin;

  /// No description provided for @pleaseConfirmEmail.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد بريدك الإلكتروني أولاً. تحقق من صندوق الوارد.'**
  String get pleaseConfirmEmail;

  /// No description provided for @loginFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح تسجيل الدخول.'**
  String get loginFailed;

  /// No description provided for @onboardingTitle1.
  ///
  /// In ar, this message translates to:
  /// **'اكتشف، سجل، وشارك عالم الروائح'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In ar, this message translates to:
  /// **'1000+ عطر  •  تقييمات من الخليج  •  مجاني'**
  String get onboardingDesc1;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @collection.
  ///
  /// In ar, this message translates to:
  /// **'مجموعتي'**
  String get collection;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @owned.
  ///
  /// In ar, this message translates to:
  /// **'مملوك'**
  String get owned;

  /// No description provided for @wish.
  ///
  /// In ar, this message translates to:
  /// **'مرغوب'**
  String get wish;

  /// No description provided for @tested.
  ///
  /// In ar, this message translates to:
  /// **'مجرب'**
  String get tested;

  /// No description provided for @emptyCollection.
  ///
  /// In ar, this message translates to:
  /// **'مجموعتك فارغة'**
  String get emptyCollection;

  /// No description provided for @emptyCollectionDesc.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة عطورك المفضلة إلى مجموعتك'**
  String get emptyCollectionDesc;

  /// No description provided for @perfumes.
  ///
  /// In ar, this message translates to:
  /// **'العطور'**
  String get perfumes;

  /// No description provided for @value.
  ///
  /// In ar, this message translates to:
  /// **'القيمة'**
  String get value;

  /// No description provided for @diversity.
  ///
  /// In ar, this message translates to:
  /// **'التنوع'**
  String get diversity;

  /// No description provided for @loadMore.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد'**
  String get loadMore;

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'حالة في مجموعتك'**
  String get status;

  /// No description provided for @notesPyramid.
  ///
  /// In ar, this message translates to:
  /// **'هرم النوتات'**
  String get notesPyramid;

  /// No description provided for @topNotes.
  ///
  /// In ar, this message translates to:
  /// **'النوتات الأولى'**
  String get topNotes;

  /// No description provided for @heartNotes.
  ///
  /// In ar, this message translates to:
  /// **'نوتات القلب'**
  String get heartNotes;

  /// No description provided for @baseNotes.
  ///
  /// In ar, this message translates to:
  /// **'النوتات الأساسية'**
  String get baseNotes;

  /// No description provided for @aboutPerfume.
  ///
  /// In ar, this message translates to:
  /// **'عن العطر'**
  String get aboutPerfume;

  /// No description provided for @rating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get rating;

  /// No description provided for @yourRating.
  ///
  /// In ar, this message translates to:
  /// **'تقييمك'**
  String get yourRating;

  /// No description provided for @longevity.
  ///
  /// In ar, this message translates to:
  /// **'الثبات'**
  String get longevity;

  /// No description provided for @sillage.
  ///
  /// In ar, this message translates to:
  /// **'الانتشار'**
  String get sillage;

  /// No description provided for @valueLabel.
  ///
  /// In ar, this message translates to:
  /// **'القيمة'**
  String get valueLabel;

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @favorite.
  ///
  /// In ar, this message translates to:
  /// **'مفضل'**
  String get favorite;

  /// No description provided for @occasion.
  ///
  /// In ar, this message translates to:
  /// **'المناسبة'**
  String get occasion;

  /// No description provided for @budget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get budget;

  /// No description provided for @recipient.
  ///
  /// In ar, this message translates to:
  /// **'المستلم'**
  String get recipient;

  /// No description provided for @style.
  ///
  /// In ar, this message translates to:
  /// **'الأسلوب'**
  String get style;

  /// No description provided for @findByAI.
  ///
  /// In ar, this message translates to:
  /// **'اعثر على عطرك بالذكاء الاصطناعي ✨'**
  String get findByAI;

  /// No description provided for @findPerfect.
  ///
  /// In ar, this message translates to:
  /// **'اعثر على العطر المثالي 🌟'**
  String get findPerfect;

  /// No description provided for @men.
  ///
  /// In ar, this message translates to:
  /// **'رجالي'**
  String get men;

  /// No description provided for @women.
  ///
  /// In ar, this message translates to:
  /// **'نسائي'**
  String get women;

  /// No description provided for @unisex.
  ///
  /// In ar, this message translates to:
  /// **'يونيسكس'**
  String get unisex;

  /// No description provided for @finderDesc.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن اسم العطر أو الماركة...'**
  String get finderDesc;

  /// No description provided for @referencePerfume.
  ///
  /// In ar, this message translates to:
  /// **'عطر مرجعي'**
  String get referencePerfume;

  /// No description provided for @estimatedPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر التقريبي'**
  String get estimatedPrice;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'حسابك الشخصي'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfile;

  /// No description provided for @premium.
  ///
  /// In ar, this message translates to:
  /// **'بريميوم'**
  String get premium;

  /// No description provided for @upgrade.
  ///
  /// In ar, this message translates to:
  /// **'ترقية'**
  String get upgrade;

  /// No description provided for @premiumDesc.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات أسعار • تحليلات متقدمة • بلا إعلانات'**
  String get premiumDesc;

  /// No description provided for @favoriteNotes.
  ///
  /// In ar, this message translates to:
  /// **'نوتاتك المفضلة'**
  String get favoriteNotes;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get english;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @privacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacy;

  /// No description provided for @exportData.
  ///
  /// In ar, this message translates to:
  /// **'تصدير البيانات'**
  String get exportData;

  /// No description provided for @inviteFriend.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ صديقاً'**
  String get inviteFriend;

  /// No description provided for @help.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة'**
  String get help;

  /// No description provided for @signout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signout;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get termsOfUse;

  /// No description provided for @dataCollection.
  ///
  /// In ar, this message translates to:
  /// **'البيانات التي نجمعها'**
  String get dataCollection;

  /// No description provided for @security.
  ///
  /// In ar, this message translates to:
  /// **'أمان البيانات'**
  String get security;

  /// No description provided for @faq.
  ///
  /// In ar, this message translates to:
  /// **'الأسئلة الشائعة'**
  String get faq;

  /// No description provided for @contact.
  ///
  /// In ar, this message translates to:
  /// **'التواصل'**
  String get contact;

  /// No description provided for @exportTitle.
  ///
  /// In ar, this message translates to:
  /// **'تصدير بيانات مجموعتك'**
  String get exportTitle;

  /// No description provided for @exportDesc.
  ///
  /// In ar, this message translates to:
  /// **'البيانات بتنسيق JSON'**
  String get exportDesc;

  /// No description provided for @shareApp.
  ///
  /// In ar, this message translates to:
  /// **'جرب تطبيق عطري — دليلك لعالم العطور'**
  String get shareApp;

  /// No description provided for @generalNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات العامة'**
  String get generalNotifications;

  /// No description provided for @newFeatures.
  ///
  /// In ar, this message translates to:
  /// **'التحديثات والميزات الجديدة'**
  String get newFeatures;

  /// No description provided for @promotions.
  ///
  /// In ar, this message translates to:
  /// **'العروض والخصومات'**
  String get promotions;

  /// No description provided for @loadingFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل النتائج. تظهر أفضل الخيارات المتاحة محلياً.'**
  String get loadingFailed;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get tryAgain;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get noResults;

  /// No description provided for @scanAgain.
  ///
  /// In ar, this message translates to:
  /// **'مسح مجدداً'**
  String get scanAgain;

  /// No description provided for @perfumeNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على العطر'**
  String get perfumeNotFound;

  /// No description provided for @addToCollection.
  ///
  /// In ar, this message translates to:
  /// **'إضافة للمجموعة ✨'**
  String get addToCollection;

  /// No description provided for @findDupes.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن البدائل الأقرب'**
  String get findDupes;

  /// No description provided for @similarity.
  ///
  /// In ar, this message translates to:
  /// **'التشابه'**
  String get similarity;

  /// No description provided for @community.
  ///
  /// In ar, this message translates to:
  /// **'المجتمع'**
  String get community;

  /// No description provided for @topReviewers.
  ///
  /// In ar, this message translates to:
  /// **'أفضل المقيّمين'**
  String get topReviewers;

  /// No description provided for @reviews.
  ///
  /// In ar, this message translates to:
  /// **'التقييمات'**
  String get reviews;

  /// No description provided for @followers.
  ///
  /// In ar, this message translates to:
  /// **'المتابعون'**
  String get followers;

  /// No description provided for @posts.
  ///
  /// In ar, this message translates to:
  /// **'المنشورات'**
  String get posts;

  /// No description provided for @todayDeals.
  ///
  /// In ar, this message translates to:
  /// **'عروض اليوم'**
  String get todayDeals;

  /// No description provided for @priceTracker.
  ///
  /// In ar, this message translates to:
  /// **'متابعة الأسعار'**
  String get priceTracker;

  /// No description provided for @watchlist.
  ///
  /// In ar, this message translates to:
  /// **'قائمة المتابعة'**
  String get watchlist;

  /// No description provided for @activeDeals.
  ///
  /// In ar, this message translates to:
  /// **'العروض النشطة'**
  String get activeDeals;

  /// No description provided for @sar.
  ///
  /// In ar, this message translates to:
  /// **'ر.س'**
  String get sar;

  /// No description provided for @discount.
  ///
  /// In ar, this message translates to:
  /// **'خصم'**
  String get discount;

  /// No description provided for @days.
  ///
  /// In ar, this message translates to:
  /// **'أيام'**
  String get days;

  /// No description provided for @hours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات'**
  String get hours;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ، حاول مجدداً'**
  String get error;

  /// No description provided for @followersCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} متابع'**
  String followersCount(Object count);

  /// No description provided for @reviewsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} تقييم'**
  String reviewsCount(Object count);

  /// No description provided for @postsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} مشاركة'**
  String postsCount(Object count);

  /// No description provided for @saveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ الحالة. حاول مرة أخرى.'**
  String get saveFailed;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get price;

  /// No description provided for @concentration.
  ///
  /// In ar, this message translates to:
  /// **'التركيز'**
  String get concentration;

  /// No description provided for @source.
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get source;

  /// No description provided for @personalNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات شخصية'**
  String get personalNotes;

  /// No description provided for @optional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optional;

  /// No description provided for @selectNotes.
  ///
  /// In ar, this message translates to:
  /// **'اختر النوتات'**
  String get selectNotes;

  /// No description provided for @year.
  ///
  /// In ar, this message translates to:
  /// **'السنة'**
  String get year;

  /// No description provided for @gender.
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get gender;

  /// No description provided for @brand.
  ///
  /// In ar, this message translates to:
  /// **'الماركة'**
  String get brand;

  /// No description provided for @perfumeName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العطر'**
  String get perfumeName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
