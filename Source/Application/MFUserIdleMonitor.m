/*******************************************************************
	FILE:		MFUserIdleMonitor.m
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Monitors the user's activity status.  Posts notifications
		when the user becomes idle or becomes active based on the
		configured timeout.
		
		This implementation polls the IOHIDSystem object in the
		kernel's IOKit registry.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 11  Created.
*******************************************************************/

#import "MFUserIdleMonitor.h"
#import <IOKit/IOKitLib.h>

// Reference implementation found at: http://www.cocoabuilder.com/archive/message/cocoa/2004/10/26/120263
// I made some modifications based on what I saw in the IOKit documentation.

NSString *kMFUserBecameIdleNotification = @"MFUserBecameIdleNotification";
NSString *kMFUserBecameActiveNotification = @"MFUserBecameActiveNotification";

@interface MFUserIdleMonitor (Private)
- (double)idleTimeInSeconds;
- (uint64_t)idleTime;
- (void)timerExpired:(NSTimer *)tmr;
@end

static MFUserIdleMonitor *gSharedMonitor = nil;

@implementation MFUserIdleMonitor

+ (id)sharedMonitor
{
	if( gSharedMonitor == nil )
		gSharedMonitor = [[MFUserIdleMonitor alloc] initWithIdleTimeout:120.0];
	return gSharedMonitor;
}

- (id)initWithIdleTimeout:(double)aTimeout
{
	self = [super init];
	if( self )
	{
		_hidEntry = nil;
		
		io_iterator_t hidIter;
		kern_return_t err = IOServiceGetMatchingServices( kIOMasterPortDefault, IOServiceMatching("IOHIDSystem"), &hidIter );
		if( err != 0 )
		{
			[self release];
			[NSException raise:@"MFUserIdleMonitorException" format:@"Kernel returned error %d", (int)err];
		}
		if( hidIter == nil )
		{
			[self release];
			[NSException raise:@"MFUserIdleMonitorException" format:@"Kernel returned nil HID iterator"];
		}
		
		_hidEntry = IOIteratorNext( hidIter );
		IOObjectRelease(hidIter);
		if( _hidEntry == nil )
		{
			[self release];
			[NSException raise:@"MFUserIdleMonitorException" format:@"HID iterator could not find IOHIDSystem object"];
		}
		
		if( aTimeout <= 0.0 )
			aTimeout = 120.0;
		_idleNotificationTimeout = aTimeout;
		
		_monitorTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
			target:self
			selector:@selector(timerExpired:)
			userInfo:nil
			repeats:YES];
		_idle = NO;
	}
	return self;
}

- (void)dealloc
{
	if( _hidEntry )
		IOObjectRelease(_hidEntry);
	_hidEntry = nil;
	[_monitorTimer invalidate];
	[super dealloc];
}

// We only care about the one value: the HIDIdleTime.
// So, we refrain from getting the entire dictionary.
// I hope this is less costly, resource-wise, than the reference implementation which retrieved the entire dictionary first.
- (uint64_t)idleTime
{
	uint64_t result = 0ULL;
	id idleTimeObj = (id)IORegistryEntryCreateCFProperty(_hidEntry,(CFStringRef)@"HIDIdleTime",kCFAllocatorDefault,0);
	
	if( [idleTimeObj isKindOfClass:[NSData class]] )
	{
		NSData *dat = idleTimeObj;
		if( [dat length] == sizeof(result) )
		{
			[dat getBytes:&result];
		}
	}
	else if( [idleTimeObj isKindOfClass:[NSNumber class]] )
	{
		NSNumber *nbr = idleTimeObj;
		result = [nbr unsignedLongLongValue];
	}
	
	if( idleTimeObj != nil )
		CFRelease((CFTypeRef)idleTimeObj);
	
	return result;
}

- (double)idleTimeInSeconds
{
	uint64_t it = [self idleTime];
	unsigned sec = ((unsigned)(it/1000000000));
	unsigned ms  = ((unsigned)(it%1000000000));
	
	return ((double)sec) + ((double)(ms/1e9));
}

- (double)idleNotificationTimeout
{
	return _idleNotificationTimeout;
}

// This may be called if the user changes their preferences in the middle of the session
// It should be okay ... when the timerExpired: handler is called it checks for idle time
// right away.  In either case, the shortest interval is 1 min, and the user must have just
// moved their mouse (e.g. not idle).
- (void)setIdleNotificationTimeout:(double)aTimeout
{
	_idleNotificationTimeout = aTimeout;
}

- (BOOL)userIsIdle
{
	return _idle;
}

- (void)timerExpired:(NSTimer *)tmr
{
	double newTime = [self idleTimeInSeconds];
	if( _idle && (newTime < 1.0) ) // something happened within the last second
	{
		_idle = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:kMFUserBecameActiveNotification object:self];
	}
	else if( (!_idle) && (newTime > _idleNotificationTimeout) )
	{
		_idle = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:kMFUserBecameIdleNotification object:self];
	}
}

@end
