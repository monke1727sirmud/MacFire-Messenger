/*******************************************************************
    FILE:       MSNPSession.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the MSNP notification server session.
        Handles login handshake, presence, contact list sync,
        and switchboard chat creation.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MSNPSession.h"
#import "MessengerContact.h"
#import "MessengerChat.h"

// --- Switchboard for 1-to-1 chat ---

@interface MSNPSwitchboard : NSObject <MessengerSocketDelegate>
{
    MSNPSession        *_session;       // not retained
    MessengerSocket    *_socket;
    NSMutableData      *_receiveBuffer;
    MessengerContact   *_remoteContact; // not retained
    NSString           *_sessionID;
    unsigned int       _transactionID;
    NSMutableArray     *_pendingMessages; // messages queued before USR/ANS completes
    BOOL               _isIncoming;
}
- (id)initWithSession:(MSNPSession *)session socket:(MessengerSocket *)socket;
- (void)setRemoteContact:(MessengerContact *)contact;
- (void)setSessionID:(NSString *)sid;
- (void)startOutgoingWithAuthString:(NSString *)authStr;
- (void)startIncomingWithAuthString:(NSString *)authStr sessionID:(NSString *)sid;
- (void)sendMessage:(NSString *)message;
- (void)close;
@end

// --- MSNPSession implementation ---

@interface MSNPSession (Private)
- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params;
- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params payload:(NSData *)payload;
- (NSString *)nextTransactionID;
- (void)processLine:(NSString *)line;
- (void)processPayloadLine:(NSString *)line payloadData:(NSData *)payload;
- (void)handleXFR:(NSString *)params;
- (void)handleRNG:(NSString *)params;
- (void)handleNLN:(NSString *)params;
- (void)handleFLN:(NSString *)params;
- (void)handleILN:(NSString *)params;
- (void)handleMSG:(NSString *)params payloadData:(NSData *)payload;
- (void)handleSYN:(NSString *)params payloadData:(NSData *)payload;
- (void)handleADD:(NSString *)params;
- (void)handleREM:(NSString *)params;
- (void)handleREA:(NSString *)params;
- (void)handleOut:(NSString *)params;
- (void)handleError:(NSString *)errorCode;
- (void)connectToSwitchboard:(NSString *)hostPort auth:(NSString *)auth contact:(MessengerContact *)contact;
- (MSNPSwitchboard *)switchboardForContact:(MessengerContact *)contact;
- (void)deliverIncomingMessage:(NSString *)message fromContact:(MessengerContact *)contact;
@end

@implementation MSNPSession

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port
{
    self = [super initWithService:service host:host port:port];
    if( self )
    {
        _receiveBuffer = [[NSMutableData alloc] init];
        _transactionID = 1;
        _switchboards = [[NSMutableDictionary alloc] init];
        _pendingTicket = nil;
        _currentDisplay = nil;
    }
    return self;
}

- (void)dealloc
{
    [_notificationSocket release];
    [_receiveBuffer release];
    [_switchboards release];
    [_pendingTicket release];
    [_currentDisplay release];
    [super dealloc];
}

- (void)doConnect
{
    _notificationSocket = [[MessengerSocket alloc] initWithTCPConnectionToHost:[self host] port:[self port]];
    if( _notificationSocket == nil )
    {
        [self notifyLoginFailed:kMessengerNetworkErrorReason];
        return;
    }
    [_notificationSocket setDelegate:self];
    [_notificationSocket scheduleInRunLoop:[NSRunLoop currentRunLoop]];

    // Start MSNP handshake: VER
    [self sendCommand:@"VER" withParams:@"MSNP15 MSNP14 MSNP13 CVR0"];
}

- (void)doDisconnect
{
    if( _notificationSocket && [_notificationSocket isConnected] )
    {
        [self sendCommand:@"OUT" withParams:nil];
        [_notificationSocket close];
    }
    // Close all switchboards
    NSEnumerator *e = [_switchboards objectEnumerator];
    MSNPSwitchboard *sb;
    while( (sb = [e nextObject]) )
        [sb close];
    [_switchboards removeAllObjects];

    [self setStatus:kMessengerStatusOffline];
}

- (void)doSendMessage:(NSString *)message toContact:(MessengerContact *)contact
{
    MSNPSwitchboard *sb = [self switchboardForContact:contact];
    [sb sendMessage:message];
}

- (void)doSetStatusString:(NSString *)text
{
    // MSN personal message via MSG with Content-Type: text/x-msnprofile
    // For MSNP15, use UUX command to set personal message
    NSString *pmXml = [NSString stringWithFormat:@"<Data><PSM>%@</PSM><CurrentMedia></CurrentMedia></Data>",
                       [self xmlEscape:text]];
    NSData *payload = [pmXml dataUsingEncoding:NSUTF8StringEncoding];
    [self sendCommand:@"UUX" withParams:nil payload:payload];
}

- (void)doSetNickname:(NSString *)text
{
    // Use PRP command to change display name (MSNP15)
    [self sendCommand:@"PRP" withParams:[NSString stringWithFormat:@"MFN %@", [self urlEncode:text]]];
}

- (void)doSendFriendInvitation:(NSString *)accountID message:(NSString *)msg
{
    // ADD command: ADD <trid> AL <accountID> <accountID>
    [self sendCommand:@"ADD" withParams:[NSString stringWithFormat:@"AL %@ %@", accountID, accountID]];
}

- (void)doRemoveContact:(MessengerContact *)contact
{
    // REM command: REM <trid> FL <accountID>
    [self sendCommand:@"REM" withParams:[NSString stringWithFormat:@"FL %@", [contact accountID]]];
}

- (void)doAcceptFriendRequest:(MessengerContact *)contact
{
    [self sendCommand:@"ADD" withParams:[NSString stringWithFormat:@"AL %@ %@", [contact accountID], [contact accountID]]];
}

- (void)doDeclineFriendRequest:(MessengerContact *)contact
{
    [self sendCommand:@"ADD" withParams:[NSString stringWithFormat:@"BL %@ %@", [contact accountID], [contact accountID]]];
}

// --- MessengerSocketDelegate ---

- (void)messengerSocket:(MessengerSocket *)aSock didReceiveData:(NSData *)data
{
    [_receiveBuffer appendData:data];
    [self processBuffer];
}

- (void)messengerSocketDidDisconnect:(MessengerSocket *)aSock reason:(int)reasonCode
{
    if( aSock == _notificationSocket )
    {
        [self notifyWillDisconnect:(reasonCode == kMessengerSocketNormalDisconnect)
            ? kMessengerNormalDisconnectReason : kMessengerServerHungUpReason];
    }
}

// --- Buffer processing ---

- (void)processBuffer
{
    // MSNP is line-based. Commands end with \r\n. Payload commands (MSG, UBX, SYN)
    // have a payload length as the last parameter.
    while( [_receiveBuffer length] > 0 )
    {
        // Find \r\n
        const char *bytes = [_receiveBuffer bytes];
        NSUInteger length = [_receiveBuffer length];
        NSUInteger lineEnd = NSNotFound;
        for( NSUInteger i = 0; i < length - 1; i++ )
        {
            if( bytes[i] == '\r' && bytes[i+1] == '\n' )
            {
                lineEnd = i;
                break;
            }
        }

        if( lineEnd == NSNotFound )
            break; // incomplete line

        NSString *line = [[[NSString alloc] initWithBytes:bytes length:lineEnd
                                                 encoding:NSUTF8StringEncoding] autorelease];
        if( line == nil )
            line = [[[NSString alloc] initWithBytes:bytes length:lineEnd
                                           encoding:NSISOLatin1StringEncoding] autorelease];

        NSUInteger consumeLength = lineEnd + 2; // include \r\n

        // Check if this is a payload command
        NSArray *parts = [line componentsSeparatedByString:@" "];
        NSString *cmd = [parts objectAtIndex:0];

        NSUInteger payloadLen = 0;
        if( ([cmd isEqualToString:@"MSG"] || [cmd isEqualToString:@"UBX"] ||
             [cmd isEqualToString:@"SYN"] || [cmd isEqualToString:@"GCF"] ||
             [cmd isEqualToString:@"NLN"] || [cmd isEqualToString:@"ILN"]) )
        {
            // For SYN and UBX, the last numeric param is the payload length
            // For MSG from server, format is: MSG <email> <display> <length>
            if( [cmd isEqualToString:@"SYN"] )
            {
                // SYN <trid> <result> <last> <length>
                if( [parts count] >= 4 )
                    payloadLen = [[parts objectAtIndex:[parts count]-1] intValue];
            }
            else if( [cmd isEqualToString:@"MSG"] )
            {
                // MSG <email> <display> <length>
                if( [parts count] >= 4 )
                    payloadLen = [[parts objectAtIndex:[parts count]-1] intValue];
            }
            else if( [cmd isEqualToString:@"UBX"] )
            {
                // UBX <email> <length>
                if( [parts count] >= 3 )
                    payloadLen = [[parts objectAtIndex:[parts count]-1] intValue];
            }
            else if( [cmd isEqualToString:@"GCF"] )
            {
                // GCF <trid> <name> <length>
                if( [parts count] >= 4 )
                    payloadLen = [[parts objectAtIndex:[parts count]-1] intValue];
            }
        }

        if( payloadLen > 0 )
        {
            // Check if we have enough data for the payload
            if( [_receiveBuffer length] < consumeLength + payloadLen )
                break; // incomplete payload, wait for more data

            NSData *payload = [_receiveBuffer subdataWithRange:
                NSMakeRange( consumeLength, payloadLen )];
            [self processPayloadLine:line payloadData:payload];

            // Consume line + payload
            NSUInteger total = consumeLength + payloadLen;
            [_receiveBuffer replaceBytesInRange:NSMakeRange(0, total) withBytes:NULL length:0];
        }
        else
        {
            [self processLine:line];
            [_receiveBuffer replaceBytesInRange:NSMakeRange(0, consumeLength) withBytes:NULL length:0];
        }
    }
}

- (void)processLine:(NSString *)line
{
    NSArray *parts = [line componentsSeparatedByString:@" "];
    if( [parts count] == 0 )
        return;

    NSString *cmd = [parts objectAtIndex:0];

    if( [cmd isEqualToString:@"VER"] )
    {
        // Server agreed on protocol version. Send CVR.
        // CVR <trid> <locale> <os> <client> <version> <reserved> <client-guid> <restart>
        [self sendCommand:@"CVR" withParams:@"0x0409 mac 8.0.0 macfire 1.0 msms "];
    }
    else if( [cmd isEqualToString:@"CVR"] )
    {
        // Server accepted CVR. Send USR with twc/twn auth.
        // USR <trid> SSO S <policy> <nonce>
        // For Escargot, we use USR <trid> TWN I <username>
        [self sendCommand:@"USR" withParams:[NSString stringWithFormat:@"TWN I %@", [self username]]];
    }
    else if( [cmd isEqualToString:@"USR"] )
    {
        // Could be:
        // USR <trid> TWN S <nonce>  - need to authenticate via HTTPS
        // USR <trid> OK <username> <verified> - login successful
        if( [parts count] >= 3 )
        {
            NSString *subCmd = [parts objectAtIndex:2];
            if( [subCmd isEqualToString:@"OK"] )
            {
                // Login successful! Send SYN to get contact list.
                [self setStatus:kMessengerStatusOnline];
                [self sendCommand:@"SYN" withParams:@"0 0 0"];
            }
            else if( [subCmd isEqualToString:@"S"] )
            {
                // Server sent nonce/ticket challenge.
                // For Escargot, we can use a simplified token-based login.
                // Send USR <trid> TWN S <ticket> where ticket is built from password.
                // Escargot supports a simple challenge-response using MD5.
                // The nonce is in parts[3].
                NSString *nonce = ([parts count] >= 4) ? [parts objectAtIndex:3] : @"";
                NSString *ticket = [self buildAuthTicketWithNonce:nonce];
                [self sendCommand:@"USR" withParams:[NSString stringWithFormat:@"TWN S %@", ticket]];
            }
        }
    }
    else if( [cmd isEqualToString:@"XFR"] )
    {
        // XFR <trid> SB <host:port> CKI <auth>
        // Switchboard transfer
        [self handleXFR:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"RNG"] )
    {
        // RNG <session-id> <host:port> CKI <auth> <caller-email> <caller-display>
        [self handleRNG:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"NLN"] )
    {
        [self handleNLN:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"FLN"] )
    {
        [self handleFLN:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"ILN"] )
    {
        [self handleILN:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"ADD"] )
    {
        [self handleADD:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"REM"] )
    {
        [self handleREM:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"REA"] )
    {
        [self handleREA:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"OUT"] )
    {
        [self handleOut:[line substringFromIndex:[cmd length]+1]];
    }
    else if( [cmd isEqualToString:@"CHG"] )
    {
        // Status change confirmed. Ignore.
    }
    else if( [cmd isEqualToString:@"BLP"] || [cmd isEqualToString:@"GTC"] )
    {
        // Privacy/prompt settings. Ignore.
    }
    else if( [cmd isEqualToString:@"BPR"] )
    {
        // Buddy property - ignore for now.
    }
    else if( [cmd isEqualToString:@"LSG"] )
    {
        // List group - ignore.
    }
    else if( [cmd isEqualToString:@"LST"] )
    {
        // List entry: LST <email> <display> <bitflags> <groups>
        if( [parts count] >= 4 )
        {
            NSString *email = [parts objectAtIndex:1];
            NSString *display = [parts objectAtIndex:2];
            if( [email length] > 0 )
            {
                MessengerContact *contact = [self contactForAccountID:email];
                if( contact == nil )
                {
                    contact = [[[MessengerContact alloc] initWithAccountID:email
                                                                     service:kMessengerServiceMSN] autorelease];
                    [self addContact:contact];
                }
                [contact setNickName:display];
                [self notifyContactChange:contact attribute:kMessengerContactWasAdded];
            }
        }
    }
    else if( [cmd hasPrefix:@"8"] || [cmd hasPrefix:@"9"] || [cmd hasPrefix:@"5"] ||
             [cmd hasPrefix:@"7"] )
    {
        // Error code (3-digit)
        [self handleError:cmd];
    }
}

- (void)processPayloadLine:(NSString *)line payloadData:(NSData *)payload
{
    NSArray *parts = [line componentsSeparatedByString:@" "];
    NSString *cmd = [parts objectAtIndex:0];

    if( [cmd isEqualToString:@"MSG"] )
    {
        [self handleMSG:line payloadData:payload];
    }
    else if( [cmd isEqualToString:@"SYN"] )
    {
        [self handleSYN:line payloadData:payload];
    }
    else
    {
        // Other payload commands (UBX, GCF, NLN-with-payload, ILN-with-payload)
        // NLN and ILN in MSNP15 may carry UBX status data.
        // For simplicity, we parse NLN/ILN params from the line itself.
        if( [cmd isEqualToString:@"NLN"] )
            [self handleNLN:[line substringFromIndex:[cmd length]+1]];
        else if( [cmd isEqualToString:@"ILN"] )
            [self handleILN:[line substringFromIndex:[cmd length]+1]];
    }
}

// --- Command handlers ---

- (void)handleXFR:(NSString *)params
{
    // XFR SB <host:port> CKI <auth>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 4 && [[parts objectAtIndex:0] isEqualToString:@"SB"] )
    {
        // This is a switchboard transfer we requested.
        // The auth string and host will be used when we start a chat.
        // This is handled by connectToSwitchboard.
    }
}

- (void)handleRNG:(NSString *)params
{
    // RNG <sid> <host:port> CKI <auth> <email> <display>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 6 )
    {
        NSString *sid = [parts objectAtIndex:0];
        NSString *hostPort = [parts objectAtIndex:1];
        NSString *auth = [parts objectAtIndex:3];
        NSString *email = [parts objectAtIndex:4];
        NSString *display = [parts objectAtIndex:5];

        MessengerContact *contact = [self contactForAccountID:email];
        if( contact == nil )
        {
            contact = [[[MessengerContact alloc] initWithAccountID:email
                                                             service:kMessengerServiceMSN] autorelease];
            [self addContact:contact];
        }
        [contact setNickName:display];

        // Connect to switchboard and answer the ring
        [self connectToSwitchboard:hostPort auth:auth contact:contact isIncoming:YES sessionID:sid];
    }
}

- (void)handleNLN:(NSString *)params
{
    // NLN <status> <email> <display> [<client-capabilities>]
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 3 )
    {
        NSString *status = [parts objectAtIndex:0];
        NSString *email = [parts objectAtIndex:1];
        NSString *display = [parts objectAtIndex:2];

        MessengerContact *contact = [self contactForAccountID:email];
        if( contact == nil )
        {
            contact = [[[MessengerContact alloc] initWithAccountID:email
                                                             service:kMessengerServiceMSN] autorelease];
            [self addContact:contact];
        }

        BOOL wasOnline = [contact isOnline];
        [contact setNickName:display];
        BOOL online = ![status isEqualToString:@"FLN"] && ![status isEqualToString:@"HDN"];
        [contact setIsOnline:online];
        [contact setStatusString:status];

        if( !wasOnline && online )
            [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusDidChange];
        else
            [self notifyContactChange:contact attribute:kMessengerContactStatusStringDidChange];
    }
}

- (void)handleFLN:(NSString *)params
{
    // FLN <email>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 1 )
    {
        NSString *email = [parts objectAtIndex:0];
        MessengerContact *contact = [self contactForAccountID:email];
        if( contact )
        {
            [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusWillChange];
            [contact setIsOnline:NO];
            [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusDidChange];
        }
    }
}

- (void)handleILN:(NSString *)params
{
    // ILN <trid> <status> <email> <display>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 4 )
    {
        NSString *status = [parts objectAtIndex:1];
        NSString *email = [parts objectAtIndex:2];
        NSString *display = [parts objectAtIndex:3];

        MessengerContact *contact = [self contactForAccountID:email];
        if( contact == nil )
        {
            contact = [[[MessengerContact alloc] initWithAccountID:email
                                                             service:kMessengerServiceMSN] autorelease];
            [self addContact:contact];
        }
        [contact setNickName:display];
        [contact setIsOnline:YES];
        [contact setStatusString:status];
        [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusDidChange];
    }
}

- (void)handleMSG:(NSString *)params payloadData:(NSData *)payload
{
    // MSG <email> <display> <length>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 3 )
    {
        NSString *email = [parts objectAtIndex:0];

        // Parse the message payload for text content
        NSString *payloadStr = [[[NSString alloc] initWithData:payload
                                                      encoding:NSUTF8StringEncoding] autorelease];
        if( payloadStr == nil )
            payloadStr = [[[NSString alloc] initWithData:payload
                                                 encoding:NSISOLatin1StringEncoding] autorelease];

        // Extract Content-Type and message body
        // MSG payload is MIME-like: headers\r\n\r\nbody
        NSRange headerEnd = [payloadStr rangeOfString:@"\r\n\r\n"];
        if( headerEnd.location != NSNotFound )
        {
            NSString *body = [payloadStr substringFromIndex:headerEnd.location + 4];
            // For text/x-msnmsgr-data messages, the body is the actual message
            // Filter out typing notifications and other non-text content
            NSString *contentType = @"";
            NSString *headers = [payloadStr substringToIndex:headerEnd.location];
            NSArray *headerLines = [headers componentsSeparatedByString:@"\r\n"];
            for( NSString *hLine in headerLines )
            {
                NSRange colon = [hLine rangeOfString:@":"];
                if( colon.location != NSNotFound )
                {
                    NSString *hName = [[hLine substringToIndex:colon.location]
                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    if( [hName caseInsensitiveCompare:@"Content-Type"] == NSOrderedSame )
                    {
                        contentType = [[hLine substringFromIndex:colon.location+1]
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    }
                }
            }

            if( [contentType hasPrefix:@"text/plain"] )
            {
                MessengerContact *contact = [self contactForAccountID:email];
                if( contact == nil )
                {
                    contact = [[[MessengerContact alloc] initWithAccountID:email
                                                                     service:kMessengerServiceMSN] autorelease];
                    [self addContact:contact];
                }
                [self deliverIncomingMessage:body fromContact:contact];
            }
            // text/x-msnmsgr-control = typing notification, ignore for now
        }
    }
}

- (void)handleSYN:(NSString *)params payloadData:(NSData *)payload
{
    // SYN payload contains the full contact list in LST/LSG format
    NSString *payloadStr = [[[NSString alloc] initWithData:payload
                                                  encoding:NSUTF8StringEncoding] autorelease];
    if( payloadStr == nil )
        return;

    NSArray *lines = [payloadStr componentsSeparatedByString:@"\r\n"];
    for( NSString *aLine in lines )
    {
        if( [aLine length] == 0 )
            continue;
        NSArray *lParts = [aLine componentsSeparatedByString:@" "];
        if( [lParts count] == 0 )
            continue;

        NSString *lCmd = [lParts objectAtIndex:0];

        if( [lCmd isEqualToString:@"LST"] )
        {
            // LST <email> <display> <flags> [<groups>]
            if( [lParts count] >= 3 )
            {
                NSString *email = [lParts objectAtIndex:1];
                NSString *display = [lParts count] >= 3 ? [lParts objectAtIndex:2] : email;

                MessengerContact *contact = [self contactForAccountID:email];
                if( contact == nil )
                {
                    contact = [[[MessengerContact alloc] initWithAccountID:email
                                                                     service:kMessengerServiceMSN] autorelease];
                    [self addContact:contact];
                }
                [contact setNickName:display];
                [self notifyContactChange:contact attribute:kMessengerContactWasAdded];
            }
        }
    }

    // After SYN completes, set initial presence to online (NLN)
    [self sendCommand:@"CHG" withParams:@"NLN 0"];
}

- (void)handleADD:(NSString *)params
{
    // ADD <trid> <list-type> <email> <display>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 4 )
    {
        NSString *listType = [parts objectAtIndex:1];
        NSString *email = [parts objectAtIndex:2];
        NSString *display = [parts objectAtIndex:3];

        if( [listType isEqualToString:@"FL"] || [listType isEqualToString:@"AL"] )
        {
            MessengerContact *contact = [self contactForAccountID:email];
            if( contact == nil )
            {
                contact = [[[MessengerContact alloc] initWithAccountID:email
                                                                 service:kMessengerServiceMSN] autorelease];
                [self addContact:contact];
            }
            [contact setNickName:display];
            [self notifyContactChange:contact attribute:kMessengerContactWasAdded];
        }
    }
}

- (void)handleREM:(NSString *)params
{
    // REM <trid> <list-type> <email>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 3 )
    {
        NSString *email = [parts objectAtIndex:2];
        MessengerContact *contact = [self contactForAccountID:email];
        if( contact )
        {
            [self notifyContactChange:contact attribute:kMessengerContactWasRemoved];
            [self removeContact:contact];
        }
    }
}

- (void)handleREA:(NSString *)params
{
    // REA <trid> <email> <new-display>
    NSArray *parts = [params componentsSeparatedByString:@" "];
    if( [parts count] >= 3 )
    {
        NSString *email = [parts objectAtIndex:1];
        NSString *display = [parts objectAtIndex:2];
        MessengerContact *contact = [self contactForAccountID:email];
        if( contact )
        {
            [contact setNickName:display];
            [self notifyContactChange:contact attribute:kMessengerContactNicknameDidChange];
        }
    }
}

- (void)handleOut:(NSString *)params
{
    // OUT OTH = another session, OUT SSD = server shutting down
    NSString *reason = ([params length] > 0) ? params : kMessengerNormalDisconnectReason;
    if( [reason hasPrefix:@"OTH"] )
        reason = kMessengerOtherSessionReason;
    [self notifyWillDisconnect:reason];
}

- (void)handleError:(NSString *)errorCode
{
    int code = [errorCode intValue];
    switch( code )
    {
        case 911: // Invalid password
        case 923: // Kid account
            [self notifyLoginFailed:kMessengerInvalidPasswordReason];
            break;
        case 910: // Server busy
        case 920: // Server unavailable
            [self notifyLoginFailed:kMessengerNetworkErrorReason];
            break;
        case 913: // Not allowed when offline
            // Not a login error, just log it
            break;
        default:
            [self notifyLoginFailed:[NSString stringWithFormat:@"Server error %@", errorCode]];
            break;
    }
}

// --- Switchboard management ---

- (void)connectToSwitchboard:(NSString *)hostPort auth:(NSString *)auth
                     contact:(MessengerContact *)contact
                   isIncoming:(BOOL)isIncoming sessionID:(NSString *)sid
{
    // Parse host:port
    NSArray *hp = [hostPort componentsSeparatedByString:@":"];
    if( [hp count] < 2 )
        return;
    NSString *host = [hp objectAtIndex:0];
    unsigned short port = (unsigned short)[[hp objectAtIndex:1] intValue];
    if( port == 0 )
        port = 1864; // Escargot SB default port

    MessengerSocket *sbSocket = [[MessengerSocket alloc] initWithTCPConnectionToHost:host port:port];
    if( sbSocket == nil )
        return;

    MSNPSwitchboard *sb = [[MSNPSwitchboard alloc] initWithSession:self socket:sbSocket];
    [sbSocket release];
    [sb setRemoteContact:contact];

    if( isIncoming )
    {
        [sb setSessionID:sid];
        [sb startIncomingWithAuthString:auth sessionID:sid];
    }
    else
    {
        [sb startOutgoingWithAuthString:auth];
    }

    [sb release];
    [_switchboards setObject:[sb retain] forKey:[contact accountID]];
}

- (MSNPSwitchboard *)switchboardForContact:(MessengerContact *)contact
{
    MSNPSwitchboard *sb = [_switchboards objectForKey:[contact accountID]];
    if( sb == nil )
    {
        // Request a switchboard from the notification server
        [self sendCommand:@"XFR" withParams:@"SB"];

        // We need to store the contact so we know who to call when XFR response comes back.
        // This is handled in the XFR response handler.
        // For now, create a placeholder that will be filled when XFR response arrives.
        // In a full implementation, we'd queue the message and send it after the SB connects.
    }
    return sb;
}

- (void)deliverIncomingMessage:(NSString *)message fromContact:(MessengerContact *)contact
{
    MessengerChat *chat = [self beginChatWithContact:contact];
    [chat didReceiveMessage:message];
    [self notifyDidBeginChat:chat];
}

// --- Utilities ---

- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params
{
    [self sendCommand:cmd withParams:params payload:nil];
}

- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params payload:(NSData *)payload
{
    NSString *trid = [self nextTransactionID];

    NSMutableString *line;
    if( params && [params length] > 0 )
        line = [NSMutableString stringWithFormat:@"%@ %@ %@\r\n", cmd, trid, params];
    else
        line = [NSMutableString stringWithFormat:@"%@ %@\r\n", cmd, trid];

    NSMutableData *packet = [NSMutableData dataWithData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    if( payload )
        [packet appendData:payload];

    [_notificationSocket sendData:packet];
}

- (NSString *)nextTransactionID
{
    return [NSString stringWithFormat:@"%d", _transactionID++];
}

- (NSString *)buildAuthTicketWithNonce:(NSString *)nonce
{
    // Escargot supports a simplified token-based authentication.
    // For MSNP15 with SSO, we build an MD5-based ticket.
    // In a production implementation, this would involve HTTPS token retrieval.
    // For Escargot's simplified auth, we hash the password with the nonce.
    NSString *combined = [NSString stringWithFormat:@"%@%@", [self password], nonce];
    const char *cstr = [combined UTF8String];
    unsigned char hash[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cstr, (CC_LONG)strlen(cstr), hash );

    NSMutableString *hex = [NSMutableString string];
    for( int i = 0; i < CC_MD5_DIGEST_LENGTH; i++ )
        [hex appendFormat:@"%02x", hash[i]];

    return hex;
}

- (NSString *)urlEncode:(NSString *)str
{
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault, (CFStringRef)str, NULL,
        CFSTR(" "), kCFStringEncodingUTF8) autorelease];
}

- (NSString *)xmlEscape:(NSString *)str
{
    NSMutableString *result = [NSMutableString stringWithString:str];
    [result replaceOccurrencesOfString:@"&" withString:@"&amp;"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@"<" withString:@"&lt;"
                               options:0 range:NSMakeRange(0, [result length])];
    [result replaceOccurrencesOfString:@">" withString:@"&gt;"
                               options:0 range:NSMakeRange(0, [result length])];
    return result;
}

@end

// --- MSNPSwitchboard implementation ---

@interface MSNPSwitchboard (Private)
- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params;
- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params payload:(NSData *)payload;
- (void)processBuffer;
- (NSString *)nextTransactionID;
@end

@implementation MSNPSwitchboard

- (id)initWithSession:(MSNPSession *)session socket:(MessengerSocket *)socket
{
    self = [super init];
    if( self )
    {
        _session = session;
        _socket = [socket retain];
        _receiveBuffer = [[NSMutableData alloc] init];
        _transactionID = 1;
        _pendingMessages = [[NSMutableArray alloc] init];
        _isIncoming = NO;
    }
    return self;
}

- (void)dealloc
{
    [_socket release];
    [_receiveBuffer release];
    [_pendingMessages release];
    [_sessionID release];
    [super dealloc];
}

- (void)setRemoteContact:(MessengerContact *)contact { _remoteContact = contact; }
- (void)setSessionID:(NSString *)sid
{
    if( _sessionID != sid )
    {
        [_sessionID release];
        _sessionID = [sid copy];
    }
}

- (void)startOutgoingWithAuthString:(NSString *)authStr
{
    [_socket setDelegate:self];
    [_socket scheduleInRunLoop:[NSRunLoop currentRunLoop]];
    // USR <trid> <email> <auth>
    [self sendCommand:@"USR" withParams:[NSString stringWithFormat:@"%@ %@",
        [[_session username] stringByDeletingEscapesForURL], authStr]];
    _isIncoming = NO;
}

- (void)startIncomingWithAuthString:(NSString *)authStr sessionID:(NSString *)sid
{
    [_socket setDelegate:self];
    [_socket scheduleInRunLoop:[NSRunLoop currentRunLoop]];
    // ANS <trid> <email> <auth> <session-id>
    [self sendCommand:@"ANS" withParams:[NSString stringWithFormat:@"%@ %@ %@",
        [_session username], authStr, sid]];
    _isIncoming = YES;
}

- (void)sendMessage:(NSString *)message
{
    if( _socket == nil || ![_socket isConnected] )
    {
        [_pendingMessages addObject:message];
        return;
    }

    // Build MSG with MIME headers
    NSString *headers = [NSString stringWithFormat:
        @"MIME-Version: 1.0\r\n"
        @"Content-Type: text/plain; charset=UTF-8\r\n"
        @"X-MMS-IM-Format: FN=Arial; EF=; CO=0; CS=0; PF=22\r\n"
        @"\r\n%@", message];

    NSData *payload = [headers dataUsingEncoding:NSUTF8StringEncoding];
    [self sendCommand:@"MSG" withParams:[NSString stringWithFormat:@"%d N", [payload length]] payload:payload];
}

- (void)close
{
    if( [_socket isConnected] )
    {
        [self sendCommand:@"OUT" withParams:nil];
        [_socket close];
    }
}

- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params
{
    [self sendCommand:cmd withParams:params payload:nil];
}

- (void)sendCommand:(NSString *)cmd withParams:(NSString *)params payload:(NSData *)payload
{
    NSString *trid = [self nextTransactionID];
    NSMutableString *line;
    if( params && [params length] > 0 )
        line = [NSMutableString stringWithFormat:@"%@ %@ %@\r\n", cmd, trid, params];
    else
        line = [NSMutableString stringWithFormat:@"%@ %@\r\n", cmd, trid];

    NSMutableData *packet = [NSMutableData dataWithData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    if( payload )
        [packet appendData:payload];
    [_socket sendData:packet];
}

- (NSString *)nextTransactionID
{
    return [NSString stringWithFormat:@"%d", _transactionID++];
}

- (void)messengerSocket:(MessengerSocket *)aSock didReceiveData:(NSData *)data
{
    [_receiveBuffer appendData:data];
    [self processBuffer];
}

- (void)messengerSocketDidDisconnect:(MessengerSocket *)aSock reason:(int)reasonCode
{
    // Switchboard disconnected. Cleanup will be handled by session.
}

- (void)processBuffer
{
    while( [_receiveBuffer length] > 0 )
    {
        const char *bytes = [_receiveBuffer bytes];
        NSUInteger length = [_receiveBuffer length];
        NSUInteger lineEnd = NSNotFound;
        for( NSUInteger i = 0; i < length - 1; i++ )
        {
            if( bytes[i] == '\r' && bytes[i+1] == '\n' )
            {
                lineEnd = i;
                break;
            }
        }
        if( lineEnd == NSNotFound )
            break;

        NSString *line = [[[NSString alloc] initWithBytes:bytes length:lineEnd
                                                 encoding:NSUTF8StringEncoding] autorelease];
        if( line == nil )
            line = [[[NSString alloc] initWithBytes:bytes length:lineEnd
                                           encoding:NSISOLatin1StringEncoding] autorelease];

        NSUInteger consumeLength = lineEnd + 2;
        NSArray *parts = [line componentsSeparatedByString:@" "];
        NSString *cmd = [parts objectAtIndex:0];

        NSUInteger payloadLen = 0;
        if( [cmd isEqualToString:@"MSG"] && [parts count] >= 4 )
        {
            payloadLen = [[parts objectAtIndex:[parts count]-1] intValue];
        }

        if( payloadLen > 0 )
        {
            if( [_receiveBuffer length] < consumeLength + payloadLen )
                break;

            NSData *payload = [_receiveBuffer subdataWithRange:
                NSMakeRange( consumeLength, payloadLen )];

            // Parse incoming chat message
            NSString *payloadStr = [[[NSString alloc] initWithData:payload
                                                          encoding:NSUTF8StringEncoding] autorelease];
            if( payloadStr == nil )
                payloadStr = [[[NSString alloc] initWithData:payload
                                                     encoding:NSISOLatin1StringEncoding] autorelease];

            NSRange headerEnd = [payloadStr rangeOfString:@"\r\n\r\n"];
            if( headerEnd.location != NSNotFound )
            {
                NSString *body = [payloadStr substringFromIndex:headerEnd.location + 4];
                // Deliver to the session
                if( [_remoteContact] )
                {
                    [(_MSNPSession*)_session deliverIncomingMessage:body fromContact:_remoteContact];
                }
            }

            NSUInteger total = consumeLength + payloadLen;
            [_receiveBuffer replaceBytesInRange:NSMakeRange(0, total) withBytes:NULL length:0];
        }
        else
        {
            if( [cmd isEqualToString:@"USR"] || [cmd isEqualToString:@"ANS"] )
            {
                // Login to switchboard OK - send pending messages
                for( NSString *msg in _pendingMessages )
                    [self sendMessage:msg];
                [_pendingMessages removeAllObjects];
            }
            else if( [cmd isEqualToString:@"JOI"] )
            {
                // JOI <email> <display> - the other user joined the switchboard
                // Send pending messages
                for( NSString *msg in _pendingMessages )
                    [self sendMessage:msg];
                [_pendingMessages removeAllObjects];
            }
            else if( [cmd isEqualToString:@"BYE"] )
            {
                // Other user left the switchboard
                [self close];
            }

            [_receiveBuffer replaceBytesInRange:NSMakeRange(0, consumeLength) withBytes:NULL length:0];
        }
    }
}

@end
