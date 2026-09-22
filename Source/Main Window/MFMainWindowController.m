/*******************************************************************
	FILE:		MFMainWindowController.m
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		The main window.  It includes log-in function and the main
		friends list.  It is modelled somewhat after the official
		Xfire client's approach, with a Mac twist, of course.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 01 03  Replaced user name combobox with a plain text field.
		2007 12 16  Added Mac game monitor support.
		2007 12 02  Added copyright notice.
		2007 11 23  Created.
*******************************************************************/

#import "MFMainWindowController.h"
#import "NSView_MFAdditions.h"
#import "NSScreen_MFAdditions.h"
#import "NSFileManager_MFAdditions.h"
#import "XfireSession.h"
#import "XfireFriend_MacFireAdditions.h"
#import "XfireFriendGroup_MacFireAdditions.h"
#import "MFGameRegistry.h"
#import "MFImageAndTextCell.h"
#import "MFGrowlHelper.h"
#import "MFPreferences.h"
#import "MFUserIdleMonitor.h"
#import "MFGameMonitor.h"
#import "MFChatWindowController.h"
#import "MFMenuItems.h"
#import "MFUserSearchWindowController.h"
#import "MFFriendshipRequestWindowController.h"
#import "MFUIStrings.h"
#import "MFXfirePrefsWindowController.h"
#import "MFApplicationSupportController.h"

static NSString *kMFNameColID = @"MacFireName";
static NSString *kMFStatusColID = @"MacFireStatus";
static NSString *kMFGameInfoColID = @"MacFireGameInfo";

static NSString *kMFXfireFriendDragType = @"MFXfireFriendDragType";

@implementation MFMainWindowController

- (id)init
{
	self = [super initWithWindowNibName:@"MFMainWindow"];
	if( self )
	{
		xfSession = nil;
		currentMode = kMacFireUIModeUninitialized;
		growlSuppressionTimer = nil;
		chatWindows = nil;
		userSearchController = nil;
		xfireOptionsController = nil;
		outlineReloadQueued = NO;
		outstandingFriendRequests = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(userBecameIdle:)
			name:kMFUserBecameIdleNotification
			object:[MFUserIdleMonitor sharedMonitor]];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(userBecameActive:)
			name:kMFUserBecameActiveNotification
			object:[MFUserIdleMonitor sharedMonitor]];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(gameDidLaunch:)
			name:kMFGameDidLaunch
			object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(gameDidExit:)
			name:kMFGameDidExit
			object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(preferencesDidChange:)
			name:MFPreferencesChangedNotificationName
			object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(applicationWillTerminate:)
			name:NSApplicationWillTerminateNotification
			object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[chatWindows release];
	[xfSession release];
	if( growlSuppressionTimer )
		[growlSuppressionTimer invalidate];
	
	chatWindows = nil;
	xfSession = nil;
	growlSuppressionTimer = nil;
	
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	NSTableColumn *col = [friendOutline tableColumnWithIdentifier:kMFNameColID];
	MFImageAndTextCell *cell = [[[MFImageAndTextCell alloc] init] autorelease];
	[cell setEditable:NO];
	[cell setDisplayImageSize:NSMakeSize(16.0f,16.0f)];
	[col setDataCell:cell];
	
	col = [friendOutline tableColumnWithIdentifier:kMFStatusColID];
	[col setDataCell:cell];
	
	col = [friendOutline tableColumnWithIdentifier:kMFGameInfoColID];
	[col setDataCell:cell];
	
	[friendOutline setRowHeight:26.0f]; // 24x24 icon plus 1 px pad top and bottom
	[friendOutline registerForDraggedTypes:[NSArray arrayWithObject:kMFXfireFriendDragType]];
	[friendOutline setVerticalMotionCanBeginDrag:YES];
	[friendOutline setAutoresizesOutlineColumn:NO]; // SCR 61 - prevent colunn width size creep
	
	NSRect mainFrame = [[MFPreferences preferences] mainWindowFrame];
	if( [NSScreen windowFrameIntersectsAnyScreen:mainFrame] )
		[[self window] setFrame:mainFrame display:YES];
	
	[self changeToMode:kMacFireUIModeLoginEntry];
	
	[friendOutline setDoubleAction:@selector(doubleClickOnFriend:)];
}

- (void)windowDidResize:(NSNotification *)aNote
{
	NSWindow *theWin = [aNote object];
	NSRect fr = [theWin frame];
	
	[[MFPreferences preferences] setMainWindowFrame:fr];
}

- (void)windowDidMove:(NSNotification *)aNote
{
	NSWindow *theWin = [aNote object];
	NSRect fr = [theWin frame];
	
	[[MFPreferences preferences] setMainWindowFrame:fr];
}

- (void)setMyModeView:(NSView *)aView
{
	[modeView removeAllSubviews];
	[modeView addSubview:aView];
	[aView setFrame:[modeView bounds]];
}

