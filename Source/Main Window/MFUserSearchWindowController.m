/*******************************************************************
	FILE:		MFUserSearchWindowController.m
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The user search/add window.  Allows searching Xfire users
		and sending Friendship requests.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 03 01  Created.
*******************************************************************/

#import "MFUserSearchWindowController.h"
#import "XfireSession.h"
#import "MFMenuItems.h"
#import "MFUIStrings.h"

@implementation MFUserSearchWindowController

- (id)initWithSession:(XfireSession *)session
{
	self = [super initWithWindowNibName:@"UserSearchWindow"];
	if( self )
	{
		_xfSession = session;
		_results = nil;
	}
	return self;
}

- (void)dealloc
{
	[_results release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[self updateControls];
}

// Used to enable/disable the search button
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self updateControls];
}

- (IBAction)beginSearch:(id)sender
{
	[_progressIndicator startAnimation:sender];
	[_xfSession beginUserSearch:[_searchTextField stringValue]];
}

- (IBAction)cancel:(id)sender
{
	[[self window] orderOut:sender];
}

- (IBAction)sendAddRequest:(id)sender
{
	int selRow = [_resultsTable selectedRow];
	if( selRow >= 0 )
	{
		XfireFriend *fr = [_results objectAtIndex:selRow];
		
		[_xfSession sendFriendInvitation:[fr userName] message:[_requestStringField stringValue]];
	}
	
	[[self window] orderOut:sender];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self updateControls];
}

- (void)updateControls
{
	if( _results && ([_results count] > 0) && ([_resultsTable selectedRow] >= 0) )
	{
		[_sendRequestButton setEnabled:YES];
	}
	else
	{
		[_sendRequestButton setEnabled:NO];
	}
	
	if( [[_searchTextField stringValue] length] > 0 )
	{
		[_beginSearchButton setEnabled:YES];
	}
	else
	{
		[_beginSearchButton setEnabled:NO];
	}
	
}

- (void)handleSearchResults:(NSArray *)results
{
	[_progressIndicator stopAnimation:self];
	
	[_results release];
	_results = [results retain];
	
	[_resultsTable reloadData];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [_results count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if( [[tableColumn identifier] isEqualToString:@"Name"] )
	{
		return [[_results objectAtIndex:row] userName];
	}
	else if( [[tableColumn identifier] isEqualToString:@"FirstName"] )
	{
		return [[_results objectAtIndex:row] firstName];
	}
	else if( [[tableColumn identifier] isEqualToString:@"LastName"] )
	{
		return [[_results objectAtIndex:row] lastName];
	}
	
	return nil;
}

/***********************************************************************************************************************/
#pragma mark Menu Item Handlers and Validation
/***********************************************************************************************************************/

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	int tag = [anItem tag];
	
	switch( tag )
	{
		case kMFLogOffMenuItemTag:
			//if( currentMode == kMacFireUIModeFriendList ) return YES;
			return YES;
			break;
		
		case kMFViewFriendProfileMenuItemTag:
			if( ([_results count] > 0) && ([_resultsTable selectedRow] >= 0) )
			{
				XfireFriend *fr = [_results objectAtIndex:[_resultsTable selectedRow]];
				if( fr && [fr isKindOfClass:[XfireFriend class]] )
				{
					return YES;
				}
			}
			break;
		
		default:
			return NO;
	}
	
	return NO;
}

- (void)displayFriendProfile:(id)sender
{
	if( ([_results count] > 0) && ([_resultsTable selectedRow] >= 0) )
	{
		XfireFriend *fr = [_results objectAtIndex:[_resultsTable selectedRow]];
		if( fr && [fr isKindOfClass:[XfireFriend class]] )
		{
			NSString *username = [fr userName];
			NSString *xfirePath = [NSString stringWithFormat: MF_UISTR_PROFILEURL, username];
			NSURL    *xfireUrl  = [NSURL URLWithString:xfirePath];
			[[NSWorkspace sharedWorkspace] openURL:xfireUrl];
		}
	}
}

@end
