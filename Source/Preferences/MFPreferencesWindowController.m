/*******************************************************************
	FILE:		MFPreferencesWindowController.m
	
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
		2008 01 06  Added code to detect whether Growl is installed.
		2007 12 07  Created.
*******************************************************************/

#import "MFPreferencesWindowController.h"
#import "MFPreferences.h"
#import "MFGrowlHelper.h"
#import "MFUserIdleMonitor.h"
#import "MFSoundManager.h"

@implementation MFPreferencesWindowController

- (id)init
{
	self = [super initWithWindowNibName:@"PreferencesWindow"];
	if( self )
	{
		_selectedFont = nil;
	}
	return self;
}

- (void)windowDidLoad
{
	[self synchronizeControlsWithDefaults];
	
	[_chatFontField setEditable:NO];
}

- (void)showWindow:(id)sender
{
	if( [self isWindowLoaded] )
		[self synchronizeControlsWithDefaults];
	
	[super showWindow:sender];
}

#define SET_CHECKBOX( _name_, _state_ ) [(_name_) setState:((_state_) ? NSOnState : NSOffState)]
- (void)synchronizeControlsWithDefaults
{
	MFPreferences *prefs = [MFPreferences preferences];
	
	[_nameDisplayStyle selectItemWithTag:[prefs nameDisplayStyle]];
	
	SET_CHECKBOX( _setIdleAutomaticallyButton, [prefs showIdleStatusAutomatically] );
	SET_CHECKBOX( _poseAsRecentXfireClientButton, [prefs poseAsNewerXfireClient] );
	SET_CHECKBOX( _notifyUsingGrowlButton, [prefs shouldPostGrowlNotifications] );
	SET_CHECKBOX( _notifyWhenInFrontButton, [prefs postGrowlNotificationsWhileActive] );
	SET_CHECKBOX( _showWhenTypingInChatButton, [prefs showWhenTyping] );
	SET_CHECKBOX( _showChatTimeStampsButton, [prefs showTimeStampsInChats] );
	SET_CHECKBOX( _logChatsButton, [prefs logChats] );
	SET_CHECKBOX( _logXfireNetworkTrafficButton, [prefs logXfireNetworkTraffic] );
	
	if( ! [[MFGrowlHelper helper] isGrowlInstalled] )
	{
		[_notifyUsingGrowlButton setEnabled:NO];
		[_notifyWhenInFrontButton setEnabled:NO];
	}
	
	// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
	[_friendNameColorWell setColor:[prefs defaultFriendNameChatColor]];
	[_myNameColorWell setColor:[prefs myNameChatColor]];
	
	NSFont *f = [prefs chatTextFont];
	[_chatFontField setStringValue:[NSString stringWithFormat:@"%@ - %.0f", [f displayName], [f pointSize]]];
	[_idleDelayField setStringValue:[NSString stringWithFormat:@"%d", [prefs idleStatusDelay]]];
	
	// TODO: figure out how to handle notification sounds
#if 0
	{
		NSArray *sounds = [[MFSoundManager sharedManager] pathsOfAvailableSounds];
		NSString *path;
		int i, cnt;
		cnt = [sounds count];
		for( i = 0; i < cnt; i++ )
		{
			path = [sounds objectAtIndex:i];
			NSLog(@" %@",[[path lastPathComponent] stringByDeletingPathExtension]);
		}
	}
#endif
	
}
#undef SET_CHECKBOX

// TODO: figure out why we get a Cocoa error after doing a reset, then work around it.
- (IBAction)resetToDefaults:(id)sender
{
	NSBeep();
//	[MFPreferences resetPreferences];
//	[NSUserDefaults resetStandardUserDefaults];
//	[NSUserDefaults 
	[self synchronizeControlsWithDefaults];
}

- (IBAction)cancel:(id)sender
{
	[[[NSFontManager sharedFontManager] fontPanel:NO] orderOut:sender];
	[[self window] orderOut:sender];
}