- (void)changeToMode:(MacFireUIMode)aMode
{
	if( currentMode == aMode )
		return;
	
	switch( aMode )
	{
		// Login credentials entry point
		case kMacFireUIModeLoginEntry:
			[self setMyModeView:loginView];
			currentMode = aMode;
			
			[usernameBox setEditable:YES];
			[passwordField setEditable:YES];
			[loginButton setEnabled:YES];
			[progressIndicator stopAnimation:self];
			[setStatusTextView setEnabled:NO];
			[setStatusTextView setStringValue:MF_UISTR_OFFLINE];
			[separatorBoxView setHidden:NO];
			
			NSString *name = [[MFPreferences preferences] defaultUserName];
			if( (name != nil) && ([name length] > 0) )
			{
				[usernameBox setStringValue:[[MFPreferences preferences] defaultUserName]];
				[[self window] makeFirstResponder:passwordField];
			}
			else
			{
				[[self window] makeFirstResponder:usernameBox];
			}
			
			[[userSearchController window] orderOut:self];
			[userSearchController release];
			userSearchController = nil;
			
			[[xfireOptionsController window] orderOut:self];
			[xfireOptionsController release];
			xfireOptionsController = nil;
			break;
		
		// Logging in (temporary screen)
		case kMacFireUIModeLoggingIn:
			[self setMyModeView:loginView];
			currentMode = aMode;
			
			[usernameBox setEditable:NO];
			[passwordField setEditable:NO];
			[loginButton setEnabled:NO];
			[progressIndicator startAnimation:self];
			[setStatusTextView setEnabled:NO];
			[setStatusTextView setStringValue:MF_UISTR_OFFLINE];
			[separatorBoxView setHidden:NO];
			break;
		
		// Logged in, displaying friend list
		case kMacFireUIModeFriendList:
			[progressIndicator stopAnimation:self];
			[self setMyModeView:userOutlineView];
			[setStatusTextView setEnabled:YES];
			[setStatusTextView setStringValue:@""];
			[separatorBoxView setHidden:YES];
			currentMode = aMode;
			
			[[self window] makeFirstResponder:friendOutline];
			[friendOutline reloadData];
			
			// resize the table columns from last session
			NSTableColumn *col;
			col = [friendOutline tableColumnWithIdentifier:kMFNameColID];
			[col setWidth:[[MFPreferences preferences] friendNameColumnWidth]];
			col = [friendOutline tableColumnWithIdentifier:kMFStatusColID];
			[col setWidth:[[MFPreferences preferences] friendStatusColumnWidth]];
			col = [friendOutline tableColumnWithIdentifier:kMFGameInfoColID];
			[col setWidth:[[MFPreferences preferences] friendGameColumnWidth]];
			break;
		
		// Not sure...
		default:
			break;
	}
}

- (IBAction)beginLogin:(id)sender
{
	if( currentMode == kMacFireUIModeLoginEntry )
	{
		if( [[usernameBox stringValue] length] == 0 )
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:MF_UISTR_NEED_UNAME];
			[alert setInformativeText:MF_UISTR_PROVIDE_UN];
			[alert addButtonWithTitle:MF_UISTR_OK];
			[alert runModal];
			return;
		}
		if( [[passwordField stringValue] length] == 0 )
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:MF_UISTR_NEED_PWORD];
			[alert setInformativeText:MF_UISTR_PROVIDE_PW];
			[alert addButtonWithTitle:MF_UISTR_OK];
			[alert runModal];
			return;
		}
		
		// Save last known username
		[[MFPreferences preferences] setDefaultUserName:[usernameBox stringValue]];
		[[MFPreferences preferences] addUserNameHistory:[usernameBox stringValue]];
		[self startSession];
	}
}

- (void)startSession
{
	[xfSession release];
	xfSession = [XfireSession newSessionWithHost:[NSHost hostWithName:[[MFPreferences preferences] xfireServerHostName]]
		port:[[MFPreferences preferences] xfireServerPortNumber]];
//	xfSession = [XfireSession newSessionWithHost:[NSHost hostWithName:@"localhost"] port:13987];
	[xfSession setDelegate:self];
	
	// Set posing version if the user wants to pose
	if( [[MFPreferences preferences] poseAsNewerXfireClient] )
	{
		unsigned int poseVersion = [[MFPreferences preferences] posingXfireClientVersion];
		if( poseVersion > [xfSession posingClientVersion] )
		{
			[xfSession setPosingClientVersion:poseVersion];
		}
	}
	
	chatWindows = [[NSMutableArray alloc] init];
	statusMessageWasAutoSet = NO;
	
	// Suspend growl notifications for the 1st two seconds to avoid spamming lots of
	// notifications as the friends list gets populated
	[[MFGrowlHelper helper] setSuspendsNotifications:YES];
	growlSuppressionTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
		target:self
		selector:@selector(startAllowingGrowlNotifications:)
		userInfo:nil
		repeats:NO];
	
	[xfSession connect];
}

- (void)startAllowingGrowlNotifications:(NSTimer *)aTimer
{
	[[MFGrowlHelper helper] setSuspendsNotifications:NO];
}

- (IBAction)changeStatusText:(id)sender
{
	NSString *txt = [sender stringValue];
	
	[xfSession setStatusString:txt];
	
	if( [txt length] > 0 )
	{
		if( ! [txt isEqualToString:MF_UISTR_AFK] )
		{
			[[MFPreferences preferences] addCustomStatusString:txt];
		}
	}
}

- (void)userBecameIdle:(NSNotification *)aNote
{
	// Ignore if not online
	if( currentMode != kMacFireUIModeFriendList )
		return;
	
	// Ignore if preferences don't want to
	if( [[MFPreferences preferences] showIdleStatusAutomatically] )
	{
		if( [[setStatusTextView stringValue] length] == 0 )
		{
			NSString *str = MF_UISTR_AFK;
			[xfSession setStatusString:str];
			[setStatusTextView setStringValue:str];
			statusMessageWasAutoSet = YES;
		}
	}
}

- (void)userBecameActive:(NSNotification *)aNote
{
	// Ignore if not online
	if( currentMode != kMacFireUIModeFriendList )
		return;
	
	// Ignore if preferences don't want to
	if( [[MFPreferences preferences] showIdleStatusAutomatically] )
	{
		if( statusMessageWasAutoSet )
		{
			[xfSession setStatusString:@""];
			[setStatusTextView setStringValue:@""];
			statusMessageWasAutoSet = NO;
		}
	}
}

- (void)gameDidLaunch:(NSNotification *)aNote
{
	if( currentMode != kMacFireUIModeFriendList )
		return;
	
	[xfSession enterGame:[[[aNote userInfo] objectForKey:kMFGameRegistryIDKey] unsignedIntValue]];
}

- (void)gameDidExit:(NSNotification *)aNote
{
	if( currentMode != kMacFireUIModeFriendList )
		return;
	
	[xfSession exitGame:[[[aNote userInfo] objectForKey:kMFGameRegistryIDKey] unsignedIntValue]];
}

