/*******************************************************************
    FILE:       YMSGSession.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of the YMSG protocol session for Yahoo
        Messenger via Escargot.  Handles the binary packet format,
        login handshake, buddy list, presence, and messaging.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "YMSGSession.h"
#import "MessengerContact.h"
#import "MessengerChat.h"
#import <CommonCrypto/CommonCrypto.h>

@interface YMSGSession (Private)
- (void)sendPacketWithService:(YMSGServiceCode)service status:(YMSGStatusCode)status payload:(NSData *)payload;
- (NSData *)buildPayloadFromKeys:(NSArray *)keys values:(NSArray *)values;
- (NSArray *)parsePayloadKeys:(NSData *)payload;
- (NSMutableDictionary *)parsePayloadToDictionary:(NSData *)payload;
- (void)processReceivedData;
- (void)handlePacketWithService:(YMSGServiceCode)service status:(YMSGStatusCode)status payload:(NSData *)payload;
- (void)handleAuthChallenge:(NSData *)payload;
- (void)handleAuthResponse:(NSData *)payload;
- (void)handleBuddyList:(NSData *)payload;
- (void)handleMessage:(NSData *)payload;
- (void)handleNotify:(NSData *)payload;
- (void)handleStatusUpdate:(NSData *)payload;
- (NSString *)buildYHashWithChallenge:(NSString *)challenge;
- (NSString *)buildYahoo16Checksum:(NSString *)challenge;
@end

// YMSG key-value separator: 0xC0 0x80
static const char kYMSGSeparator[2] = { (char)0xC0, (char)0x80 };

@implementation YMSGSession

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port
{
    self = [super initWithService:service host:host port:port];
    if( self )
    {
        _receiveBuffer = [[NSMutableData alloc] init];
        _sessionID = 0;
        _loggedIn = NO;
    }
    return self;
}

- (void)dealloc
{
    [_socket release];
    [_receiveBuffer release];
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

    // Send verify packet: empty payload, service=Verify, status=0
    [self sendPacketWithService:kYMSGServiceVerify status:0 payload:nil];
}

- (void)doDisconnect
{
    if( _socket && [_socket isConnected] )
    {
        [self sendPacketWithService:kYMSGServiceLogoff status:0 payload:nil];
        [_socket close];
    }
    _loggedIn = NO;
    [self setStatus:kMessengerStatusOffline];
}

- (void)doSendMessage:(NSString *)message toContact:(MessengerContact *)contact
{
    // Message payload: key 0 = sender, key 1 = recipient, key 14 = message text
    NSData *payload = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"0", @"1", @"14", nil]
        values:[NSArray arrayWithObjects:[self username], [contact accountID], message, nil]];
    [self sendPacketWithService:kYMSGServiceMessage status:kYMSGStatusOffline payload:payload];
}

- (void)doSetStatusString:(NSString *)text
{
    // Set custom status via status service
    // Key 10 = status type, key 19 = custom message
    NSData *payload = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"10", @"19", nil]
        values:[NSArray arrayWithObjects:@"99", text, nil]];
    [self sendPacketWithService:kYMSGServiceStatus status:kYMSGStatusCustom payload:payload];
}

- (void)doSetNickname:(NSString *)text
{
    // YMSG doesn't have a separate nickname concept like MSN.
    // The display name is set via profile, not the protocol.
}

- (void)doSendFriendInvitation:(NSString *)accountID message:(NSString *)msg
{
    // Add buddy: key 1 = our ID, key 7 = buddy ID, key 65 = group name, key 14 = message
    NSData *payload = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"1", @"7", @"65", @"14", nil]
        values:[NSArray arrayWithObjects:[self username], accountID, @"Friends", msg, nil]];
    [self sendPacketWithService:kYMSGServiceContact status:kYMSGStatusAvailable payload:payload];
}

- (void)doRemoveContact:(MessengerContact *)contact
{
    // Remove buddy: key 1 = our ID, key 7 = buddy ID, key 65 = group name
    NSData *payload = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"1", @"7", @"65", nil]
        values:[NSArray arrayWithObjects:[self username], [contact accountID], @"Friends", nil]];
    [self sendPacketWithService:kYMSGServiceContactRemove status:kYMSGStatusAvailable payload:payload];
}

- (void)doAcceptFriendRequest:(MessengerContact *)contact
{
    // Accept: same as add buddy
    [self doSendFriendInvitation:[contact accountID] message:@"Approved"];
}

- (void)doDeclineFriendRequest:(MessengerContact *)contact
{
    // Decline: ignore the contact
    NSData *payload = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"1", @"7", @"13", nil]
        values:[NSArray arrayWithObjects:[self username], [contact accountID], @"2", nil]];
    [self sendPacketWithService:kYMSGServiceContact status:kYMSGStatusAvailable payload:payload];
}

// --- MessengerSocketDelegate ---

- (void)messengerSocket:(MessengerSocket *)aSock didReceiveData:(NSData *)data
{
    [_receiveBuffer appendData:data];
    [self processReceivedData];
}

- (void)messengerSocketDidDisconnect:(MessengerSocket *)aSock reason:(int)reasonCode
{
    if( _loggedIn )
        [self notifyWillDisconnect:(reasonCode == kMessengerSocketNormalDisconnect)
            ? kMessengerNormalDisconnectReason : kMessengerServerHungUpReason];
    else
        [self notifyLoginFailed:kMessengerNetworkErrorReason];
}

// --- Packet building and parsing ---

- (void)sendPacketWithService:(YMSGServiceCode)service status:(YMSGStatusCode)status payload:(NSData *)payload
{
    NSUInteger payloadLen = payload ? [payload length] : 0;

    NSMutableData *packet = [NSMutableData dataWithCapacity:20 + payloadLen];

    // Header: "YMSG" + version(16) + vendorID(0) + length + service + status + sessionID
    [packet appendBytes:"YMSG" length:4];

    uint16_t version = htons(16);
    [packet appendBytes:&version length:2];

    uint16_t vendorID = htons(0);
    [packet appendBytes:&vendorID length:2];

    uint16_t len = htons((uint16_t)payloadLen);
    [packet appendBytes:&len length:2];

    uint16_t svc = htons((uint16_t)service);
    [packet appendBytes:&svc length:2];

    uint32_t st = htonl((uint32_t)status);
    [packet appendBytes:&st length:4];

    uint32_t sid = htonl(_sessionID);
    [packet appendBytes:&sid length:4];

    if( payload && payloadLen > 0 )
        [packet appendData:payload];

    [_socket sendData:packet];
}

- (NSData *)buildPayloadFromKeys:(NSArray *)keys values:(NSArray *)values
{
    NSMutableData *result = [NSMutableData data];
    NSUInteger count = [keys count];
    for( NSUInteger i = 0; i < count; i++ )
    {
        NSString *key = [keys objectAtIndex:i];
        NSString *value = (i < [values count]) ? [values objectAtIndex:i] : @"";
        NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
        NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];

        [result appendData:keyData];
        [result appendBytes:kYMSGSeparator length:2];
        [result appendData:valueData];
        [result appendBytes:kYMSGSeparator length:2];
    }
    return result;
}

- (NSMutableDictionary *)parsePayloadToDictionary:(NSData *)payload
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if( payload == nil || [payload length] == 0 )
        return dict;

    // Split on 0xC080 separator
    const char *bytes = [payload bytes];
    NSUInteger length = [payload length];
    NSMutableArray *tokens = [NSMutableArray array];
    NSUInteger start = 0;

    for( NSUInteger i = 0; i + 1 < length; i++ )
    {
        if( bytes[i] == (char)0xC0 && bytes[i+1] == (char)0x80 )
        {
            NSUInteger tokenLen = i - start;
            if( tokenLen > 0 )
            {
                NSString *tok = [[[NSString alloc] initWithBytes:bytes+start
                                                           length:tokenLen
                                                         encoding:NSUTF8StringEncoding] autorelease];
                if( tok == nil )
                    tok = [[[NSString alloc] initWithBytes:bytes+start
                                                       length:tokenLen
                                                     encoding:NSISOLatin1StringEncoding] autorelease];
                [tokens addObject:tok];
            }
            else
            {
                [tokens addObject:@""];
            }
            start = i + 2;
            i++; // skip the 0x80
        }
    }
    // Last token
    if( start < length )
    {
        NSUInteger tokenLen = length - start;
        NSString *tok = [[[NSString alloc] initWithBytes:bytes+start
                                                   length:tokenLen
                                                 encoding:NSUTF8StringEncoding] autorelease];
        if( tok == nil )
            tok = [[[NSString alloc] initWithBytes:bytes+start
                                               length:tokenLen
                                             encoding:NSISOLatin1StringEncoding] autorelease];
        [tokens addObject:tok];
    }

    // Tokens alternate: key, value, key, value...
    for( NSUInteger i = 0; i + 1 < [tokens count]; i += 2 )
    {
        [dict setObject:[tokens objectAtIndex:i+1] forKey:[tokens objectAtIndex:i]];
    }

    return dict;
}

- (void)processReceivedData
{
    // YMSG packets have a 20-byte header. We need at least 20 bytes.
    while( [_receiveBuffer length] >= 20 )
    {
        const char *bytes = [_receiveBuffer bytes];

        // Verify magic
        if( memcmp(bytes, "YMSG", 4) != 0 )
        {
            // Out of sync. Discard one byte and try again.
            [_receiveBuffer replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
            continue;
        }

        // Read payload length from header
        uint16_t payloadLen = ntohs(*(uint16_t*)(bytes + 8));
        uint16_t service = ntohs(*(uint16_t*)(bytes + 10));
        uint32_t status = ntohl(*(uint32_t*)(bytes + 12));
        uint32_t sid = ntohl(*(uint32_t*)(bytes + 16));

        NSUInteger totalLen = 20 + payloadLen;

        if( [_receiveBuffer length] < totalLen )
            break; // incomplete packet, wait for more data

        // Extract payload
        NSData *payload = nil;
        if( payloadLen > 0 )
            payload = [_receiveBuffer subdataWithRange:NSMakeRange(20, payloadLen)];

        // Update session ID if server assigned one
        if( sid != 0 )
            _sessionID = sid;

        // Handle the packet
        [self handlePacketWithService:(YMSGServiceCode)service
                                status:(YMSGStatusCode)status
                               payload:payload];

        // Consume the packet
        [_receiveBuffer replaceBytesInRange:NSMakeRange(0, totalLen) withBytes:NULL length:0];
    }
}

- (void)handlePacketWithService:(YMSGServiceCode)service status:(YMSGStatusCode)status payload:(NSData *)payload
{
    switch( service )
    {
        case kYMSGServiceVerify:
            // Server confirmed we can connect. Send auth.
            [self handleAuthChallenge:nil];
            break;

        case kYMSGServiceAuth:
            // Server sent auth challenge
            [self handleAuthChallenge:payload];
            break;

        case kYMSGServiceAuthResp:
            // Login response
            [self handleAuthResponse:payload];
            break;

        case kYMSGServiceList:
            // Buddy list
            [self handleBuddyList:payload];
            break;

        case kYMSGServiceMessage:
            // Incoming message
            [self handleMessage:payload];
            break;

        case kYMSGServiceNotify:
            // Buddy online/offline notification
            [self handleNotify:payload];
            break;

        case kYMSGServiceStatus:
            // Status update
            [self handleStatusUpdate:payload];
            break;

        case kYMSGServiceLogoff:
            // Server forcing logoff
            [self notifyWillDisconnect:kMessengerOtherSessionReason];
            break;

        case kYMSGServicePing:
            // Keepalive response. Ignore.
            break;

        case kYMSGServiceContact:
            // Buddy added confirmation
            {
                NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];
                NSString *buddyID = [dict objectForKey:@"7"];
                if( buddyID )
                {
                    MessengerContact *contact = [self contactForAccountID:buddyID];
                    if( contact == nil )
                    {
                        contact = [[[MessengerContact alloc] initWithAccountID:buddyID
                                                                         service:kMessengerServiceYahoo] autorelease];
                        [self addContact:contact];
                        [self notifyContactChange:contact attribute:kMessengerContactWasAdded];
                    }
                }
            }
            break;

        case kYMSGServiceContactRemove:
            // Buddy removed confirmation
            {
                NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];
                NSString *buddyID = [dict objectForKey:@"7"];
                if( buddyID )
                {
                    MessengerContact *contact = [self contactForAccountID:buddyID];
                    if( contact )
                    {
                        [self notifyContactChange:contact attribute:kMessengerContactWasRemoved];
                        [self removeContact:contact];
                    }
                }
            }
            break;

        default:
            // Unhandled service code. Ignore.
            break;
    }
}

- (void)handleAuthChallenge:(NSData *)payload
{
    NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];

    // If no challenge, send initial auth request
    // Auth request: key 0 = username, key 2 = challenge (if any)
    if( [dict count] == 0 )
    {
        // Step 1: send username to get challenge
        NSData *p = [self buildPayloadFromKeys:
            [NSArray arrayWithObjects:@"0", @"2", nil]
            values:[NSArray arrayWithObjects:[self username], @"", nil]];
        [self sendPacketWithService:kYMSGServiceAuth status:0 payload:p];
        return;
    }

    // Step 2: we have a challenge string. Build auth response.
    NSString *challenge = [dict objectForKey:@"94"];
    if( challenge == nil )
        challenge = @"";

    // Build Yahoo16 auth response
    NSString *response = [self buildYahoo16Checksum:challenge];

    // Send auth response with username and hashed password
    NSData *p = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"0", @"6", @"96", nil]
        values:[NSArray arrayWithObjects:[self username], response, challenge, nil]];
    [self sendPacketWithService:kYMSGServiceAuthResp status:0 payload:p];
}

- (void)handleAuthResponse:(NSData *)payload
{
    NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];

    // Check if login was successful
    // Key 66 = error code, key 20 = buddy list start
    NSString *errCode = [dict objectForKey:@"66"];
    if( errCode && ![errCode isEqualToString:@"0"] )
    {
        [self notifyLoginFailed:kMessengerInvalidPasswordReason];
        return;
    }

    _loggedIn = YES;
    [self setStatus:kMessengerStatusOnline];

    // Request buddy list
    NSData *p = [self buildPayloadFromKeys:
        [NSArray arrayWithObjects:@"1", nil]
        values:[NSArray arrayWithObjects:[self username], nil]];
    [self sendPacketWithService:kYMSGServiceList status:kYMSGStatusAvailable payload:p];
}

- (void)handleBuddyList:(NSData *)payload
{
    NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];

    // Buddy list is in key 302 (start), 301 (groups), 300 (buddies in group)
    // Key 7 = buddy ID, key 65 = group name, key 317 = status
    // The format is: initial buddy list then online status updates.
    // For a simplified implementation, parse all key 7 values.

    // Parse the raw payload for buddy names
    // The buddy list payload contains multiple entries.
    // We look for "7" keys which contain buddy IDs.
    NSString *buddyStr = [dict objectForKey:@"7"];
    if( buddyStr )
    {
        // Could be comma-separated or single
        NSArray *buddies = [buddyStr componentsSeparatedByString:@","];
        for( NSString *bid in buddies )
        {
            if( [bid length] > 0 )
            {
                MessengerContact *contact = [self contactForAccountID:bid];
                if( contact == nil )
                {
                    contact = [[[MessengerContact alloc] initWithAccountID:bid
                                                                     service:kMessengerServiceYahoo] autorelease];
                    [self addContact:contact];
                    [self notifyContactChange:contact attribute:kMessengerContactWasAdded];
                }
            }
        }
    }

    // The raw payload may contain multiple buddy entries.
    // Re-parse with full token extraction.
    if( payload && [payload length] > 0 )
    {
        const char *bytes = [payload bytes];
        NSUInteger length = [payload length];
        NSMutableArray *tokens = [NSMutableArray array];
        NSUInteger start = 0;

        for( NSUInteger i = 0; i + 1 < length; i++ )
        {
            if( bytes[i] == (char)0xC0 && bytes[i+1] == (char)0x80 )
            {
                NSUInteger tokenLen = i - start;
                NSString *tok = (tokenLen > 0)
                    ? [[[NSString alloc] initWithBytes:bytes+start length:tokenLen
                                               encoding:NSUTF8StringEncoding] autorelease]
                    : @"";
                if( tok == nil )
                    tok = @"";
                [tokens addObject:tok];
                start = i + 2;
                i++;
            }
        }

        // Walk tokens: key,value pairs. Key "7" = buddy name.
        for( NSUInteger i = 0; i + 1 < [tokens count]; i += 2 )
        {
            NSString *k = [tokens objectAtIndex:i];
            NSString *v = [tokens objectAtIndex:i+1];
            if( [k isEqualToString:@"7"] && [v length] > 0 )
            {
                MessengerContact *contact = [self contactForAccountID:v];
                if( contact == nil )
                {
                    contact = [[[MessengerContact alloc] initWithAccountID:v
                                                                     service:kMessengerServiceYahoo] autorelease];
                    [self addContact:contact];
                    [self notifyContactChange:contact attribute:kMessengerContactWasAdded];
                }
            }
            else if( [k isEqualToString:@"10"] )
            {
                // Status code for the previous buddy
                // 0 = offline, nonzero = online
            }
        }
    }
}

- (void)handleMessage:(NSData *)payload
{
    NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];

    NSString *sender = [dict objectForKey:@"4"];   // sender ID
    NSString *message = [dict objectForKey:@"14"];  // message text

    if( sender && message && [sender length] > 0 )
    {
        MessengerContact *contact = [self contactForAccountID:sender];
        if( contact == nil )
        {
            contact = [[[MessengerContact alloc] initWithAccountID:sender
                                                             service:kMessengerServiceYahoo] autorelease];
            [self addContact:contact];
        }

        // Deliver message
        MessengerChat *chat = [self beginChatWithContact:contact];
        [chat didReceiveMessage:message];
        [self notifyDidBeginChat:chat];
    }
}

- (void)handleNotify:(NSData *)payload
{
    // Notify packets contain buddy online/offline status
    // Key 4 = buddy, key 10 = status code, key 14 = status message
    NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];

    NSString *buddy = [dict objectForKey:@"4"];
    NSString *statusStr = [dict objectForKey:@"10"];
    NSString *customMsg = [dict objectForKey:@"19"];

    if( buddy == nil )
        return;

    MessengerContact *contact = [self contactForAccountID:buddy];
    if( contact == nil )
    {
        contact = [[[MessengerContact alloc] initWithAccountID:buddy
                                                         service:kMessengerServiceYahoo] autorelease];
        [self addContact:contact];
    }

    BOOL wasOnline = [contact isOnline];
    int statusVal = statusStr ? [statusStr intValue] : 0;
    BOOL online = (statusVal != 0);

    if( wasOnline != online )
    {
        [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusWillChange];
        [contact setIsOnline:online];
        [self notifyContactChange:contact attribute:kMessengerContactOnlineStatusDidChange];
    }

    if( customMsg )
        [contact setStatusString:customMsg];
}

- (void)handleStatusUpdate:(NSData *)payload
{
    NSMutableDictionary *dict = [self parsePayloadToDictionary:payload];

    NSString *buddy = [dict objectForKey:@"7"];
    NSString *customMsg = [dict objectForKey:@"19"];

    if( buddy )
    {
        MessengerContact *contact = [self contactForAccountID:buddy];
        if( contact )
        {
            if( customMsg )
            {
                [contact setStatusString:customMsg];
                [self notifyContactChange:contact attribute:kMessengerContactStatusStringDidChange];
            }
        }
    }
}

// --- Yahoo auth ---

- (NSString *)buildYHashWithChallenge:(NSString *)challenge
{
    // Simple MD5 hash of password + challenge
    NSString *combined = [NSString stringWithFormat:@"%@%@", [self password], challenge];
    const char *cstr = [combined UTF8String];
    unsigned char hash[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cstr, (CC_LONG)strlen(cstr), hash );

    NSMutableString *hex = [NSMutableString string];
    for( int i = 0; i < CC_MD5_DIGEST_LENGTH; i++ )
        [hex appendFormat:@"%02x", hash[i]];
    return hex;
}

- (NSString *)buildYahoo16Checksum:(NSString *)challenge
{
    // Yahoo16 authentication: MD5(MD5(password) + challenge)
    // Step 1: MD5 the password
    const char *pwCstr = [[self password] UTF8String];
    unsigned char pwHash[CC_MD5_DIGEST_LENGTH];
    CC_MD5( pwCstr, (CC_LONG)strlen(pwCstr), pwHash );

    // Convert to hex string
    NSMutableString *pwHex = [NSMutableString string];
    for( int i = 0; i < CC_MD5_DIGEST_LENGTH; i++ )
        [pwHex appendFormat:@"%02x", pwHash[i]];

    // Step 2: MD5(pwHex + challenge)
    NSString *combined = [NSString stringWithFormat:@"%@%@", pwHex, challenge];
    const char *combCstr = [combined UTF8String];
    unsigned char finalHash[CC_MD5_DIGEST_LENGTH];
    CC_MD5( combCstr, (CC_LONG)strlen(combCstr), finalHash );

    // Convert to base64-like string (Yahoo uses a custom encoding)
    // For Escargot's simplified auth, the hex digest is sufficient
    NSMutableString *result = [NSMutableString string];
    for( int i = 0; i < CC_MD5_DIGEST_LENGTH; i++ )
        [result appendFormat:@"%02x", finalHash[i]];
    return result;
}

@end
