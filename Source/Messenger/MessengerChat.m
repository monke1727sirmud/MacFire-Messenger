/*******************************************************************
    FILE:       MessengerChat.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the generic chat model.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MessengerChat.h"
#import "MessengerSession.h"

@implementation MessengerChat

- (id)initWithRemoteContact:(MessengerContact *)aContact session:(MessengerSession *)aSession
{
    self = [super init];
    if( self )
    {
        _remoteContact = aContact;
        _session = aSession;
        _delegate = nil;
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (MessengerContact *)remoteContact { return _remoteContact; }
- (MessengerSession *)session { return _session; }

- (void)sendMessage:(NSString *)message
{
    [_session sendMessage:message toContact:_remoteContact];
}

- (void)setDelegate:(id)aDelegate { _delegate = aDelegate; }
- (id)delegate { return _delegate; }

- (void)closeChat
{
    [_session endChat:self];
    [self autorelease];
}

- (void)didReceiveMessage:(NSString *)message
{
    if( [_delegate respondsToSelector:@selector(messengerSession:chat:didReceiveMessage:)] )
        [_delegate messengerSession:_session chat:self didReceiveMessage:message];
}

@end
