/*******************************************************************
	FILE:		NSView_MFAdditions.h
	
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

#import <Cocoa/Cocoa.h>

@interface NSView (MFAdditions)
- (void)removeAllSubviews;
- (void)removeSubview:(NSView *)view;
@end