- (void)doubleClickOnFriend:(id)sender
{
	XfireFriend *fr = [self selectedOnlineFriendNotFoF];
	if( fr )
	{
		[self startChatWithFriend:fr];
	}
}

- (void)sendFriendAMessage:(id)sender
{
	[self doubleClickOnFriend:sender];
}

- (void)startChatWithFriend:(XfireFriend *)fr
{
	if( [fr isOnline] )
	{
		MFChatWindowController *chatWindowCtl = [self chatWindowForFriend:fr];
		if( chatWindowCtl )
		{
			[chatWindowCtl showWindow:nil];
		}
		else
		{
			[xfSession beginChatWithFriend:fr];
		}
	}
}

- (MFChatWindowController *)chatWindowForFriend:(XfireFriend *)fr
{
	MFChatWindowController *chatCtl;
	int i, cnt;
	cnt = [chatWindows count];
	XfireChat *chat = [xfSession chatForSessionID:[fr sessionID]];
	if( chat == nil )
		return nil;
	for( i = 0; i < cnt; i++ )
	{
		chatCtl = [chatWindows objectAtIndex:i];
		if( [chatCtl chat] == chat )
		{
			return chatCtl;
		}
	}
	return nil;
}

- (MFChatWindowController *)chatWindowForChat:(XfireChat *)chat
{
	MFChatWindowController *chatCtl;
	int i, cnt;
	if( chat == nil )
		return nil;
	cnt = [chatWindows count];
	for( i = 0; i < cnt; i++ )
	{
		chatCtl = [chatWindows objectAtIndex:i];
		if( [chatCtl chat] == chat )
		{
			return chatCtl;
		}
	}
	return nil;
}

// in the friend outline view
- (int)activeRow
{
	int selRow, clickRow, row;
	
	// first check the selected row
	selRow = [friendOutline selectedRow];
	clickRow = [friendOutline clickedRow];
	
	if( selRow == clickRow )
	{
		row = selRow;
	}
	else if( clickRow >= 0 )
	{
		row = clickRow;
	}
	else
	{
		row = selRow;
	}
	
	return row;
}

- (XfireFriend *)selectedFriend
{
	int row = [self activeRow];
	
	if( row >= 0 )
	{
		id selItem = [friendOutline itemAtRow:row];
		if( [selItem isKindOfClass:[XfireFriend class]] )
		{
			return selItem;
		}
	}
	return nil;
}

- (XfireFriend *)selectedFriendNotFoF
{
	XfireFriend *fr = [self selectedFriend];
	if( ! [fr isFriendOfFriend] )
		return fr;
	return nil;
}

- (XfireFriend *)selectedOnlineFriendNotFoF
{
	XfireFriend *fr = [self selectedFriendNotFoF];
	if( [fr isOnline] )
		return fr;
	return nil;
}

- (XfireFriend *)selectedOnlineFriend
{
	XfireFriend *fr = [self selectedFriend];
	if( [fr isOnline] )
		return fr;
	return nil;
}

// only custom friend groups; ignore standard dynamic groups
- (XfireFriendGroup *)selectedFriendGroup
{
	int row = [self activeRow];
	
	if( row >= 0 )
	{
		id selItem = [friendOutline itemAtRow:row];
		if( [selItem isKindOfClass:[XfireFriendGroup class]] )
		{
			return selItem;
		}
	}
	return nil;
}

- (XfireFriendGroup *)selectedCustomFriendGroup
{
	XfireFriendGroup *grp = [self selectedFriendGroup];
	if( grp )
	{
		if( [grp groupType] == kXfireFriendGroupCustom )
			return grp;
	}
	return nil;
}

- (XfireFriendGroup *)friendGroupForItemAtRow:(int)row
{
	int rowLvl = [friendOutline levelForRow:row];
	int lvl;
	id item;
	id friendAtRow = [friendOutline itemAtRow:row];
	
	if( ! [friendAtRow isKindOfClass:[XfireFriend class]] )
		return nil;
	
	while( row >= 0 )
	{
		lvl = [friendOutline levelForRow:row];
		if( lvl < rowLvl )
		{
			item = [friendOutline itemAtRow:row];
			if( [item isKindOfClass:[XfireFriendGroup class]] && [item friendIsMember:friendAtRow] )
			{
				return item;
			}
		}
		row--;
	}
	
	return nil;
}

- (void)preferencesDidChange:(NSNotification*)aNote
{
	if( currentMode == kMacFireUIModeFriendList )
	{
		// for display name style
		[friendOutline reloadData];
		[ourNameView setStringValue:[[xfSession loginIdentity] displayNameString]];
		
		// for idle monitor changes
		if( ! [[MFPreferences preferences] showIdleStatusAutomatically] )
		{
			if( statusMessageWasAutoSet )
			{
				[xfSession setStatusString:@""];
				[setStatusTextView setStringValue:@""];
				statusMessageWasAutoSet = NO;
			}
		}
		else
		{
			MFUserIdleMonitor *mon = [MFUserIdleMonitor sharedMonitor];
			unsigned int newDelay = [[MFPreferences preferences] idleStatusDelay];
			if( [mon idleNotificationTimeout] != (60.0 * newDelay) )
			{
				[mon setIdleNotificationTimeout:(60.0 * newDelay)];
			}
		}
	}
}

- (void)applicationWillTerminate:(NSNotification *)aNote
{
	if( currentMode == kMacFireUIModeFriendList )
	{
		if( [xfSession status] == kXfireSessionStatusOnline )
		{
			// This forces the session to cleanly disconnect
			// So our callbacks get called before the session is removed (for local caching/logging)
			[xfSession disconnect];
		}
	}
}

