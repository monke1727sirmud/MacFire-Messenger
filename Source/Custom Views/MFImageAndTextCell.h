/*******************************************************************
	FILE:		MFImageAndTextCell.h
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		A cell that displays an image and text.  It displays text
		left aligned and vertically centered.
	
	HISTORY:
		2008 04 06  Changed copyright to BSD license.
		2007 12 02  Added copyright notice.
		2007 12 01  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@interface MFImageAndTextCell : NSTextFieldCell
{
	NSImage *_image;
	NSSize _displayImageSize;
}

- (void)setImage:(NSImage *)anImage;
- (NSImage *)image;

- (void)setDisplayImageSize:(NSSize)sz;
- (NSSize)displayImageSize;

@end
