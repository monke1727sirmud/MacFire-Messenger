
COM=gcc -Wall -fobjc-exceptions

##############################################

all:	extract genit testit

extract:	extract.o MFDataScanner.o MFWin32DLLResourceFile.o
	$(COM) -framework Cocoa extract.o MFDataScanner.o MFWin32DLLResourceFile.o -o extract

genit:	genit.o NSData_XfireAdditions.o MFDataEmitter.o MFDataScanner.o
	$(COM) -framework Cocoa -lz genit.o NSData_XfireAdditions.o MFDataEmitter.o MFDataScanner.o -o genit

testit: testit.o NSData_XfireAdditions.o MFDataScanner.o MFDataEmitter.o
	$(COM) -framework Cocoa -lz testit.o NSData_XfireAdditions.o MFDataEmitter.o MFDataScanner.o -o testit

##############################################

extract.o:	extract.m MFWin32DLLResourceFile.h
	$(COM) -c extract.m

genit.o:	genit.m NSData_XfireAdditions.h
	$(COM) -c genit.m

testit.o:	testit.m NSData_XfireAdditions.h
	$(COM) -c testit.m

MFDataScanner.o:	MFDataScanner.m MFDataScanner.h
	$(COM) -c MFDataScanner.m

MFWin32DLLResourceFile.o: MFWin32DLLResourceFile.m MFWin32DLLResourceFile.h MFDataScanner.h
	$(COM) -c MFWin32DLLResourceFile.m

NSData_XfireAdditions.o:	NSData_XfireAdditions.m NSData_XfireAdditions.h MFDataEmitter.h
	$(COM) -c NSData_XfireAdditions.m

MFDataEmitter.o:	MFDataEmitter.m MFDataEmitter.h
	$(COM) -c MFDataEmitter.m

