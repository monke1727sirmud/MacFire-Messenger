/*******************************************************************
	FILE:		NSUserDefaults_MFAdditions.m
	
	COPYRIGHT:
		Copyright 2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful additions to NSUserDefaults.
	
	HISTORY:
		2009 01 01  Created.
*******************************************************************/

#import "NSUserDefaults_MFAdditions.h"

@implementation NSUserDefaults (MFAdditions)

- (NSFont *)fontForKey:(NSString *)key
{
	NSData		*data;
	NSFont		*font;
	
	data = [self objectForKey:key];
	font = [NSUnarchiver unarchiveObjectWithData:data];
	if( ! [font isKindOfClass:[NSFont class]] )
	{
		font = nil;
	}
	
	return font;
}

- (void)setFont:(NSFont *)font forKey:(NSString *)key
{
	NSData		*data;
	data = [NSArchiver archivedDataWithRootObject:font];
	[self setObject:data forKey:key];
}

// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (NSColor *)colorForKey:(NSString *)key
{
	NSData		*data;
	NSColor		*color;
	
	data = [self objectForKey:key];
	color= [NSUnarchiver unarchiveObjectWithData:data];
	if( ! [color isKindOfClass:[NSColor class]] )
	{
		color = nil;
	}
	
	return color;
}

// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (void)setColor:(NSColor *)color forKey:(NSString *)key
{
	NSData		*data;
	data = [NSArchiver archivedDataWithRootObject:color];
	[self setObject:data forKey:key];
}

@end
