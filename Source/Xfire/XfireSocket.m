/*******************************************************************
	FILE:		XfireSocket.m
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Abstracts away a socket.  Surprisingly, Cocoa does not include
		a direct wrapper for a socket (or CFSocket).  This exists
		because in the future a UDP connection may be required (some
		games like Halo use UDP for server queries).  I wanted a common
		interface logic.
	
	HISTORY:
		2026 11 25  Replaced NSHost with hostname resolution via getaddrinfo.
		2008 04 06  Changed copyright to BSD license.
		2008 01 12  Rewrote using CFSocket and a delegate approach.
		2007 11 17  Created.
*******************************************************************/

#import "XfireSocket.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

static void _XfireSocketCallback(CFSocketRef sock, CFSocketCallBackType cbType, CFDataRef address, const void *data, void *info);

@interface XfireSocket (Private)
- (unsigned int)addressIntegerForPeer:(BOOL)peer;
- (void)receiveData:(NSData *)data fromAddress:(NSData *)address;
- (BOOL)resolveHostName:(NSString *)hostName intoAddress:(struct sockaddr_in *)addr;
- (void)closeWithReason:(int)reasonCode;
- (void)_close;
@end


@implementation XfireSocket

- (void)dealloc
{
	[self _close];
}

- (void)setDelegate:(id)aDelegate
{
	_delegate = aDelegate;
}

- (id)delegate
{
	return _delegate;
}

- (NSString *)ourAddress
{
	unsigned int addrInt = [self ourAddressInteger];
	if( addrInt == 0 )
		return nil;
	
	char bfr[64];
	struct in_addr iaddr;
	iaddr.s_addr = htonl(addrInt);
	if( inet_ntop( PF_INET, &iaddr, bfr, 64 ) )
	{
		return [NSString stringWithUTF8String:bfr];
	}
	return nil;
}

- (unsigned int)ourAddressInteger
{
	return [self addressIntegerForPeer:NO];
}