- (void)friendRequestSheetDidEnd
{
	if( currentMode == kMacFireUIModeFriendList )
	{
		if( [outstandingFriendRequests count] > 0 )
		{
			XfireFriend *fr = [[outstandingFriendRequests objectAtIndex:0] retain];
			if( fr )
			{
				[outstandingFriendRequests removeObjectAtIndex:0];
				
				MFFriendshipRequestWindowController *friendRequestController;
				friendRequestController = [[MFFriendshipRequestWindowController alloc] initWithSession:xfSession
					requestor:fr
					message:[fr statusString]
					mainWindow:self];
				[fr autorelease];
				[friendRequestController runModalForWindow:[self window]];
			}
		}
		else
		{
			[outstandingFriendRequests release];
			outstandingFriendRequests = nil;
		}
	}
}

/***********************************************************************************************************************/
#pragma mark Combo Box Data Source
/***********************************************************************************************************************/

- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
	int tag = [aComboBox tag];
	if( tag == 1 )
	{
		return [[[MFPreferences preferences] userNameHistory] count];
	}
	else if( tag == 2 )
	{
		if( currentMode == kMacFireUIModeFriendList )
		{
			return [[[MFPreferences preferences] customStatusStrings] count] + 2;
		}
	}
	
	return 0;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index
{
	int tag = [aComboBox tag];
	if( tag == 1 )
	{
		return [[[MFPreferences preferences] userNameHistory] objectAtIndex:index];
	}
	else if( tag == 2 )
	{
		if( currentMode == kMacFireUIModeFriendList )
		{
			if( index == 0 )
				return @"";
			else if( index == 1 )
				return MF_UISTR_AFK;
			else
				return [[[MFPreferences preferences] customStatusStrings] objectAtIndex:index-2];
		}
	}
	
	return nil;
}

/***********************************************************************************************************************/
#pragma mark XfireSession Delegation
/***********************************************************************************************************************/

// Return the plaintext password and usernames for the given session
// THIS IS REQUIRED!
- (void)xfireGetSession:(XfireSession *)session userName:(NSString **)aName password:(NSString **)password
{
	*aName = [[usernameBox stringValue] copy];
	*password = [[passwordField stringValue] copy];
}

// Get the current skin/theme
// THIS IS REQUIRED!
- (XfireSkin *)xfireSessionSkin:(XfireSession *)session
{
	return [XfireSkin theSkin];
}

// Get the folder path for connection logs
- (NSString *)xfireSessionLogPath:(XfireSession *)session
{
	if( [[MFPreferences preferences] logXfireNetworkTraffic] )
	{
		return [self folderCachePathForName:@"MacFire"];
	}
	
	return nil;
}

// The session status changed
- (void)xfireSession:(XfireSession *)session didChangeStatus:(XfireSessionStatus)newStatus
{
	if( newStatus == kXfireSessionStatusLoggingOn )
	{
		[self changeToMode:kMacFireUIModeLoggingIn];
		[ourNameView setStringValue:MF_UISTR_OFFLINE];
	}
	else if( newStatus == kXfireSessionStatusOnline )
	{
		[self changeToMode:kMacFireUIModeFriendList];
		[ourNameView setStringValue:[[xfSession loginIdentity] displayNameString]];
		[passwordField setStringValue:@""]; // SCR 23 (don't keep password in memory); SCR 48 don't clear when pose-as response is Yes
		
		// SCR 37 - this really belongs here and not in changeToMode: which is for GUI stuff
		// if we're in a game, send it now
		NSArray *runningGames = [[MFGameMonitor sharedMonitor] runningGames];
		if( [runningGames count] > 0 )
		{
			[xfSession enterGame:[[[runningGames lastObject] objectForKey:kMFGameRegistryIDKey] unsignedIntValue]];
		}
	}
	else if( newStatus == kXfireSessionStatusLoggingOff )
	{
		[self changeToMode:kMacFireUIModeLoggingIn];
		[ourNameView setStringValue:MF_UISTR_OFFLINE];
	}
	else if( newStatus == kXfireSessionStatusOffline )
	{
		[self changeToMode:kMacFireUIModeLoginEntry];
		[ourNameView setStringValue:MF_UISTR_OFFLINE];
		
		[chatWindows release];
		chatWindows = nil;
	}
}

// Login failed
// XfireSession either calls -xfireSession:didChangeStatus:kXfireSessionStatusOnline or xfireSessionLoginFailed:reason:
- (void)xfireSessionLoginFailed:(XfireSession *)session reason:(NSString *)reason
{
	[growlSuppressionTimer invalidate];
	growlSuppressionTimer = nil;
	
	if( [reason isEqualToString:kXfireVersionTooOldReason] )
	{
		int result;
		
		// SCR 36 - added new client version # to the pose-as dialog
		NSString *fmtStr = MF_UISTR_VERSIONOLD;
		NSString *alertPanelDetail = [NSString stringWithFormat:fmtStr, [xfSession latestClientVersion]];
		NSAlert *versionAlert = [[NSAlert alloc] init];
		[versionAlert setMessageText:MF_UISTR_LOGINFAIL];
		[versionAlert setInformativeText:alertPanelDetail];
		[versionAlert addButtonWithTitle:MF_UISTR_POSE];
		[versionAlert addButtonWithTitle:MF_UISTR_CANCEL];
		NSModalResponse result = [versionAlert runModal];
		if( result == NSAlertFirstButtonReturn )
		{
			// Pose as newer version always
			// try again
			[[MFPreferences preferences] setPoseAsNewerXfireClient:YES];
			[[MFPreferences preferences] setPosingXfireClientVersion:[xfSession latestClientVersion]];
			[self startSession];
		}
		else
		{
			// cancel, or anything else happened
			[self changeToMode:kMacFireUIModeLoginEntry];
			[passwordField setStringValue:@""]; // SCR 23 (don't keep password in memory); SCR 48 don't clear when pose-as response is Yes
		}
	}
	else if( [reason isEqualToString:kXfireInvalidPasswordReason] )
	{
		[self changeToMode:kMacFireUIModeLoginEntry];
		[passwordField setStringValue:@""];
		
		NSAlert *badPassAlert = [[NSAlert alloc] init];
		[badPassAlert setMessageText:MF_UISTR_LOGINFAIL];
		[badPassAlert setInformativeText:MF_UISTR_BADPASSWD];
		[badPassAlert addButtonWithTitle:MF_UISTR_OK];
		[badPassAlert runModal];
	}
	else if( [reason isEqualToString:kXfireNetworkErrorReason] )
	{
		[self changeToMode:kMacFireUIModeLoginEntry];
		[passwordField setStringValue:@""];
		
		// TODO: Localize this
		NSAlert *netErrAlert = [[NSAlert alloc] init];
		[netErrAlert setMessageText:MF_UISTR_LOGINFAIL];
		[netErrAlert setInformativeText:@"An error occurred."];
		[netErrAlert addButtonWithTitle:MF_UISTR_OK];
		[netErrAlert runModal];
	}
}

