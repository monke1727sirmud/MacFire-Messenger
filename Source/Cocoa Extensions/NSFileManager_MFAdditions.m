/*******************************************************************
	FILE:		NSFileManager_MFAdditions.m
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful methods for the NSFileManager class.
	
	HISTORY:
		2026 11 25  Replaced the deprecated directoryContentsAtPath: and
		            createDirectoryAtPath:attributes: calls.
		2008 12 27  Created.
*******************************************************************/

#import "NSFileManager_MFAdditions.h"

@implementation NSFileManager (MFAdditions)

+ (BOOL)ensureDirectoryExistsAtPath:(NSString *)path attributes:(NSDictionary *)attrs
{
	NSFileManager *mgr = [self defaultManager];
	BOOL isDir = NO;
	
	if( [mgr fileExistsAtPath:path isDirectory:&isDir] )
	{
		// something exists, is it a directory?
		return isDir;
	}
	
	// Does not exist, try to create it (including any missing parents)
	NSError *error = nil;
	if( [mgr createDirectoryAtPath:path withIntermediateDirectories:YES attributes:attrs error:&error] )
	{
		return YES;
	}
	
	NSLog(@"[MacFire] Unable to create directory at %@: %@", path, error);
	return NO;
}

- (NSArray *)fullSubpathsAtPath:(NSString *)folder
{
	if( folder == nil )
		return nil;
	
	NSError *error = nil;
	NSArray *dirList = [self contentsOfDirectoryAtPath:folder error:&error];
	if( dirList == nil )
		return nil;
	
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:[dirList count]];
	for( NSString *name in dirList )
	{
		[paths addObject:[folder stringByAppendingPathComponent:name]];
	}
	
	return paths;
}

@end
