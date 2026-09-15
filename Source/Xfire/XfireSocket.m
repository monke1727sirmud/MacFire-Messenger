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
		2008 04 06  Changed copyright to BSD license.
		2008 01 12  Rewrote using CFSocket and a delegate approach.
		2007 11 17  Created.
*******************************************************************/

#import "XfireSocket.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

static void _XfireSocketCallback(CFSocketRef sock, CFSocketCallBackType cbType, CFDataRef address, const void *data, void *info);

@interface XfireSocket (Private)
- (unsigned int)addressIntegerForPeer:(BOOL)peer;
- (void)receiveData:(NSData *)data fromAddress:(NSData *)address;
- (BOOL)getAddress:(struct sockaddr_in*)addr forHost:(NSHost *)aHost;
- (void)closeWithReason:(int)reasonCode;
- (void)_close;
@end


@implementation XfireSocket

- (void)dealloc
{
	[self _close];
	[super dealloc];
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
	unsigned long addrInt = [self ourAddressInteger];
	if( addrInt == 0 )
		return nil;
	
	char bfr[64];
	struct in_addr iaddr;
	iaddr.s_addr = htonl(addrInt);
	if( inet_ntop( PF_INET, &iaddr, bfr, 64 ) )
	{
		return [NSString stringWithCString:bfr];
	}
	return nil;
}

- (unsigned int)ourAddressInteger
{
	return [self addressIntegerForPeer:NO];
}

- (unsigned int)addressIntegerForPeer:(BOOL)peer
{
	NSData *addrObj;
	const struct sockaddr_in *addr;
	unsigned long addrInt;
	
	if( _sock == NULL )
		return 0;
	
	if( peer )
		addrObj = (NSData*)CFSocketCopyPeerAddress( _sock );
	else
		addrObj = (NSData*)CFSocketCopyAddress( _sock );
	if( addrObj == nil )
		return 0;
	
	if( [addrObj length] != sizeof(struct sockaddr_in) )
	{
		CFRelease(addrObj);
		return 0;
	}
	addr = (const struct sockaddr_in*) [addrObj bytes];
	if( addr->sin_family != PF_INET )
	{
		CFRelease(addrObj);
		return 0;
	}
	
	addrInt = ntohl( addr->sin_addr.s_addr );
	CFRelease(addrObj);
	
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

- (BOOL)getAddress:(struct sockaddr_in*)addr forHost:(NSHost *)aHost
{
	NSArray *addresses = [aHost addresses];
	const char *addrString;
	int i, cnt;
	
	// Some addresses are valid, others are not.  For example, it will return IPv6 address first for 'localhost'
	// For now, we're only using the IPv4 address.  So, we just check all of them until inet_pton succeeds and gives
	// us something.
	cnt = [addresses count];
	for( i = 0; i < cnt; i++ )
	{
		addrString = [[addresses objectAtIndex:i] UTF8String];
		if( addrString != NULL )
		{
			if( inet_pton( addr->sin_family, addrString, &(addr->sin_addr) ) == 1 )
			{
				return YES;
			}
		}
	}
	
	return NO;
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
			_runLoop = nil;
		}
		CFRelease(_sock);
	}
	_sock = NULL;
	_runLoopSource = NULL;
}

- (BOOL)isConnected
{
	return (_sock != NULL);
}

@end

@implementation XfireSocket (TCPSocket)

- (id)initWithTCPConnectionToHost:(NSHost *)aHost port:(unsigned short)aPort
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
		
		if( ![self getAddress:&addr forHost:aHost] )
		{
			[self release];
			return nil;
		}
		sig.address = (CFDataRef)[NSData dataWithBytes:&addr length:sizeof(addr)];
		
		// Set up socket context (callbacks)
		cxt.version = 0;
		cxt.info = self;
		cxt.retain = nil;
		cxt.release = nil;
		cxt.copyDescription = nil;
		
		// Open the connection
		_sock = CFSocketCreateConnectedToSocketSignature( NULL,
			&sig, kCFSocketDataCallBack,
			_XfireSocketCallback,
			&cxt,
			0.0);
		if( _sock == nil )
		{
			NSLog(@"failed to create socket");
			[self release];
			return nil;
		}
	}
	return self;
}

- (BOOL)sendData:(NSData *)data
{
	if( _sock )
	{
		CFSocketError err = CFSocketSendData(_sock, NULL, (CFDataRef)data, 1.0); // wait up to 1 sec
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
	unsigned long addrInt = [self addressIntegerForPeer:YES];
	if( addrInt == 0 )
		return nil;
	
	char bfr[64];
	struct in_addr iaddr;
	iaddr.s_addr = htonl(addrInt);
	if( inet_ntop( PF_INET, &iaddr, bfr, 64 ) )
	{
		return [NSString stringWithCString:bfr];
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
	XfireSocket *xfsock = (XfireSocket*)info;
	if( cbType == kCFSocketDataCallBack )
	{
		[xfsock receiveData:(NSData*)data fromAddress:(NSData*)address];
	}
	else
	{
		NSLog(@"_XfireSocketCallback received unknown callback type %d",cbType);
	}
}



/*
Future interfaces - not yet implemented
*/
//@interface XfireSocket (TCPSocket)
//- (id)initTCPListeningOnPort:(unsigned short)aPort;
//- (XfireSocket *)listen; // listening only
//@end
//
//@interface XfireSocket (UDPSocket)
//- (id)initUDPClient;
//- (id)initUDPServerOnPort:(unsigned short)aPort;
//- (void)sendData:(NSData *)data toHost:(NSHost *)aHost port:(unsigned short)aPort;
//@end

