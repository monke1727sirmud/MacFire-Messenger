/*******************************************************************
	FILE:		MFPreferences.m
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Provides a specialized interface to NSUserDefaults.  It takes
		care of setting up the default preferences and interfacing
		with NSUserDefaults by handling the details of encoding and
		decoding settings in a manner that NSUserDefaults can understand
		(since it can't store just any type).
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 03 01  Added Xfire network traffic log pref.
		2008 01 03  Added friend name and status colunn widths.
					Moved pref init code to +preferences due to Leopard issue.
		2007 12 07  Created.
*******************************************************************/

#import "MFPreferences.h"
#import "NSUserDefaults_MFAdditions.h"

// This is the preferences-changed notification name
NSString *MFPreferencesChangedNotificationName = @"MFPreferencesChangedNotificationName";

// These are the keys for NSUserDefaults
//					----------------------------------  ---------------------------------           -----------------------------
//					KEY									VALUE										TYPE
//					----------------------------------  ---------------------------------           -----------------------------
static NSString*	kMFNameDisplayStylePrefKey			= @"NameDisplayStyle"				; //	int
static NSString*	kMFShowIdleStatusAutoPrefKey		= @"ShowIdleAutomatically"			; //	BOOL
static NSString*	kMFIdleStatusDelayPrefKey			= @"IdleStatusDelay"				; //	int
static NSString*	kMFTrackGameStatusPrefKey			= @"TrackGameStatus"				; //	BOOL
static NSString*	kMFLogXfireNetworkTrafficPrefKey	= @"LogXfireNetworkTraffic"			; //	BOOL
static NSString*	kMFMainWindowRectPrefKey			= @"MainWindowRect"					; //	NSString (via NSStringFromRect)
static NSString*	kMFCustomStatusStringsPrefKey		= @"CustomStatusStrings"			; //	NSArray<NSString>
static NSString*	kMFDefaultUserNamePrefKey			= @"DefaultUserName"				; //	NSString
static NSString*	kMFUserNameHistoryPrefKey			= @"UserNameHistory"				; //	NSArray<NSString>
static NSString*	kMFFriendNameColumnWidthPrefKey		= @"FriendNameColumnWidth"			; //	float
static NSString*	kMFFriendStatusColumnWidthPrefKey	= @"FriendStatusColumnWidth"		; //	float
static NSString*	kMFFriendGameColumnWidthPrefKey		= @"FriendGameColumnWidth"			; //	float
static NSString*	kMFShowWhenTypingPrefKey			= @"ShowWhenTyping"					; //	BOOL
static NSString*	kMFShowTimeStampsPrefKey			= @"ShowTimeStamps"					; //	BOOL
static NSString*	kMFLogChatsPrefKey					= @"LogChats"						; //	BOOL
static NSString*	kMFChatTextFontPrefKey				= @"ChatTextFont"					; //	NSData (archived NSFont)
static NSString*	kMFPostGrowlNotesPrefKey			= @"PostGrowlNotifications"			; //	BOOL
static NSString*	kMFPostGrowlWhileActivePrefKey		= @"PostGrowlWhileActive"			; //	BOOL
static NSString*	kMFPoseAsNewerXfirePrefKey			= @"PoseAsNewerXfire"				; //	BOOL
static NSString*	kMFPosingXfireVersionPrefKey		= @"PosingXfireVersion"				; //	int
static NSString*	kMFXfireServerHostNamePrefKey		= @"XfireServerHostName"			; //	NSString
static NSString*	kMFXfireServerPortNumberPrefKey		= @"XfireServerPortNumber"			; //	int
static NSString*	kMFFriendNameChatColorPrefKey		= @"FriendNameChatColor"			; //	NSData (archived NSColor)
static NSString*	kMFMyNameChatColorPrefKey			= @"MyNameChatColor"				; //	NSData (archived NSColor)

static MFPreferences *gPrefs = nil;




@implementation MFPreferences

