/*******************************************************************
	FILE:		MFImageAndTextView.m
	
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

#import "MFImageAndTextView.h"
#import "MFImageAndTextCell.h"

@interface MFImageAndTextView ()
- (void)_commonInit;
@end

@implementation MFImageAndTextView

- (void)_commonInit
{
	_cell = [[MFImageAndTextCell alloc] initTextCell:@"default"];
	_text = nil;
}

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if( self )
	{
		[self _commonInit];
	}
	return self;
}

// Nib loading (including nibs recompiled by current ibtool) decodes the view
// with initWithCoder:, so the cell has to be built here too or the view draws
// nothing.
- (id)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if( self )
	{
		[self _commonInit];
	}
	return self;
}

- (void)setImageValue:(NSImage *)anImage
{
	[_cell setImage:anImage];
}

- (void)setStringValue:(NSString *)string
{
	_text = string;
}

- (void)setDisplayImageSize:(NSSize)sz
{
	[_cell setDisplayImageSize:sz];
}

- (void)setFont:(NSFont *)aFont
{
	[_cell setFont:aFont];
}

- (void)drawRect:(NSRect)rect
{
	[_cell setStringValue:_text];
	[_cell drawInteriorWithFrame:rect inView:self];
}

@end
