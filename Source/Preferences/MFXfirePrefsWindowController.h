/*******************************************************************
	FILE:		MFXfirePrefsWindowController.h
	
	COPYRIGHT:
		Copyright 2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Manages the user options window.  These are options that are
		stored and managed by the Xfire server.
	
	HISTORY:
		2008 10 13  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class XfireSession;

@interface MFXfirePrefsWindowController : NSWindowController
{
	IBOutlet NSTextField    *_nicknameField;
	IBOutlet NSButton       *_showOfflineFriendsButton;
	IBOutlet NSButton       *_showWhenITypeButton;
	IBOutlet NSButton       *_showChatTimeStampButton;
	IBOutlet NSButton       *_showMyFriendsButton;
	IBOutlet NSButton       *_showGameStatusOnProfileButton;
	IBOutlet NSButton       *_showGameServerDataButton;
	IBOutlet NSButton       *_showFriendsOfFriendsButton;
	
	XfireSession *_session;
}

- (id)initWithSession:(XfireSession *)aSession;

- (IBAction)cancel:(id)sender;
- (IBAction)apply:(id)sender;

@end
