/*******************************************************************
	FILE:		MFSoundManager.m
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Finds and manages the notification sounds, if any.
	
	HISTORY:
		2008 12 27  Created.
*******************************************************************/

#import "MFSoundManager.h"
#import "NSFileManager_MFAdditions.h"
#import "MFApplicationSupportController.h"

static MFSoundManager *gSharedManager = nil;

@implementation MFSoundManager

+ (id)sharedManager
{
	if( gSharedManager == nil )
	{
		gSharedManager = [[MFSoundManager alloc] init];
	}
	
	return gSharedManager;
}

- (id)init
{
	self = [super init];
	if( self )
	{
		//_incomingChatMessageSound = nil;
	}
	return self;
}

// System locations as noted in the documentation for -[NSSound soundNamed:]
// Plus the application support's sounds folder
- (NSArray *)pathsOfAvailableSounds
{
	NSFileManager *mgr = [NSFileManager defaultManager];
	NSMutableArray *sounds = [NSMutableArray array];
	NSArray *dirList;
	
	dirList = [mgr fullSubpathsAtPath:@"/Library/Sounds"];
	if( dirList )
		[sounds addObjectsFromArray:dirList];
	
	dirList = [mgr fullSubpathsAtPath:[@"~/Library/Sounds" stringByExpandingTildeInPath]];
	if( dirList )
		[sounds addObjectsFromArray:dirList];
	
	dirList = [mgr fullSubpathsAtPath:@"/System/Library/Sounds"];
	if( dirList )
		[sounds addObjectsFromArray:dirList];
	
	NSString *path = [[MFApplicationSupportController sharedController] soundsFolderPath];
	if( path )
	{
		dirList = [mgr fullSubpathsAtPath:path];
		if( dirList )
			[sounds addObjectsFromArray:dirList];
	}
	
	return sounds;
}

- (NSArray *)availableSounds
{
	NSArray *paths = [self pathsOfAvailableSounds];
	NSMutableArray *sounds = [NSMutableArray array];
	NSSound *snd;
	int i, cnt;
	cnt = [paths count];
	for( i = 0; i < cnt; i++ )
	{
		snd = [[NSSound alloc] initWithContentsOfFile:[paths objectAtIndex:i] byReference:NO];
		if( snd )
		{
			[sounds addObject:snd];
		}
	}
	
	return sounds;
}

@end
