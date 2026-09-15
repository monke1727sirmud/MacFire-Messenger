/*******************************************************************
	FILE:		MFChatWindowController.m
	
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

#import "MFChatWindowController.h"
#import "MFPreferences.h"
#import "MFGrowlHelper.h"
#import "XfireFriend.h"
#import "XfireChat.h"
#import "XfireSession.h"
#import "XfireFriend_MacFireAdditions.h"
#import "MFUIStrings.h"
#import "MFApplicationSupportController.h"
#import "MFChatLog.h"

static NSDateFormatter *gChatTimeStampFormatter = nil;
static NSColor *gDateColor = nil;

@interface MFChatWindowController (Private)
+ (NSDateFormatter *)chatTimeStampFormatter;
+ (NSColor *)dateColor;
@end

@implementation MFChatWindowController

+ (NSDateFormatter *)chatTimeStampFormatter
{
	if( gChatTimeStampFormatter == nil )
	{
		// see http://developer.apple.com/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html#//apple_ref/doc/uid/TP40002369
		
		gChatTimeStampFormatter = [[NSDateFormatter alloc] init];
		[gChatTimeStampFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[gChatTimeStampFormatter setDateFormat:@"[hh:mm:ss aa] "];
	}
	
	return gChatTimeStampFormatter;
}

+ (NSColor *)dateColor
{
	if( gDateColor == nil )
	{
		gDateColor = [[NSColor colorWithCalibratedRed:(154.0/255.0) green:(145.0/255.0) blue:(151.0/255.0) alpha:1.0] retain];
	}
	return gDateColor;
}

- (id)initWithChat:(XfireChat *)aChat
{
	self = [super initWithWindowNibName:@"ChatWindow"];
	if( self )
	{
		_chat = aChat;
		_log = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(friendDidChange:)
			name:XfireFriendDidChangeNotification
			object:[_chat remoteFriend]];
		
		
		if( [[MFPreferences preferences] logChats] )
		{
			NSString *logPath = [[MFApplicationSupportController sharedController] nextChatLogPathForAccount:[[aChat session] loginIdentity]];
			if( logPath )
			{
				_log = [[MFChatLog alloc] init];
				[_log setPath:logPath];
			}
		}
		
		_scrollUpdatePending = NO;
	}
	return self;
}

- (void)dealloc
{
	_chat = nil;
	
	[_log release];
	_log = nil;
	
	[super dealloc];
}

// There is no -dealloc because the XfireSession owns the _chat and everything else is a nib reference

- (XfireChat *)chat
{
	return _chat;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// TODO: add more?
	[[self window] setTitle:[NSString stringWithFormat:MF_UISTR_CHAT_TITLE, [[_chat remoteFriend] displayNameString]]];
	[self updateFriendSummary];
	
	[[self window] setDelegate:self];
}

- (IBAction)sendMessage:(id)sender
{
	NSString *msg = [chatTypingView stringValue];
	[chatTypingView setStringValue:@""];
	
	if( [msg length] > 0 )
	{
		XfireFriend *me = [[_chat session] loginIdentity];
		[_chat sendMessage:msg];
		[self appendMessage:[self formattedMessage:msg fromFriend:me]];
		
		if( _log )
			[_log addMessage:msg fromFriend:me outgoing:YES];
	}
}

// This method contains contributions partially created by Jasarien
- (NSAttributedString *)formattedMessage:(NSString *)msg fromFriend:(XfireFriend *)aFriend
{
	NSString *shortDispName = [aFriend shortDisplayNameString];
	NSMutableAttributedString *fmtMsg;
	
	NSFont *chatFont = [[MFPreferences preferences] chatTextFont];
	NSFont *boldChatFont = [[NSFontManager sharedFontManager] convertWeight:YES ofFont:chatFont];
	
	NSString *newline = @"";
	NSString *timeStamp = @"";
	
	NSRange boldStyleRange = NSMakeRange(0,0);
	NSRange nameStyleRange = NSMakeRange(0,0);
	NSRange dateStyleRange = NSMakeRange(0,0);
	
	NSColor *nameColor;
	
	// Figure out whether to put a newline on the front
	// We apply a newline in front like this so the chat text fills the entire text view (cleaner that way)
	if( [[chatHistoryView textStorage] length] > 0 )
	{
		newline = @"\n";
		
		// don't make the newline bold or have color applied
		boldStyleRange.location ++;
		nameStyleRange.location ++;
		dateStyleRange.location ++;
	}
	
	if( [[MFPreferences preferences] showTimeStampsInChats] )
	{
		NSDateFormatter *dateFormatter = [MFChatWindowController chatTimeStampFormatter];
		timeStamp = [dateFormatter stringFromDate:[NSDate date]];
		
		// don't make the time stamp have color applied
		nameStyleRange.location += [timeStamp length];
		dateStyleRange.length = [timeStamp length];
	}
	
	nameStyleRange.length = [shortDispName length] + 1; // the name plus colon
	boldStyleRange.length = [timeStamp length] + [shortDispName length] + 1; // the time plus name plus colon
	
	if (aFriend == [[_chat session] loginIdentity])
		nameColor = [[MFPreferences preferences] myNameChatColor];
	else
		nameColor = [[MFPreferences preferences] defaultFriendNameChatColor];
	
	fmtMsg = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat:@"%@%@%@:  %@",newline,timeStamp,shortDispName,msg]];
	
	[fmtMsg addAttribute:NSFontAttributeName value:chatFont     range:NSMakeRange(0,[fmtMsg length])];
	[fmtMsg addAttribute:NSFontAttributeName value:boldChatFont range:boldStyleRange];
	[fmtMsg addAttribute:NSForegroundColorAttributeName value:nameColor range:nameStyleRange];
	if( dateStyleRange.length > 0 )
		[fmtMsg addAttribute:NSForegroundColorAttributeName value:[[self class] dateColor] range:dateStyleRange];
	
	return [fmtMsg autorelease];
}

- (void)appendMessage:(NSAttributedString *)msg
{
	[[chatHistoryView textStorage] appendAttributedString:msg];
	
	if( ! _scrollUpdatePending )
	{
		_scrollUpdatePending = YES;
		
		// This forces the scroll update to be performed after the NSTextView has processed and redrawn the updated text
		// Otherwise the code in -updateScrollPosition will not properly account for the new text (because it hasn't been
		// incorporated yet).
		[self performSelector:@selector(updateScrollPosition) withObject:nil afterDelay:0.1f];
	}
}

- (void)updateScrollPosition
{
	_scrollUpdatePending = NO;
	
	NSClipView   *clipView   = (NSClipView*)[chatHistoryView superview];
	NSScrollView *scrollView = (NSScrollView*)[clipView superview];
	NSRect       tvFrame     = [chatHistoryView frame];
	
	[clipView scrollToPoint:[clipView constrainScrollPoint:NSMakePoint(tvFrame.origin.x,tvFrame.origin.y+tvFrame.size.height)]];
	[scrollView reflectScrolledClipView:clipView];
}

- (void)xfireSession:(XfireSession *)session chat:(XfireChat *)aChat didReceiveMessage:(NSString *)msg
{
	if( ![[self window] isVisible] )
	{
		[self showWindow:self];
	}
	
	[self appendMessage:[self formattedMessage:msg fromFriend:[aChat remoteFriend]]];
	
	if( _log )
		[_log addMessage:msg fromFriend:[aChat remoteFriend] outgoing:NO];
	
	[[MFGrowlHelper helper] postFriend:[aChat remoteFriend] chatMessage:msg];
}

- (void)updateFriendSummary
{
	XfireFriend *fr = [_chat remoteFriend];
	
	NSImage *img = [fr displayImage];
	NSSize sz = NSMakeSize(24,24);
	[img setSize:sz];
	[friendSummaryView setDisplayImageSize:sz];
	[friendSummaryView setImageValue:img];
	[friendSummaryView setFont:[NSFont systemFontOfSize:12.0]];
	[friendSummaryView setStringValue:[fr displayNameString]];
	[friendSummaryView setNeedsDisplay:YES];
	
	[friendStatusView setStringValue:[fr statusDisplayString]];
	[friendStatusView setFont:[NSFont systemFontOfSize:10.0]];
	[friendStatusView setNeedsDisplay:YES];
}

- (void)windowWillClose:(NSNotification *)aNote
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_chat closeChat];
}

- (void)friendDidChange:(NSNotification *)aNote
{
	XfireFriendChangeAttribute attr = [[[aNote userInfo] objectForKey:kXfireFriendChangeAttribute] intValue];
	
	switch( attr )
	{
		case kXfireFriendNicknameDidChange:
			[self updateFriendSummary];
			break;
		case kXfireFriendOnlineStatusDidChange:
			{
				if( [[aNote object] isOnline] )
				{
					[sendChatButton setEnabled:YES];
					[chatTypingView setEnabled:YES];
				}
				else
				{
					[sendChatButton setEnabled:NO];
					[chatTypingView setEnabled:NO];
				}
				[self updateFriendSummary];
			}
			break;
		case kXfireFriendGameInfoDidChange:
			[self updateFriendSummary];
			break;
		case kXfireFriendStatusStringDidChange:
			[self updateFriendSummary];
			break;
	}
}

@end
