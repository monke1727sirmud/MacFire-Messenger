/*******************************************************************
	FILE:		MFSoundManager.h
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Finds and manages the notification sounds, if any.
	
	HISTORY:
		2008 12 27  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@interface MFSoundManager : NSObject
{
//	NSSound *_incomingChatMessageSound;
//	NSSound *_logOnSound;
//	NSSound *_logOffSound;
//	NSSound *_friendLogOnSound;
//	NSSound *_friendLogOffSound;
}

+ (id)sharedManager;

- (NSArray *)pathsOfAvailableSounds;

@end
