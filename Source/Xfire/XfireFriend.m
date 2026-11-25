/*******************************************************************
	FILE:		XfireFriend.m
	
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

#import "XfireFriend.h"
#import "XfireSession_Private.h"

@implementation XfireFriend

- (id)init
{
	self = [super init];
	if( self )
	{
		_userID = 0;
		_username = nil;
		_nickname = nil;
		_firstName = nil;
		_lastName = nil;
		_isOnline = NO;
		_sessionID = nil;
		_statusString = nil;
		_publicIP = 0;
		_publicPort = 0;
		_gameID = 0;
		_gameIPAddress = 0;
		_gamePort = 0;
		_isFriendOfFriend = NO;
		_commonFriendIDs = nil;
	}
	return self;
}

- (void)dealloc
{
	[_username release];
	[_nickname release];
	[_sessionID release];
	[_statusString release];
	[_commonFriendIDs release];
	
	_username = nil;
	_nickname = nil;
	_sessionID = nil;
	_statusString = nil;
	_commonFriendIDs = nil;
	
	[super dealloc];
}

- (void)setUserID:(unsigned int)newID
{
	_userID = newID;
}
- (unsigned int)userID
{
	return _userID;
}

- (void)setUserName:(NSString *)aName
{
	NSString *tmp = [aName copy];
	[_username release];
	_username = tmp;
}
- (NSString *)userName
{
	return _username;
}

- (void)setNickName:(NSString *)aName
{
	NSString *tmp = [aName copy];
	[_nickname release];
	_nickname = tmp;
}
- (NSString *)nickName
{
	return _nickname;
}

- (void)setFirstName:(NSString *)aName
{
	NSString *tmp = [aName copy];
	[_firstName release];
	_firstName = tmp;
}
- (NSString *)firstName
{
	return _firstName;
}

- (void)setLastName:(NSString *)aName
{
	NSString *tmp = [aName copy];
	[_lastName release];
	_lastName = tmp;
}
- (NSString *)lastName
{
	return _lastName;
}


- (void)setIsOnline:(BOOL)status
{
	_isOnline = status;
}
- (BOOL)isOnline
{
	return _isOnline;
}

- (void)setIsFriendOfFriend:(BOOL)isFoF
{
	_isFriendOfFriend = isFoF;
}
- (BOOL)isFriendOfFriend
{
	return _isFriendOfFriend;
}

- (void)setSessionID:(NSData *)anID
{
	NSData *tmp = [anID copy];
	[_sessionID release];
	_sessionID = tmp;
}
- (NSData *)sessionID
{
	return _sessionID;
}

- (void)setPublicIP:(unsigned int)anIP
{
	_publicIP = anIP;
}
- (unsigned int)publicIP
{
	return _publicIP;
}

- (void)setPublicPort:(unsigned short)aPort
{
	_publicPort = aPort;
}
- (unsigned short)publicPort
{
	return _publicPort;
}

- (void)setStatusString:(NSString *)aString
{
	NSString *tmp = [aString copy];
	[_statusString release];
	_statusString = tmp;
}
- (NSString *)statusString
{
	if( _statusString )
		return _statusString;
	return @"";
}

- (void)setGameID:(int)anID
{
	_gameID = anID;
}
- (int)gameID
{
	return _gameID;
}

- (void)setGameIPAddress:(unsigned int)anIP
{
	_gameIPAddress = anIP;
}
- (unsigned int)gameIPAddress
{
	return _gameIPAddress;
}

- (void)setGamePort:(unsigned short)port
{
	_gamePort = port;
}
- (unsigned short)gamePort
{
	return _gamePort;
}

- (void)setSession:(XfireSession *)aSession
{
	_session = aSession;
}

- (XfireSession *)session
{
	return _session;
}

// For Friend of Friend only
- (void)addCommonFriendID:(NSNumber*)anID
{
	if( _commonFriendIDs == nil )
		_commonFriendIDs = [[NSMutableArray alloc] init];
	[_commonFriendIDs addObject:anID];
}

// array of XfireFriend
- (NSArray *)commonFriends
{
	int i, cnt;
	NSMutableArray *arr = [NSMutableArray array];
	NSNumber *frID;
	XfireFriend *fr;
	
	cnt = [_commonFriendIDs count];
	for( i = 0; i < cnt; i++ )
	{
		frID = [_commonFriendIDs objectAtIndex:i];
		fr = [[self session] friendForUserID:[frID unsignedIntValue]];
		if( fr )
		{
			[arr addObject:fr];
		}
	}
	
	return arr;
}

- (NSString *)description
{
	NSMutableString *str = [NSMutableString string];
	
	[str appendFormat:@"XfireFriend (%@):\n",_nickname];
	[str appendFormat:@"  user ID     = %u (0x%08x)\n",_userID,_userID];
	[str appendFormat:@"  user name   = %@\n",_username];
	[str appendFormat:@"  nick name   = %@\n",_nickname];
	[str appendFormat:@"  status      = %@\n",_statusString];
	[str appendFormat:@"  game ID     = %d\n",_gameID];
	[str appendFormat:@"  session ID  = %@\n",_sessionID];
	[str appendFormat:@"  is online   = %@\n", (_isOnline?@"Yes":@"No")];
	[str appendFormat:@"  public IP   = %d (0x%08x)\n",_publicIP,_publicIP];
	[str appendFormat:@"  public port = %d\n",_publicPort];
	
	return str;
}

- (NSComparisonResult)compareFriendsByUserName:(XfireFriend *)aFriend
{
	return [[self userName] compare:[aFriend userName]];
}

@end
