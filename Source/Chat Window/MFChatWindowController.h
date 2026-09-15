/*******************************************************************
	FILE:		MFChatWindowController.h
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The chat window.  It's basically a text view that shows each
		message sent between people.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 01 06  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

#import "XfireSession.h"
#import "MFImageAndTextView.h"

@class MFChatLog;

@interface MFChatWindowController : NSWindowController
{
	IBOutlet NSTextView  *chatHistoryView;
	IBOutlet NSTextField *chatTypingView;
	IBOutlet NSButton    *sendChatButton;
	
	IBOutlet MFImageAndTextView *friendSummaryView;
	IBOutlet MFImageAndTextView *friendStatusView;
	
	XfireChat *_chat;
	MFChatLog *_log;
	
	BOOL _scrollUpdatePending;
}

- (id)initWithChat:(XfireChat *)aChat;
- (XfireChat *)chat;

- (IBAction)sendMessage:(id)sender;

- (NSAttributedString *)formattedMessage:(NSString *)msg fromFriend:(XfireFriend *)aFriend;
- (void)appendMessage:(NSAttributedString *)msg;

- (void)updateFriendSummary;

@end