#define SETDEF( _key, _value ) [defaults setObject:(_value) forKey:(_key)]
#define SETBOOL( _key, _value ) [defaults setObject:[NSNumber numberWithBool:(_value)] forKey:(_key)]
#define SETFLOAT( _key, _value ) [defaults setObject:[NSString stringWithFormat:@"%g", (_value)] forKey:(_key)]
#define SETFONT( _key, _name, _size) [defaults setObject:[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:(_name) size:(_size)]] forKey:(_key)]
#define SETFONT2( _key, _font ) [defaults setObject:[NSArchiver archivedDataWithRootObject:(_font)] forKey:(_key)]
#define SETCOLOR( _key, _color ) [defaults setObject:[NSArchiver archivedDataWithRootObject:(_color)] forKey:(_key)]
+ (NSMutableDictionary *)defaultPreferences
{
	NSMutableDictionary		*defaults;
	
	// set up factory defaults dictionary
	defaults = [NSMutableDictionary dictionary];
	SETDEF(  kMFNameDisplayStylePrefKey,		[NSNumber numberWithInt:kMFPreferenceDisplayStyleNickname] );
	SETBOOL( kMFShowIdleStatusAutoPrefKey,		YES );
	SETDEF(  kMFIdleStatusDelayPrefKey,			[NSNumber numberWithInt:3] );
	SETBOOL( kMFTrackGameStatusPrefKey,			YES );
	SETBOOL( kMFLogXfireNetworkTrafficPrefKey,	NO  );
	SETDEF(  kMFMainWindowRectPrefKey,			NSStringFromRect(NSMakeRect(349,367,377,301)) );
	SETDEF(  kMFCustomStatusStringsPrefKey,		[NSArray array] );
	SETDEF(  kMFDefaultUserNamePrefKey,			@"" );
	SETDEF(  kMFUserNameHistoryPrefKey,         [NSArray array] );
	SETFLOAT(kMFFriendNameColumnWidthPrefKey,	144.0f );
	SETFLOAT(kMFFriendStatusColumnWidthPrefKey,	100.0f );
	SETFLOAT(kMFFriendGameColumnWidthPrefKey,	105.0f );
	SETBOOL( kMFShowWhenTypingPrefKey,			NO  );
	SETBOOL( kMFShowTimeStampsPrefKey,			YES );
	SETBOOL( kMFLogChatsPrefKey,				NO  );
	SETFONT2( kMFChatTextFontPrefKey,			[self defaultChatTextFont] );
	SETBOOL( kMFPostGrowlNotesPrefKey,			YES );
	SETBOOL( kMFPostGrowlWhileActivePrefKey,	NO  );
	SETBOOL( kMFPoseAsNewerXfirePrefKey,		NO  );
	SETDEF(  kMFPosingXfireVersionPrefKey,		[NSNumber numberWithInt:0] );
	SETDEF(  kMFXfireServerHostNamePrefKey,		@"cs.xfire.com" );
	SETDEF(  kMFXfireServerPortNumberPrefKey,	[NSNumber numberWithInt:25999] );
	SETCOLOR( kMFFriendNameChatColorPrefKey,	[NSColor colorWithCalibratedRed:(122.0/255.0) green:(36.0/255.0) blue:(33.0/255.0)  alpha:1.0] ); // a red hue
	SETCOLOR( kMFMyNameChatColorPrefKey,		[NSColor colorWithCalibratedRed:(47.0/255.0)  green:(78.0/255.0) blue:(137.0/255.0) alpha:1.0] ); // a blue hue
	
	return defaults;
}
#undef SETDEF
#undef SETBOOL
#undef SETFLOAT
#undef SETFONT
#undef SETFONT2
#undef SETCOLOR

+ (void)resetPreferences
{
	NSLog(@"CurrentDefaults = %@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
	
	[NSUserDefaults resetStandardUserDefaults];
	NSUserDefaults *stdDefaults = [NSUserDefaults standardUserDefaults];
	[stdDefaults registerDefaults:[self defaultPreferences]];
	
	// Double check.  I've seen strange things from time to time.
	if( [stdDefaults fontForKey:kMFChatTextFontPrefKey] == nil)
	{
		[stdDefaults removeObjectForKey:kMFChatTextFontPrefKey];
		[stdDefaults setFont:[self defaultChatTextFont] forKey:kMFChatTextFontPrefKey];
	}
	
	NSLog(@"ResetDefaults = %@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
}

+ (MFPreferences *)preferences
{
	if( gPrefs == nil )
	{
		gPrefs = [[MFPreferences alloc] init];
		
		NSUserDefaults *stdDefaults = [NSUserDefaults standardUserDefaults];
		[stdDefaults registerDefaults:[self defaultPreferences]];
		
		// Double check.  I've seen strange things from time to time.
		if( [stdDefaults fontForKey:kMFChatTextFontPrefKey] == nil)
		{
			[stdDefaults removeObjectForKey:kMFChatTextFontPrefKey];
			[stdDefaults setFont:[self defaultChatTextFont] forKey:kMFChatTextFontPrefKey];
		}
	}
	return gPrefs;
}

- (void)setNameDisplayStyle:(int)styleNumber
{
	if( (styleNumber == kMFPreferenceDisplayStyleNickname) ||
		(styleNumber == kMFPreferenceDisplayStyleUsername) ||
		(styleNumber == kMFPreferenceDisplayStyleNickUser) ||
		(styleNumber == kMFPreferenceDisplayStyleUserNick) )
	{
		[[NSUserDefaults standardUserDefaults] setInteger:styleNumber forKey:kMFNameDisplayStylePrefKey];
	}
}
- (int)nameDisplayStyle
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kMFNameDisplayStylePrefKey];
}

