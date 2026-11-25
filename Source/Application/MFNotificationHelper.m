/*******************************************************************
	FILE:		MFNotificationHelper.m
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Posts user notifications (friends coming online/offline and
		incoming chat messages) using the UserNotifications framework.
	
	HISTORY:
		2026 11 25  Replaced the retired Growl framework with
		            UserNotifications.
		2008 04 06  Changed copyright to BSD license.
		2007 12 02  Created.
*******************************************************************/

#import "MFNotificationHelper.h"
#import "MFPreferences.h"
#import "XfireSession.h"
#import "XfireFriend_MacFireAdditions.h"
#import "MFUIStrings.h"

static MFNotificationHelper *gSharedHelper = nil;

static NSString * const kMFNotificationFriendCameOnlineIdentifier = @"MFNotificationFriendCameOnline";
static NSString * const kMFNotificationFriendWentOfflineIdentifier = @"MFNotificationFriendWentOffline";
static NSString * const kMFNotificationFriendSentMessageIdentifier = @"MFNotificationFriendSentMessage";

@interface MFNotificationHelper (Private)
- (BOOL)shouldPost;
- (void)postNotificationWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier;
@end

@implementation MFNotificationHelper

+ (instancetype)helper
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		gSharedHelper = [[MFNotificationHelper alloc] init];
	});
	return gSharedHelper;
}

- (instancetype)init
{
	self = [super init];
	if( self )
	{
		_suspendNotifications = NO;
		_postsWhileActive = NO;
		[self requestAuthorizationIfNeeded];
	}
	return self;
}

- (void)requestAuthorizationIfNeeded
{
	if( ![self isNotificationCenterAvailable] )
		return;

	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	center.delegate = self;

	[center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
		completionHandler:^(BOOL granted, NSError *error) {
			if( !granted )
			{
				NSLog(@"[MacFire] Notification authorization was not granted%@",
					error ? [NSString stringWithFormat:@": %@", error] : @"");
			}
		}];
}

// Detect whether the system notification center is available
- (BOOL)isNotificationCenterAvailable
{
	return (NSClassFromString(@"UNUserNotificationCenter") != nil);
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
	if( [[MFPreferences preferences] shouldPostNotifications] )
	{
		if( ![self isNotificationCenterAvailable] )
			return NO;
		
		if( _suspendNotifications )
			return NO;
		
		if( [[NSApplication sharedApplication] isActive] )
			return [[MFPreferences preferences] postNotificationsWhileActive];
		
		return YES;
	}
	
	return NO;
}

- (void)postFriendCameOnline:(XfireFriend *)fr
{
	if( [self shouldPost] )
	{
		[self
			postNotificationWithTitle:MF_UISTR_NOTIFICATION_ONLINE_MAJ
			body:[NSString stringWithFormat:MF_UISTR_NOTIFICATION_ONLINE_MIN, [fr displayNameString]]
			identifier:kMFNotificationFriendCameOnlineIdentifier];
	}
}

- (void)postFriendWentOffline:(XfireFriend *)fr
{
	if( [self shouldPost] )
	{
		[self
			postNotificationWithTitle:MF_UISTR_NOTIFICATION_OFFLINE_MAJ
			body:[NSString stringWithFormat:MF_UISTR_NOTIFICATION_OFFLINE_MIN, [fr displayNameString]]
			identifier:kMFNotificationFriendWentOfflineIdentifier];
	}
}

- (void)postFriend:(XfireFriend *)fr chatMessage:(NSString *)aMessage
{
	if( [self shouldPost] )
	{
		NSString *msg = aMessage;
		if( [aMessage length] > 50 )
		{
			msg = [[aMessage substringToIndex:50] stringByAppendingString:@"..."];
		}
		
		[self
			postNotificationWithTitle:[NSString stringWithFormat:MF_UISTR_NOTIFICATION_CHAT_MAJ, [fr shortDisplayNameString]]
			body:[NSString stringWithFormat:MF_UISTR_NOTIFICATION_CHAT_MIN, msg]
			identifier:kMFNotificationFriendSentMessageIdentifier];
	}
}

- (void)postNotificationWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier
{
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = title;
	content.body = body;
	content.sound = [UNNotificationSound defaultSound];
	
	NSString *uniqueIdentifier = [NSString stringWithFormat:@"%@-%@", identifier, [[NSUUID UUID] UUIDString]];
	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:uniqueIdentifier
		content:content
		trigger:nil];
	
	[[UNUserNotificationCenter currentNotificationCenter]
		addNotificationRequest:request
		withCompletionHandler:^(NSError *error) {
			if( error )
			{
				NSLog(@"[MacFire] Unable to post notification: %@", error);
			}
		}];
}

///////////////////////////
// Notification delegate
///////////////////////////

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
	willPresentNotification:(UNNotification *)notification
	withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
	// shouldPost already suppresses notifications while the app is active,
	// so anything that arrives here is meant to be shown.
	completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

@end
