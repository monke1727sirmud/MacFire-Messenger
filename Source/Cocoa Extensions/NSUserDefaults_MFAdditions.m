/*******************************************************************
	FILE:		NSUserDefaults_MFAdditions.m
	
	COPYRIGHT:
		Copyright 2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful additions to NSUserDefaults.
	
	HISTORY:
		2026 11 25  Replaced NSArchiver/NSUnarchiver with NSKeyedArchiver.
		2009 01 01  Created.
*******************************************************************/

#import "NSUserDefaults_MFAdditions.h"

// Decodes a keyed archive written by -setFont:forKey: or -setColor:forKey:.
// The archives are created with requiringSecureCoding:NO so that all of the
// NSFont/NSColor representations the system can produce are supported.
static id MFUnarchiveObjectOfClass(NSData *data, Class cls)
{
	if( ![data isKindOfClass:[NSData class]] )
		return nil;
	
	NSError *error = nil;
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
	if( unarchiver == nil )
		return nil;
	
	unarchiver.requiresSecureCoding = NO;
	id obj = [unarchiver decodeObjectOfClass:cls forKey:NSKeyedArchiveRootObjectKey];
	[unarchiver finishDecoding];
	
	if( ![obj isKindOfClass:cls] )
		return nil;
	
	return obj;
}

@implementation NSUserDefaults (MFAdditions)

- (NSFont *)fontForKey:(NSString *)key
{
	return MFUnarchiveObjectOfClass([self objectForKey:key], [NSFont class]);
}

- (void)setFont:(NSFont *)font forKey:(NSString *)key
{
	if( font == nil )
	{
		[self removeObjectForKey:key];
		return;
	}
	
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:font requiringSecureCoding:NO error:&error];
	if( data )
		[self setObject:data forKey:key];
	else
		NSLog(@"[MacFire] Unable to archive the chat font: %@", error);
}

// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (NSColor *)colorForKey:(NSString *)key
{
	return MFUnarchiveObjectOfClass([self objectForKey:key], [NSColor class]);
}

// JA ( http://xblaze.co.uk ) Allow user to choose colours for the names shown in the chat history
- (void)setColor:(NSColor *)color forKey:(NSString *)key
{
	if( color == nil )
	{
		[self removeObjectForKey:key];
		return;
	}
	
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:color requiringSecureCoding:NO error:&error];
	if( data )
		[self setObject:data forKey:key];
	else
		NSLog(@"[MacFire] Unable to archive the chat color: %@", error);
}

@end
