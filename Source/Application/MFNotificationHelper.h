/*******************************************************************
	FILE:		MFNotificationHelper.h
	
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

#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>

@class XfireFriend;

@interface MFNotificationHelper : NSObject <UNUserNotificationCenterDelegate>
{
	BOOL _suspendNotifications;
}

// Shared object
+ (instancetype)helper;

// Request notification authorization from the user (safe to call more than once)
- (void)requestAuthorizationIfNeeded;

// Whether the system notification center is available
- (BOOL)isNotificationCenterAvailable;

// Suspend notifications (useful when logging on)
- (void)setSuspendsNotifications:(BOOL)suspends;

// Post notifications we support
- (void)postFriendCameOnline:(XfireFriend *)fr;
- (void)postFriendWentOffline:(XfireFriend *)fr;
- (void)postFriend:(XfireFriend *)fr chatMessage:(NSString *)aMessage;

@end
