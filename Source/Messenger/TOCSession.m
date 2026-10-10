/*******************************************************************
    FILE:       TOCSession.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the TOC protocol session for AIM and ICQ
        via NINA.chat.  Handles the FLAP frame layer, signon
        handshake, buddy list, presence, and instant messaging.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "TOCSession.h"
#import "MessengerContact.h"
#import "MessengerChat.h"

// TOC frame types
enum
{
    kTOCFrameFlap      = 0x2A,
    kTOCFrameSignon    = 0x01,
    kTOCFrameData      = 0x02,
    kTOCFrameKeepAlive = 0x03,
    kTOCFrameSignoff   = 0x04
};

// TOC roast key (XOR key for password)
static const char kTOCRoastKey[] = "Tic/Toc";

@interface TOCSession (Private)
- (void)sendFlapFrame:(uint8_t)type data:(NSData *)data;
- (void)sendTOCCommand:(NSString *)command;
- (void)sendTOCCommand:(NSString *)command withArgs:(NSString *)args;
- (void)processBuffer;
- (void)handleData:(NSData *)frameData;
- (void)handleCommand:(NSString *)cmd withArgs:(NSString *)args;
- (NSString *)roastPassword:(NSString *)password;
- (NSString *)tocEscape:(NSString *)str;
@end

@implementation TOCSession

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port
{
    self = [super initWithService:service host:host port:port];
    if( self )
    {
        _receiveBuffer = [[NSMutableData alloc] init];
        _sequenceNumber = 0;
        _signedOn = NO;
    }
    return self;
}

- (void)dealloc
{
    [_socket release];
    [_receiveBuffer release];
    [_roastedPassword release];
    [super dealloc];
}

- (void)doConnect
{
    _socket = [[MessengerSocket alloc] initWithTCPConnectionToHost:[self host] port:[self port]];
    if( _socket == nil )
    {
        [self notifyLoginFailed:kMessengerNetworkErrorReason];
        return;
    }
    [_socket setDelegate:self];
    [_socket scheduleInRunLoop:[NSRunLoop currentRunLoop]];

    // Send initial FLAP SIGN_ON frame
    // Frame: FLAP(0x2A) + Signon(0x01) + seq(0x0000) + len(4) + version(0x0001) + TLV(0x0001)
    char frame[10];
    frame[0] = kTOCFrameFlap;
    frame[1] = kTOCFrameSignon;
    frame[2] = 0x00;
    frame[3] = 0x00;
    frame[4] = 0x00;
    frame[5] = 0x04;  // data length = 4
    frame[6] = 0x00;
    frame[7] = 0x01;  // FLAP version 1
    frame[8] = 0x00;
    frame[9] = 0x01;  // TLV type 1

    NSData *signonFrame = [NSData dataWithBytes:frame length:10];
    [_socket sendData:signonFrame];
}

- (void)doDisconnect
{
    if( _socket && [_socket isConnected] )
    {
        [self sendFlapFrame:kTOCFrameSignoff data:nil];
        [_socket close];
    }
    _signedOn = NO;
    [self setStatus:kMessengerStatusOffline];
}

- (void)doSendMessage:(NSString *)message toContact:(MessengerContact *)contact
{
    // toc_send_im <screenname> <message> [auto]
    NSString *escapedMsg = [self tocEscape:message];
    NSString *cmd = [NSString stringWithFormat:@"toc_send_im %@ %@",
                     [self tocEscape:[contact accountID]], escapedMsg];
    [self sendTOCCommand:cmd];
}

- (void)doSetStatusString:(NSString *)text
{
    if( text && [text length] > 0 )
    {
        // Set away message
        [self sendTOCCommand:@"toc_set_away" withArgs:[self tocEscape:text]];
    }
    else
    {
        // Clear away message (go available)
        [self sendTOCCommand:@"toc_set_away" withArgs:nil];
    }
}

- (void)doSetNickname:(NSString *)text
{
    // TOC doesn't support changing display name via protocol.
    // The screen name IS the identity.
}

- (void)doSendFriendInvitation:(NSString *)accountID message:(NSString *)msg
{
    // toc_add_buddy <buddy1> [<buddy2> ...]
    [self sendTOCCommand:@"toc_add_buddy" withArgs:[self tocEscape:accountID]];

    // Send the invitation message
    if( msg && [msg length] > 0 )
    {
        NSString *escapedMsg = [self tocEscape:msg];
        NSString *cmd = [NSString stringWithFormat:@"toc_send_im %@ %@ T",
                         [self tocEscape:accountID], escapedMsg];
        [self sendTOCCommand:cmd];
    }
}

- (void)doRemoveContact:(MessengerContact *)contact
{
    [self sendTOCCommand:@"toc_remove_buddy" withArgs:[self tocEscape:[contact accountID]]];
}

- (void)doAcceptFriendRequest:(MessengerContact *)contact
{
    // Add buddy to list
    [self sendTOCCommand:@"toc_add_buddy" withArgs:[self tocEscape:[contact accountID]]];
}

- (void)doDeclineFriendRequest:(MessengerContact *)contact
{
    // Add to deny list
    [self sendTOCCommand:@"toc_add_deny" withArgs:[self tocEscape:[contact accountID]]];
}

// --- MessengerSocketDelegate ---

- (void)messengerSocket:(MessengerSocket *)aSock didReceiveData:(NSData *)data
{
    [_receiveBuffer appendData:data];
    [self processBuffer];
}

- (void)messengerSocketDidDisconnect:(MessengerSocket *)aSock reason:(int)reasonCode
{
    if( _signedOn )
        [self notifyWillDisconnect:(reasonCode == kMessengerSocketNormalDisconnect)
            ? kMessengerNormalDisconnectReason : kMessengerServerHungUpReason];
    else
        [self notifyLoginFailed:kMessengerNetworkErrorReason];
}

// --- FLAP frame handling ---

- (void)sendFlapFrame:(uint8_t)type data:(NSData *)data
{
    NSUInteger dataLen = data ? [data length] : 0;
    if( dataLen > 65535 )
        dataLen = 65535; // TOC frames max 64KB

    NSMutableData *frame = [NSMutableData dataWithCapacity:6 + dataLen];

    uint8_t header[6];
    header[0] = kTOCFrameFlap;
    header[1] = type;
    _sequenceNumber++;
    header[2] = (_sequenceNumber >> 8) & 0xFF;
    header[3] = _sequenceNumber & 0xFF;
    uint16_t len = htons((uint16_t)dataLen);
    memcpy( &header[4], &len, 2 );

    [frame appendBytes:header length:6];
    if( data && dataLen > 0 )
        [frame appendData:data];

    [_socket sendData:frame];
}

- (void)sendTOCCommand:(NSString *)command
{
    NSData *cmdData = [command dataUsingEncoding:NSUTF8StringEncoding];
    [self sendFlapFrame:kTOCFrameData data:cmdData];
}

- (void)sendTOCCommand:(NSString *)command withArgs:(NSString *)args
{
    NSString *full;
    if( args && [args length] > 0 )
        full = [NSString stringWithFormat:@"%@ %@", command, args];
    else
        full = command;
    [self sendTOCCommand:full];
}

- (void)processBuffer
{
    // FLAP frames: 6-byte header
    while( [_receiveBuffer length] >= 6 )
    {
        const char *bytes = [_receiveBuffer bytes];

        // Verify FLAP magic
        if( (uint8_t)bytes[0] != kTOCFrameFlap )
        {
            // Out of sync. Discard one byte.
            [_receiveBuffer replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
            continue;
        }

        uint8_t frameType = (uint8_t)bytes[1];
        uint16_t dataLen = ntohs(*(uint16_t*)(bytes + 4));

        NSUInteger totalLen = 6 + dataLen;

        if( [_receiveBuffer length] < totalLen )
            break; // incomplete frame, wait for more data

        NSData *frameData = nil;
        if( dataLen > 0 )
            frameData = [_receiveBuffer subdataWithRange:NSMakeRange(6, dataLen)];

        // Handle the frame based on type
        if( frameType == kTOCFrameSignon )
        {
            // Server sent SIGN_ON. Now we send toc_signon.
            _roastedPassword = [[self roastPassword:[self password]] copy];

            NSString *signonCmd = [NSString stringWithFormat:
                @"toc_signon %@ %d %@ %@ english macfire\"",
                [self host], [self port],
                [self tocEscape:[self username]],
                [self tocEscape:_roastedPassword]];
            [self sendTOCCommand:signonCmd];
        }
        else if( frameType == kTOCFrameData )
        {
            [self handleData:frameData];
        }
        else if( frameType == kTOCFrameKeepAlive )
        {
            // Server keepalive. Respond with keepalive.
            [self sendFlapFrame:kTOCFrameKeepAlive data:nil];
        }
        else if( frameType == kTOCFrameSignoff )
        {
            // Server disconnecting us
            [self notifyWillDisconnect:kMessengerServerHungUpReason];
        }

        // Consume the frame
        [_receiveBuffer replaceBytesInRange:NSMakeRange(0, totalLen) withBytes:NULL length:0];
    }
}

- (void)handleData:(NSData *)frameData
{
    // Data frame contains a text command
    NSString *dataStr = [[[NSString alloc] initWithData:frameData
                                               encoding:NSUTF8StringEncoding] autorelease];
    if( dataStr == nil )
        dataStr = [[[NSString alloc] initWithData:frameData
                                         encoding:NSISOLatin1StringEncoding] autorelease];

    // Split command and args at first colon or space
    NSRange colonRange = [dataStr rangeOfString:@":"];
    NSRange spaceRange = [dataStr rangeOfString:@" "];

    NSString *cmd;
    NSString *args = nil;

    // Use whichever comes first (colon or space)
    NSUInteger splitPos = NSNotFound;
    if( colonRange.location != NSNotFound && spaceRange.location != NSNotFound )
        splitPos = MIN( colonRange.location, spaceRange.location );
    else if( colonRange.location != NSNotFound )
        splitPos = colonRange.location;
    else if( spaceRange.location != NSNotFound )
        splitPos = spaceRange.location;

    if( splitPos != NSNotFound )
    {
        cmd = [dataStr substringToIndex:splitPos];
        args = [dataStr substringFromIndex:splitPos + 1];
    }
    else
    {
        cmd = dataStr;
    }

    [self handleCommand:cmd withArgs:args];
}

- (void)handleCommand:(NSString *)cmd withArgs:(NSString *)args
{
    if( [cmd isEqualToString:@"SIGN_ON"] )
    {
        // Server confirmed our signon. Send toc_init_done.
        [self sendTOCCommand:@"toc_init_done"];
        _signedOn = YES;
        [self setStatus:kMessengerStatusOnline];
    }
    else if( [cmd isEqualToString:@"NICK"] )
    {
        // Our screen name confirmed
        [[self loginIdentity] setAccountID:args];
    }
    else if( [cmd isEqualToString:@"IM_IN"] )
    {
        // IM_IN:<screenname>:<auto-response>:<message>
        NSArray *parts = [args componentsSeparatedByString:@":"];
        if( [parts count] >= 3 )
        {
            NSString *sender = [parts objectAtIndex:0];
            // parts[1] = auto-response flag (T/F)
            // message = everything after the second colon
            NSRange firstColon = [args rangeOfString:@":"];
            NSRange secondColon = [args rangeOfString:@":"
                                              options:NSLiteralSearch
                                                range:NSMakeRange(firstColon.location+1,
                                                                 [args length]-firstColon.location-1)];
            NSString *message = @"";
            if( secondColon.location != NSNotFound )
                message = [args substringFromIndex:secondColon.location+1];

            MessengerContact *contact = [self contactForAccountID:sender];
            if( contact == nil )
            {
                contact = [[[MessengerContact alloc] initWithAccountID:sender
                                                                 service:[self service]] autorelease];
                [self addContact:contact];
            }

            MessengerChat *chat = [self beginChatWithContact:contact];
            [chat didReceiveMessage:message];
            [self notifyDidBeginChat:chat];
        }
    }
    else if( [cmd isEqualToString:@"UPDATE_BUDDY"] )
    {
        // UPDATE_BUDDY:<screenname>:<online>:<evil>:<signon-time>:<idle-time>:<user-class>:<status>
        NSArray *parts = [args componentsSeparatedByString:@":"];
        if( [parts count] >= 2 )
        {
            NSString *buddy = [parts objectAtIndex:0];
            BOOL online = [[parts objectAtIndex:1] isEqualToString:@"T"];

            MessengerContact *contact = [self contactForAccountID:buddy];
            if( contact == nil )
            {
                contact = [[[MessengerContact alloc] initWithAccountID:buddy
                                                                 service:[self service]] autorelease];
                [self addContact:contact];
            }

            BOOL wasOnline = [contact isOnline];
            if( wasOnline != online )
            {
                [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusWillChange];
                [contact setIsOnline:online];
                [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusDidChange];
            }

            // Status/away message is in parts[6] if present
            if( [parts count] >= 7 )
            {
                NSString *awayMsg = [parts objectAtIndex:6];
                if( [awayMsg length] > 0 )
                {
                    [contact setStatusString:awayMsg];
                    [self notifyContactChange:contact attribute:kMessengerContactStatusStringDidChange];
                }
            }
        }
    }
    else if( [cmd isEqualToString:@"GOTO_URL"] )
    {
        // GOTO_URL:<name>:<url> - info/profile URL. Ignore for now.
    }
    else if( [cmd isEqualToString:@"EVILED"] )
    {
        // EVILED:<new-level>:<eviler> - someone warned us. Ignore.
    }
    else if( [cmd isEqualToString:@"CHAT_JOIN"] )
    {
        // Chat room joined. Not implementing chat rooms for now.
    }
    else if( [cmd isEqualToString:@"CHAT_IN"] )
    {
        // Chat room message. Not implementing chat rooms for now.
    }
    else if( [cmd isEqualToString:@"CHAT_UPDATE_BUDDY"] )
    {
        // Chat room buddy update. Ignore.
    }
    else if( [cmd isEqualToString:@"ADMIN_STATUS"] )
    {
        // Admin notification. Ignore.
    }
    else if( [cmd isEqualToString:@"ERROR"] )
    {
        // ERROR:<code>:<args>
        NSArray *parts = [args componentsSeparatedByString:@":"];
        NSString *errCode = [parts count] > 0 ? [parts objectAtIndex:0] : @"0";
        int code = [errCode intValue];

        switch( code )
        {
            case 980: // Bad username/password
                [self notifyLoginFailed:kMessengerInvalidPasswordReason];
                break;
            case 981: // Service unavailable
            case 982: // Warning too high
                [self notifyLoginFailed:kMessengerNetworkErrorReason];
                break;
            case 983: // Someone logged in as us
                [self notifyWillDisconnect:kMessengerOtherSessionReason];
                break;
            default:
                [self notifyLoginFailed:[NSString stringWithFormat:@"Server error %@", errCode]];
                break;
        }
    }
    else
    {
        // Unknown command. Ignore.
    }
}

// --- TOC utilities ---

- (NSString *)roastPassword:(NSString *)password
{
    // TOC roasts the password by XORing each byte with the roast key
    const char *pw = [password UTF8String];
    NSUInteger pwLen = strlen( pw );
    NSUInteger keyLen = sizeof( kTOCRoastKey ) - 1; // exclude null terminator

    NSMutableString *result = [NSMutableString stringWithString:@"0x"];

    for( NSUInteger i = 0; i < pwLen; i++ )
    {
        unsigned char roasted = pw[i] ^ kTOCRoastKey[i % keyLen];
        [result appendFormat:@"%02X", roasted];
    }

    return result;
}

- (NSString *)tocEscape:(NSString *)str
{
    // TOC escaping: replace special characters
    // Spaces become %20, etc. TOC uses its own encoding.
    // Also need to escape: $, {, }, [, ], (, ), ', ", \
    NSMutableString *result = [NSMutableString stringWithString:str];

    // Order matters - escape backslash first
    [result replaceOccurrencesOfString:@"\\" withString:@"\\\\"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"$" withString:@"\\$"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"{" withString:@"\\{"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"}" withString:@"\\}"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"[" withString:@"\\["
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"]" withString:@"\\]"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"(" withString:@"\\("
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@")" withString:@"\\)"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"'" withString:@"\\'"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"\"" withString:@"\\\""
                               options:0 range:NSMakeRange(0, [result length])];

    return result;
}

@end
