/*******************************************************************
	FILE:		NSFileManager_MFAdditions.m
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful methods for the NSFileManager class.
	
	HISTORY:
		2008 12 27  Created.
*******************************************************************/

#import "NSFileManager_MFAdditions.h"

@implementation NSFileManager (MFAdditions)

+ (BOOL)ensureDirectoryExistsAtPath:(NSString *)path attributes:(NSDictionary *)attrs
{
	NSFileManager *mgr = [self defaultManager];
	BOOL isDir;
	
	if( [mgr fileExistsAtPath:path isDirectory:&isDir] )
	{
		if( isDir ) // something exists, is it a directory?
		{
			return YES;
		}
	}
	else
	{
		// Does not exist, try to create it
		if( [mgr createDirectoryAtPath:path attributes:attrs] )
		{
			return YES;
		}
	}
	
	// If we fall through to here, we failed to create the desired folder
	return NO;
}

- (NSArray *)fullSubpathsAtPath:(NSString *)folder
{
	if( folder )
	{
		NSArray *dirList = [self directoryContentsAtPath:folder];
		NSMutableArray *paths = nil;
		if( dirList )
		{
			paths = [NSMutableArray array];
			int i, cnt;
			cnt = [dirList count];
			for( i = 0; i < cnt; i++ )
			{
				[paths addObject:[folder stringByAppendingPathComponent:[dirList objectAtIndex:i]]];
			}
		}
		return paths;
	}
	
	return nil;
}

@end
