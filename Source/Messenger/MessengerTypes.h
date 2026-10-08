/*******************************************************************
    FILE:       MessengerTypes.h

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Shared types and constants for multi-protocol messenger
        support.  Defines the service identifiers and common
        notification strings used across all protocol backends.

    HISTORY:
        2026 10 07  Created for multi-service Escargot/NINA support.
*******************************************************************/

#import <Cocoa/Cocoa.h>

typedef enum
{
    kMessengerServiceXfire = 0,
    kMessengerServiceMSN,
    kMessengerServiceYahoo,
    kMessengerServiceAIM,
    kMessengerServiceICQ
} MessengerService;

extern NSString *kMessengerLoginFailedReason;
extern NSString *kMessengerNetworkErrorReason;
extern NSString *kMessengerInvalidPasswordReason;
extern NSString *kMessengerOtherSessionReason;
extern NSString *kMessengerServerHungUpReason;
extern NSString *kMessengerNormalDisconnectReason;

extern NSString *MessengerContactDidChangeNotification;
extern NSString *kMessengerContactChangeAttribute;

typedef enum
{
    kMessengerContactNicknameDidChange = 1,
    kMessengerContactWasAdded,
    kMessengerContactWasRemoved,
    kMessengerContactOnlineStatusWillChange,
    kMessengerContactOnlineStatusDidChange,
    kMessengerContactStatusStringDidChange
} MessengerContactChangeAttribute;

@interface NSString (MessengerServiceName)
+ (NSString *)displayNameForService:(MessengerService)service;
+ (NSString *)accountLabelForService:(MessengerService)service;
@end
