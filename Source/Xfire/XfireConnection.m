/*******************************************************************
	FILE:		XfireConnection.m
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Abstract base class with common support for a threaded
		connection to some kind of IP socket.
	
	HISTORY:
		2026 11 25  Converted to ARC; connections now take a host name.
		2008 04 06  Changed copyright to BSD license.
		2008 03 01  Changed to use external packet log cache file
					path with new session delegate method.
		2008 02 10  Eliminated secondary reader thread.
		2008 01 11  Rewrote using new threading and notification model.
		            Should be less likely to have problems later.
		2007 10 26  Created.
*******************************************************************/

#import "XfireConnection.h"
#import "XfireSession_Private.h"
#import "XfireConnection_Private.h"
#import "XfireSocket.h"
#import "XfireLoginConnection.h"
#import "XfirePacket.h"
#import "XfirePacketLogger.h"

@implementation XfireConnection

// The login connection is the initial connection to the Xfire server
+ (instancetype)loginConnectionToHostName:(NSString *)hostName port:(unsigned short)portNumber
{
	return [[XfireLoginConnection alloc] initWithHostName:hostName port:portNumber];
}

- (instancetype)initWithHostName:(NSString *)hostName port:(unsigned short)aPort
{
	self = [super init];
	if( self )
	{
		_hostName = [hostName copy];
		_port = aPort;
		_status = kXfireConnectionDisconnected;
		_socket = nil;
		_packetLogger = nil;
	}
	return self;
}

- (void)dealloc
{
	// Detach the delegate first so closing the socket doesn't call back
	// into an object that is being deallocated.
	if( _socket )
	{
		[_socket setDelegate:nil];
		[_socket close];
		_socket = nil;
	}
}

// Start a connection
- (void)connect
{
	if( [self status] != kXfireConnectionDisconnected )
		return;
	
	NSString *logPath = [[self session] delegate_sessionLogPath];
	if( logPath )
	{
		_packetLogger = [[XfirePacketLogger alloc] initWithCacheFolderName:logPath];
	}
	
	// We're starting up now
	_status = kXfireConnectionStarting;
	
	// Get set up
	_socket = [[XfireSocket alloc] initWithTCPConnectionToHostName:_hostName port:_port];
	if( _socket )
	{
		[_socket setDelegate:self];
		[_socket scheduleInRunLoop:[NSRunLoop currentRunLoop]];
		
		// Now we're "connected"
		_status = kXfireConnectionConnected;
		
		[self connectionDidConnect];
	}
	else
	{
		_packetLogger = nil;
		_status = kXfireConnectionDisconnected;
		[[self session] loginFailed:kXfireNetworkErrorReason];
	}
}

// End a connection
- (void)disconnect
{
	if( [self status] != kXfireConnectionConnected )
		return;
	
	_status = kXfireConnectionStopping;
	
	[self connectionWillDisconnect];
	
	[_socket setDelegate:nil]; // causes the socket to disconnect
	[_socket close];
	_socket = nil;
	
	_packetLogger = nil;
	
	_status = kXfireConnectionDisconnected;
}

- (XfireConnectionStatus)status
{
	return _status;
}

// Send keepalive, if applicable
- (void)keepAlive
{
	// no implementation here
}

// Get/set -- don't change this after set!
- (void)setSession:(XfireSession *)session
{
	_session = session;
}

- (XfireSession *)session
{
	return _session;
}

- (void)sendData:(NSData *)dat
{
	[_socket sendData:dat];
}

// Sending data
// Can be used by outside objects, so it must lock.
// This locks to prevent being disconnected between the time we check
// the _status and actually send the data.
- (void)sendPacket:(XfirePacket *)pkt
{
	if( [self status] != kXfireConnectionConnected )
	{
		@throw [NSException exceptionWithName:@"XfireConnection"
			reason:@"Attempted to send packet to disconnected XfireConnection"
			userInfo:nil];
	}
	
	if( [pkt isKindOfClass:[XfireMutablePacket class]] )
	{
		[((XfireMutablePacket *)pkt) generate];
	}
	
	[self sendPacketSafe:pkt];
}

// Send a packet
- (void)sendPacketSafe:(XfirePacket *)pkt
{
	[_packetLogger logOutbound:pkt];
	[self sendData:[pkt raw]];
}

- (void)socket:(XfireSocket *)aSock didReceiveData:(NSData *)data fromAddress:(NSData *)address
{
	[self receiverProcessData:data];
}

- (void)socketDidDisconnect:(XfireSocket *)aSock reason:(int)reasonCode
{
	_status = kXfireConnectionStopping;
	
	[self connectionWillDisconnect];
	
	[_socket setDelegate:nil]; // The socket is already disconnected
	_socket = nil;
	
	_packetLogger = nil;
	
	_status = kXfireConnectionDisconnected;
}

- (void)connectionDidConnect
{
}

- (void)connectionWillDisconnect
{
}

- (void)receiverProcessData:(NSData *)data
{
}

@end
