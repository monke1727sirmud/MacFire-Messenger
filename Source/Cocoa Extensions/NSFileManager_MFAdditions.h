/*******************************************************************
	FILE:		NSFileManager_MFAdditions.h
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful methods for the NSFileManager class.
	
	HISTORY:
		2008 12 27  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@interface NSFileManager (MFAdditions)

// Creates the specified folder if necessary
// returns YES on success or NO on failure
+ (BOOL)ensureDirectoryExistsAtPath:(NSString *)path attributes:(NSDictionary *)attrs;

// Pass this the full path of a folder
// The returned array includes full paths (the folder), in contrast to -directoryContentsAtPath: or -subpathsAtPath:
// which only include one name.  This method uses -directoryContentsAtPath: so has those semantics for symlinks/aliases.
// May return 'nil' if the folder does not exist, or has no contents.
- (NSArray *)fullSubpathsAtPath:(NSString *)folder;

@end
