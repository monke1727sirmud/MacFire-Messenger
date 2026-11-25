/*******************************************************************
	FILE:		MFApplicationDelegate.m
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The NSApplication's delegate.
		Currently just creates the main window.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 16  Removed stored list of sessions.
		2007 12 07  Added Preferences window support.
		2007 12 02  Created.
*******************************************************************/

#import "MFApplicationDelegate.h"
#import "MFMainWindowController.h"
#import "MFGrowlHelper.h"
#import "MFPreferences.h"
#import "MFGameRegistry.h"
#import "MFUserIdleMonitor.h"
#import "MFGameMonitor.h"
#import "MFPreferencesWindowController.h"
#import "MFApplicationSupportController.h"

@implementation MFApplicationDelegate

- (id)init
{
	self = [super init];
	if( self )
	{
		_mainWindow = nil;
		_preferenceController = nil;
	}
	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// Forces preferences to be set
	[MFPreferences preferences];
	
	// Forces game registry to load
	[MFGameRegistry registry];
	
	// Forces game monitor to start
	[MFGameMonitor sharedMonitor];
	
	// Start the user idle monitor
	[[MFUserIdleMonitor sharedMonitor] setIdleNotificationTimeout:(60.0 * [[MFPreferences preferences] idleStatusDelay])];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Forces Growl to load
	[MFGrowlHelper helper];
	
	// Forces application support folders to be created if they don't yet exist
	[MFApplicationSupportController sharedController];
	
	// Create the main window with log-in prompt
	_mainWindow = [[MFMainWindowController alloc] init];
	[_mainWindow showWindow:self];
}

- (IBAction)showPreferencePanel:(id)sender
{
	if( _preferenceController == nil )
	{
		_preferenceController = [[MFPreferencesWindowController alloc] init];
	}
	
	[_preferenceController showWindow:sender];
}

- (IBAction)showMainWindow:(id)sender
{
	[_mainWindow showWindow:sender];
}

@end
