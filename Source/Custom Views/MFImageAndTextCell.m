/*******************************************************************
	FILE:		MFImageAndTextCell.m
	
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

#import "MFImageAndTextCell.h"

@implementation MFImageAndTextCell

- (id)copyWithZone:(NSZone *)zone
{
	MFImageAndTextCell *c = (MFImageAndTextCell*)[super copyWithZone:zone];
	c->_image = [_image retain];
	c->_displayImageSize = _displayImageSize;
	return c;
}

- (void)dealloc
{
	[_image release];
	[super dealloc];
}

- (void)setImage:(NSImage *)anImage
{
	[anImage retain];
	[_image release];
	_image = anImage;
}

- (NSImage *)image
{
	return _image;
}

// we draw the image
// let the superview (NSTextFieldCell) draw the image
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
	if( [self image] )
	{
		NSRect imageFrame;
		NSSize imageSize = [self displayImageSize];
		
		// handy utility to split rectangles into two sections
		NSDivideRect(cellFrame,&imageFrame,&cellFrame, 3.0f+imageSize.width,NSMinXEdge);
		
		if( [self drawsBackground] )
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.size = imageSize;
		if( [controlView isFlipped] )
			imageFrame.origin.y += (ceil(cellFrame.size.height+imageFrame.size.height)/2.0f);
		else
			imageFrame.origin.y += (ceil(cellFrame.size.height-imageFrame.size.height)/2.0f);
		[[self image] setSize:[self displayImageSize]];
		[[self image] compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	
	// all this is just so we can draw vertically centered in the bounding box
	// still left aligned
	NSAttributedString *attrStr = [self attributedStringValue];
	NSSize bndSize = [attrStr size];
	NSPoint drawPt;
	drawPt.x = cellFrame.origin.x + 2.0f;
	drawPt.y = cellFrame.origin.y + (cellFrame.size.height - bndSize.height)/2.0f;
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[NSBezierPath clipRect:cellFrame];
	[attrStr drawAtPoint:drawPt];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (NSSize)cellSize
{
	NSSize sz = [super cellSize];
	sz.width += ([self displayImageSize].width + 3.0f);
	return sz;
}

- (void)setDisplayImageSize:(NSSize)sz
{
	_displayImageSize = sz;
}

- (NSSize)displayImageSize
{
	return _displayImageSize;
}

@end

