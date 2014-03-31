//
//  SAX_JSON_Parser_ForStreamingDataTests.m
//  SAX-JSON-Parser-ForStreamingDataTests
//
//  Created by David Hoerl on 2/25/14.
//
//

#import <XCTest/XCTest.h>

#import "JSONObjectExtractor.h"


#define LOOPS		1000000
#define CHUNK_SIZE	256

#ifdef MONGO_DB
#define FILE_NAME @"JSON+Mongo"
#else
#define FILE_NAME @"JSON"
#endif

@interface SAX_JSON_Parser_ForStreamingDataTests : XCTestCase <JSONObjectExtractorProtocol>

@end

@implementation SAX_JSON_Parser_ForStreamingDataTests
{
	NSArray *preComputedObjects;
	NSMutableArray *parsedObjects;

	NSTimer *t;
	NSUInteger offset;
	
	NSUInteger curCount;
	float progress;
	
	NSData *data;
	
	JSONObjectExtractor *json;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

	NSString *path = [[NSBundle mainBundle] pathForResource:FILE_NAME ofType:@"txt"];
	assert(path);
	
	data = [NSData dataWithContentsOfFile:path];
	assert(data);
	assert([JSONObjectExtractor isArray:data]);

	__autoreleasing NSError *error;
	preComputedObjects = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	assert([preComputedObjects isKindOfClass:[NSArray class]]);
	NSUInteger count = [preComputedObjects count];
	assert(count);
	
	parsedObjects = [NSMutableArray arrayWithCapacity:count];
	
	sranddev();
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test1
{
	for(NSUInteger i=0; i<LOOPS; ++i) {
		json = [[JSONObjectExtractor alloc] initWithDelegate:self];
		json.totalReceiveSize = [data length];
		json.identifier = @"Howdie!";
	
		curCount	= 0;
		progress	= 0;
		offset		= 0;

		NSUInteger totalLen = [data length];
		while(YES)
		{
			NSUInteger readNow = totalLen - offset;
			
			if(readNow > CHUNK_SIZE) {
				readNow = (rand() % (CHUNK_SIZE - 1)) + 1;	// avoid 0
			}
			
			NSUInteger newOffset = offset + readNow;
			if(readNow) {
//NSLog(@"SEND %d", readNow);
				json.currentReceiveSize = newOffset;
				[json addData:[data subdataWithRange:NSMakeRange(offset, readNow)]];
			}
			offset = newOffset;
			
			if(offset == totalLen) {
				// processed everything
				[json addData:nil];
				
				[self query:json.identifier lastResults:json.objects error:nil];
				json = nil;
			} else {
				break;
			}
		}
	}
}


- (void)query:(id)identifier partialResults:(NSArray *)results perCentDone:(NSDictionary *)pDict;
{
//NSLog(@"QUERY P");
	assert([results isKindOfClass:[NSArray class]]);
	float prog = [pDict[kPercentComplete] floatValue];
	// NSLog(@"pDict: %@ progress=%f", pDict, prog);
	
	//dispatch_async(dispatch_get_main_queue(), ^
		{
			[parsedObjects addObjectsFromArray:results];

			curCount += [results count];
			progress = prog;
			
			//[self updateUI];
		} // );
}

- (void)query:(id)identifier lastResults:(NSArray *)results error:(NSError *)error
{
//NSLog(@"QUERY F");
	//dispatch_async(dispatch_get_main_queue(), ^
		{
			[parsedObjects addObjectsFromArray:results];

			curCount += [results count];
			progress = 1;
			
			//[self updateUI];
			
			XCTAssertTrue([preComputedObjects count], @"Empty array");
			XCTAssertTrue([preComputedObjects isEqualToArray:parsedObjects], @"Arrays were not equal!!!");
			
			//dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^
				{
					t = nil;
					//[self updateUI];
					
					[parsedObjects removeAllObjects];
				} //);
		} //);
}

@end
