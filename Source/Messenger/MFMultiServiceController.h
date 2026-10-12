/*******************************************************************
    FILE:       MFMultiServiceController.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Coordinates multiple protocol sessions (Xfire, MSN, Yahoo,
        AIM, ICQ) and provides a unified contact list to the UI.
        The main window controller delegates to this for multi-
        service login, contact aggregation, and chat routing.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>
#import "MessengerTypes.h"

@class XfireSession;
@class MessengerSession;
@class MessengerContact;
@class MessengerChat;
@class XfireFriend;
@class XfireChat;

@interface MFMultiServiceController : NSObject
{
    XfireSession          *_xfireSession;
    NSMutableDictionary  *_messengerSessions; // service(int) -> MessengerSession
    id                    _delegate;
}

+ (MFMultiServiceController *)sharedController;

- (void)setDelegate:(id)aDelegate;
- (id)delegate;

- (XfireSession *)xfireSession;
- (MessengerSession *)sessionForService:(MessengerService)service;
- (NSArray *)allSessions;

// Login
- (void)connectXfireWithHost:(NSString *)host port:(unsigned short)port;
- (void)connectService:(MessengerService)service;
- (void)connectAllEnabledServices;
- (void)disconnectAll;

// Unified contact list across all services
- (NSArray *)allContacts;           // MessengerContact objects from all non-Xfire sessions
- (NSArray *)allOnlineContacts;
- (int)totalContactCount;
- (int)onlineContactCount;

// Chat routing
- (void)startChatWithMessengerContact:(MessengerContact *)contact;
- (void)startChatWithXfireFriend:(XfireFriend *)friend;

@end

@interface NSObject (MFMultiServiceDelegate)
- (void)multiServiceController:(MFMultiServiceController *)controller
           sessionDidConnect:(MessengerService)service;
- (void)multiServiceController:(MFMultiServiceController *)controller
          sessionDidDisconnect:(MessengerService)service;
- (void)multiServiceController:(MFMultiServiceController *)controller
         sessionLoginFailed:(MessengerService)service reason:(NSString *)reason;
- (void)multiServiceController:(MFMultiServiceController *)controller
         contactListDidChange;
- (void)multiServiceController:(MFMultiServiceController *)controller
        didBeginMessengerChat:(MessengerChat *)chat;
- (void)multiServiceController:(MFMultiServiceController *)controller
        didBeginXfireChat:(XfireChat *)chat;
@end
