/*******************************************************************
	FILE:		XfireFriend.h
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Container represents information about a contact on the Xfire
		network.
	
	HISTORY:
		2008 04 12  Moved display string stuff out elsewhere.
		2008 04 06  Changed copyright to BSD license.
		2008 03 01  Added first and last name support.
		2008 02 10  Added support for game IP and port.
		2008 01 12  Added copyright notice.
		2007 11 20  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class XfireSession;

@interface XfireFriend : NSObject
{
	unsigned int		_userID;
	NSString			*_username;
	NSString			*_nickname;
	NSString			*_firstName;
	NSString			*_lastName;
	
	BOOL				_isOnline;
	NSData				*_sessionID; // 16 byte UUID, nil if not online
	
	BOOL				_isFriendOfFriend;
	NSMutableArray		*_commonFriendIDs; // array of NSNumbers of common friend IDs
	
	NSString			*_statusString;
	
	unsigned int		_gameID;
	unsigned int		_gameIPAddress;
	unsigned short		_gamePort;
	
	// for chats
	unsigned int		_publicIP;
	unsigned short		_publicPort;
	
	XfireSession		*_session;
}

// create using usual -init

- (void)setUserID:(unsigned int)newID;
- (unsigned int)userID;

- (void)setUserName:(NSString *)aName;
- (NSString *)userName;

- (void)setNickName:(NSString *)aName;
- (NSString *)nickName;

- (void)setFirstName:(NSString *)aName;
- (NSString *)firstName;

- (void)setLastName:(NSString *)aName;
- (NSString *)lastName;

- (void)setIsOnline:(BOOL)status;
- (BOOL)isOnline;

- (void)setIsFriendOfFriend:(BOOL)isFoF;
- (BOOL)isFriendOfFriend;

- (void)setSessionID:(NSData *)anID;
- (NSData *)sessionID;

- (void)setPublicIP:(unsigned int)anIP;
- (unsigned int)publicIP;

- (void)setPublicPort:(unsigned short)aPort;
- (unsigned short)publicPort;

- (void)setStatusString:(NSString *)aString;
- (NSString *)statusString;

- (void)setGameID:(int)anID;
- (int)gameID;

- (void)setGameIPAddress:(unsigned int)anIP;
- (unsigned int)gameIPAddress;

- (void)setGamePort:(unsigned short)port;
- (unsigned short)gamePort;

- (void)setSession:(XfireSession *)aSession;
- (XfireSession *)session;

// For Friend of Friend only
- (void)addCommonFriendID:(NSNumber*)anID;
- (NSArray *)commonFriends; // array of XfireFriend

@end
