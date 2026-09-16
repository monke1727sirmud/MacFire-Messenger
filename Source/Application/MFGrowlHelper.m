/*******************************************************************
	FILE:		MFGrowlHelper.m
	
	COPYRIGHT:
		Copyright 2007-2026, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Helps support user notifications using the modern macOS
		UserNotifications framework (replaces the old Growl-based
		notifications).
	
	HISTORY:
		2026 09 15  Replaced Growl with native macOS UserNotifications.
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
- (void)postNotificationTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier;
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
		
		[UNUserNotificationCenter currentNotificationCenter].delegate = self;
		[self requestAuthorization];
	}
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)requestAuthorization
{
	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound;
	[center requestAuthorizationWithOptions:options
		completionHandler:^(BOOL granted, NSError *error) {
			if( !granted )
			{
				NSLog(@"Notification authorization was not granted");
			}
		}];
}

// Detect whether notifications are enabled
- (BOOL)isGrowlInstalled
{
	__block BOOL enabled = NO;
	UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
	dispatch_semaphore_t sem = dispatch_semaphore_create(0);
	[center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
		enabled = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
		dispatch_semaphore_signal(sem);
	}];
	dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
	return enabled;
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
		[self postNotificationTitle:MF_UISTR_GROWL_ONLINE_MAJ
			body:[NSString stringWithFormat:MF_UISTR_GROWL_ONLINE_MIN, [fr displayNameString]]
			identifier:kMFGrowlFriendCameOnlineKey];
	}
}

- (void)postFriendWentOffline:(XfireFriend *)fr
{
	if( [self shouldPost] )
	{
		[self postNotificationTitle:MF_UISTR_GROWL_OFFLINE_MAJ
			body:[NSString stringWithFormat:MF_UISTR_GROWL_OFFLINE_MIN, [fr displayNameString]]
			identifier:kMFGrowlFriendWentOfflineKey];
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
		
		[self postNotificationTitle:[NSString stringWithFormat:MF_UISTR_GROWL_CHAT_MAJ, [fr shortDisplayNameString]]
			body:[NSString stringWithFormat:MF_UISTR_GROWL_CHAT_MIN, msg]
			identifier:kMFGrowlFriendSentMessageKey];
	}
}

- (void)postNotificationTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier
{
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = title;
	content.body = body;
	content.sound = [UNNotificationSound defaultSound];
	
	UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger
		triggerWithTimeInterval:0.1 repeats:NO];
	
	NSString *uuidStr = [[NSUUID UUID] UUIDString];
	UNNotificationRequest *request = [UNNotificationRequest
		requestWithIdentifier:uuidStr
		content:content
		trigger:trigger];
	
	[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
		withCompletionHandler:^(NSError *error) {
			if( error )
			{
				NSLog(@"Error posting notification: %@", error);
			}
		}];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
	willPresentNotification:(UNNotification *)notification
	withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
	if( _postsWhileActive )
	{
		completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
	}
	else
	{
		completionHandler(UNNotificationPresentationOptionNone);
	}
}

@end
