/*******************************************************************
	FILE:		MFUIStrings.h
	
	COPYRIGHT:
		Copyright 2008-2009, the MacFire.org team.
		Use of this software is governed by the license terms
		indicated in the License.txt file (a BSD license).
	
	DESCRIPTION:
		Utility definitions for the getting ui.strings file strings.
	
	HISTORY:
		2008 05 26  Created.
*******************************************************************/

/* General */

#define MF_UISTR_OK             NSLocalizedStringFromTable(@"OK", @"ui", @"OK")
#define MF_UISTR_CANCEL         NSLocalizedStringFromTable(@"Cancel", @"ui", @"Cancel")
#define MF_UISTR_PROFILEURL     NSLocalizedStringFromTable(@"XfireProfileURL", @"ui", @"http://www.xfire.com/profile/%@")

/* Log in */

#define MF_UISTR_LOGINFAIL      NSLocalizedStringFromTable(@"MFLogInFailed", @"ui", @"Log in failed")
#define MF_UISTR_BADPASSWD      NSLocalizedStringFromTable(@"MFBadPassword", @"ui", @"Username/password combination was invalid.")
#define MF_UISTR_VERSIONOLD     NSLocalizedStringFromTable(@"MFVersionTooOld", @"ui", @"Client version is too old (current 1.%d).")

#define MF_UISTR_POSE           NSLocalizedStringFromTable(@"Pose", @"ui", @"Pose")
#define MF_UISTR_NEED_UNAME     NSLocalizedStringFromTable(@"MFNeedUsername", @"ui", @"No user name")
#define MF_UISTR_PROVIDE_UN     NSLocalizedStringFromTable(@"MFProvideUserName", @"ui", @"A user name must be provided.")
#define MF_UISTR_NEED_PWORD     NSLocalizedStringFromTable(@"MFNeedPassword", @"ui", @"No password")
#define MF_UISTR_PROVIDE_PW     NSLocalizedStringFromTable(@"MFProvidePassword",@"ui",@"A password must be provided.")

#define MF_UISTR_DISCONNECTED   NSLocalizedStringFromTable(@"MFDisconnected",@"ui",@"You have been disconnected.")
#define MF_UISTR_LOGGED_IN_ELSEWHERE NSLocalizedStringFromTable(@"MFLoggedInOnAnotherPC",@"ui",@"You have logged in on another PC.")
#define MF_UISTR_SERVER_HUNG_UP NSLocalizedStringFromTable(@"MFServerHungUp",@"ui",@"The Xfire server closed the connection.")
#define MF_UISTR_SERVER_STOPPED_RESPONDING NSLocalizedStringFromTable(@"MFServerStoppedResponding",@"ui",@"The Xfire server stopped responding.")
#define MF_UISTR_UNKNOWN_REASON NSLocalizedStringFromTable(@"MFUnknownReason",@"ui",@"An unexpected error occurred.")

/* Friend group names */

#define MF_UISTR_ONLINE_GROUP   NSLocalizedStringFromTable(@"MFFriendsOnlineGroupName", @"ui", @"Friends Online")
#define MF_UISTR_OFFLINE_GROUP  NSLocalizedStringFromTable(@"MFFriendsOfflineGroupName", @"ui", @"Friends Offline")
#define MF_UISTR_FOF_GROUP      NSLocalizedStringFromTable(@"MFFriendsOfFriendsGroupName", @"ui", @"Friends of Friends Playing")
#define MF_UISTR_UNKONWN_GROUP  NSLocalizedStringFromTable(@"MFUnknownFriendsGroupName", @"ui", @"<Unknown>")

/* Friend tooltips */