// Session is being terminated
- (void)xfireSessionWillDisconnect:(XfireSession *)session reason:(NSString *)reason
{
	// change here so the user list is not shown
	[self changeToMode:kMacFireUIModeLoginEntry];
	[ourNameView setStringValue:MF_UISTR_OFFLINE];
	
	// update our cache of contacts
	[[MFApplicationSupportController sharedController] updateAllContacts:session];
	
	if( [reason isEqualToString:kXfireServerHungUpReason] )
	{
		NSAlert *discAlert1 = [[NSAlert alloc] init];
		[discAlert1 setMessageText:MF_UISTR_DISCONNECTED];
		[discAlert1 setInformativeText:MF_UISTR_SERVER_HUNG_UP];
		[discAlert1 addButtonWithTitle:MF_UISTR_OK];
		[discAlert1 runModal];
	}
	else if( [reason isEqualToString:kXfireOtherSessionReason] )
	{
		NSAlert *discAlert2 = [[NSAlert alloc] init];
		[discAlert2 setMessageText:MF_UISTR_DISCONNECTED];
		[discAlert2 setInformativeText:MF_UISTR_LOGGED_IN_ELSEWHERE];
		[discAlert2 addButtonWithTitle:MF_UISTR_OK];
		[discAlert2 runModal];
	}
	else if( [reason isEqualToString:kXfireNormalDisconnectReason] )
	{
		// nothing to do - normal disconnect
	}
	else if( [reason isEqualToString:kXfireServerStoppedRespondingReason] )
	{
		NSAlert *discAlert3 = [[NSAlert alloc] init];
		[discAlert3 setMessageText:MF_UISTR_DISCONNECTED];
		[discAlert3 setInformativeText:MF_UISTR_SERVER_STOPPED_RESPONDING];
		[discAlert3 addButtonWithTitle:MF_UISTR_OK];
		[discAlert3 runModal];
	}
	else
	{
		NSAlert *discAlert4 = [[NSAlert alloc] init];
		[discAlert4 setMessageText:MF_UISTR_DISCONNECTED];
		[discAlert4 setInformativeText:MF_UISTR_UNKNOWN_REASON];
		[discAlert4 addButtonWithTitle:MF_UISTR_OK];
		[discAlert4 runModal];
	}
}

// Our nickname changed
- (void)xfireSession:(XfireSession *)session nicknameDidChange:(NSString *)newNick
{
	if( currentMode == kMacFireUIModeFriendList )
	{
		[ourNameView setStringValue:[[xfSession loginIdentity] displayNameString]];
	}
}

// User search results
// returns an array of XfireFriend .. only username, first name, and last name are valid
- (void)xfireSession:(XfireSession *)session searchResults:(NSArray *)friends
{
	if( userSearchController && [[userSearchController window] isVisible] )
	{
		[userSearchController handleSearchResults:friends];
	}
}

// Incoming friendship requests
- (void)xfireSession:(XfireSession *)session didReceiveFriendshipRequests:(NSArray *)requestors
{
	if( currentMode == kMacFireUIModeFriendList )
	{
		outstandingFriendRequests = [requestors retain];
		
		// roundabout but it works
		[self friendRequestSheetDidEnd];
	}
}

// Something about this friend changed
- (void)xfireSession:(XfireSession *)session friendDidChange:(XfireFriend *)fr attribute:(XfireFriendChangeAttribute)attr
{
	// Ignore if we're not displaying the friends list
	if( currentMode != kMacFireUIModeFriendList )
		return;
	
	switch( attr )
	{
		case kXfireFriendNicknameDidChange:
			// Changing nicknames may cause the list to be re-sorted
			// This is the easy way of handling that - reload all the data instead of just the one item
			[self queueReloadData];
			[[MFApplicationSupportController sharedController] updateContact:fr];
			break;
		
		case kXfireFriendWasAdded:
			[self queueReloadData];
			[[MFApplicationSupportController sharedController] updateContact:fr];
			break;
		
		case kXfireFriendWasRemoved:
			[self queueReloadData];
			[[MFApplicationSupportController sharedController] updateContact:fr];
			break;
		
		case kXfireFriendOnlineStatusWillChange:
			[[MFApplicationSupportController sharedController] updateContact:fr];
			break;
		
		case kXfireFriendOnlineStatusDidChange:
			if( [fr isOnline] )
				[[MFGrowlHelper helper] postFriendCameOnline:fr];
			else
				[[MFGrowlHelper helper] postFriendWentOffline:fr];
			break;
		
		case kXfireFriendStatusStringDidChange:
			//[friendOutline reloadItem:fr];
			[self queueReloadData];
			break;
		
		case kXfireFriendGameInfoDidChange:
			//[friendOutline reloadItem:fr];
			[self queueReloadData];
			break;
		
		default:
			// TBD
			//NSLog(@"FriendChange:  %d\n%@", attr,fr);
			break;
	}
}

- (void)xfireSession:(XfireSession *)session friendGroupDidChange:(XfireFriendGroup *)grp
{
	[self queueReloadData];
}

