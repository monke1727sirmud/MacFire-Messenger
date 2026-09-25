/*******************************************************************
	FILE:		MFGameMonitor.m
	
	COPYRIGHT:
		Copyright 2007-2026, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Monitors when applications are launched and when they exit
		and searches for known games.  It posts notifications for
		when known games start and quit.
	
	HISTORY:
		2026 09 15  Updated to use NSWorkspaceObservation and running
		            app properties instead of deprecated launchedApplications
		            and NSWorkspace app notifications.
		2008 04 06  Changed copyright to BSD license.
		2007 12 16  Created.
*******************************************************************/

#import "MFGameMonitor.h"
#import "MFGAmeRegistry.h"

NSString *kMFGameDidLaunch = @"MFGameDidLaunch";
NSString *kMFGameDidExit = @"MFGameDidExit";

static MFGameMonitor *gSharedMonitor = nil;

@interface MFGameMonitor (Private)
- (void)startMonitoring;
- (void)workspaceAppDidLaunch:(NSNotification *)aNote;
- (void)workspaceAppDidExit:(NSNotification *)aNote;
- (NSDictionary *)gameInfoForAppURL:(NSURL *)appURL;
@end


@implementation MFGameMonitor

+ (id)sharedMonitor
{
	if( gSharedMonitor == nil )
	{
		gSharedMonitor = [[MFGameMonitor alloc] init];
	}
	
	return gSharedMonitor;
}

- (id)init
{
	self = [super init];
	if( self )
	{
		_runningGames = [[NSMutableArray alloc] init];
		
		[self startMonitoring];
	}
	return self;
}

- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	[_runningGames release];
	_runningGames = nil;
	[super dealloc];
}

- (NSArray *)runningGames
{
	return [NSArray arrayWithArray:_runningGames];
}

- (NSDictionary *)gameInfoForAppURL:(NSURL *)appURL
{
	NSString *appPath = [[appURL lastPathComponent] uppercaseString];
	return [[MFGameRegistry registry] infoForMacApplication:
		[NSDictionary dictionaryWithObject:[appURL path] forKey:@"NSApplicationPath"]];
}

// check all currently running apps to make sure we catch everything that's running
- (void)startMonitoring
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	// Use the modern runningApplications property instead of deprecated launchedApplications
	NSArray *runningApps = [workspace runningApplicationsWithBundleIdentifier:nil
		launchDate:nil
		activationPolicy:NSApplicationActivationPolicyRegular];
	
	NSDictionary *gameInfo;
	NSInteger i, cnt;
	cnt = [runningApps count];
	for( i = 0; i < cnt; i++ )
	{
		NSRunningApplication *theApp = [runningApps objectAtIndex:i];
		gameInfo = [self gameInfoForAppURL:[theApp bundleURL]];
		if( gameInfo )
		{
			[_runningGames addObject:gameInfo];
			[[NSNotificationCenter defaultCenter] postNotificationName:kMFGameDidLaunch object:self userInfo:gameInfo];
		}
	}
	
	// Use the modern notification names
	[[workspace notificationCenter] addObserver:self
		selector:@selector(workspaceAppDidLaunch:)
		name:NSWorkspaceDidActivateApplicationNotification
		object:nil];
	[[workspace notificationCenter] addObserver:self
		selector:@selector(workspaceAppDidExit:)
		name:NSWorkspaceDidDeactivateApplicationNotification
		object:nil];
}

// Intercept any app launch
- (void)workspaceAppDidLaunch:(NSNotification *)aNote
{
	NSRunningApplication *app = [[aNote userInfo] objectForKey:NSWorkspaceApplicationKey];
	if( !app )
		return;
	
	NSDictionary *gameInfo = [self gameInfoForAppURL:[app bundleURL]];
	if( gameInfo )
	{
		[_runningGames addObject:gameInfo];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMFGameDidLaunch object:self userInfo:gameInfo];
	}
}

// Intercept any app exit
- (void)workspaceAppDidExit:(NSNotification *)aNote
{
	NSRunningApplication *app = [[aNote userInfo] objectForKey:NSWorkspaceApplicationKey];
	if( !app )
		return;
	
	NSDictionary *gameInfo = [self gameInfoForAppURL:[app bundleURL]];
	
	if( gameInfo && [_runningGames containsObject:gameInfo] )
	{
		[_runningGames removeObject:gameInfo];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMFGameDidExit object:self userInfo:gameInfo];
	}
}

@end