- (void)setShowIdleStatusAutomatically:(BOOL)setting
{
	[[NSUserDefaults standardUserDefaults] setBool:setting forKey:kMFShowIdleStatusAutoPrefKey];
}
- (BOOL)showIdleStatusAutomatically
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFShowIdleStatusAutoPrefKey];
}

- (void)setIdleStatusDelay:(unsigned int)delay
{
	[[NSUserDefaults standardUserDefaults] setInteger:delay forKey:kMFIdleStatusDelayPrefKey];
}
- (unsigned int)idleStatusDelay
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kMFIdleStatusDelayPrefKey];
}

- (void)setTrackUserGameStatus:(BOOL)setting
{
	[[NSUserDefaults standardUserDefaults] setBool:setting forKey:kMFTrackGameStatusPrefKey];
}
- (BOOL)trackUserGameStatus
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFTrackGameStatusPrefKey];
}

- (void)setLogXfireNetworkTraffic:(BOOL)shouldLog
{
	[[NSUserDefaults standardUserDefaults] setBool:shouldLog forKey:kMFLogXfireNetworkTrafficPrefKey];
}
- (BOOL)logXfireNetworkTraffic
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFLogXfireNetworkTrafficPrefKey];
}

- (void)setMainWindowFrame:(NSRect)aRect
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(aRect) forKey:kMFMainWindowRectPrefKey];
}
- (NSRect)mainWindowFrame
{
	NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey:kMFMainWindowRectPrefKey];
	if( str )
	{
		NSRect r = NSRectFromString(str);
		if( (r.size.width > 0) && (r.size.height > 0) )
		{
			return r;
		}
	}
	return NSMakeRect(349,367,377,301);
}

- (void)addCustomStatusString:(NSString *)string
{
	NSArray *a = [self customStatusStrings];
	if( [a containsObject:string] )
	{
		// make sure it's first in the list
		NSMutableArray *tmp = [NSMutableArray arrayWithArray:a];
		[tmp removeObject:string];
		[tmp insertObject:string atIndex:0];
		if( [tmp count] > 10 )
			[tmp removeLastObject];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:tmp] forKey:kMFCustomStatusStringsPrefKey];
	}
	else
	{
		NSMutableArray *tmp = [NSMutableArray arrayWithArray:a];
		[tmp insertObject:string atIndex:0];
		if( [tmp count] > 10 )
			[tmp removeLastObject];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:tmp] forKey:kMFCustomStatusStringsPrefKey];
	}
}
- (NSArray *)customStatusStrings
{
	return [[NSUserDefaults standardUserDefaults] arrayForKey:kMFCustomStatusStringsPrefKey];
}

- (void)setDefaultUserName:(NSString *)aName
{
	[[NSUserDefaults standardUserDefaults] setObject:aName forKey:kMFDefaultUserNamePrefKey];
}
- (NSString *)defaultUserName
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:kMFDefaultUserNamePrefKey];
}

- (void)addUserNameHistory:(NSString *)name
{
	NSArray *a = [self userNameHistory];
	if( [a containsObject:name] )
	{
		// make sure it's first in the list
		NSMutableArray *tmp = [NSMutableArray arrayWithArray:a];
		[tmp removeObject:name];
		[tmp insertObject:name atIndex:0];
		if( [tmp count] > 5 )
			[tmp removeLastObject];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:tmp] forKey:kMFUserNameHistoryPrefKey];
	}
	else
	{
		NSMutableArray *tmp = [NSMutableArray arrayWithArray:a];
		[tmp insertObject:name atIndex:0];
		if( [tmp count] > 5 )
			[tmp removeLastObject];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:tmp] forKey:kMFUserNameHistoryPrefKey];
	}
}
- (NSArray *)userNameHistory
{
	return [[NSUserDefaults standardUserDefaults] arrayForKey:kMFUserNameHistoryPrefKey];
}

- (void)setFriendNameColumnWidth:(float)width
{
	[[NSUserDefaults standardUserDefaults] setFloat:width forKey:kMFFriendNameColumnWidthPrefKey];
}
- (float)friendNameColumnWidth
{
	return [[NSUserDefaults standardUserDefaults] floatForKey:kMFFriendNameColumnWidthPrefKey];
}