- (void)xfireSession:(XfireSession *)session friendGroupWasAdded:(XfireFriendGroup *)grp
{
	[grp setFriendSortSelector:@selector(compareFriendsByDisplayName:)];
	[self queueReloadData];
	
	// expand the item after a short delay, to ensure the NSOutlineView has loaded the data first
	// otherwise the item may not expand properly.
	// TODO: save user option for group expansion state
	[friendOutline performSelector:@selector(expandItem:) withObject:grp afterDelay:0.5];
}

- (void)xfireSession:(XfireSession *)session friendGroupWillBeRemoved:(XfireFriendGroup *)grp
{
	[self queueReloadData];
}

// A new incoming chat (instant) message
// the handler is expected to configure a delegate for the chat;
// everything for this chat subsequent to this is handled by the XfireChat
- (void)xfireSession:(XfireSession *)session didBeginChat:(XfireChat *)chat
{
	MFChatWindowController *ctl = [[MFChatWindowController alloc] initWithChat:chat];
	[chat setDelegate:ctl];
	[ctl showWindow:self];
	[chatWindows addObject:ctl];
	[ctl release]; // don't leak
}

- (void)xfireSession:(XfireSession *)session chatDidEnd:(XfireChat *)aChat
{
	MFChatWindowController * chatCtl = [self chatWindowForChat:aChat];
	if( chatCtl )
		[chatWindows removeObject:chatCtl];
}

/***********************************************************************************************************************/
#pragma mark Friends Outline View Delegation/DataSource
/***********************************************************************************************************************/

- (id)outlineView:(NSOutlineView *)olView child:(int)index ofItem:(id)item
{
	if( currentMode != kMacFireUIModeFriendList )
		return @"";
	
	if( item == nil )
	{
		return [[xfSession friendGroups] objectAtIndex:index];
	}
	else if( [item isKindOfClass:[XfireFriendGroup class]] )
	{
		return [item memberAtIndex:index];
	}
	
	// XfireFriends don't have children
	// or something strange happened
	return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if( currentMode != kMacFireUIModeFriendList )
		return NO;
	
	if( (item == nil) || [item isKindOfClass:[XfireFriendGroup class]] )
		return YES;
	
	return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	if( [item isKindOfClass:[XfireFriendGroup class]] )
		return YES;
	return NO;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if( currentMode != kMacFireUIModeFriendList )
		return 0;
	
	if( item == nil )
	{
		return [[xfSession friendGroups] count];
	}
	else if( [item isKindOfClass:[XfireFriendGroup class]] )
	{
		return [item numberOfMembers];
	}
	
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if( currentMode != kMacFireUIModeFriendList )
		return nil;
	
	if( [item isKindOfClass:[XfireFriendGroup class]] )
	{
		if( [[tableColumn identifier] isEqualTo:kMFNameColID] )
		{
			return [item displayName];
		}
		return nil;
	}
	else if( [item isKindOfClass:[XfireFriend class]] )
	{
		XfireFriend *fr = item;
		
		if( [[tableColumn identifier] isEqualTo:kMFNameColID] )
		{
			return [fr displayNameString];
		}
		else if( [[tableColumn identifier] isEqualTo:kMFStatusColID] )
		{
			return [fr statusDisplayString];
		}
		else if( [[tableColumn identifier] isEqualTo:kMFGameInfoColID] )
		{
			if( [fr gameIPAddress] != 0 )
			{
				return [NSString stringWithFormat:@"%@:%u",
					MFStringFromIPAddress([fr gameIPAddress]),
					[fr gamePort]];
			}
			return nil;
		}
	}
	
	return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if( [[tableColumn identifier] isEqualTo:kMFNameColID] )
	{
		MFImageAndTextCell *ic = (MFImageAndTextCell *)cell;
		[ic setDisplayImageSize:NSMakeSize(24.0f,24.0f)];
		[ic setFont:[NSFont systemFontOfSize:12.0f]];
		[ic setImage:nil];
		
		if( [item isKindOfClass:[XfireFriend class]] )
		{
			XfireFriend *fr = item;
			int gid = [fr gameID];
			NSImage *dispImg = [[MFGameRegistry registry] defaultImage];
			if( gid != 0 )
			{
				NSDictionary *gameInfo = [MFGameRegistry infoForGameID:gid];
				if( gameInfo )
				{
					NSImage *tmp = [gameInfo objectForKey:kMFGameRegistryIconKey];
					if( tmp )
						dispImg = tmp;
				}
			}
			
			[dispImg setScalesWhenResized:YES]; // for some reason most of the .ICOs default to NO
			[ic setImage:dispImg];
		}
#if 0 /* 10.5 ONLY */
		else
		{
			NSImage *dispImg = [NSImage imageNamed:@"NSFolderSmart"];
			[dispImg setScalesWhenResized:YES];
			[ic setImage:dispImg];
		}
#endif
	}
	else
	{
		[cell setFont:[NSFont systemFontOfSize:10.0f]];
		[cell setImage:nil];
	}
}

- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return 26.0f; // icon is 24x24, want 1px margin around it
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

