/*******************************************************************
	FILE:		MFApplicationDelegate.h
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The NSApplication's delegate.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 16  Removed stored list of sessions.
		2007 12 07  Added Preferences window support.
		2007 12 02  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class MFPreferencesWindowController;
@class MFMainWindowController;

@interface MFApplicationDelegate : NSObject
{
	MFMainWindowController *_mainWindow;
	MFPreferencesWindowController *_preferenceController;
}

- (IBAction)showPreferencePanel:(id)sender;
- (IBAction)showMainWindow:(id)sender;

@end
