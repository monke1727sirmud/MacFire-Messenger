/*******************************************************************
    FILE:       MessengerTypes.m

    COPYRIGHT:
        Copyright 2026, the MacFire.org team.
        Use of this software is governed by the license terms
        indicated in the License.txt file (a BSD license).

    DESCRIPTION:
        Implementation of shared multi-protocol types and constants.

    HISTORY:
        2026 10 07  Created.
*******************************************************************/

#import "MessengerTypes.h"

NSString *kMessengerLoginFailedReason       = @"Login failed";
NSString *kMessengerNetworkErrorReason      = @"Network error";
NSString *kMessengerInvalidPasswordReason   = @"Invalid password";
NSString *kMessengerOtherSessionReason      = @"Another session logged in";
NSString *kMessengerServerHungUpReason      = @"Server hung up";
NSString *kMessengerNormalDisconnectReason  = @"Normal disconnect";

NSString *MessengerContactDidChangeNotification = @"MessengerContactDidChangeNotification";
NSString *kMessengerContactChangeAttribute       = @"MessengerContactChangeAttribute";

@implementation NSString (MessengerServiceName)

+ (NSString *)displayNameForService:(MessengerService)service
{
    switch( service )
    {
        case kMessengerServiceMSN:    return @"MSN / Windows Live";
        case kMessengerServiceYahoo:  return @"Yahoo Messenger";
        case kMessengerServiceAIM:    return @"AIM";
        case kMessengerServiceICQ:    return @"ICQ";
        case kMessengerServiceXfire:
        default:                      return @"Xfire";
    }
}

+ (NSString *)accountLabelForService:(MessengerService)service
{
    switch( service )
    {
        case kMessengerServiceMSN:    return @"Email (e.g. user@escargot.chat)";
        case kMessengerServiceYahoo:  return @"Yahoo ID";
        case kMessengerServiceAIM:    return @"Screen Name";
        case kMessengerServiceICQ:    return @"ICQ Number";
        case kMessengerServiceXfire:
        default:                      return @"Xfire Username";
    }
}

@end
