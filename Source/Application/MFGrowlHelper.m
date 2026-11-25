/*******************************************************************
	FILE:		MFGrowlHelper.m
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Helps support Growl notifications we use.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 02  Created.
*******************************************************************/

#import "MFGrowlHelper.h"
#import "MFPreferences.h"
#import "XfireSession.h"
#import "XfireFriend_MacFireAdditions.h"
#import "MFUIStrings.h"

static MFGrowlHelper *gSharedHelper = nil;

NSString *kMFGrowlFriendCameOnlineKey = @"Friend came online";
NSString *kMFGrowlFriendWentOfflineKey = @"Friend went offline";
NSString *kMFGrowlFriendSentMessageKey = @"Friend sent a message";

@interface MFGrowlHelper (Private)
- (void)postGrowlNotificationTitle:(NSString *)title description:(NSString *)aDesc noteName:(NSString *)name;
- (BOOL)shouldPost;
@end

@implementation MFGrowlHelper

+ (MFGrowlHelper *)helper
{
	if( gSharedHelper == nil )
	{
		gSharedHelper = [[MFGrowlHelper alloc] init];
	}
	return gSharedHelper;
}

- (id)init
{
	self = [super init];
	if( self )
	{
		_suspendNotifications = NO;
		_postsWhileActive = NO;
		_icon = nil;
		
		// load Growl
		NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
		NSString *growlPath = [[myBundle privateFrameworksPath] stringByAppendingPathComponent:@"Growl.framework"];
		NSBundle *growlBundle = [NSBundle bundleWithPath:growlPath];
		if( growlBundle )
		{
			[growlBundle load];
			[GrowlApplicationBridge setGrowlDelegate:self];
		}
	}
	return self;
}

- (void)dealloc
{
	[_icon release];
	_icon = nil;
	
	[super dealloc];
}

// Detect whether Growl is installed
- (BOOL)isGrowlInstalled
{
	return [GrowlApplicationBridge isGrowlInstalled];
}

// Suspend notifications (useful when logging on)
- (void)setSuspendsNotifications:(BOOL)suspends
{
	_suspendNotifications = suspends;
}

// Suspends notifications when the application is in the foreground (the active app)
- (void)setPostsWhileActive:(BOOL)posts
{
	_postsWhileActive = posts;
}

// Helper
- (BOOL)shouldPost
{
	if( [[MFPreferences preferences] shouldPostGrowlNotifications] )
	{
		if( ! [self isGrowlInstalled] )
			return NO;
		
		if( _suspendNotifications )
			return NO;
		
		if( [NSApp isActive] )
			return [[MFPreferences preferences] postGrowlNotificationsWhileActive];
		
		return YES;
	}
	
	return NO;
}

- (void)postFriendCameOnline:(XfireFriend *)fr
{
	if( [self shouldPost] )
	{
		[self
			postGrowlNotificationTitle:MF_UISTR_GROWL_ONLINE_MAJ
			description:[NSString stringWithFormat:MF_UISTR_GROWL_ONLINE_MIN, [fr displayNameString]]
			noteName:kMFGrowlFriendCameOnlineKey];
	}
}

- (void)postFriendWentOffline:(XfireFriend *)fr
{
	if( [self shouldPost] )
	{
		[self
			postGrowlNotificationTitle:MF_UISTR_GROWL_OFFLINE_MAJ
			description:[NSString stringWithFormat:MF_UISTR_GROWL_OFFLINE_MIN, [fr displayNameString]]
			noteName:kMFGrowlFriendWentOfflineKey];
	}
}

- (void)postFriend:(XfireFriend *)fr chatMessage:(NSString *)aMessage
{
	if( [self shouldPost] )
	{
		NSString *msg = aMessage;
		if( [aMessage length] > 50 )
		{
			msg = [[aMessage substringToIndex:5] stringByAppendingString:@"..."];
		}
		
		[self
			postGrowlNotificationTitle:[NSString stringWithFormat:MF_UISTR_GROWL_CHAT_MAJ, [fr shortDisplayNameString]]
			description:[NSString stringWithFormat:MF_UISTR_GROWL_CHAT_MIN, msg]
			noteName:kMFGrowlFriendSentMessageKey];
	}
}

- (void)postGrowlNotificationTitle:(NSString *)title description:(NSString *)aDesc noteName:(NSString *)name
{
	if( _icon == nil )
	{
		_icon = [[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MacFire" ofType:@"icns"]] retain];
	}
	
	[GrowlApplicationBridge
		notifyWithTitle:title
		description:aDesc
		notificationName:name
		iconData:_icon
		priority:0
		isSticky:NO
		clickContext:nil];
}

///////////////////////////
// Growl Delegate Methods
///////////////////////////

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	NSArray *notes = [NSArray arrayWithObjects:
		kMFGrowlFriendCameOnlineKey,
		kMFGrowlFriendWentOfflineKey,
		kMFGrowlFriendSentMessageKey,
		nil];
	[d setObject:notes forKey:GROWL_NOTIFICATIONS_ALL];
	[d setObject:notes forKey:GROWL_NOTIFICATIONS_DEFAULT];
	
	return d;
}

- (NSString *)applicationNameForGrowl
{
	return @"MacFire";
}

@end
