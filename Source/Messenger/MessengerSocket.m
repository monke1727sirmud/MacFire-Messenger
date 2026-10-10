/*******************************************************************
    FILE:       MessengerSocket.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        TCP socket wrapper for messenger protocols.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MessengerSocket.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

static void _MessengerSocketCallback(CFSocketRef sock, CFSocketCallBackType cbType,
                                      CFDataRef address, const void *data, void *info);

@interface MessengerSocket (Private)
- (void)receiveData:(NSData *)data;
- (void)closeWithReason:(int)reasonCode;
- (void)_close;
@end

@implementation MessengerSocket

- (id)initWithTCPConnectionToHost:(NSString *)hostName port:(unsigned short)portNumber
{
    self = [super init];
    if( self )
    {
        _sock = NULL;
        _delegate = nil;
        _runLoopSource = NULL;
        _runLoop = nil;
        _receiveBuffer = [[NSMutableData alloc] init];

        NSHost *aHost = [NSHost hostWithName:hostName];
        if( aHost == nil )
        {
            [self release];
            return nil;
        }

        NSArray *addresses = [aHost addresses];
        const char *addrString = NULL;
        BOOL resolved = NO;

        struct sockaddr_in addr;
        memset( &addr, 0, sizeof(struct sockaddr_in) );
        addr.sin_len = sizeof(struct sockaddr_in);
        addr.sin_family = AF_INET;
        addr.sin_port = htons(portNumber);

        for( NSUInteger i = 0; i < [addresses count]; i++ )
        {
            addrString = [[addresses objectAtIndex:i] UTF8String];
            if( addrString && inet_pton( AF_INET, addrString, &(addr.sin_addr) ) == 1 )
            {
                resolved = YES;
                break;
            }
        }

        if( !resolved )
        {
            [self release];
            return nil;
        }

        NSData *addrData = [NSData dataWithBytes:&addr length:sizeof(addr)];

        CFSocketContext cxt;
        cxt.version = 0;
        cxt.info = self;
        cxt.retain = nil;
        cxt.release = nil;
        cxt.copyDescription = nil;

        _sock = CFSocketCreate( NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                                kCFSocketDataCallBack, _MessengerSocketCallback, &cxt );
        if( _sock == NULL )
        {
            [self release];
            return nil;
        }

        CFSocketError connectErr = CFSocketConnectToAddress( _sock, (CFDataRef)addrData, 10.0 );
        if( connectErr != kCFSocketSuccess )
        {
            CFRelease( _sock );
            _sock = NULL;
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [self _close];
    [_receiveBuffer release];
    [super dealloc];
}

- (void)setDelegate:(id)aDelegate { _delegate = aDelegate; }
- (id)delegate { return _delegate; }

- (BOOL)isConnected { return (_sock != NULL); }

- (void)scheduleInRunLoop:(NSRunLoop *)aLoop
{
    if( _runLoopSource == NULL )
    {
        _runLoop = aLoop;
        _runLoopSource = CFSocketCreateRunLoopSource( nil, _sock, 0 );
        CFRunLoopAddSource( [aLoop getCFRunLoop], _runLoopSource, kCFRunLoopDefaultMode );
    }
}

- (BOOL)sendData:(NSData *)data
{
    if( _sock )
    {
        CFSocketError err = CFSocketSendData( _sock, NULL, (CFDataRef)data, 5.0 );
        if( err == kCFSocketSuccess )
            return YES;
        if( err == kCFSocketTimeout )
            return NO;
        [self closeWithReason:kMessengerSocketAbnormalTermination];
        return NO;
    }
    return NO;
}

- (void)close
{
    [self closeWithReason:kMessengerSocketNormalDisconnect];
}

- (void)closeWithReason:(int)reasonCode
{
    if( _sock != NULL )
    {
        [self _close];
        id deleg = _delegate;
        _delegate = nil;
        if( [deleg respondsToSelector:@selector(messengerSocketDidDisconnect:reason:)] )
            [deleg messengerSocketDidDisconnect:self reason:reasonCode];
    }
}

- (void)_close
{
    if( _sock != NULL )
    {
        CFSocketInvalidate( _sock );
        if( _runLoopSource != NULL )
        {
            CFRunLoopRemoveSource( [_runLoop getCFRunLoop], _runLoopSource, kCFRunLoopDefaultMode );
            CFRelease( _runLoopSource );
            _runLoop = nil;
            _runLoopSource = NULL;
        }
        CFRelease( _sock );
    }
    _sock = NULL;
}

- (void)receiveData:(NSData *)data
{
    if( [data length] > 0 )
    {
        if( [_delegate respondsToSelector:@selector(messengerSocket:didReceiveData:)] )
            [_delegate messengerSocket:self didReceiveData:data];
    }
    else
    {
        [self closeWithReason:kMessengerSocketNormalDisconnect];
    }
}

@end

void _MessengerSocketCallback( CFSocketRef sock, CFSocketCallBackType cbType,
                                CFDataRef address, const void *data, void *info )
{
    MessengerSocket *mssock = (MessengerSocket *)info;
    if( cbType == kCFSocketDataCallBack )
    {
        [mssock receiveData:(NSData *)data];
    }
}
