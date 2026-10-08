/*******************************************************************
    FILE:       MessengerContact.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the generic contact model.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MessengerContact.h"
#import "MessengerSession.h"

@implementation MessengerContact

- (id)initWithAccountID:(NSString *)accountID service:(MessengerService)service
{
    self = [super init];
    if( self )
    {
        _accountID = [accountID copy];
        _service = service;
        _isOnline = NO;
        _isPending = NO;
        _nickname = nil;
        _statusString = nil;
        _personalMessage = nil;
    }
    return self;
}

- (void)dealloc
{
    [_accountID release];
    [_nickname release];
    [_statusString release];
    [_personalMessage release];
    [super dealloc];
}

- (MessengerService)service { return _service; }
- (void)setService:(MessengerService)service { _service = service; }

- (void)setAccountID:(NSString *)anID
{
    if( _accountID != anID )
    {
        [_accountID release];
        _accountID = [anID copy];
    }
}

- (NSString *)accountID { return _accountID; }

- (void)setNickName:(NSString *)aName
{
    if( _nickname != aName )
    {
        [_nickname release];
        _nickname = [aName copy];
    }
}

- (NSString *)nickName { return _nickname; }

- (void)setStatusString:(NSString *)aString
{
    if( _statusString != aString )
    {
        [_statusString release];
        _statusString = [aString copy];
    }
}

- (NSString *)statusString { return _statusString; }

- (void)setPersonalMessage:(NSString *)aMessage
{
    if( _personalMessage != aMessage )
    {
        [_personalMessage release];
        _personalMessage = [aMessage copy];
    }
}

- (NSString *)personalMessage { return _personalMessage; }

- (void)setIsOnline:(BOOL)status { _isOnline = status; }
- (BOOL)isOnline { return _isOnline; }

- (void)setIsPending:(BOOL)pending { _isPending = pending; }
- (BOOL)isPending { return _isPending; }

- (void)setSession:(MessengerSession *)aSession { _session = aSession; }
- (MessengerSession *)session { return _session; }

- (NSString *)displayName
{
    if( [_nickname length] > 0 )
        return _nickname;
    return _accountID;
}

@end
