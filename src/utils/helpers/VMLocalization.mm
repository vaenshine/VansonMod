#import "include/VMLocalization.h"
#include "LocalizationCore.hpp"
#import "VMLanguageRefresh.h"

@interface VMLocalization ()
@end

@implementation VMLocalization

+ (instancetype)shared {
  static VMLocalization *s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    s = [self new];
  });
  return s;
}

- (instancetype)init {
  if (self = [super init]) {
    
    [self updateCoreLanguage];
  }
  return self;
}

- (void)updateCoreLanguage {
  NSString *lang = [self currentLanguage];

  if ([lang isEqualToString:@"Auto"]) {
    NSArray *preferredLangs = [NSLocale preferredLanguages];
    if (preferredLangs.count > 0) {
      NSString *sysLang = preferredLangs.firstObject;
      
      if ([sysLang hasPrefix:@"zh-Hans"] || [sysLang hasPrefix:@"zh-CN"]) {
        lang = @"zh-Hans";
      } else if ([sysLang hasPrefix:@"zh-Hant"] || [sysLang hasPrefix:@"zh-TW"] || [sysLang hasPrefix:@"zh-HK"]) {
        lang = @"zh-Hant";
      } else if ([sysLang hasPrefix:@"zh"]) {
        lang = @"zh-Hans"; 
      } else if ([sysLang hasPrefix:@"ja"]) {
        lang = @"ja";
      } else if ([sysLang hasPrefix:@"ko"]) {
        lang = @"ko";
      } else if ([sysLang hasPrefix:@"vi"]) {
        lang = @"vi";
      } else if ([sysLang hasPrefix:@"th"]) {
        lang = @"th";
      } else if ([sysLang hasPrefix:@"ru"]) {
        lang = @"ru";
      } else if ([sysLang hasPrefix:@"es"]) {
        lang = @"es";
      } else if ([sysLang hasPrefix:@"pt"]) {
        lang = @"pt";
      } else if ([sysLang hasPrefix:@"fr"]) {
        lang = @"fr";
      } else if ([sysLang hasPrefix:@"de"]) {
        lang = @"de";
      } else if ([sysLang hasPrefix:@"ar"]) {
        lang = @"ar";
      } else {
        lang = @"en";
      }
    } else {
      lang = @"en"; 
    }
  }

  if (lang) {
    LocalizationCore::getInstance().setLanguage([lang UTF8String]);
  }
}

- (void)setLanguage:(NSString *)lang {
  VMLanguageTrace(@"preferences-write-begin");
  [[NSUserDefaults standardUserDefaults] setObject:lang forKey:@"user_lang"];
  VMLanguageTrace(@"preferences-write-end");

  [self updateCoreLanguage];
  VMLanguageTrace(@"translation-switch-end");
}

- (NSString *)localizedString:(NSString *)key {
  if (!key || ![key isKindOfClass:[NSString class]] || key.length == 0) {
    return @"";
  }

  std::string cppKey = [key UTF8String];
  std::string cppVal = LocalizationCore::getInstance().get(cppKey);

  return [NSString stringWithUTF8String:cppVal.c_str()];
}

- (NSString *)currentLanguage {
  NSString *lang =
      [[NSUserDefaults standardUserDefaults] objectForKey:@"user_lang"];
  if (!lang || ![lang isKindOfClass:[NSString class]] || lang.length == 0) {
    return @"Auto";
  }
  return lang;
}

@end
