//
//  DHViewController.m
//  SAX-JSON-Parser-ForStreamingData
//
//  Created by David Hoerl on 2/25/14.
//  Copyright 2014 David Hoerl
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DHViewController.h"

#import "JSONObjectExtractor.h"

#define CHUNK_SIZE	256

@interface DHViewController () <JSONObjectExtractorProtocol>
@property (strong, nonatomic) IBOutlet UIButton *runButton;
@property (strong, nonatomic) IBOutlet UIProgressView *progressBar;
@property (strong, nonatomic) IBOutlet UILabel *countLabel;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@end

@implementation DHViewController
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.


	NSString *path = [[NSBundle mainBundle] pathForResource:@"JSON" ofType:@"txt"];
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

	[self updateUI];
	
	sranddev();
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)runAction:(id)sender
{
	json = [[JSONObjectExtractor alloc] initWithDelegate:self];
	json.totalReceiveSize = [data length];
	json.identifier = @"Howdie!";

	t = [NSTimer scheduledTimerWithTimeInterval:.001f target:self selector:@selector(timer:) userInfo:nil repeats:YES];
	[self updateUI];
}

- (void)timer:(NSTimer *)timer
{
	NSUInteger totalLen = [data length];
	NSUInteger readNow = totalLen - offset;
	
	if(readNow > CHUNK_SIZE) {
		readNow = (rand() % (CHUNK_SIZE - 1)) + 1;	// avoid 0
	}
	
	NSUInteger newOffset = offset + readNow;
	if(readNow) {
NSLog(@"SEND %d", readNow);
		json.currentReceiveSize = newOffset;
		[json addData:[data subdataWithRange:NSMakeRange(offset, readNow)]];
	}
	offset = newOffset;
	
	if(offset == totalLen) {
		// processed everything
		[json addData:nil];
		
		[self query:json.identifier lastResults:json.objects error:nil];
		json = nil;
		[timer invalidate];
	}
}

- (void)updateUI
{
	BOOL isRunning = t ? YES : NO;
	BOOL animated = NO;

	if(isRunning) {
		[_spinner startAnimating];
		_runButton.enabled = NO, _runButton.alpha = 0.5f;
		animated = YES;
	} else {
		curCount	= 0;
		progress	= 0;
		offset		= 0;
		[_spinner stopAnimating];
		_runButton.enabled = YES, _runButton.alpha = 1;
	}
	[_progressBar setProgress:progress animated:animated];
	_countLabel.text = [NSString stringWithFormat:@"%tu", curCount];
}

- (void)query:(id)identifier partialResults:(NSArray *)results perCentDone:(NSDictionary *)pDict;
{
//NSLog(@"QUERY P");
	assert([results isKindOfClass:[NSArray class]]);
	float prog = [pDict[kPercentComplete] floatValue];
	// NSLog(@"pDict: %@ progress=%f", pDict, prog);
	
	dispatch_async(dispatch_get_main_queue(), ^
		{
			[parsedObjects addObjectsFromArray:results];

			curCount += [results count];
			progress = prog;
			
			[self updateUI];
		} );
}

- (void)query:(id)identifier lastResults:(NSArray *)results error:(NSError *)error
{
//NSLog(@"QUERY F");
	dispatch_async(dispatch_get_main_queue(), ^
		{
			[parsedObjects addObjectsFromArray:results];

			curCount += [results count];
			progress = 1;
			
			[self updateUI];
			
			BOOL ret = [preComputedObjects isEqualToArray:parsedObjects];
			assert(ret);
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^
				{
					t = nil;
					[self updateUI];
					
					[parsedObjects removeAllObjects];
				} );
		} );
}

@end