- (unsigned int)addressIntegerForPeer:(BOOL)peer
{
	const struct sockaddr_in *addr;
	unsigned int addrInt;
	
	if( _sock == NULL )
		return 0;
	
	CFDataRef addrRef = peer ? CFSocketCopyPeerAddress(_sock) : CFSocketCopyAddress(_sock);
	if( addrRef == NULL )
		return 0;
	NSData *addrObj = CFBridgingRelease(addrRef);
	
	if( [addrObj length] != sizeof(struct sockaddr_in) )
		return 0;
	
	addr = (const struct sockaddr_in *)[addrObj bytes];
	if( addr->sin_family != PF_INET )
		return 0;
	
	addrInt = ntohl( addr->sin_addr.s_addr );
	
	return addrInt;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aLoop
{
	if( _runLoopSource == NULL )
	{
		_runLoop = aLoop;
		_runLoopSource = CFSocketCreateRunLoopSource(nil,_sock,0);
		CFRunLoopAddSource([aLoop getCFRunLoop],_runLoopSource,kCFRunLoopDefaultMode);
	}
	else
	{
		NSLog(@"Attemped to schedule XfireSocket in more than on NSRunLoop");
	}
}

// Resolve the host name to an IPv4 address.  This replaces the
// deprecated NSHost class.  Only IPv4 is supported by the Xfire protocol.
- (BOOL)resolveHostName:(NSString *)hostName intoAddress:(struct sockaddr_in *)addr
{
	struct addrinfo hints;
	struct addrinfo *results = NULL;
	BOOL resolved = NO;
	
	if( [hostName length] == 0 )
		return NO;
	
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	
	if( getaddrinfo([hostName UTF8String], NULL, &hints, &results) != 0 )
		return NO;
	
	for( struct addrinfo *ai = results; ai != NULL; ai = ai->ai_next )
	{
		if( (ai->ai_family == AF_INET) && (ai->ai_addrlen == sizeof(struct sockaddr_in)) )
		{
			memcpy(addr, ai->ai_addr, sizeof(struct sockaddr_in));
			resolved = YES;
			break;
		}
	}
	
	freeaddrinfo(results);
	return resolved;
}

- (void)close
{
	[self closeWithReason:kXfireSocketNormalDisconnect];
}

- (void)closeWithReason:(int)reasonCode
{
	if( _sock != NULL )
	{
		[self _close];
		
		id deleg = _delegate;
		_delegate = nil;
		
		if( [deleg respondsToSelector:@selector(socketDidDisconnect:reason:)] )
			[deleg socketDidDisconnect:self reason:reasonCode];
	}
}

- (void)_close
{
	if( _sock != NULL )
	{
		CFSocketInvalidate(_sock); // also invalidates the run loop source
		if( _runLoopSource != NULL )
		{
			CFRunLoopRemoveSource( [_runLoop getCFRunLoop], _runLoopSource, kCFRunLoopDefaultMode );
			CFRelease(_runLoopSource);
		}
		CFRelease(_sock);
	}
	_sock = NULL;
	_runLoopSource = NULL;
	_runLoop = nil;
}

- (BOOL)isConnected
{
	return (_sock != NULL);
}

@end

@implementation XfireSocket (TCPSocket)

- (instancetype)initWithTCPConnectionToHostName:(NSString *)hostName port:(unsigned short)aPort
{
	self = [super init];
	if( self )
	{
		_sock = NULL;
		_delegate = nil;
		_runLoopSource = NULL;
		_runLoop = nil;
		
		CFSocketSignature sig;
		CFSocketContext cxt;
		struct sockaddr_in addr;
		
		// Set up address and signature records
		sig.protocolFamily = PF_INET;
		sig.socketType = SOCK_STREAM;
		sig.protocol = IPPROTO_TCP;
		memset( &addr, 0, sizeof(struct sockaddr_in) );
		addr.sin_len = sizeof(struct sockaddr_in);
		addr.sin_family = AF_INET;
		addr.sin_port = htons(aPort);
		
		if( ![self resolveHostName:hostName intoAddress:&addr] )
		{
			NSLog(@"Unable to resolve Xfire server host \"%@\"", hostName);
			return nil;
		}
		
		NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];
		sig.address = (__bridge CFDataRef)addressData;
		
		// Set up socket context (callbacks)
		cxt.version = 0;
		cxt.info = (__bridge void *)self;
		cxt.retain = nil;
		cxt.release = nil;
		cxt.copyDescription = nil;
		
		// Open the connection
		_sock = CFSocketCreateConnectedToSocketSignature( NULL,
			&sig, kCFSocketDataCallBack,
			_XfireSocketCallback,
			&cxt,
			0.0);
		if( _sock == NULL )
		{
			NSLog(@"failed to create socket");
			return nil;
		}
	}
	return self;
}

- (BOOL)sendData:(NSData *)data
{
	if( _sock )
	{
		CFSocketError err = CFSocketSendData(_sock, NULL, (__bridge CFDataRef)data, 1.0); // wait up to 1 sec
		if( err == kCFSocketSuccess )
		{
			return YES;
		}
		else if( err == kCFSocketTimeout )
		{
			return NO;
		}
		else if( err == kCFSocketError )
		{
			[self closeWithReason:kXfireSocketAbnormalTermination];
			return NO;
		}
	}
	return NO;
}

- (NSString *)peerAddress
{
	unsigned int addrInt = [self addressIntegerForPeer:YES];
	if( addrInt == 0 )
		return nil;
	
	char bfr[64];
	struct in_addr iaddr;
	iaddr.s_addr = htonl(addrInt);
	if( inet_ntop( PF_INET, &iaddr, bfr, 64 ) )
	{
		return [NSString stringWithUTF8String:bfr];
	}
	return nil;
}

- (void)receiveData:(NSData *)data fromAddress:(NSData *)address
{
	if( [data length] > 0 )
	{
		if( [[self delegate] respondsToSelector:@selector(socket:didReceiveData:fromAddress:)] )
		{
			[[self delegate] socket:self didReceiveData:data fromAddress:address];
		}
	}
	else
	{
		[self closeWithReason:kXfireSocketNormalDisconnect];
	}
}

@end

void _XfireSocketCallback(CFSocketRef sock, CFSocketCallBackType cbType, CFDataRef address, const void *data, void *info)
{
	XfireSocket *xfsock = (__bridge XfireSocket *)info;
	if( cbType == kCFSocketDataCallBack )
	{
		[xfsock receiveData:(__bridge NSData *)data fromAddress:(__bridge NSData *)address];
	}
	else
	{
		NSLog(@"_XfireSocketCallback received unknown callback type %u",(unsigned)cbType);
	}
}
