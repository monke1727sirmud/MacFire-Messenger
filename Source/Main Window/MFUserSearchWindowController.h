/*******************************************************************
	FILE:		MFUserSearchWindowController.h
	
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

#import <Cocoa/Cocoa.h>

@class XfireSession;

@interface MFUserSearchWindowController : NSWindowController
{
	IBOutlet NSTextField *_searchTextField;
	IBOutlet NSTableView *_resultsTable;
	IBOutlet NSTextField *_requestStringField;
	IBOutlet NSProgressIndicator *_progressIndicator;
	IBOutlet NSButton    *_beginSearchButton;
	IBOutlet NSButton    *_sendRequestButton;
	
	XfireSession *_xfSession;
	NSArray *_results;
}

- (id)initWithSession:(XfireSession *)session;

- (IBAction)beginSearch:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)sendAddRequest:(id)sender;

- (void)updateControls;

- (void)handleSearchResults:(NSArray *)results;

@end
