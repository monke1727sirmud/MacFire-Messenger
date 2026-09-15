/*******************************************************************
	FILE:		NSScreen_MFAdditions.m
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful methods for the NSScreen class.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 16  Created.
*******************************************************************/

#import "NSScreen_MFAdditions.h"

@implementation NSScreen (MFAdditions)

+ (BOOL)windowFrameIntersectsAnyScreen:(NSRect)aFrame
{
	NSEnumerator *screenEnumerator = [[self screens] objectEnumerator];
	NSScreen *screen;
	
	while( (screen = [screenEnumerator nextObject]) != nil )
	{
		if( NSIntersectsRect([screen frame],aFrame) )
			return YES;
	}
	
	return NO;
}

@end
