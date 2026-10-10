/*******************************************************************
    FILE:       MSNPSession.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        MSNP (Microsoft Notification Protocol) session for Escargot.
        Implements the notification server connection for MSN /
        Windows Live Messenger via Escargot.chat servers.

        Supports MSNP15 protocol level: VER, CVR, USR (twc/twn),
        SYN, BLP, GTC, ADG, REM, ADD, REA, NLN, FLN, ILN, CHG,
        MSG, XFR (SB switchboard), and switchboard chat messaging.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>
#import "MessengerSession.h"
#import "MessengerSocket.h"

@class MSNPSwitchboard;

@interface MSNPSession : MessengerSession <MessengerSocketDelegate>
{
    MessengerSocket        *_notificationSocket;
    NSMutableData          *_receiveBuffer;
    unsigned int           _transactionID;
    NSString               *_pendingTicket;   // from USR twc response
    NSString               *_currentDisplay;  // current nickname

    // Switchboards: accountID -> MSNPSwitchboard
    NSMutableDictionary    *_switchboards;
}

- (id)initWithService:(MessengerService)service host:(NSString *)host port:(unsigned short)port;

@end
