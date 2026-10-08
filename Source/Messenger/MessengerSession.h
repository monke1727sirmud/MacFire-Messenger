/*******************************************************************
    FILE:       MessengerSession.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Abstract base class for protocol sessions.  Each protocol
        backend (MSNP, YMSG, TOC) subclasses this and implements
        the connection, login, and messaging logic for its service.
        The UI layer interacts only through this interface.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>
#import "MessengerTypes.h"

@class MessengerContact;
@class MessengerChat;

typedef enum
{
    kMessengerStatusOffline = 0,
    kMessengerStatusOnline,
    kMessengerStatusLoggingOn,
    kMessengerStatusLoggingOff
} MessengerSessionStatus;

@interface MessengerSession : NSObject
{
    MessengerSessionStatus   _status;
    MessengerService         _service;
    NSString                 *_host;
    unsigned short           _port;
    NSString                 *_username;
    NSString                 *_password;
    id                       _delegate;
    NSMutableArray           *_contacts;
    NSMutableArray           *_chats;
    MessengerContact         *_loginIdentity;
}

+ (NSString *)defaultHostNameForService:(MessengerService)service;
+ (unsigned short)defaultPortForService:(MessengerService)service;

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port;

- (MessengerService)service;
- (MessengerSessionStatus)status;
- (NSString *)host;
- (unsigned short)port;

- (void)setDelegate:(id)aDelegate;
- (id)delegate;

- (void)setUsername:(NSString *)aName;
- (NSString *)username;
- (void)setPassword:(NSString *)aPassword;
- (NSString *)password;

- (MessengerContact *)loginIdentity;
- (NSArray *)contacts;
- (NSArray *)contactsOnline;
- (MessengerContact *)contactForAccountID:(NSString *)accountID;

- (void)connect;
- (void)disconnect;

- (void)setStatusString:(NSString *)text;
- (void)setNickname:(NSString *)text;

- (void)sendFriendInvitation:(NSString *)accountID message:(NSString *)msg;
- (void)sendRemoveContact:(MessengerContact *)contact;
- (void)acceptFriendRequest:(MessengerContact *)contact;
- (void)declineFriendRequest:(MessengerContact *)contact;

- (MessengerChat *)beginChatWithContact:(MessengerContact *)contact;
- (void)endChat:(MessengerChat *)chat;
- (void)sendMessage:(NSString *)message toContact:(MessengerContact *)contact;

// Subclasses must override these
- (void)doConnect;
- (void)doDisconnect;
- (void)doSendMessage:(NSString *)message toContact:(MessengerContact *)contact;
- (void)doSetStatusString:(NSString *)text;
- (void)doSetNickname:(NSString *)text;
- (void)doSendFriendInvitation:(NSString *)accountID message:(NSString *)msg;
- (void)doRemoveContact:(MessengerContact *)contact;
- (void)doAcceptFriendRequest:(MessengerContact *)contact;
- (void)doDeclineFriendRequest:(MessengerContact *)contact;

// Helpers for subclasses to update state and notify
- (void)setStatus:(MessengerSessionStatus)newStatus;
- (void)addContact:(MessengerContact *)contact;
- (void)removeContact:(MessengerContact *)contact;
- (void)notifyContactChange:(MessengerContact *)contact attribute:(MessengerContactChangeAttribute)attr;
- (void)notifyLoginFailed:(NSString *)reason;
- (void)notifyWillDisconnect:(NSString *)reason;
- (void)notifyDidBeginChat:(MessengerChat *)chat;
- (void)notifyChatDidEnd:(MessengerChat *)chat;
- (void)notifyStatusChanged;
- (void)notifyNicknameChanged:(NSString *)newNick;
- (void)notifyFriendshipRequests:(NSArray *)requestors;

@end


@interface NSObject (MessengerSessionDelegate)

- (void)messengerSession:(MessengerSession *)session didChangeStatus:(MessengerSessionStatus)newStatus;
- (void)messengerSessionLoginFailed:(MessengerSession *)session reason:(NSString *)reason;
- (void)messengerSessionWillDisconnect:(MessengerSession *)session reason:(NSString *)reason;
- (void)messengerSession:(MessengerSession *)session contactDidChange:(MessengerContact *)contact attribute:(MessengerContactChangeAttribute)attr;
- (void)messengerSession:(MessengerSession *)session didBeginChat:(MessengerChat *)chat;
- (void)messengerSession:(MessengerSession *)session chatDidEnd:(MessengerChat *)chat;
- (void)messengerSession:(MessengerSession *)session nicknameDidChange:(NSString *)newNick;
- (void)messengerSession:(MessengerSession *)session didReceiveFriendshipRequests:(NSArray *)requestors;

@end