#define MF_UISTR_TTIP_UNAME     NSLocalizedStringFromTable(@"MFToolTipUserName", @"ui", @"Username: %@")
#define MF_UISTR_TTIP_UID       NSLocalizedStringFromTable(@"MFToolTipUserID", @"ui", @"User ID: %u")
#define MF_UISTR_TTIP_NNAME     NSLocalizedStringFromTable(@"MFToolTipNickName", @"ui", @"Nickname: %@")
#define MF_UISTR_TTIP_PLAYING   NSLocalizedStringFromTable(@"MFToolTipPlaying", @"ui", @"Playing: %@")
#define MF_UISTR_TTIP_GAMESRV   NSLocalizedStringFromTable(@"MFToolTipGameServer", @"ui", @"Game Server: %@")
#define MF_UISTR_TTIP_COMMONFR  NSLocalizedStringFromTable(@"MFToolTipCommonFriends", @"ui", @"Common Friends:")
#define MF_UISTR_TTIP_LASTSEEN  NSLocalizedStringFromTable(@"MFToolTipLastSeenOnline", @"ui", @"Last Seen Online: %@")
#define MF_UISTR_TTIP_NOW       NSLocalizedStringFromTable(@"MFToolTipNow", @"ui", @"Now")

/* Friend status */

#define MF_UISTR_OFFLINE        NSLocalizedStringFromTable(@"MFFriendStatusOffline", @"ui", @"(Offline)")
#define MF_UISTR_AFK            NSLocalizedStringFromTable(@"MFFriendStatusAFK", @"ui", @"(AFK) Away From Keyboard")

/* Chat window title */

#define MF_UISTR_CHAT_TITLE     NSLocalizedStringFromTable(@"MFChatWindowTitle", @"ui", @"%@ - Chat")

/* String prompt UI items */

#define MF_UISTR_CHANGE_NICK_PROMPT	    NSLocalizedStringFromTable(@"MFChangeNickPrompt", @"ui", @"Enter your new nickname:")
#define MF_UISTR_CHANGE_NICK_BUTTON     NSLocalizedStringFromTable(@"MFChangeNickButton", @"ui", @"Accept")
#define MF_UISTR_ADD_GROUP_PROMPT       NSLocalizedStringFromTable(@"MFAddFriendGroupPrompt", @"ui", @"Enter the new friend group's name:")
#define MF_UISTR_ADD_GROUP_BUTTON       NSLocalizedStringFromTable(@"MFAddFriendGroupButton", @"ui", @"Add")
#define MF_UISTR_RENAME_GROUP_PROMPT    NSLocalizedStringFromTable(@"MFRenameFriendGroupPrompt", @"ui", @"Friend group's new name:")
#define MF_UISTR_RENAME_GROUP_BUTTON    NSLocalizedStringFromTable(@"MFRenameFriendGroupButton", @"ui", @"Change")

/* Growl notification strings */

#define MF_UISTR_GROWL_ONLINE_MAJ  NSLocalizedStringFromTable(@"MFGrowlFriendCameOnlineMajor", @"ui", @"Xfire friend came online")
#define MF_UISTR_GROWL_ONLINE_MIN  NSLocalizedStringFromTable(@"MFGrowlFriendCameOnlineMinor", @"ui", @"%@ came online")
#define MF_UISTR_GROWL_OFFLINE_MAJ NSLocalizedStringFromTable(@"MFGrowlFriendWentOfflineMajor", @"ui", @"Xfire friend went offline")
#define MF_UISTR_GROWL_OFFLINE_MIN NSLocalizedStringFromTable(@"MFGrowlFriendWentOfflineMinor", @"ui", @"%@ went offline")
#define MF_UISTR_GROWL_CHAT_MAJ    NSLocalizedStringFromTable(@"MFGrowlFriendSentMessageMajor", @"ui", @"%@ sent a message")
#define MF_UISTR_GROWL_CHAT_MIN    NSLocalizedStringFromTable(@"MFGrowlFriendSentMessageMinor", @"ui", @"Message: %@")

/* Remove Friend, Group */

#define MF_UISTR_REMOVE_GROUP_PROMPT    NSLocalizedStringFromTable(@"MFRemoveFriendGroupPrompt", @"ui", @"Do you want to remove friend group \"%@\"?")
#define MF_UISTR_REMOVE_GROUP_BUTTON    NSLocalizedStringFromTable(@"MFRemoveFriendGroupButton", @"ui", @"Remove Group")
#define MF_UISTR_REMOVE_FRIEND_PROMPT   NSLocalizedStringFromTable(@"MFRemoveFriendPrompt", @"ui", @"Do you want to remove friend \"%@\"?")
#define MF_UISTR_REMOVE_FRIEND_BUTTON   NSLocalizedStringFromTable(@"MFRemoveFriendButton", @"ui", @"Remove Friend")

