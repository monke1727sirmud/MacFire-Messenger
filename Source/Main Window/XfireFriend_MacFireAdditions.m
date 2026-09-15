/*******************************************************************
	FILE:		XfireFriend_MacFireAdditions.m
	
	COPYRIGHT:
		Copyright 2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Additions to the XfireFriend class for use by the UI.  This
		purposefully splits UI code from Xfire library code.
	
	HISTORY:
		2008 04 27  Added sorting method.
		2008 04 12  Created.
*******************************************************************/

#import "XfireFriend_MacFireAdditions.h"
#import "MFGameRegistry.h"
#import "MFUIStrings.h"
#import "MFApplicationSupportController.h"

@implementation XfireFriend (MacFireAdditions)

- (NSString*)displayNameString
{
	NSString* nn = [self nickName];
	NSString* un = [self userName];
	
	switch( [[MFPreferences preferences] nameDisplayStyle] )
	{
		case kMFPreferenceDisplayStyleNickname:
			if( nn && ([nn length] > 0) )
				return nn;
			return un;
			break;
		
		case kMFPreferenceDisplayStyleNickUser:
			if( nn && ([nn length] > 0) )
			{
				return [NSString stringWithFormat:@"%@ (%@)", nn, un];
			}
			return un;
			break;
		
		case kMFPreferenceDisplayStyleUserNick:
			if( nn && ([nn length] > 0) )
			{
				return [NSString stringWithFormat:@"%@ (%@)", un, nn];
			}
			return un;
			break;
		
		case kMFPreferenceDisplayStyleUsername:
		default:
			return un;
			break;
	}
}

// always nickname when available
- (NSString*)shortDisplayNameString
{
	NSString *nn;
	nn = [self nickName];
	if( [nn length] > 0 )
		return nn;
	return [self userName];
}

- (NSComparisonResult)compareFriendsByDisplayName:(XfireFriend *)aFriend
{
	return [[self displayNameString] localizedCaseInsensitiveCompare:[aFriend displayNameString]];
}

- (NSImage *)displayImage
{
	int gid = [self gameID];
	NSImage *dispImg = [[MFGameRegistry registry] defaultImage];
	if( gid != 0 )
	{
		NSDictionary *gameInfo = [MFGameRegistry infoForGameID:gid];
		if( gameInfo )
		{
			NSImage *tmp = [gameInfo objectForKey:kMFGameRegistryIconKey];
			if( tmp )
				dispImg = tmp;
		}
	}
	
	return dispImg;
}

- (NSString *)statusDisplayString
{
	if( [self isOnline] )
	{
		NSString *frStatStr = [self statusString];
		NSString *frGameStr = nil;
		int gid = [self gameID];
		if( gid != 0 )
			frGameStr = [MFGameRegistry longNameForGameID:gid];
		
		if( [frGameStr length] == 0 )
			return frStatStr;
		
		if( [frStatStr length] > 0 )
		{
			return [NSString stringWithFormat:@"%@\n%@",
				frStatStr,
				frGameStr];
		}
		
		return frGameStr;
	}
	else
	{
		return MF_UISTR_OFFLINE;
	}
	
	return nil;
}

- (void)showProfile
{
	NSString *username = [self userName];
	NSString *xfirePath = [NSString stringWithFormat: MF_UISTR_PROFILEURL, username];
	NSURL    *xfireUrl  = [NSURL URLWithString:xfirePath];
	[[NSWorkspace sharedWorkspace] openURL:xfireUrl];
}

- (NSString *)toolTip
{
	NSMutableString *tmp = [NSMutableString string];
	
	[tmp appendFormat:MF_UISTR_TTIP_UNAME, [self userName]];
	
	if( [[self nickName] length] > 0 )
	{
		[tmp appendString:@"\n"];
		[tmp appendFormat:MF_UISTR_TTIP_NNAME, [self nickName]];
	}
	
	[tmp appendString:@"\n"];
	[tmp appendFormat:MF_UISTR_TTIP_UID, [self userID]];
	
	if( [self gameID] != 0 )
	{
		NSString *gameName = [MFGameRegistry longNameForGameID:[self gameID]];
		if( gameName )
		{
			[tmp appendString:@"\n"];
			[tmp appendFormat:MF_UISTR_TTIP_PLAYING, gameName];
		}
		if( [self gameIPAddress] != 0 )
		{
			[tmp appendString:@"\n"];
			[tmp appendFormat:MF_UISTR_TTIP_GAMESRV, MFStringFromIPAddress([self gameIPAddress])];
			[tmp appendFormat:@":%u",[self gamePort]];
		}
	}
	
	if( [self isOnline] )
	{
		[tmp appendString:@"\n"];
		[tmp appendFormat:MF_UISTR_TTIP_LASTSEEN, MF_UISTR_TTIP_NOW];
	}
	else
	{
		NSDictionary *cacheInfo = [[MFApplicationSupportController sharedController] cachedInfoForContact:self];
		if( cacheInfo )
		{
			NSDate *seenOnline = [cacheInfo objectForKey:kMFLastSeenOnlineKey];
			if( seenOnline )
			{
				NSDateFormatter *dfmt = [[[NSDateFormatter alloc] init] autorelease];
				[dfmt setFormatterBehavior:NSDateFormatterBehavior10_4];
				[dfmt setDateStyle:NSDateFormatterShortStyle];
				[dfmt setTimeStyle:NSDateFormatterMediumStyle];
				
				[tmp appendString:@"\n"];
				[tmp appendFormat:MF_UISTR_TTIP_LASTSEEN, [dfmt stringFromDate:seenOnline]];
			}
		}
	}
	
	if( [self isFriendOfFriend] )
	{
		NSArray *commonFriends = [self commonFriends];
		if( commonFriends )
		{
			commonFriends = [commonFriends sortedArrayUsingSelector:@selector(compareFriendsByDisplayName:)];
			
			NSEnumerator *numer = [commonFriends objectEnumerator];
			XfireFriend *commonFr;
			
			[tmp appendFormat:@"\n%@",MF_UISTR_TTIP_COMMONFR];
			while( (commonFr = [numer nextObject]) != nil )
			{
				[tmp appendFormat:@"\n   %@",[commonFr displayNameString]];
			}
		}
	}
	
	return tmp;
}

@end
