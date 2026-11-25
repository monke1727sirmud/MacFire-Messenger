/*******************************************************************
	FILE:		MFApplicationSupportController.m
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Controls access to the application support folder for MacFire
		and provides utilities to access the contents.
	
	HISTORY:
		2008 12 27  Created.
*******************************************************************/

#import "MFApplicationSupportController.h"
#import "NSFileManager_MFAdditions.h"
#import "XfireSession.h"

NSString* kMFUserNameKey         = @"UserName";          // NSString
NSString* kMFUserIDKey           = @"UserID";            // NSNumber(int)
NSString* kMFNickNameKey         = @"NickName";          // NSString
NSString* kMFLastSeenOnlineKey   = @"LastSeenOnline";    // NSDate
NSString* kMFIsFriendOfFriendKey = @"IsFriendOfFriend";  // NSNumber(BOOL)

static MFApplicationSupportController *gSharedController = nil;

/*

Folder organization:

~/Library/Application Support/MacFire/
	Accounts/
		username/						Use the username as it's currently guaranteed to be usable for a file path (lower case letters and numbers per their site)
			Contacts.plist				Archive of all known people with extra info (e.g. date/time last seen)
			Groups.plist				Info on friend groups (e.g. whether the group is expanded in the list)
			Chat Logs/
				yyyymmdd xx.plist
				...
				yyyymmdd xx.plist
				...
		username/
			...
	Sounds/


Contacts property list:
	
	root object is NSDictionary with keys:
		kMFUserNameKey
		kMFUserIDKey
		kMFNickNameKey
		kMFLastSeenOnlineKey
		kMFIsFriendOfFriendKey
		
		TBD:
		kMFLastSeenPlayingKey {what game they were seen playing last}
*/


@interface MFApplicationSupportController (Private)
- (NSString *)pathForAccount:(XfireFriend *)user;
- (NSString *)pathForAccountContacts:(XfireFriend *)user;

- (BOOL)updateContact:(XfireFriend *)fr inCache:(NSMutableDictionary *)cache;

- (NSString *)currentDateFormat;
@end

@implementation MFApplicationSupportController

+ (id)sharedController
{
	if( gSharedController == nil )
	{
		gSharedController = [[MFApplicationSupportController alloc] init];
	}
	
	return gSharedController;
}

- (id)init
{
	self = [super init];
	if( self )
	{
		_basePath = nil;
		
		NSArray *appSupportFolders = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);
		if( appSupportFolders && ([appSupportFolders count] > 0) )
		{
			_basePath = [[[appSupportFolders objectAtIndex:0] stringByAppendingPathComponent:@"MacFire"] retain];
		}
		
		if( ! [NSFileManager ensureDirectoryExistsAtPath:_basePath attributes:nil] )
		{
			NSLog(@"Unable to create application support folder");
			_basePath = nil;
			return self;
		}
		
		if( ! [NSFileManager ensureDirectoryExistsAtPath:[_basePath stringByAppendingPathComponent:@"Sounds"] attributes:nil] )
		{
			NSLog(@"Unable to create application support sounds folder");
		}
		
		if( ! [NSFileManager ensureDirectoryExistsAtPath:[_basePath stringByAppendingPathComponent:@"Accounts"] attributes:nil] )
		{
			NSLog(@"Unable to create application support accounts folder");
		}
	}
	return self;
}

#pragma mark *** Path Utilities and Internals ***

- (NSString *)soundsFolderPath
{
	if( _basePath == nil )
		return nil;
	
	NSString *tmp = [_basePath stringByAppendingPathComponent:@"Sounds"];
	
	if( ! [NSFileManager ensureDirectoryExistsAtPath:tmp attributes:nil] )
	{
		NSLog(@"Unable to create application support sounds folder");
		return nil;
	}
	
	return tmp;
}

- (NSString *)pathForAccount:(XfireFriend *)user
{
	if( _basePath == nil )
		return nil;
	
	NSString *accountsFolder = [_basePath stringByAppendingPathComponent:@"Accounts"];
	if( ! [NSFileManager ensureDirectoryExistsAtPath:accountsFolder attributes:nil] )
	{
		NSLog(@"Unable to create application support accounts folder");
		return nil;
	}
	
	NSString *userFolder = [accountsFolder stringByAppendingPathComponent:[user userName]];
	if( ! [NSFileManager ensureDirectoryExistsAtPath:userFolder attributes:nil] )
	{
		NSLog(@"Unable to create application support user folder for %@",[user userName]);
		return nil;
	}
	
	return userFolder;
}

- (NSString *)pathForAccountContacts:(XfireFriend *)user
{
	NSString *tmp = [self pathForAccount:user];
	if( tmp == nil )
		return nil;
	
	return [tmp stringByAppendingPathComponent:@"Contacts.plist"];
}

- (NSString *)chatLogFolderPathForAccount:(XfireFriend *)account
{
	NSString *accountFolder = [self pathForAccount:account];
	if( accountFolder == nil )
		return nil;
	
	NSString *chatLogsFolder = [accountFolder stringByAppendingPathComponent:@"Chat Logs"];
	if( ! [NSFileManager ensureDirectoryExistsAtPath:chatLogsFolder attributes:nil] )
	{
		NSLog(@"Unable to create chat logs folder for %@",[account userName]);
		return nil;
	}
	
	return chatLogsFolder;
}

