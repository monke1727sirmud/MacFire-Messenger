/*******************************************************************
	FILE:		XfireFriendGroup_MacFireAdditions.h
	
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

#import "XfireFriendGroup.h"

@interface XfireFriendGroup (MacFireAdditions)

- (NSString *)displayName;

@end
