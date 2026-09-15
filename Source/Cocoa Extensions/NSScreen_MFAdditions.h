/*******************************************************************
	FILE:		NSScreen_MFAdditions.h
	
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

#import <Cocoa/Cocoa.h>

@interface NSScreen (MFAdditions)

// returns YES only if the specified window frame lies on any screen
+ (BOOL)windowFrameIntersectsAnyScreen:(NSRect)aFrame;

@end
