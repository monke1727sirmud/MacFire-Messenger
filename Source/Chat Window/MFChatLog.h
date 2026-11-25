/*******************************************************************
	FILE:		MFChatLog.h
	
	COPYRIGHT:
		Copyright 2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Chat logs.  It manages chat history and writing to log file.
	
	HISTORY:
		2009 01 03  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class XfireFriend;

@interface MFChatLog : NSObject
{
	NSMutableArray *_log;
	NSString *_path;
}

// use -init
// eventually we'll add either -initWithContentsOfFile: or a -readFile: method

- (void)setPath:(NSString *)logFilePath;

- (void)addMessage:(NSString *)msg fromFriend:(XfireFriend *)fr outgoing:(BOOL)outgoing;

- (void)updateLogFile;

@end
