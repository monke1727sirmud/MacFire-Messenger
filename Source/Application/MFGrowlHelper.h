/*******************************************************************
	FILE:		MFGrowlHelper.h
	
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

#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>

@class XfireFriend;

@interface MFGrowlHelper : NSObject <UNUserNotificationCenterDelegate>

// Shared object
+ (MFGrowlHelper *)helper;

// Request notification permission
- (void)requestAuthorization;

// Detect whether notifications are enabled
- (BOOL)isGrowlInstalled;

// Suspend notifications (useful when logging on)
- (void)setSuspendsNotifications:(BOOL)suspends;

// Suspends notifications when the application is in the foreground (the active app)
- (void)setPostsWhileActive:(BOOL)posts;

// Post notifications we support
- (void)postFriendCameOnline:(XfireFriend *)fr;
- (void)postFriendWentOffline:(XfireFriend *)fr;
- (void)postFriend:(XfireFriend *)fr chatMessage:(NSString *)aMessage;

@end
