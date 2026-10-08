/*******************************************************************
    FILE:       MessengerSession.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the abstract session base class.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MessengerSession.h"
#import "MessengerContact.h"
#import "MessengerChat.h"

@implementation MessengerSession

+ (NSString *)defaultHostNameForService:(MessengerService)service
{
    switch( service )
    {
        case kMessengerServiceMSN:
            return @"ds.escargot.nina.chat";
        case kMessengerServiceYahoo:
            return @"scsa.msg.yahoo.com";
        case kMessengerServiceAIM:
        case kMessengerServiceICQ:
            return @"toc.oscar.nina.chat";
        case kMessengerServiceXfire:
        default:
            return @"cs.xfire.com";
    }
}

+ (unsigned short)defaultPortForService:(MessengerService)service
{
    switch( service )
    {
        case kMessengerServiceMSN:
            return 1863;
        case kMessengerServiceYahoo:
            return 5050;
        case kMessengerServiceAIM:
        case kMessengerServiceICQ:
            return 9898;
        case kMessengerServiceXfire:
        default:
            return 25775;
    }
}

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port
{
    self = [super init];
    if( self )
    {
        _service = service;
        _host = [host copy];
        _port = port;
        _status = kMessengerStatusOffline;
        _contacts = [[NSMutableArray alloc] init];
        _chats = [[NSMutableArray alloc] init];
        _loginIdentity = [[MessengerContact alloc] initWithAccountID:@"" service:service];
        _username = nil;
        _password = nil;
    }
    return self;
}

- (void)dealloc
{
    [_host release];
    [_username release];
    [_password release];
    [_contacts release];
    [_chats release];
    [_loginIdentity release];
    [super dealloc];
}

- (MessengerService)service { return _service; }
- (MessengerSessionStatus)status { return _status; }
- (NSString *)host { return _host; }
- (unsigned short)port { return _port; }

- (void)setDelegate:(id)aDelegate { _delegate = aDelegate; }
- (id)delegate { return _delegate; }

- (void)setUsername:(NSString *)aName
{
    if( _username != aName )
    {
        [_username release];
        _username = [aName copy];
        [_loginIdentity setAccountID:aName];
    }
}

- (NSString *)username { return _username; }

- (void)setPassword:(NSString *)aPassword
{
    if( _password != aPassword )
    {
        [_password release];
        _password = [aPassword copy];
    }
}

- (NSString *)password { return _password; }

- (MessengerContact *)loginIdentity { return _loginIdentity; }

- (NSArray *)contacts { return [NSArray arrayWithArray:_contacts]; }

- (NSArray *)contactsOnline
{
    NSMutableArray *online = [NSMutableArray array];
    for( MessengerContact *c in _contacts )
    {
        if( [c isOnline] )
            [online addObject:c];
    }
    return online;
}

- (MessengerContact *)contactForAccountID:(NSString *)accountID
{
    for( MessengerContact *c in _contacts )
    {
        if( [[c accountID] isEqualToString:accountID] )
            return c;
    }
    return nil;
}

- (void)connect
{
    if( _status != kMessengerStatusOffline )
        return;
    [self setStatus:kMessengerStatusLoggingOn];
    [self doConnect];
}

- (void)disconnect
{
    if( _status == kMessengerStatusOffline )
        return;
    [self setStatus:kMessengerStatusLoggingOff];
    [self doDisconnect];
}

- (void)setStatusString:(NSString *)text
{
    [self doSetStatusString:text];
}

- (void)setNickname:(NSString *)text
{
    [self doSetNickname:text];
}

- (void)sendFriendInvitation:(NSString *)accountID message:(NSString *)msg
{
    [self doSendFriendInvitation:accountID message:msg];
}

- (void)sendRemoveContact:(MessengerContact *)contact
{
    [self doRemoveContact:contact];
}

- (void)acceptFriendRequest:(MessengerContact *)contact
{
    [self doAcceptFriendRequest:contact];
}

- (void)declineFriendRequest:(MessengerContact *)contact
{
    [self doDeclineFriendRequest:contact];
}

- (MessengerChat *)beginChatWithContact:(MessengerContact *)contact
{
    MessengerChat *chat = [[MessengerChat alloc] initWithRemoteContact:contact session:self];
    [_chats addObject:chat];
    [chat release];
    return chat;
}

- (void)endChat:(MessengerChat *)chat
{
    [_chats removeObject:chat];
}

- (void)sendMessage:(NSString *)message toContact:(MessengerContact *)contact
{
    [self doSendMessage:message toContact:contact];
}

// --- Subclass overrides (default no-op implementations) ---

- (void)doConnect {}
- (void)doDisconnect {}
- (void)doSendMessage:(NSString *)message toContact:(MessengerContact *)contact {}
- (void)doSetStatusString:(NSString *)text {}
- (void)doSetNickname:(NSString *)text {}
- (void)doSendFriendInvitation:(NSString *)accountID message:(NSString *)msg {}
- (void)doRemoveContact:(MessengerContact *)contact {}
- (void)doAcceptFriendRequest:(MessengerContact *)contact {}
- (void)doDeclineFriendRequest:(MessengerContact *)contact {}

// --- Helpers for subclasses ---

- (void)setStatus:(MessengerSessionStatus)newStatus
{
    _status = newStatus;
    if( [_delegate respondsToSelector:@selector(messengerSession:didChangeStatus:)] )
        [_delegate messengerSession:self didChangeStatus:newStatus];
}

- (void)addContact:(MessengerContact *)contact
{
    [contact setSession:self];
    if( ![_contacts containsObject:contact] )
        [_contacts addObject:contact];
}

- (void)removeContact:(MessengerContact *)contact
{
    [_contacts removeObject:contact];
}

- (void)notifyContactChange:(MessengerContact *)contact attribute:(MessengerContactChangeAttribute)attr
{
    if( [_delegate respondsToSelector:@selector(messengerSession:contactDidChange:attribute:)] )
        [_delegate messengerSession:self contactDidChange:contact attribute:attr];

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[NSNumber numberWithInt:attr] forKey:kMessengerContactChangeAttribute];
    [[NSNotificationCenter defaultCenter] postNotificationName:MessengerContactDidChangeNotification
                                                        object:contact
                                                      userInfo:userInfo];
}

- (void)notifyLoginFailed:(NSString *)reason
{
    [self setStatus:kMessengerStatusOffline];
    if( [_delegate respondsToSelector:@selector(messengerSessionLoginFailed:reason:)] )
        [_delegate messengerSessionLoginFailed:self reason:reason];
}

- (void)notifyWillDisconnect:(NSString *)reason
{
    if( [_delegate respondsToSelector:@selector(messengerSessionWillDisconnect:reason:)] )
        [_delegate messengerSessionWillDisconnect:self reason:reason];
    [self setStatus:kMessengerStatusOffline];
}

- (void)notifyDidBeginChat:(MessengerChat *)chat
{
    if( [_delegate respondsToSelector:@selector(messengerSession:didBeginChat:)] )
        [_delegate messengerSession:self didBeginChat:chat];
}

- (void)notifyChatDidEnd:(MessengerChat *)chat
{
    if( [_delegate respondsToSelector:@selector(messengerSession:chatDidEnd:)] )
        [_delegate messengerSession:self chatDidEnd:chat];
}

- (void)notifyStatusChanged
{
    if( [_delegate respondsToSelector:@selector(messengerSession:didChangeStatus:)] )
        [_delegate messengerSession:self didChangeStatus:_status];
}

- (void)notifyNicknameChanged:(NSString *)newNick
{
    [_loginIdentity setNickName:newNick];
    if( [_delegate respondsToSelector:@selector(messengerSession:nicknameDidChange:)] )
        [_delegate messengerSession:self nicknameDidChange:newNick];
}

- (void)notifyFriendshipRequests:(NSArray *)requestors
{
    if( [_delegate respondsToSelector:@selector(messengerSession:didReceiveFriendshipRequests:)] )
        [_delegate messengerSession:self didReceiveFriendshipRequests:requestors];
}

@end
