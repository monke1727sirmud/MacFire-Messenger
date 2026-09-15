/*******************************************************************
	FILE:		MFPreferencesWindowController.h
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The preferences window.  It shows a dialog and updates the
		NSUserDefaults (via MFPreferences) if the user clicks Apply.
		Provides a notification when the preferences are changed.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 03 01  Added Xfire network traffic log pref.
		2007 12 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@interface MFPreferencesWindowController : NSWindowController
{
	IBOutlet NSPopUpButton  *_nameDisplayStyle;
	IBOutlet NSButton       *_setIdleAutomaticallyButton;
	IBOutlet NSButton       *_poseAsRecentXfireClientButton;
	IBOutlet NSButton       *_notifyUsingGrowlButton;
	IBOutlet NSButton       *_notifyWhenInFrontButton;
	IBOutlet NSButton       *_showWhenTypingInChatButton;
	IBOutlet NSButton       *_showChatTimeStampsButton;
	IBOutlet NSButton       *_logChatsButton;
	IBOutlet NSTextField    *_chatFontField;
	IBOutlet NSTextField    *_idleDelayField;
	IBOutlet NSButton       *_logXfireNetworkTrafficButton;
	IBOutlet NSColorWell	*_friendNameColorWell;
	IBOutlet NSColorWell	*_myNameColorWell;
	
	NSFont  *_selectedFont;
}

- (IBAction)resetToDefaults:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)apply:(id)sender;
- (IBAction)deleteChatLogs:(id)sender;
- (IBAction)resetChatFont:(id)sender;
- (IBAction)chooseChatFont:(id)sender;

- (void)synchronizeControlsWithDefaults;

@end
