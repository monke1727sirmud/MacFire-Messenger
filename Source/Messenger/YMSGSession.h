/*******************************************************************
    FILE:       YMSGSession.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        YMSG (Yahoo Messenger) protocol session.
        Implements the binary YMSG16 packet format for connecting
        to Yahoo Messenger via Escargot's YMSG relay.

        YMSG packet structure:
          [0..3]   "YMSG" magic
          [4..5]   version (16-bit BE)
          [6..7]   vendor ID (16-bit BE)
          [8..9]   payload length (16-bit BE)
          [10..11] service code (16-bit BE)
          [12..15] status code (32-bit BE)
          [16..19] session ID (32-bit BE)
          [20..]   payload (key-value pairs separated by 0xC080)

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>
#import "MessengerSession.h"
#import "MessengerSocket.h"

@interface YMSGSession : MessengerSession <MessengerSocketDelegate>
{
    MessengerSocket    *_socket;
    NSMutableData      *_receiveBuffer;
    uint32_t           _sessionID;
    BOOL               _loggedIn;
}

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port;

@end

// YMSG service codes
typedef enum
{
    kYMSGServiceVerify      = 0x4C,  // 76 - verify
    kYMSGServiceAuth        = 0x57,  // 87 - auth
    kYMSGServiceAuthResp    = 0x54,  // 84 - auth response
    kYMSGServiceList        = 0x55,  // 85 - buddy list
    kYMSGServicePing        = 0x8E,  // 142 - ping/keepalive
    kYMSGServiceMessage     = 0x06,  // 6 - private message
    kYMSGServiceIsBack      = 0x03,  // 3 - back from idle
    kYMSGServiceIsAway      = 0x05,  // 5 - away/idle
    kYMSGServiceLogoff      = 0x02,  // 2 - logoff
    kYMSGServiceContact     = 0x0A,  // 10 - add buddy
    kYMSGServiceContactRemove = 0x0B, // 11 - remove buddy
    kYMSGServiceStatus      = 0x0C,  // 12 - status update
    kYMSGServiceNotify      = 0x4B,  // 75 - buddy online/offline notify
    kYMSGServiceIgnore      = 0x69,  // 105 - ignore
    kYMSGServiceNewMail     = 0x09,  // 9 - new mail
    kYMSGServiceGameInvite  = 0x4D,  // 77 - game invite
    kYMSGServiceFileXfer    = 0x46,  // 70 - file transfer
    kYMSGServiceOfflineMsg  = 0x0F,  // 15 - offline message
    kYMSGServiceAddIgnore   = 0x82,  // 130 - add to ignore list
    kYMSGServiceGroupRename = 0x87,  // 135 - rename group
    kYMSGServiceStealthPerm = 0xB9,  // 185 - stealth session
} YMSGServiceCode;

// YMSG status codes
typedef enum
{
    kYMSGStatusAvailable   = 0x5A55AA56,
    kYMSGStatusBRB         = 0x5A55AA55,
    kYMSGStatusBusy        = 0x5A55AAFD,
    kYMSGStatusSteppedOut  = 0x5A55AAFC,
    kYMSGStatusIdle        = 0x5A55AAFF,
    kYMSGStatusInvisible   = 0x5A55AAFE,
    kYMSGStatusCustom      = 0x5A55AAF9,
    kYMSGStatusOffline     = 0x5A55AA00,
    kYMSGStatusNotify      = 0xFFFFFFFF,
} YMSGStatusCode;
