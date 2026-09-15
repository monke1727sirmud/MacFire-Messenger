Code Read-me
1 Jan 2009

Overview:

The main code for the MacFire application is covered by the Xcode project.

Some utilities are also provided to help create some support data files used by MacFire.
They are currently built using a command-line approach for simplicity.  They are built
from Terminal by using "make".


Special Folders:

Documentation/   Contains Release notes and a sub-folder containing my understanding
                 of the Xfire network protocol (HTML format).  Both are continually
                 updated.

Frameworks/      Contains external frameworks (as of this writing just the Growl client
                 framework) used by MacFire.

Games/           Contains the Games.plist file used by MacFire, the packaged icons file,
                 and code for a utility used to help build the Games.plist file using
                 the xfire_games.ini file and the old "Mac Games.plist" file.

                 The makefile creates an executable "build_games", which assumes the
                 data files are in the same folder ("xfire_games.ini" and "Mac
                 Games.plist").  It creates a "Games new.plist" file that can be
                 compared and re-named to "Games.plist" when you're satisfied.

Icons/           This contains code for utility programs used ultimately to create the
                 packaged "icons.mar" file in the "Games" folder.  Use "make" to build
                 the "extract" and "genit" programs.  These programs are described in
                 more detail later.

Source/          The main source code for the MacFire application.


Icon File Generation:

Follow these steps to create an updated icons.mar archive file.  This uses the utilities
in the "Icons" folder and requires a working official Xfire client installation.

  0. Every time Xfire runs, it checks for and downloads updated game definition and icon
     files.  Each new Xfire client version includes an updated "icons.dll" file which
     contains all of the icons (in Microsoft ICO format).  So, make sure you have run
     Xfire and get the recent game icons and xfire_games.ini.

  1. Copy the latest "icons.dll" file from Xfire installation into the "Icons" folder of
     the MacFire source code.  I usually name the file to be consistent with the
     associated Xfire release (e.g. "icons 1.101.dll").

  2. Open a Terminal window and navigate to the "Icons" folder.  Type "make" if you have
     not yet compiled the tools.

  3. In Terminal, type "extract icons\ 1.101.dll" or whatever the DLL file name is.  This
     will create a new folder "icons 1.101.dll_icons" with all the icons extracted from it.
     It also uses NSImage to check whether the file is properly formatted.  One icon always
     seems to be corrupted (XF_EVILG.ICO) and is not included.  NSImage can't use it at
     runtime in MacFire anyway.

  4. In the Xfire installation folder, you will also need to copy any and all files from the
     separate "icons" folder over to the new "icons 1.101.dll_icons" folder in the MacFire
     source code folder.  Each file needs to be re-named to have the prefix "XF_" in front
     of the file name (like all the other files).

  5. In Terminal, make sure you are in the "icons 1.101.dll_icons" folder.  Enter the
     following command to create the icons.mar file in this folder:

          ../genit *.ICO *.ico

  6. You can now copy the new "icons.mar" file to wherever you need it (e.g. the MacFire
     source codes' "Games" folder).

  7. While you're at it, if the Xfire installation's xfire_games.ini file is newer than the
     one used to generate Games.plist (there is a version number in it), you should generate
     the new Games.plist file (see the discussion above for the Games folder).

