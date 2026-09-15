/*******************************************************************
	FILE:		MFChatLog.m
	
	COPYRIGHT:
		Copyright 2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Chat logs.  It manages chat history and writing to log file.
	
	HISTORY:
		2009 01 03  Created.
*******************************************************************/

#import "MFChatLog.h"
#import "XfireSession.h"
#import "MFApplicationSupportController.h"

NSString *kMFTimeStampKey = @"TimeStamp";
NSString *kMFMessageKey = @"Message";
NSString *kMFLogKey = @"Log";
NSString *kMFOutgoingKey = @"Outgoing";

@implementation MFChatLog

- (id)init
{
	self = [super init];
	if( self )
	{
		_log = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_log release];
	[_path release];
	
	_log = nil;
	_path = nil;
	
	[super dealloc];
}

- (void)addMessage:(NSString *)msg fromFriend:(XfireFriend *)fr outgoing:(BOOL)outgoing
{
	NSMutableDictionary *logEnt = [NSMutableDictionary dictionary];
	
	[logEnt setObject:[NSDate date] forKey:kMFTimeStampKey];
	[logEnt setObject:[fr userName] forKey:kMFUserNameKey];
	if( [fr nickName] )
		[logEnt setObject:[fr nickName] forKey:kMFNickNameKey];
	[logEnt setObject:[msg copy] forKey:kMFMessageKey];
	if( outgoing )
		[logEnt setObject:[NSNumber numberWithBool:YES] forKey:kMFOutgoingKey];
	
	[_log addObject:logEnt];
	
	[self updateLogFile];
}

- (void)updateLogFile
{
	if( _path )
	{
		[[NSDictionary dictionaryWithObject:_log forKey:kMFLogKey]
			writeToFile:_path
			atomically:NO];
	}
}

- (void)setPath:(NSString *)logFilePath
{
	_path = [[logFilePath copy] retain];
	if( [_log count] > 0 )
	{
		[self updateLogFile];
	}
	else
	{
		// this reserves the file so another won't be created on us
		[[NSDictionary dictionary] writeToFile:_path atomically:NO];
	}
}

@end
