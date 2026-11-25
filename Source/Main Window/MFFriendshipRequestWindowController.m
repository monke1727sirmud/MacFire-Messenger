/*******************************************************************
	FILE:		MFFriendshipRequestWindowController.m
	
	COPYRIGHT:
		Copyright 2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The friend request window.  Displays the message from the
		requestor and options to accept or decline the invitation.
		
		The window runs as a sheet attached to the main window.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 03 02  Created.
*******************************************************************/

#import "MFFriendshipRequestWindowController.h"
#import "XfireSession.h"
#import "XfireFriend.h"
#import "XfireFriend_MacFireAdditions.h"
#import "MFUIStrings.h"
#import "MFMainWindowController.h"

@implementation MFFriendshipRequestWindowController

- (instancetype)initWithSession:(XfireSession *)session requestor:(XfireFriend *)fr message:(NSString *)msg mainWindow:(MFMainWindowController *)mainWindow
{
	self = [super initWithWindowNibName:@"FriendshipRequestWindow"];
	if( self )
	{
		_xfSession = session;
		_requestor = fr;
		_message = [msg copy];
		_mainWindow = mainWindow;
	}
	return self;
}

- (void)runModalForWindow:(NSWindow *)win
{
	[self window]; // forces load if not already loaded
	
	NSString *tmp = [_requestTextField stringValue];
	tmp = [NSString stringWithFormat:tmp, [_requestor displayNameString]];
	[_requestTextField setStringValue:tmp];
	
	[_messageTextField setStringValue:_message];
	
	NSWindow *sheet = [self window];
	[win beginSheet:sheet completionHandler:^(NSModalResponse returnCode) {
		[sheet orderOut:self];

		if( returnCode == -1 )
		{
			[self->_xfSession declineFriendRequest:self->_requestor];
		}
		else if( returnCode == 1 )
		{
			[self->_xfSession acceptFriendRequest:self->_requestor];
		}

		// Keep this controller alive while the main window drops its reference to it.
		MFFriendshipRequestWindowController *keepAlive = self;
		[self->_mainWindow friendRequestControllerDidFinish:self];
		[self->_mainWindow friendRequestSheetDidEnd];
		(void)keepAlive;
	}];
}

- (IBAction)deferRequest:(id)sender
{
	[[[self window] sheetParent] endSheet:[self window] returnCode:0];
}

- (IBAction)declineRequest:(id)sender
{
	[[[self window] sheetParent] endSheet:[self window] returnCode:-1];
}

- (IBAction)acceptRequest:(id)sender
{
	[[[self window] sheetParent] endSheet:[self window] returnCode:1];
}

- (IBAction)showProfile:(id)sender
{
	[_requestor showProfile];
}

@end
