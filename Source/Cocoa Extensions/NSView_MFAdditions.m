/*******************************************************************
	FILE:		NSView_MFAdditions.m
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful methods for the NSView class.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 02  Added copyright notice.
		2007 11 23  Created.
*******************************************************************/

#import "NSView_MFAdditions.h"

@implementation NSView (MFAdditions)

- (void)removeAllSubviews
{
	int i, cnt;
	NSArray *sv = [self subviews];
	cnt = [sv count];
	for( i = 0; i < cnt; i++ )
	{
		[[sv objectAtIndex:i] removeFromSuperview];
	}
}

- (void)removeSubview:(NSView *)view
{
	int i, cnt;
	NSArray *sv = [self subviews];
	cnt = [sv count];
	for( i = 0; i < cnt; i++ )
	{
		if( [sv objectAtIndex:i] == view )
		{
			[view removeFromSuperview];
			return;
		}
	}
}

@end
