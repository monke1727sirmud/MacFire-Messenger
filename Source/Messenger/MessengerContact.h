/*******************************************************************
    FILE:       MessengerContact.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Generic contact model used by all non-Xfire protocol
        backends.  Mirrors the interface of XfireFriend but is
        protocol-agnostic.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>
#import "MessengerTypes.h"

@class MessengerSession;

@interface MessengerContact : NSObject
{
    MessengerService    _service;
    NSString            *_accountID;   // email, YID, screen name, or UIN
    NSString            *_nickname;
    NSString            *_statusString;
    NSString            *_personalMessage;
    BOOL                _isOnline;
    BOOL                _isPending;    // pending friend request
    MessengerSession    *_session;     // not retained
}

- (id)initWithAccountID:(NSString *)accountID service:(MessengerService)service;

- (MessengerService)service;
- (void)setService:(MessengerService)service;

- (void)setAccountID:(NSString *)anID;
- (NSString *)accountID;

- (void)setNickName:(NSString *)aName;
- (NSString *)nickName;

- (void)setStatusString:(NSString *)aString;
- (NSString *)statusString;

- (void)setPersonalMessage:(NSString *)aMessage;
- (NSString *)personalMessage;

- (void)setIsOnline:(BOOL)status;
- (BOOL)isOnline;

- (void)setIsPending:(BOOL)pending;
- (BOOL)isPending;

- (void)setSession:(MessengerSession *)aSession;
- (MessengerSession *)session;

- (NSString *)displayName; // nickname if set, else accountID

@end
