use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ErrorCode {
    E100, // No internet or captive portal
    E110, // System clock skew
    E120, // Auto ladder exhausted
    E130, // Identity rejected by Cloudflare
    E140, // Cloudflare registration API blocked
    E200, // Helper service not running
    E210, // Virtual adapter creation failure (Wintun/driver)
    E220, // VPN permission denied
    E230, // VPN revoked by another VPN application
    E250, // IPC protocol version mismatch
    E300, // Engine busy / another tunnel active
    E400, // Internal engine / supervisor failure
}

impl ErrorCode {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::E100 => "E100",
            Self::E110 => "E110",
            Self::E120 => "E120",
            Self::E130 => "E130",
            Self::E140 => "E140",
            Self::E200 => "E200",
            Self::E210 => "E210",
            Self::E220 => "E220",
            Self::E230 => "E230",
            Self::E250 => "E250",
            Self::E300 => "E300",
            Self::E400 => "E400",
        }
    }

    pub fn title_fa(&self) -> &'static str {
        match self {
            Self::E100 => "عدم دسترسی به اینترنت",
            Self::E110 => "ساعت سیستم نادرست است",
            Self::E120 => "عدم موفقیت در برقراری ارتباط",
            Self::E130 => "رد هویت ارتباطی",
            Self::E140 => "اختلال در ثبت ارتباط",
            Self::E200 => "سرویس پشتیبان فعال نیست",
            Self::E210 => "اختلال در راهاندازی تونل شبکه",
            Self::E220 => "مجوز شبکه داده نشد",
            Self::E230 => "اتصال توسط برنامه دیگری متوقف شد",
            Self::E250 => "ناهماهنگی در نسخه ارتباطی",
            Self::E300 => "سرویس در حال استفاده است",
            Self::E400 => "خطای داخلی سامانه",
        }
    }

    pub fn message_fa(&self) -> &'static str {
        match self {
            Self::E100 => "ارتباط اینترنت برقرار نیست یا پورتال لاگین شبکه فعال است.",
            Self::E110 => "ساعت دستگاه بیش از ۵ دقیقه با زمان واقعی اختلاف دارد.",
            Self::E120 => "روشهای اتصال خودکار در این شبکه پاسخگو نبودند.",
            Self::E130 => "هویت ثبتشده توسط کارگزار پذیرفته نشد.",
            Self::E140 => "دسترسی به درگاه ثبت اولیه در این شبکه مسدود شده است.",
            Self::E200 => "سرویس سیستمی زحل در پسزمینه اجرا نشده است.",
            Self::E210 => "امکان ساخت آداپتور شبکه وجود ندارد؛ احتمالا توسط ضدویروس مسدود شده است.",
            Self::E220 => "مجوز ایجاد شبکه امن توسط کاربر یا سامانه رد شد.",
            Self::E230 => "برنامه دیگری مدیریت شبکه امن را در دست گرفت.",
            Self::E250 => "نسخه پروتکل واسط کاربری و موتور هماهنگ نیست.",
            Self::E300 => "اتصال دیگری به طور همزمان در سیستم فعال است.",
            Self::E400 => "موتور اصلی با خطای غیرمنتظره مواجه شد و بازنشانی گردید.",
        }
    }

    pub fn hint_fa(&self) -> Option<&'static str> {
        match self {
            Self::E100 => Some("اتصال اینترنت خود را بررسی کنید و وارد صفحه ورود شبکه شوید."),
            Self::E110 => Some("ساعت و تاریخ دستگاه را روی حالت خودکار بگذارید."),
            Self::E120 => Some("حالت اتصال را دستی تغییر دهید یا شبکه اینترنت را عوض کنید."),
            Self::E130 => Some("از بخش تنظیمات گزینه بازنشانی هویت را انتخاب نمایید."),
            Self::E140 => Some("برای نخستین اتصال از یک اینترنت دیگر استفاده فرمایید."),
            Self::E200 => Some("تلاش برای راهاندازی سرویس را از بخش تنظیمات بزنید."),
            Self::E210 => Some("زحل را در ضدویروس مجاز کنید یا به عنوان مدیر سیستم اجرا نمایید."),
            Self::E220 => Some("در پنجره باز شده دکمه تایید مجوز را بزنید."),
            Self::E230 => Some("سایر برنامههای قندشکن فعال را ببندید."),
            Self::E250 => Some("برنامه را به آخرین نگارش بهروزرسانی کنید."),
            Self::E300 => Some("اتصال کاربر دیگر را قطع کنید یا برنامه قبلی را ببندید."),
            Self::E400 => Some("برنامه مجددا به صورت خودکار راهاندازی خواهد شد."),
        }
    }
}
