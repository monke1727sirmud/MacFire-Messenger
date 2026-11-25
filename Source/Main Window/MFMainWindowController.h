/*******************************************************************
	FILE:		MFMainWindowController.h
	
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
		2007 12 02  Added copyright notice.
		2007 11 23  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

typedef enum
{
	kMacFireUIModeLoginEntry = 1,
	kMacFireUIModeLoggingIn,
	kMacFireUIModeFriendList,
	kMacFireUIModeUninitialized
} MacFireUIMode;

@class XfireSession;
@class XfireFriend;
@class XfireFriendGroup;
@class XfireChat;
@class MFUserSearchWindowController;
@class MFXfirePrefsWindowController;
@class MFChatWindowController;

@interface MFMainWindowController : NSWindowController
{
	// main views
	IBOutlet NSView *modeView; // subview either loginView or usersView
	IBOutlet NSView *loginView;
	IBOutlet NSView *usersView;
	IBOutlet NSView *userOutlineView;
	IBOutlet NSBox  *separatorBoxView;
	
	// always-visible views
	IBOutlet NSTextField *ourNameView;
	IBOutlet NSComboBox *setStatusTextView;
	
	// login view
	IBOutlet NSComboBox *usernameBox;
	IBOutlet NSSecureTextField *passwordField;
	IBOutlet NSButton *loginButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	
	// friend list view
	IBOutlet NSOutlineView *friendOutline;
	
	// the simple string prompt aux window (used as a sheet)
	IBOutlet NSWindow *stringPromptWindow;
	IBOutlet NSTextField *stringPromptField;
	IBOutlet NSTextField *stringPromptText;
	IBOutlet NSButton *stringPromptAcceptButton;
	
	// aux windows
	MFUserSearchWindowController        *userSearchController;
	MFXfirePrefsWindowController        *xfireOptionsController;
	
	XfireSession   *xfSession;
	NSTimer        *growlSuppressionTimer;
	MacFireUIMode  currentMode;
	NSMutableArray *outstandingFriendRequests;
	NSMutableArray *chatWindows;
	BOOL           statusMessageWasAutoSet;
	
	// for delayed "friend changed" events
	BOOL           outlineReloadQueued;
}

- (void)changeToMode:(MacFireUIMode)aMode;

- (IBAction)beginLogin:(id)sender;

- (void)setMyModeView:(NSView *)aView;

- (IBAction)changeStatusText:(id)sender;

- (void)startSession;

- (void)startChatWithFriend:(XfireFriend *)fr;
- (MFChatWindowController *)chatWindowForFriend:(XfireFriend *)fr;
- (MFChatWindowController *)chatWindowForChat:(XfireChat *)chat;

- (int)activeRow; // in the friend outline view
- (XfireFriend *)selectedFriend; // get the selected friend (if any), or nil
- (XfireFriend *)selectedFriendNotFoF; // get selected friend that isn't a Friend of Friend (or nil), online or offline
- (XfireFriend *)selectedOnlineFriend; // get the friend in the list that is online (if any); returns nil if no selection or selection is offline
- (XfireFriend *)selectedOnlineFriendNotFoF; // get selected friend that isn't FoF, but only if they're online
- (XfireFriendGroup *)selectedFriendGroup;
- (XfireFriendGroup *)selectedCustomFriendGroup; // only custom friend groups; ignore standard dynamic groups
- (XfireFriendGroup *)friendGroupForItemAtRow:(int)row;

- (NSString *)folderCachePathForName:(NSString *)aName;

- (void)queueReloadData;

- (void)friendRequestSheetDidEnd;

// the simple string prompt aux window (used as a sheet)
- (IBAction)stringPromptAccept:(id)sender;
- (IBAction)stringPromptCancel:(id)sender;
- (void)runStringPrompt:(NSString *)prompt defaultValue:(NSString *)value acceptButton:(NSString *)acceptString didEndSelector:(SEL)aSelector contextInfo:(id)info;
- (void)runChangeNicknameSheet;
- (void)runAddCustomGroupSheet;
- (void)runRenameCustomGroupSheet;

@end

NSString* MFStringFromIPAddress(unsigned int addr);

