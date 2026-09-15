/*******************************************************************
	FILE:		MFXfirePrefsWindowController.m
	
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

#import "MFXfirePrefsWindowController.h"
#import "XfireSession.h"

static inline void _SetOptionButton( NSDictionary *options, NSString *key, NSButton *but );
static inline void _SetOptionDictionary( NSButton *but, NSDictionary *currentOptions, NSMutableDictionary *newOptions, NSString *key );

@interface MFXfirePrefsWindowController (Private)
- (void)synchronizeControlsWithSession;
@end


@implementation MFXfirePrefsWindowController

- (id)initWithSession:(XfireSession *)aSession
{
	self = [super initWithWindowNibName:@"XfirePrefsWindow"];
	if( self )
	{
		_session = aSession;
	}
	return self;
}

- (void)windowDidLoad
{
	[self synchronizeControlsWithSession];
}

- (void)showWindow:(id)sender
{
	if( [self isWindowLoaded] )
		[self synchronizeControlsWithSession];
	
	[super showWindow:sender];
}

- (IBAction)cancel:(id)sender
{
	// don't do anything!
	[[self window] orderOut:sender];
}

- (IBAction)apply:(id)sender
{
	NSDictionary *currentOptions = [_session userOptions];
	NSMutableDictionary *newOptions = [NSMutableDictionary dictionary];
	
	_SetOptionDictionary( _showOfflineFriendsButton,      currentOptions, newOptions, kXfireShowMyOfflineFriendsOption );
	_SetOptionDictionary( _showWhenITypeButton,           currentOptions, newOptions, kXfireShowWhenITypeOption );
	_SetOptionDictionary( _showChatTimeStampButton,       currentOptions, newOptions, kXfireShowChatTimeStampsOption );
	_SetOptionDictionary( _showMyFriendsButton,           currentOptions, newOptions, kXfireShowMyFriendsOption );
	_SetOptionDictionary( _showGameStatusOnProfileButton, currentOptions, newOptions, kXfireShowOnMyProfileOption );
	_SetOptionDictionary( _showGameServerDataButton,      currentOptions, newOptions, kXfireShowMyGameServerDataOption );
	_SetOptionDictionary( _showFriendsOfFriendsButton,    currentOptions, newOptions, kXfireShowFriendsOfFriendsOption );
	
	[_session setUserOptions:newOptions];
	
	if( ! [[_nicknameField stringValue] isEqualToString:[[_session loginIdentity] nickName]] )
	{
		[_session setNickname:[_nicknameField stringValue]];
	}
	
	[[self window] orderOut:sender];
}

- (void)synchronizeControlsWithSession
{
	NSDictionary *options = [_session userOptions];
	
	_SetOptionButton( options, kXfireShowMyOfflineFriendsOption, _showOfflineFriendsButton );
	_SetOptionButton( options, kXfireShowWhenITypeOption,        _showWhenITypeButton );
	_SetOptionButton( options, kXfireShowChatTimeStampsOption,   _showChatTimeStampButton );
	_SetOptionButton( options, kXfireShowMyFriendsOption,        _showMyFriendsButton );
	_SetOptionButton( options, kXfireShowOnMyProfileOption,      _showGameStatusOnProfileButton );
	_SetOptionButton( options, kXfireShowMyGameServerDataOption, _showGameServerDataButton );
	_SetOptionButton( options, kXfireShowFriendsOfFriendsOption, _showFriendsOfFriendsButton );
	
	[_nicknameField setStringValue:[[_session loginIdentity] nickName]];
}

@end

static inline void _SetOptionButton( NSDictionary *options, NSString *key, NSButton *but )
{
	NSNumber *opt = [options objectForKey:key];
	if( opt && [opt boolValue] )
	{
		[but setState:NSOnState];
	}
	else
	{
		[but setState:NSOffState];
	}
}

static inline void _SetOptionDictionary( NSButton *but, NSDictionary *currentOptions, NSMutableDictionary *newOptions, NSString *key )
{
	BOOL val = NO;
	if( [but state] == NSOnState )
		val = YES;
	NSNumber *valObj = [NSNumber numberWithBool:val];
	
	if( [[currentOptions objectForKey:key] boolValue] != val )
		[newOptions setObject:valObj forKey:key];
}
