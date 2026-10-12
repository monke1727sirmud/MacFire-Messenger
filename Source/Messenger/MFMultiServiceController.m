/*******************************************************************
    FILE:       MFMultiServiceController.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the multi-service coordinator.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MFMultiServiceController.h"
#import "MFPreferences.h"
#import "MessengerSession.h"
#import "MessengerContact.h"
#import "MessengerChat.h"
#import "MSNPSession.h"
#import "YMSGSession.h"
#import "TOCSession.h"
#import "XfireSession.h"
#import "XfireFriend.h"
#import "XfireChat.h"

static MFMultiServiceController *gSharedController = nil;

@interface MFMultiServiceController (Private)
- (MessengerSession *)createSessionForService:(MessengerService)service;
- (void)registerForNotifications;
- (void)contactDidChange:(NSNotification *)note;
@end

@implementation MFMultiServiceController

+ (MFMultiServiceController *)sharedController
{
    if( gSharedController == nil )
        gSharedController = [[MFMultiServiceController alloc] init];
    return gSharedController;
}

- (id)init
{
    self = [super init];
    if( self )
    {
        _messengerSessions = [[NSMutableDictionary alloc] init];
        _xfireSession = nil;
        [self registerForNotifications];
    }
    return self;
}

- (void)dealloc
{
    [_xfireSession release];
    [_messengerSessions release];
    [super dealloc];
}

- (void)setDelegate:(id)aDelegate { _delegate = aDelegate; }
- (id)delegate { return _delegate; }

- (XfireSession *)xfireSession { return _xfireSession; }

- (MessengerSession *)sessionForService:(MessengerService)service
{
    if( service == kMessengerServiceXfire )
        return nil;
    return [_messengerSessions objectForKey:[NSNumber numberWithInt:(int)service]];
}

- (NSArray *)allSessions
{
    return [_messengerSessions allValues];
}

- (void)connectXfireWithHost:(NSString *)host port:(unsigned short)port
{
    if( _xfireSession )
        return;

    NSHost *xfireHost = [NSHost hostWithName:host];
    _xfireSession = [[XfireSession newSessionWithHost:xfireHost port:port] retain];
    // The main window controller will set itself as delegate and call connect.
}

- (MessengerSession *)createSessionForService:(MessengerService)service
{
    MFPreferences *prefs = [MFPreferences preferences];
    NSString *host = [prefs serverHostNameForService:service];
    unsigned short port = [prefs serverPortForService:service];
    NSString *username = [prefs userNameForService:service];

    MessengerSession *session = nil;
    switch( service )
    {
        case kMessengerServiceMSN:
            session = [[MSNPSession alloc] initWithService:service host:host port:port];
            break;
        case kMessengerServiceYahoo:
            session = [[YMSGSession alloc] initWithService:service host:host port:port];
            break;
        case kMessengerServiceAIM:
        case kMessengerServiceICQ:
            session = [[TOCSession alloc] initWithService:service host:host port:port];
            break;
        default:
            return nil;
    }

    if( session )
    {
        [session setUsername:username];
        // Password is supplied at login time by the delegate.
        [session setDelegate:self];
        [session autorelease];

        NSNumber *key = [NSNumber numberWithInt:(int)service];
        [_messengerSessions setObject:[session retain] forKey:key];
        [session release];
    }

    return session;
}

- (void)connectService:(MessengerService)service
{
    MessengerSession *session = [self sessionForService:service];
    if( session == nil )
        session = [self createSessionForService:service];
    if( session )
    {
        // Set credentials from preferences
        MFPreferences *prefs = [MFPreferences preferences];
        [session setUsername:[prefs userNameForService:service]];
        [session connect];
    }
}

- (void)connectAllEnabledServices
{
    MFPreferences *prefs = [MFPreferences preferences];

    MessengerService services[] = {
        kMessengerServiceMSN, kMessengerServiceYahoo,
        kMessengerServiceAIM, kMessengerServiceICQ
    };

    for( int i = 0; i < 4; i++ )
    {
        MessengerService svc = services[i];
        if( [prefs isServiceEnabled:svc] )
        {
            NSString *username = [prefs userNameForService:svc];
            if( username && [username length] > 0 )
                [self connectService:svc];
        }
    }
}

- (void)disconnectAll
{
    NSEnumerator *e = [_messengerSessions objectEnumerator];
    MessengerSession *session;
    while( (session = [e nextObject]) )
    {
        [session disconnect];
    }
    if( _xfireSession )
        [_xfireSession disconnect];
}

- (NSArray *)allContacts
{
    NSMutableArray *all = [NSMutableArray array];
    NSEnumerator *e = [_messengerSessions objectEnumerator];
    MessengerSession *session;
    while( (session = [e nextObject]) )
    {
        [all addObjectsFromArray:[session contacts]];
    }
    return all;
}

- (NSArray *)allOnlineContacts
{
    NSMutableArray *online = [NSMutableArray array];
    NSEnumerator *e = [_messengerSessions objectEnumerator];
    MessengerSession *session;
    while( (session = [e nextObject]) )
    {
        [online addObjectsFromArray:[session contactsOnline]];
    }
    return online;
}

- (int)totalContactCount
{
    int count = 0;
    NSEnumerator *e = [_messengerSessions objectEnumerator];
    MessengerSession *session;
    while( (session = [e nextObject]) )
    {
        count += [[session contacts] count];
    }
    return count;
}

- (int)onlineContactCount
{
    int count = 0;
    NSEnumerator *e = [_messengerSessions objectEnumerator];
    MessengerSession *session;
    while( (session = [e nextObject]) )
    {
        count += [[session contactsOnline] count];
    }
    return count;
}

- (void)startChatWithMessengerContact:(MessengerContact *)contact
{
    MessengerSession *session = [contact session];
    if( session )
    {
        MessengerChat *chat = [session beginChatWithContact:contact];
        if( [_delegate respondsToSelector:@selector(multiServiceController:didBeginMessengerChat:)] )
            [_delegate multiServiceController:self didBeginMessengerChat:chat];
    }
}

- (void)startChatWithXfireFriend:(XfireFriend *)fr
{
    if( _xfireSession )
    {
        XfireChat *chat = [_xfireSession beginChatWithFriend:fr];
        if( [_delegate respondsToSelector:@selector(multiServiceController:didBeginXfireChat:)] )
            [_delegate multiServiceController:self didBeginXfireChat:chat];
    }
}

// --- MessengerSessionDelegate ---

- (void)messengerSession:(MessengerSession *)session didChangeStatus:(MessengerSessionStatus)newStatus
{
    MessengerService service = [session service];
    if( newStatus == kMessengerStatusOnline )
    {
        if( [_delegate respondsToSelector:@selector(multiServiceController:sessionDidConnect:)] )
            [_delegate multiServiceController:self sessionDidConnect:service];
    }
    else if( newStatus == kMessengerStatusOffline )
    {
        if( [_delegate respondsToSelector:@selector(multiServiceController:sessionDidDisconnect:)] )
            [_delegate multiServiceController:self sessionDidDisconnect:service];
    }
}

- (void)messengerSessionLoginFailed:(MessengerSession *)session reason:(NSString *)reason
{
    MessengerService service = [session service];
    if( [_delegate respondsToSelector:@selector(multiServiceController:sessionLoginFailed:reason:)] )
        [_delegate multiServiceController:self sessionLoginFailed:service reason:reason];
}

- (void)messengerSessionWillDisconnect:(MessengerSession *)session reason:(NSString *)reason
{
    // Will transition to offline via didChangeStatus
}

- (void)messengerSession:(MessengerSession *)session contactDidChange:(MessengerContact *)contact
                  attribute:(MessengerContactChangeAttribute)attr
{
    if( [_delegate respondsToSelector:@selector(multiServiceController:contactListDidChange)] )
        [_delegate multiServiceController:self contactListDidChange];
}

- (void)messengerSession:(MessengerSession *)session didBeginChat:(MessengerChat *)chat
{
    if( [_delegate respondsToSelector:@selector(multiServiceController:didBeginMessengerChat:)] )
        [_delegate multiServiceController:self didBeginMessengerChat:chat];
}

- (void)messengerSession:(MessengerSession *)session chatDidEnd:(MessengerChat *)chat
{
    // Handled by individual chat window controllers
}

- (void)messengerSession:(MessengerSession *)session nicknameDidChange:(NSString *)newNick
{
    // Could update unified display. For now, ignore.
}

- (void)messengerSession:(MessengerSession *)session didReceiveFriendshipRequests:(NSArray *)requestors
{
    // Forward to delegate for UI handling
}

// --- Notification handling ---

- (void)registerForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(contactDidChange:)
                                                name:MessengerContactDidChangeNotification
                                              object:nil];
}

- (void)contactDidChange:(NSNotification *)note
{
    if( [_delegate respondsToSelector:@selector(multiServiceController:contactListDidChange)] )
        [_delegate multiServiceController:self contactListDidChange];
}

@end
