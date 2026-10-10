/*******************************************************************
    FILE:       MessengerSocket.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        TCP socket wrapper for the messenger protocol layer.
        Mirrors XfireSocket's interface but is independent so the
        messenger code does not depend on the Xfire library.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@interface MessengerSocket : NSObject
{
    CFSocketRef         _sock;
    CFRunLoopSourceRef  _runLoopSource;
    NSRunLoop           *_runLoop;
    id                  _delegate;
    NSMutableData       *_receiveBuffer;
}

- (id)initWithTCPConnectionToHost:(NSString *)hostName port:(unsigned short)portNumber;
- (void)setDelegate:(id)aDelegate;
- (id)delegate;
- (BOOL)isConnected;
- (BOOL)sendData:(NSData *)data;
- (void)close;
- (void)scheduleInRunLoop:(NSRunLoop *)aLoop;

@end

enum {
    kMessengerSocketNormalDisconnect = 1,
    kMessengerSocketAbnormalTermination
};

@interface NSObject (MessengerSocketDelegate)
- (void)messengerSocket:(MessengerSocket *)aSock didReceiveData:(NSData *)data;
- (void)messengerSocketDidDisconnect:(MessengerSocket *)aSock reason:(int)reasonCode;
@end
