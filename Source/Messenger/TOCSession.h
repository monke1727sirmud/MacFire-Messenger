/*******************************************************************
    FILE:       TOCSession.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        TOC (Toc/Open/Cannibalism) protocol session for AIM and ICQ
        via NINA.chat servers.  TOC is a text-based protocol that
        is simpler than OSCAR and well-suited for third-party
        clients.

        TOC frame format:
          [0]     'DATA' / 'SIGN_ON' / 'FLAP' (4 bytes)
          [1]     frame type (1 byte)
          [2..3]  sequence number (16-bit BE)
          [4..5]  data length (16-bit BE)
          [6..]   data payload

        TOC commands:
          C->S: toc_signon, toc_init_done, toc_send_im, toc_add_buddy,
                toc_remove_buddy, toc_set_config, toc_set_info,
                toc_set_away, toc_add_permit, toc_add_deny
          S->C: NICK, SIGN_ON, UPDATE_BUDDY, IM_IN, GOTO_URL,
                EVILED, CHAT_JOIN, CHAT_IN, CHAT_UPDATE_BUDDY,
                ERROR, ADMIN_STATUS

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>
#import "MessengerSession.h"
#import "MessengerSocket.h"

@interface TOCSession : MessengerSession <MessengerSocketDelegate>
{
    MessengerSocket    *_socket;
    NSMutableData      *_receiveBuffer;
    uint16_t           _sequenceNumber;
    BOOL               _signedOn;
    NSString           *_roastedPassword; // TOC password is "roasted" with XOR
}

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port;

@end