- (NSString *)nextChatLogPathForAccount:(XfireFriend *)account
{
	NSString *chatLogsFolder = [self chatLogFolderPathForAccount:account];
	if( chatLogsFolder == nil )
		return nil;
	
	NSString *fileName;
	NSString *formattedDate;
	BOOL found;
	int i;
	
	found = NO;
	i = 1;
	formattedDate = [self currentDateFormat];
	while( !found )
	{
		fileName = [chatLogsFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ %d.plist", formattedDate, i]];
		if( ! [[NSFileManager defaultManager] fileExistsAtPath:fileName] )
		{
			found = YES;
		}
		else
		{
			i++;
		}
	}
	
	return fileName;
}

- (BOOL)updateContact:(XfireFriend *)xfFriend inCache:(NSMutableDictionary *)cache
{
	BOOL contactsUpdated = NO;
	NSDictionary *contact = [cache objectForKey:[xfFriend userName]];
	NSMutableDictionary *d;
	if( contact )
	{
		// contact already known, just update fields as necessary
		d = [NSMutableDictionary dictionaryWithDictionary:contact];
	}
	else
	{
		// contact is not yet known, create a new dictionary for them
		d = [NSMutableDictionary dictionary];
		contactsUpdated = YES;
	}
	
	[d setObject:[NSNumber numberWithInt:[xfFriend userID]] forKey:kMFUserIDKey];
	if( [xfFriend userName] && (! [[xfFriend userName] isEqualToString:[d objectForKey:kMFUserNameKey]] ) )
	{
		[d setObject:[xfFriend userName] forKey:kMFUserNameKey];
		contactsUpdated = YES;
	}
	if( [xfFriend nickName] && (! [[xfFriend nickName] isEqualToString:[d objectForKey:kMFNickNameKey]] ) )
	{
		[d setObject:[xfFriend nickName] forKey:kMFNickNameKey];
		contactsUpdated = YES;
	}
	if( [xfFriend isOnline] )
	{
		[d setObject:[NSDate date] forKey:kMFLastSeenOnlineKey];
		contactsUpdated = YES;
	}
	if( [xfFriend isFriendOfFriend] )
	{
		[d setObject:[NSNumber numberWithBool:[xfFriend isFriendOfFriend]] forKey:kMFIsFriendOfFriendKey];
		contactsUpdated = YES;
	}
	
	if( contactsUpdated )
	{
		[cache setObject:d forKey:[xfFriend userName]];
	}
	
	return contactsUpdated;
}

#pragma mark *** Public Interfaces ***

- (void)updateContact:(XfireFriend *)xfFriend
{
	NSString *contactsPath = [self pathForAccountContacts:[[xfFriend session] loginIdentity]];
	if( contactsPath == nil )
		return;
	
	BOOL contactsUpdated = NO;
	
	NSMutableDictionary *contacts = [NSMutableDictionary dictionaryWithContentsOfFile:contactsPath];
	if( contacts == nil )
	{
		contacts = [NSMutableDictionary dictionary];
		contactsUpdated = YES;
	}
	
	if( [self updateContact:xfFriend inCache:contacts] )
		contactsUpdated = YES;
	
	if( contactsUpdated )
	{
		[contacts writeToFile:contactsPath atomically:YES];
	}
}

- (void)updateAllContacts:(XfireSession *)session
{
	NSString *contactsPath = [self pathForAccountContacts:[session loginIdentity]];
	if( contactsPath == nil )
		return;
	
	BOOL contactsUpdated = NO;
	
	NSMutableDictionary *contacts = [NSMutableDictionary dictionaryWithContentsOfFile:contactsPath];
	if( contacts == nil )
	{
		contacts = [NSMutableDictionary dictionary];
		contactsUpdated = YES;
	}
	
	NSArray *friends = [session friends];
	int i, cnt;
	cnt = [friends count];
	for( i = 0; i < cnt; i++ )
	{
		if( [self updateContact:[friends objectAtIndex:i] inCache:contacts] )
			contactsUpdated = YES;
	}
	
	if( contactsUpdated )
	{
		[contacts writeToFile:contactsPath atomically:YES];
	}
}

- (NSDictionary *)cachedInfoForContact:(XfireFriend *)xfFriend
{
	NSString *contactsPath = [self pathForAccountContacts:[[xfFriend session] loginIdentity]];
	if( contactsPath == nil )
		return nil;
	
	NSDictionary *contacts = [NSDictionary dictionaryWithContentsOfFile:contactsPath];
	if( contacts == nil )
		return nil;
	
	return [contacts objectForKey:[xfFriend userName]];
}

- (NSString *)currentDateFormat
{
	NSString *str;
	
	NSDateFormatter *dateFormatter;
	dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	[dateFormatter setDateFormat:@"yyyyMMdd"];
	str = [dateFormatter stringFromDate:[NSDate date]];
	[dateFormatter release];
	
	return str;
}

@end
