/*******************************************************************
	FILE:		MFGrowlHelper.h
	
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

#import <Cocoa/Cocoa.h>
#import <Growl/GrowlApplicationBridge.h>

@class XfireFriend;

@interface MFGrowlHelper : NSObject <GrowlApplicationBridgeDelegate>
{
	NSData *_icon;
	BOOL   _suspendNotifications;
	BOOL   _postsWhileActive;
}

// Shared object
+ (MFGrowlHelper *)helper;

// Detect whether Growl is installed
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
