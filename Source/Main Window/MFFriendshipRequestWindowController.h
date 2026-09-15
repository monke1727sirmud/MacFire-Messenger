/*******************************************************************
	FILE:		MFFriendshipRequestWindowController.h
	
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

#import <Cocoa/Cocoa.h>

@class XfireSession;
@class XfireFriend;
@class MFMainWindowController;

@interface MFFriendshipRequestWindowController : NSWindowController
{
	IBOutlet NSTextField *_requestTextField;
	IBOutlet NSTextField *_messageTextField;
	
	XfireSession *_xfSession;
	XfireFriend *_requestor;
	NSString *_message;
	MFMainWindowController *_mainWindow;
}

- (id)initWithSession:(XfireSession *)session requestor:(XfireFriend *)fr message:(NSString *)msg mainWindow:(MFMainWindowController *)mainWindow;
- (void)runModalForWindow:(NSWindow *)win;

- (IBAction)deferRequest:(id)sender;
- (IBAction)declineRequest:(id)sender;
- (IBAction)acceptRequest:(id)sender;
- (IBAction)showProfile:(id)sender;

@end
