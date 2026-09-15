/*******************************************************************
	FILE:		XfireFriendGroup_MacFireAdditions.m
	
	COPYRIGHT:
		Copyright 2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Additions to the XfireFriendGroup class for use by the UI.
		This purposefully splits UI code from Xfire library code.
	
	HISTORY:
		2008 10 01  Created.
*******************************************************************/

#import "XfireFriendGroup_MacFireAdditions.h"
#import "MFUIStrings.h"

@implementation XfireFriendGroup (MacFireAdditions)

- (NSString *)displayName
{
	XfireFriendGroupType type = [self groupType];
	
	if( type == kXfireFriendGroupOnline )
		return MF_UISTR_ONLINE_GROUP;
	else if( type == kXfireFriendGroupOffline )
		return MF_UISTR_OFFLINE_GROUP;
	else if( type == kXfireFriendGroupFriendOfFriends )
		return MF_UISTR_FOF_GROUP;
	else
		return [self groupName];
}

@end
