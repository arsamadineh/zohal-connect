<div align="center">
  <img src="assets/logo.png" alt="Zohal Connect Logo" width="128" height="128" />
</div>

<div dir="rtl">

# زحل | Zohal Connect

**قندشکن زحل: بی‌دردسر وصل شو.**

---

زحل یه برنامه‌س برای ویندوز، لینوکس و اندروید که رو هسته‌ی متن‌باز [Aether](https://github.com/CluvexStudio/Aether) ساخته‌ی CluvexStudio پیاده شده. Aether از WARP کلودفلر با MASQUE و WireGuard استفاده می‌کنه و اون قسمت سخت کار رو انجام میده. ما فقط یه رابط درست‌وحسابی دورش کشیدیم، همون‌جوری که آدم دوست داره رو گوشی و لپ‌تاپش داشته باشه.

## چرا ساختیمش؟

راستش خسته شده بودیم:
* از اینکه هر دفعه وصل شدن یه دقیقه طول بکشه
* از برنامه‌هایی که نصفه‌راه قطع می‌شن و اینترنتت رو آویزون میذارن
* از اون رابط‌های شلوغی که انگار فقط از سر ناچاری یه گوشه‌ای چپونده شدن

## چی داره؟

**اتصال سریع.**  
برنامه آخرین دروازه‌های سالم هر شبکه رو به خاطر می‌سپره و چندتا مسیر رو هم‌زمان امتحان می‌کنه. هدفمون اینه که اگه قبلاً به همون شبکه وصل شدی، زیر ۲ ثانیه بهت وصل کنه. اعداد واقعی رو هم تو `docs/GATES.md` می‌نویسیم، نه شعار.

**کل سیستم، نه فقط مرورگر.**  
حالت TUN همه‌ی ترافیک رو از تونل رد می‌کنه. اگه نخواستی، حالت پراکسی سیستم هم هست.

**ناسازگاری نداره.**  
هر تغییری که می‌خوایم رو مسیرها، DNS یا تنظیمات پراکسی بدیم، اول تو یه دفترچه ثبت می‌کنیم، بعد اجرا می‌کنیم. اگه برنامه وسط کار کرش کنه، دفعه‌ی بعد خودش همه‌چی رو سر جاش برمی‌گردونه. به چیزی که مال ما نیست دست نمی‌زنیم.

**نشتی نداره.**  
DNS و IPv6 زیر نظرن. سایت‌های داخلی (‎.ir) و شبکه‌ی محلی به‌صورت پیش‌فرض مستقیم باز می‌شن. دیگه بانک‌ها و درگاه‌ها با آی‌پی خارجی گیر نمی‌دن.

**کلیک‌های پشت‌سرهم مشکلی درست نمی‌کنن.**  
موتور برنامه فقط به آخرین درخواست شما نگاه می‌کنه، پس هرچقدر رو دکمه بزنی چیزی خراب نمی‌شه.

**رابط ساده.**  
راست‌به‌چپ. فونت وزیرمتن. گوشه‌های تیز. یه دکمه‌ی اصلی. رنگ‌ها رو هم از تم سیستمت می‌گیره.

**حریم خصوصی.**  
بدون تحلیل‌گر، بدون تلمتری، بدون گزارش خودکار، بدون حساب کاربری. هیچ‌چیز جایی ارسال نمی‌شه، جز ترافیک خودت به لبه‌ی کلودفلر.

---

## وضعیت پروژه

زحل هنوز بتاست. هرچی رو کاغذ نوشتیم و هنوز تست نشده، صادقانه تو `docs/KNOWN_LIMITS.md` گذاشتیم. اگه چیزی خراب بود، لطفاً یه issue باز کن. شرمنده نمی‌شیم، فقط درستش می‌کنیم.

---

## ساختار پروژه

```
zohal-connect/
  engine/                موتور اتصال (Rust)
    crates/
      zohal-proto/       پروتکل ارتباط، تنظیمات، کدهای خطا
      zohal-engine/      ناظر اصلی، نردبان خودکار، حافظه‌ی دروازه‌ها، دفترچه‌ی بازیابی
      zohal-platform/    مسیریابی لینوکس، ویندوز، حالت پراکسی
      zohal-tun/         رابط TUN و شمارنده‌ی ترافیک
      zohald/            سرویس پس‌زمینه (service، user، cleanup، status)
      zohal-bridge/      پل بین رابط و موتور
  app/                   رابط کاربری (Flutter)
  packaging/             بسته‌بندی deb، rpm و نصب‌کننده‌ی ویندوز
  docs/                  معماری، تصمیم‌ها، نتیجه‌ی آزمون‌ها و راهنمای تست دستی
```

---

## ساخت از روی سورس

موتور:

```bash
cd engine
cargo build --release -p zohald
cargo test --all
```

آخرین نسخه‌ی پایدار Rust رو نصب کن. Aether تو نسخه‌ی ۲٫۳٫۰ به Rust 1.98 نیاز داره.

رابط:

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

آخرین نسخه‌ی پایدار Flutter کافیه.

---

## مشارکت

پیشنهاد، گزارش خطا و پول‌ریکوئست همیشه خوش‌آمده. فقط یه خواهش داریم: کدی که نفهمیدی چی‌کار می‌کنه، تو پروژه نریز.

---

## سپاس

زحل بدون کار خوب [CluvexStudio](https://github.com/CluvexStudio) رو Aether ممکن نبود. از Cloudflare quiche، tun2proxy، Wintun و فونت وزیرمتن هم ممنونیم. مجوز هرکدوم تو پوشه‌ی `THIRD_PARTY_LICENSES` هست.

---

## مجوز

زحل تحت [AGPL-3.0](https://github.com/arsamadineh/zohal-connect/blob/main/LICENSE) منتشر می‌شه.  
یعنی آزاده، آزاد بمونه.

</div>

---

## English (short)

Zohal Connect is a cross-platform censorship-circumvention client for Windows, Linux and Android, built on the open-source [Aether](https://github.com/CluvexStudio/Aether) core (Cloudflare WARP over MASQUE/WireGuard). It adds a TUN and system-proxy engine, a crash-safe journal that undoes every system change, a gateway cache for fast reconnects, and a clean RTL interface.

It is beta software. Known limits are listed in `docs/KNOWN_LIMITS.md`. Licensed under AGPL-3.0.
