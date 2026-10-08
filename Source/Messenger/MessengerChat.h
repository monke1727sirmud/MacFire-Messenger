/*******************************************************************
    FILE:       MessengerChat.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Generic chat conversation model for non-Xfire protocols.
        Mirrors XfireChat but uses MessengerContact and
        MessengerSession.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class MessengerContact;
@class MessengerSession;

@interface MessengerChat : NSObject
{
    MessengerContact    *_remoteContact; // not retained; owned by session
    MessengerSession    *_session;       // not retained
    id                  _delegate;
}

- (id)initWithRemoteContact:(MessengerContact *)aContact session:(MessengerSession *)aSession;

- (MessengerContact *)remoteContact;
- (MessengerSession *)session;

- (void)sendMessage:(NSString *)message;

- (void)setDelegate:(id)aDelegate;
- (id)delegate;

- (void)closeChat;

- (void)didReceiveMessage:(NSString *)message; // called by session to deliver incoming

@end

@interface NSObject (MessengerChatDelegate)
- (void)messengerSession:(MessengerSession *)session chat:(MessengerChat *)aChat didReceiveMessage:(NSString *)msg;
@end