- (void)outlineViewColumnDidResize:(NSNotification *)aNotification
{
	NSTableColumn *col = [[aNotification userInfo] objectForKey:@"NSTableColumn"];
	
	// only change the preference setting if the width actually changed
	float oldWidth;
	
	if( [[col identifier] isEqualTo:kMFNameColID] )
	{
		oldWidth = [[MFPreferences preferences] friendNameColumnWidth];
		if( fabsf(oldWidth-[col width]) >= 1.0f )
			[[MFPreferences preferences] setFriendNameColumnWidth:[col width]];
	}
	else if( [[col identifier] isEqualTo:kMFStatusColID] )
	{
		oldWidth = [[MFPreferences preferences] friendStatusColumnWidth];
		if( fabsf(oldWidth-[col width]) >= 1.0f )
			[[MFPreferences preferences] setFriendStatusColumnWidth:[col width]];
	}
	else if( [[col identifier] isEqualTo:kMFGameInfoColID] )
	{
		oldWidth = [[MFPreferences preferences] friendGameColumnWidth];
		if( fabsf(oldWidth-[col width]) >= 1.0f )
			[[MFPreferences preferences] setFriendGameColumnWidth:[col width]];
	}
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation
{
	if( [item isKindOfClass:[XfireFriend class]] )
	{
		return [item toolTip];
	}
	
	return nil;
}

// Copy something about this friend to the pasteboard for friend dragging (used to add friends to custom groups)
- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard
{
	if( [items count] > 1 )
		return NO; // This should never happen, but abort gracefully if it actually does
	
	if( [[items objectAtIndex:0] isKindOfClass:[XfireFriendGroup class]] )
		return NO; // Don't allow moving friend groups
	
	if( [[items objectAtIndex:0] isKindOfClass:[XfireFriend class]] )
	{
		XfireFriend *fr = [items objectAtIndex:0];
		if( ! [fr isFriendOfFriend] )
		{
			unsigned int uid = [fr userID];
			NSData *d = [NSData dataWithBytes:&uid length:sizeof(uid)];
			
			[pasteboard declareTypes:[NSArray arrayWithObject:kMFXfireFriendDragType] owner:self];
			if( [pasteboard setData:d forType:kMFXfireFriendDragType] )
			{
				[pasteboard setString:[fr displayNameString] forType:NSStringPboardType];
				return YES;
			}
		}
		// TODO: else bring up the add friend dialog box
	}
	
	return NO;
}

// Check that we can recieve this drop, retarget as necessary
- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)proposedItem proposedChildIndex:(int)index
{
	if( proposedItem == nil )
	{
		// drop on to the view itself - don't allow
		return NSDragOperationNone;
	}
	else if( [proposedItem isKindOfClass:[XfireFriendGroup class]] )
	{
		// only allow dragging on to custom friend groups
		XfireFriendGroup *grp = proposedItem;
		if( [grp groupType] == kXfireFriendGroupCustom )
		{
			return NSDragOperationGeneric;
		}
		return NSDragOperationNone;
	}
	return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
	NSPasteboard *pboard = [info draggingPasteboard];
	NSData       *d = [pboard dataForType:kMFXfireFriendDragType];
	unsigned int uid;
	
	if( ([d length] == 4) && [item isKindOfClass:[XfireFriendGroup class]] )
	{
		[d getBytes:&uid length:sizeof(unsigned int)];
		XfireFriend *fr = [xfSession friendForUserID:uid];
		XfireFriendGroup *grp = item;
		
		if( fr && grp )
		{
			[grp addFriend:fr];
		}
		
		return YES;
	}
	return NO;
}

/***********************************************************************************************************************/
#pragma mark Simple String Prompt Aux Window
/***********************************************************************************************************************/

- (void)runChangeNicknameSheet
{
	[self runStringPrompt:MF_UISTR_CHANGE_NICK_PROMPT
		defaultValue:[[xfSession loginIdentity] nickName]
		acceptButton:MF_UISTR_CHANGE_NICK_BUTTON
		didEndSelector:@selector(changeNicknameSheetDidEnd:returnCode:contextInfo:)
		contextInfo:nil];
}

- (void)runAddCustomGroupSheet
{
	[self runStringPrompt:MF_UISTR_ADD_GROUP_PROMPT
		defaultValue:@""
		acceptButton:MF_UISTR_ADD_GROUP_BUTTON
		didEndSelector:@selector(addFriendGroupSheetDidEnd:returnCode:contextInfo:)
		contextInfo:nil];
}

- (void)runRenameCustomGroupSheet
{
	[self runStringPrompt:MF_UISTR_RENAME_GROUP_PROMPT
		defaultValue:[[self selectedCustomFriendGroup] displayName]
		acceptButton:MF_UISTR_RENAME_GROUP_BUTTON
		didEndSelector:@selector(renameFriendGroupSheetDidEnd:returnCode:contextInfo:)
		contextInfo:[self selectedCustomFriendGroup]];
}

- (void)runStringPrompt:(NSString *)prompt defaultValue:(NSString *)value acceptButton:(NSString *)acceptString didEndSelector:(SEL)aSelector contextInfo:(id)info
{
	[stringPromptField setStringValue:prompt];
	[stringPromptText  setStringValue:value];
	[stringPromptAcceptButton setTitle:acceptString];
	
	[NSApp beginSheet:stringPromptWindow
		modalForWindow:[self window]
		modalDelegate:self
		didEndSelector:aSelector
		contextInfo:info];
}

- (IBAction)stringPromptAccept:(id)sender
{
	[NSApp endSheet:stringPromptWindow returnCode:0];
}

- (IBAction)stringPromptCancel:(id)sender
{
	[NSApp endSheet:stringPromptWindow returnCode:-1];
}

- (void)changeNicknameSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[stringPromptWindow orderOut:self];
	
	if( returnCode == 0 )
	{
		[xfSession setNickname:[stringPromptText stringValue]];
	}
}

- (void)addFriendGroupSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[stringPromptWindow orderOut:self];
	
	if( returnCode == 0 )
	{
		NSString *str = [stringPromptText stringValue];
		if( [str length] > 0 )
		{
			[xfSession requestNewFriendGroup:str];
		}
	}
}

- (void)renameFriendGroupSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[stringPromptWindow orderOut:self];
	
	if( returnCode == 0 )
	{
		NSString *str = [stringPromptText stringValue];
		XfireFriendGroup *grp = contextInfo;
		if( ([str length] > 0) && grp )
		{
			[xfSession renameFriendGroup:grp newName:str];
		}
	}
}

