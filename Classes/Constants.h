//
//  Constants.h
//  HFRplus
//
//  Created by FLK on 05/08/10.
//

#import <Foundation/Foundation.h>
#import "UITableViewController+Ext.h"
#import "NSDictionary+Merging.h"
#import "HFRNavigationController.h"
#import "UIColor+Extension.h"

#ifdef CONFIGURATION_Release
#define NSLog(__FORMAT__, ...)
#else
#define NSLog(__FORMAT__, ...) NSLog((@"%s [Line %d] " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#endif

static const NSInteger kDispatchPeriodSeconds = 20;

typedef enum {
	kIdle,
	kMaintenance,
	kNoResults,
    kNoAuth,
	kComplete
} STATUS;

typedef enum {
    kTerminator,
    kPoussin
} BLMOD;

typedef enum {
    kALL,
    kFav,
    kFlag,
    kRed
} FLAGTYPE;

typedef enum {
    kSync, //pour repositionner les boutons en fonction du mode Main Gauche
    kReload,
    kCancel,
    kNewTopic,
    kAllCat
} BARBTNTYPE;

typedef enum Theme : int {
    ThemeLight = 0,
    ThemeDark = 1
} Theme;



#define kStatusChangedNotification  @"kStatusChangedNotification"
#define kLoginChangedNotification  @"kLoginChangedNotification"
#define kThemeChangedNotification  @"kThemeChangedNotification"
#define kSmileysSizeChangedNotification  @"kSmileysSizeChangedNotification"

//#define kForumURL                   @"http://forum.hardware.fr"
#define kCatTemplateURL				@"/forum1.php?config=hfr.inc&cat=$1&page=1&subcat=$2&owntopic=$3"
#define kTTURL                      @"http://www.teletubbies.com"

// $1 cat not 0 - $2 subcat 0 - $3 flag : 0=all, 1=flag+fav, 2=fav, 3=red

#define kTimeoutMini		30
#define kTimeoutMaxi		60
#define kTimeoutAvatar      10

#define MAX_HEIGHT 1200.0f 
#define MAX_CELL_CONTENT 300.0f
#define MAX_TEXT_WIDTH 250.0f

#ifndef DEBUG_LOGS
	#define DEBUG_LOGS 0
#endif

//Alerts Tags 100 + ####
#define kAlertBlackListOK       1000001
#define kAlertSondageOK         1000002
#define kAlertPasteBoardOK      1000003

#define REHOST_IMAGE_FILE @"rehostImages.plist"
#define SEARCH_SMILEYS_FILE @"smileysSearch.plist"
#define LAST_SMILEYS_FILE @"lastSmileysSearch.plist"
#define BLACKLIST_FILE @"blackList.plist"
#define BLACKLISTDICO_FILE @"blackListDico.plist"
#define WHITELIST_FILE @"whiteList.plist"
#define OFFLINE_TOPICS_DICO_FILE @"offlineTopicsDico.plist"
#define OFFLINE_IMAGECACHE_DICO_FILE @"offlineImageCacheDico.plist"
#define FORUMSMETA_FILE @"forumsMeta.plist"
#define FORUMS_CACHE_FILE @"forumsCache.plist"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define kNewMessageFromUpdate   1
#define kNewMessageFromShake    2
#define kNewMessageFromEditor   3
#define kNewMessageFromUnkwn    4
#define kNewMessageFromNext     5

// iOS7
#define HEIGHT_FOR_HEADER_IN_SECTION                36.0f
#define SPACE_FOR_BARBUTTON                         10.0f

// Multis feature
#define HFR_COMPTES_KEY @"HFR_COMPTES_KEY"
#define PSEUDO_KEY @"PSEUDO"
#define COOKIES_KEY @"COOKIES"
#define AVATAR_KEY @"AVATAR"
#define PSEUDO_DISPLAY_KEY @"PSEUDO_DISPLAY"
#define HASH_KEY @"HASH"
#define MAIN_KEY @"MAIN"

// Chevereto
#define CHEVERETO_KEY @"% PUT CHEVERETO KEY HERE %"

// Min & max
#define MAXIMUM(a,b) ( ((a) > (b)) ? (a) : (b) )
#define MINIMUM(a,b) ( ((a) < (b)) ? (a) : (b) )
