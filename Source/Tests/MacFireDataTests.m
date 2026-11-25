#import <XCTest/XCTest.h>

#import "MFDataEmitter.h"
#import "MFDataScanner.h"
#import "NSData_MFAdditions.h"

@interface MacFireDataTests : XCTestCase
@end

@implementation MacFireDataTests

- (void)testEmitterAndScannerRoundTripPrimitives
{
	unsigned char rawBytes[] = { 0xDE, 0xAD };
	NSData *payload = [NSData dataWithBytes:rawBytes length:sizeof(rawBytes)];

	MFDataEmitter *emitter = [MFDataEmitter emitter];
	[emitter emitUInt8:0x12];
	[emitter emitUInt16:0x3456];
	[emitter emitUInt32:0x789ABCDE];
	[emitter emitString:@"hello"];
	[emitter emitData:payload];

	NSData *encoded = [emitter data];
	XCTAssertEqual([encoded length], (NSUInteger)(1 + 2 + 4 + 2 + 5 + 4 + 2));

	MFDataScanner *scanner = [MFDataScanner scannerWithData:encoded];
	XCTAssertEqual([scanner scanUInt8], (UInt8)0x12);
	XCTAssertEqual([scanner scanUInt16], (UInt16)0x3456);
	XCTAssertEqual([scanner scanUInt32], (UInt32)0x789ABCDE);
	XCTAssertEqualObjects([scanner scanString], @"hello");
	XCTAssertEqualObjects([scanner scanData], payload);
}

- (void)testEmptyStringAndDataRoundTrip
{
	MFDataEmitter *emitter = [MFDataEmitter emitter];
	[emitter emitString:@""];
	[emitter emitData:[NSData data]];

	MFDataScanner *scanner = [MFDataScanner scannerWithData:[emitter data]];
	XCTAssertEqualObjects([scanner scanString], @"");
	XCTAssertEqual([[scanner scanData] length], (NSUInteger)0);
}

- (void)testScannerRaisesWhenBufferIsShort
{
	unsigned char oneByte[] = { 0x01 };
	MFDataScanner *scanner = [MFDataScanner scannerWithData:[NSData dataWithBytes:oneByte length:1]];
	XCTAssertThrowsSpecificNamed([scanner scanUInt32], NSException, @"ScannerException");
}

- (void)testEmitterRejectsOversizedString
{
	NSString *huge = [@"" stringByPaddingToLength:65536 withString:@"a" startingAtIndex:0];
	MFDataEmitter *emitter = [MFDataEmitter emitter];
	XCTAssertThrowsSpecificNamed([emitter emitString:huge], NSException, @"MFDataEmitterException");
}

- (void)testZlibRoundTrip
{
	NSData *original = [@"MacFire packet data, compressed" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *compressed = [original compressedZlibData];
	XCTAssertNotNil(compressed);
	XCTAssertGreaterThan([compressed length], (NSUInteger)0);
	XCTAssertEqualObjects([compressed decompressedZlibData], original);
}

- (void)testArchiveRoundTrip
{
	NSString *contents = @"archived contents";
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MacFireTests-archive.txt"];
	BOOL wrote = [contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	XCTAssertTrue(wrote);

	@try
	{
		NSData *archive = [NSData archivedDataWithFiles:[NSArray arrayWithObject:path]];
		XCTAssertNotNil(archive);

		NSArray *files = [archive unarchivedFiles];
		XCTAssertEqual([files count], (NSUInteger)1);

		id archivedFile = [files objectAtIndex:0];
		XCTAssertEqualObjects([archivedFile valueForKey:@"path"], path);
		XCTAssertEqualObjects([archivedFile valueForKey:@"data"],
			[contents dataUsingEncoding:NSUTF8StringEncoding]);
	}
	@finally
	{
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	}
}

@end