/***********************************************************************************************************************/
#pragma mark Menu Item Handlers and Validation
/***********************************************************************************************************************/

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if( currentMode != kMacFireUIModeFriendList )
	{
		return NO;
	}
	
	int tag = [anItem tag];
	
	switch( tag )
	{
		case kMFLogOffMenuItemTag:
		case kMFShowMyProfileMenuItemTag:
		case kMFChangeNicknameMenuItemTag:
		case kMFSearchXfireUsersMenuItemTag:
		case kMFXfirePrefsMenuItemTag:
			return YES;
			break;
		
		case kMFViewFriendProfileMenuItemTag:
			if( [self selectedFriend] != nil )
			{
				return YES;
			}
			break;
		
		case kMFRemoveFriendMenuItemTag:
			if( [self selectedFriendNotFoF] != nil )
			{
				return YES;
			}
			break;
		
		case kMFSendMessageMenuItemTag:
			if( [self selectedOnlineFriendNotFoF] != nil )
			{
				return YES;
			}
			break;
		
		case kMFAddCustomGroupMenuItemTag:
			return YES;
			break;
		
		case kMFRenameCustomGroupMenuItemTag:
		case kMFRemoveCustomGroupMenuItemTag:
			if( [self selectedCustomFriendGroup] != nil )
			{
				return YES;
			}
			break;
		
		case kMFRemoveFriendFromGroupMenuItemTag:
			{
				XfireFriendGroup *grp = [self friendGroupForItemAtRow:[self activeRow]];
				if( [grp groupType] == kXfireFriendGroupCustom )
					return YES;
			}
			return NO;
			break;
		
		default:
			return NO;
	}
	
	return NO;
}

- (void)logOff:(id)sender
{
	[xfSession disconnect];
	[self changeToMode:kMacFireUIModeLoginEntry];
}

- (void)displayMyProfile:(id)sender
{
	[[xfSession loginIdentity] showProfile];
}

- (void)changeMyNickname:(id)sender
{
	[self runChangeNicknameSheet];
}

- (void)displayFriendProfile:(id)sender
{
	XfireFriend *fr = [self selectedFriend];
	if( fr )
	{
		[fr showProfile];
	}
}

- (void)beginUserSearch:(id)sender
{
	if( userSearchController == nil )
	{
		userSearchController = [[MFUserSearchWindowController alloc] initWithSession:xfSession];
	}
	
	[userSearchController showWindow:sender];
}

- (void)removeFriend:(id)sender
{
	NSString *alertmsg = [NSString stringWithFormat:MF_UISTR_REMOVE_FRIEND_PROMPT,
		[[self selectedFriendNotFoF] displayNameString]];
	
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:alertmsg];
	[alert addButtonWithTitle:MF_UISTR_CANCEL];
	[alert addButtonWithTitle:MF_UISTR_REMOVE_FRIEND_BUTTON];
	[alert setAlertStyle:NSAlertStyleWarning];
	
	XfireFriend *friendToRemove = [self selectedFriendNotFoF];
	[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
		if( returnCode == NSAlertSecondButtonReturn )
		{
			if( friendToRemove )
			{
				[xfSession sendRemoveFriend:friendToRemove];
			}
		}
	}];
}

- (void)addCustomFriendGroup:(id)sender
{
	[self runAddCustomGroupSheet];
}

- (void)renameCustomFriendGroup:(id)sender
{
	[self runRenameCustomGroupSheet];
}

- (void)removeCustomFriendGroup:(id)sender
{
	NSString *alertmsg = [NSString stringWithFormat:MF_UISTR_REMOVE_GROUP_PROMPT,
		[[self selectedCustomFriendGroup] displayName]];
	
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:alertmsg];
	[alert addButtonWithTitle:MF_UISTR_CANCEL];
	[alert addButtonWithTitle:MF_UISTR_REMOVE_GROUP_BUTTON];
	[alert setAlertStyle:NSAlertStyleWarning];
	
	XfireFriendGroup *groupToRemove = [self selectedCustomFriendGroup];
	[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
		if( returnCode == NSAlertSecondButtonReturn )
		{
			if( groupToRemove )
			{
				[xfSession removeFriendGroup:groupToRemove];
			}
		}
	}];
}

// Not irreparable so we don't prompt
- (void)removeFriendFromGroup:(id)sender
{
	XfireFriendGroup	*grp = [self friendGroupForItemAtRow:[self activeRow]];
	XfireFriend			*fr  = [self selectedFriendNotFoF];
	
	[grp removeFriend:fr];
}

- (void)showXfireOptions:(id)sender
{
	if( xfireOptionsController == nil )
	{
		xfireOptionsController = [[MFXfirePrefsWindowController alloc] initWithSession:xfSession];
	}
	
	[xfireOptionsController showWindow:sender];
}

// Returns a folder path name under ~/Library/Caches, if possible
- (NSString *)folderCachePathForName:(NSString *)aName
{
	NSArray *cacheFolders;
	NSString *folderPath;
	
	// Get folder path
	cacheFolders = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
	if( cacheFolders && ([cacheFolders count] > 0) )
	{
		folderPath = [cacheFolders objectAtIndex:0];
		folderPath = [folderPath stringByAppendingPathComponent:aName]; // do not retain
	}
	else
	{
		folderPath = [@"/tmp" stringByAppendingPathComponent:aName];
	}
	
	// Try to create folder, if it doesn't exist yet
	if( ! [NSFileManager ensureDirectoryExistsAtPath:folderPath attributes:nil] )
	{
		NSLog(@"Unable to create packet log cache folder");
		return nil;
	}
	
	return folderPath;
}

- (void)queueReloadData
{
	if( !outlineReloadQueued )
	{
		[self performSelector:@selector(doReloadData:) withObject:nil afterDelay:0];
		outlineReloadQueued = YES;
	}
}

- (void)doReloadData:(id)ignored
{
	outlineReloadQueued = NO;
	[friendOutline reloadData];
}

@end


NSString* MFStringFromIPAddress(unsigned int addr)
{
	unsigned char t1, t2, t3, t4;
	
	t1 = (addr >> 24) & 0xFF;
	t2 = (addr >> 16) & 0xFF;
	t3 = (addr >>  8) & 0xFF;
	t4 = (addr      ) & 0xFF;
	
	return [NSString stringWithFormat:@"%u.%u.%u.%u",t1,t2,t3,t4];
}
