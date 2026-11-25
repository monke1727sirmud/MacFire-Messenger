/*******************************************************************
	FILE:		MFApplicationSupportController.h
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Controls access to the application support folder for MacFire
		and provides utilities to access the contents.
	
	HISTORY:
		2008 12 27  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class XfireFriend;
@class XfireSession;

extern NSString* kMFUserNameKey;          // NSString
extern NSString* kMFUserIDKey;            // NSNumber(int)
extern NSString* kMFNickNameKey;          // NSString
extern NSString* kMFLastSeenOnlineKey;    // NSDate
extern NSString* kMFIsFriendOfFriendKey;  // NSNumber(BOOL)

@interface MFApplicationSupportController : NSObject
{
	NSString *_basePath; // Should be   "~/Library/Application Support/MacFire"    (with tilde expanded)
}

// Singleton
+ (id)sharedController;

- (NSString *)soundsFolderPath;
//- (NSArray *)contactsForAccount:(int)userID;


// Manage contact info

- (void)updateContact:(XfireFriend *)xfFriend;
- (void)updateAllContacts:(XfireSession *)session;
- (NSDictionary *)cachedInfoForContact:(XfireFriend *)xfFriend;


// Chat logging

- (NSString *)chatLogFolderPathForAccount:(XfireFriend *)account;
- (NSString *)nextChatLogPathForAccount:(XfireFriend *)account; // a free file name

@end
