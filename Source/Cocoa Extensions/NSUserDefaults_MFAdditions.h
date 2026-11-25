/*******************************************************************
	FILE:		NSUserDefaults_MFAdditions.h
	
	COPYRIGHT:
		Copyright 2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Useful additions to NSUserDefaults.
	
	HISTORY:
		2009 01 01  Created.
*******************************************************************/

#import <Cocoa/Cocoa.h>

@interface NSUserDefaults (MFAdditions)

- (NSFont *)fontForKey:(NSString *)key;
- (void)setFont:(NSFont *)font forKey:(NSString *)key;

- (NSColor *)colorForKey:(NSString *)key;
- (void)setColor:(NSColor *)color forKey:(NSString *)key;

@end