- (void)setFriendStatusColumnWidth:(float)width
{
	[[NSUserDefaults standardUserDefaults] setFloat:width forKey:kMFFriendStatusColumnWidthPrefKey];
}
- (float)friendStatusColumnWidth
{
	return [[NSUserDefaults standardUserDefaults] floatForKey:kMFFriendStatusColumnWidthPrefKey];
}

- (void)setFriendGameColumnWidth:(float)width
{
	[[NSUserDefaults standardUserDefaults] setFloat:width forKey:kMFFriendGameColumnWidthPrefKey];
}
- (float)friendGameColumnWidth
{
	return [[NSUserDefaults standardUserDefaults] floatForKey:kMFFriendGameColumnWidthPrefKey];
}

- (void)setShowWhenTyping:(BOOL)show
{
	[[NSUserDefaults standardUserDefaults] setBool:show forKey:kMFShowWhenTypingPrefKey];
}
- (BOOL)showWhenTyping
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFShowWhenTypingPrefKey];
}

- (void)setShowTimeStampsInChats:(BOOL)show
{
	[[NSUserDefaults standardUserDefaults] setBool:show forKey:kMFShowTimeStampsPrefKey];
}
- (BOOL)showTimeStampsInChats
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFShowTimeStampsPrefKey];
}

- (void)setLogChats:(BOOL)log
{
	[[NSUserDefaults standardUserDefaults] setBool:log forKey:kMFLogChatsPrefKey];
}
- (BOOL)logChats
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFLogChatsPrefKey];
}

- (void)setChatTextFont:(NSFont *)font
{
	[[NSUserDefaults standardUserDefaults] setFont:font forKey:kMFChatTextFontPrefKey];
}
- (NSFont *)chatTextFont
{
	NSFont *f = [[NSUserDefaults standardUserDefaults] fontForKey:kMFChatTextFontPrefKey];
	if( f )
		return f;
	return [[self class] defaultChatTextFont];
}
+ (NSFont *)defaultChatTextFont
{
	return [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
}

// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (void)setDefaultChatColorForFriendsName:(NSColor *)aColor
{
	[[NSUserDefaults standardUserDefaults] setColor:aColor forKey:kMFFriendNameChatColorPrefKey];
}
- (NSColor *)defaultFriendNameChatColor
{
	NSColor *friendColor = [[NSUserDefaults standardUserDefaults] colorForKey:kMFFriendNameChatColorPrefKey];
	
	if (friendColor)
		return friendColor;
	
	return [NSColor colorWithCalibratedRed:(122.0/255.0) green:(36.0/255.0) blue:(33.0/255.0) alpha:1.0];
}

// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (void)setChatColorForMyName:(NSColor *)aColor
{
	[[NSUserDefaults standardUserDefaults] setColor:aColor forKey:kMFMyNameChatColorPrefKey];
}
- (NSColor *)myNameChatColor
{
	NSColor *myColor = [[NSUserDefaults standardUserDefaults] colorForKey:kMFMyNameChatColorPrefKey];
	
	if (myColor)
		return myColor;
	
	return [NSColor colorWithCalibratedRed:(47.0/255.0)  green:(78.0/255.0) blue:(137.0/255.0) alpha:1.0];
}


- (void)setShouldPostGrowlNotifications:(BOOL)post
{
	[[NSUserDefaults standardUserDefaults] setBool:post forKey:kMFPostGrowlNotesPrefKey];
}
- (BOOL)shouldPostGrowlNotifications
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFPostGrowlNotesPrefKey];
}

- (void)setPostGrowlNotificationsWhileActive:(BOOL)post
{
	[[NSUserDefaults standardUserDefaults] setBool:post forKey:kMFPostGrowlWhileActivePrefKey];
}
- (BOOL)postGrowlNotificationsWhileActive
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFPostGrowlWhileActivePrefKey];
}

- (void)setPoseAsNewerXfireClient:(BOOL)pose
{
	[[NSUserDefaults standardUserDefaults] setBool:pose forKey:kMFPoseAsNewerXfirePrefKey];
}
- (BOOL)poseAsNewerXfireClient
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kMFPoseAsNewerXfirePrefKey];
}

- (void)setPosingXfireClientVersion:(unsigned int)version
{
	[[NSUserDefaults standardUserDefaults] setInteger:version forKey:kMFPosingXfireVersionPrefKey];
}
- (unsigned int)posingXfireClientVersion
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kMFPosingXfireVersionPrefKey];
}

- (NSString *)xfireServerHostName
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:kMFXfireServerHostNamePrefKey];
}

- (unsigned int)xfireServerPortNumber
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kMFXfireServerPortNumberPrefKey];
}

@end