#define GET_CHECKBOX( _name_ ) (([(_name_) state] == NSOnState)?YES:NO)
- (IBAction)apply:(id)sender
{
	MFPreferences *prefs = [MFPreferences preferences];
	
	[prefs setNameDisplayStyle:[_nameDisplayStyle selectedTag]];
	[prefs setShowIdleStatusAutomatically:GET_CHECKBOX(_setIdleAutomaticallyButton)];
	[prefs setPoseAsNewerXfireClient:GET_CHECKBOX(_poseAsRecentXfireClientButton)];
	[prefs setShouldPostGrowlNotifications:GET_CHECKBOX(_notifyUsingGrowlButton)];
	[prefs setPostGrowlNotificationsWhileActive:GET_CHECKBOX(_notifyWhenInFrontButton)];
	[prefs setShowWhenTyping:GET_CHECKBOX(_showWhenTypingInChatButton)];
	[prefs setShowTimeStampsInChats:GET_CHECKBOX(_showChatTimeStampsButton)];
	[prefs setLogChats:GET_CHECKBOX(_logChatsButton)];
	[prefs setLogXfireNetworkTraffic:GET_CHECKBOX(_logXfireNetworkTrafficButton)];
	
	// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
	[prefs setDefaultChatColorForFriendsName:[_friendNameColorWell color]];
	[prefs setChatColorForMyName:[_myNameColorWell color]];
	
	unsigned int idleMonitorTimeout = [[_idleDelayField stringValue] intValue];
	if( idleMonitorTimeout != [prefs idleStatusDelay] )
	{
		[prefs setIdleStatusDelay:idleMonitorTimeout];
		
		// Need to change this here so it takes effect
		[[MFUserIdleMonitor sharedMonitor] setIdleNotificationTimeout:(60.0*idleMonitorTimeout)];
	}
	
	if( ! [[prefs chatTextFont] isEqual:_selectedFont] )
	{
		[prefs setChatTextFont:_selectedFont];
	}
	
	// Make sure they are written to disk
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// Notify observers
	[[NSNotificationCenter defaultCenter]
		postNotificationName:MFPreferencesChangedNotificationName
		object:self];
	
	// Hide the window and the font panel (if it exists)
	// Don't release it
	[[[NSFontManager sharedFontManager] fontPanel:NO] orderOut:sender];
	[[self window] orderOut:sender];
}
#undef GET_CHECKBOX

- (IBAction)deleteChatLogs:(id)sender
{
}

- (IBAction)resetChatFont:(id)sender
{
	[_selectedFont release];
	_selectedFont = [[MFPreferences defaultChatTextFont] retain];
	[_chatFontField setStringValue:[NSString stringWithFormat:@"%@ - %.0f", [_selectedFont displayName], [_selectedFont pointSize]]];
}

- (IBAction)chooseChatFont:(id)sender
{
	NSFontManager *sharedMgr = [NSFontManager sharedFontManager];
	[sharedMgr orderFrontFontPanel:self];
	
	// This next line is completely not intuitive and Apple's documentation is largely misleading.  So, thanks to
	// Scott Anguish at Stepwise and his helpful example:
	//   http://www.stepwise.com/Articles/Technical/HTMLEditor/HTMLEditor-5.1.html
	// Basically, -changeFont: only gets called down the responder chain and not to the delegate of NSFontManager.
	// You can use -setTarget: on 10.5, but for now I need to support 10.4.  As the NSWindowController subclass for
	// the preferences window we will get called if we force the first responder like this.  Ugh.
	[[self window] makeFirstResponder:[_chatFontField window]];
	
	NSFont *f = [[MFPreferences preferences] chatTextFont];
	if( f )
		[sharedMgr setSelectedFont:f isMultiple:NO];
	else
		[sharedMgr setSelectedFont:[MFPreferences defaultChatTextFont] isMultiple:NO];
}

// NOTE: This apparently is only called down the responder chain.  Ugh.
- (void)changeFont:(id)sender
{
	NSFontManager *mgr = sender;
	NSFont *newFont = [mgr convertFont:[[MFPreferences preferences] chatTextFont]];
	[_chatFontField setStringValue:[NSString stringWithFormat:@"%@ - %.0f", [newFont displayName], [newFont pointSize]]];
	_selectedFont = [newFont retain];
}

@end
