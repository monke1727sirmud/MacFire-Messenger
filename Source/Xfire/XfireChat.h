/*******************************************************************
	FILE:		XfireChat.h
	
	COPYRIGHT:
		Copyright 2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Represents a chat conversation between two users.  Needs work...
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 01 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class XfireFriend;
@class XfireSession;
@class XfireConnection;

@interface XfireChat : NSObject
{
	XfireFriend			*remoteFriend;
	XfireConnection		*conn;
	unsigned int		sendSeqNo;
	__weak id				_delegate;
}

// This is the friend you will chat with
- (id)initWithRemoteFriend:(XfireFriend *)aFriend connection:(XfireConnection *)aConn;

// The person on the other end of this chat conversation
- (XfireFriend *)remoteFriend;

// Sending messages
- (void)sendMessage:(NSString *)message;

// Session using this
- (XfireSession *)session;

- (NSData *)sessionID;

// Chat delegation
- (void)setDelegate:(id)aDelegate;
- (id)delegate;

// This tells the owning session to drop its reference to the chat
- (void)closeChat;

@end

@interface NSObject (XfireChatDelegate)
- (void)xfireSession:(XfireSession *)session chat:(XfireChat *)aChat didReceiveMessage:(NSString *)msg;
@end

