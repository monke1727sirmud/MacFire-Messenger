/*******************************************************************
	FILE:		MFUserIdleMonitor.h
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Monitors the user's activity status.  Posts notifications
		when the user becomes idle or becomes active based on the
		configured timeout.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 11  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

extern NSString *kMFUserBecameIdleNotification;
extern NSString *kMFUserBecameActiveNotification;

@interface MFUserIdleMonitor : NSObject
{
	io_registry_entry_t _hidEntry;
	double _idleNotificationTimeout; // seconds
	NSTimer *_monitorTimer;
	BOOL _idle;
}

+ (id)sharedMonitor;

- (id)initWithIdleTimeout:(double)aTimeout;

- (double)idleNotificationTimeout;
- (void)setIdleNotificationTimeout:(double)aTimeout;

- (BOOL)userIsIdle;

@end
