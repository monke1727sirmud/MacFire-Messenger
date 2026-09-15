/*******************************************************************
	FILE:		MFPreferences.h
	
	COPYRIGHT:
		Copyright 2007-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Provides a specialized interface to NSUserDefaults.  It takes
		care of setting up the default preferences and interfacing
		with NSUserDefaults by handling the details of encoding and
		decoding settings in a manner that NSUserDefaults can understand
		(since it can't store just any type).
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2008 03 01  Added Xfire network traffic log pref.
		2008 01 03  Added friend name and status colunn widths.
		2007 12 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

// This notification is generated when the user clicks the OK
// button on the preference window to accept changes.
extern NSString *MFPreferencesChangedNotificationName;

#define kMFPreferenceDisplayStyleNickname 1
#define kMFPreferenceDisplayStyleUsername 2
#define kMFPreferenceDisplayStyleNickUser 3
#define kMFPreferenceDisplayStyleUserNick 4

@interface MFPreferences : NSObject
{
}

+ (MFPreferences *)preferences;
+ (NSMutableDictionary *)defaultPreferences;
+ (void)resetPreferences;

// general
- (int)nameDisplayStyle; // default kMFPreferencedisplayStyleNickname
- (BOOL)showIdleStatusAutomatically; // default YES
- (unsigned int)idleStatusDelay; // default 3 min
- (BOOL)trackUserGameStatus; // default is YES -- TBD, do we want to turn this off?
- (BOOL)logXfireNetworkTraffic; // default is NO

// main window common/general
- (NSRect)mainWindowFrame; // default {349,367}x{377,301} (TBD)
- (NSArray *)customStatusStrings; // default is ().  Always get: ("", "(AFK) Away From Keyboard")

// log in pane
- (NSString *)defaultUserName; // default "", from last successful login session
- (NSArray *)userNameHistory; // the last 5 known user names

// friends list pane
- (float)friendNameColumnWidth; // default TBD
- (float)friendStatusColumnWidth; // default TBD
- (float)friendGameColumnWidth; // default TBD

// chat window
- (BOOL)showWhenTyping; // default NO
- (BOOL)showTimeStampsInChats; // default YES?
- (BOOL)logChats; // default NO
- (NSFont *)chatTextFont;
+ (NSFont *)defaultChatTextFont;
- (NSColor *)defaultFriendNameChatColor; // JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (NSColor *)myNameChatColor; // JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history

// notifications
- (BOOL)shouldPostGrowlNotifications; // default YES
- (BOOL)postGrowlNotificationsWhileActive; // default NO

// official Xfire stuff
- (BOOL)poseAsNewerXfireClient;
- (unsigned int)posingXfireClientVersion;
- (NSString *)xfireServerHostName;
- (unsigned int)xfireServerPortNumber;


// local game settings
// TBD
//- (NSDictionary *)settingsForGameID:(int)gid;

// other misc
// blocked users list
// sounds


- (void)setNameDisplayStyle:(int)styleNumber;
- (void)setShowIdleStatusAutomatically:(BOOL)setting;
- (void)setIdleStatusDelay:(unsigned int)delay;
- (void)setTrackUserGameStatus:(BOOL)setting;
- (void)setLogXfireNetworkTraffic:(BOOL)shouldLog;
- (void)setMainWindowFrame:(NSRect)aRect;
- (void)addCustomStatusString:(NSString *)string;
- (void)setDefaultUserName:(NSString *)aName;
- (void)addUserNameHistory:(NSString *)name;
- (void)setFriendNameColumnWidth:(float)width;
- (void)setFriendStatusColumnWidth:(float)width;
- (void)setFriendGameColumnWidth:(float)width;
- (void)setShowWhenTyping:(BOOL)show;
- (void)setShowTimeStampsInChats:(BOOL)show;
- (void)setLogChats:(BOOL)log;
- (void)setChatTextFont:(NSFont *)font;
- (void)setShouldPostGrowlNotifications:(BOOL)post;
- (void)setPostGrowlNotificationsWhileActive:(BOOL)post;
- (void)setPoseAsNewerXfireClient:(BOOL)pose;
- (void)setPosingXfireClientVersion:(unsigned int)version;
- (void)setDefaultChatColorForFriendsName:(NSColor *)aColor; // JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (void)setChatColorForMyName:(NSColor *)aColor; // JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history

@end
