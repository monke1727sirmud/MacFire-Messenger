/*******************************************************************
	FILE:		MFImageAndTextView.h
	
	COPYRIGHT:
		Copyright 2007-2008, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		A view that is a stand-alone version of an MFImageAndTextCall.
		It displays text and an image left aligned and vertically
		centered.
	
	HISTORY:
		2008 05 17  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@class MFImageAndTextCell;

@interface MFImageAndTextView : NSView
{
	NSString *_text;
	MFImageAndTextCell *_cell;
}

- (void)setImageValue:(NSImage *)img;
- (void)setDisplayImageSize:(NSSize)sz;
- (void)setStringValue:(NSString *)string;
- (void)setFont:(NSFont *)aFont;

@end
