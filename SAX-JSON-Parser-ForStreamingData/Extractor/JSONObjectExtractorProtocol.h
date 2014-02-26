//
//  JSONObjectExtractorProtocol.h
//  DB_Lookup
//
//  Created by David Hoerl on 2/25/14.
//
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

// Used in a returned dictionary object when parsing fails
#define kHOErrorKey			@"ErrorKey with more junk to be sure its unique  "
#define kHOErrorText		@"ErroredText"

// Progress dictionary
#define kCurReceiveSize		@"currentReceiveSize"
#define kTotReceiveSize		@"totalReceiveSize"
#define kPercentComplete	@"percentComplete"

@protocol JSONObjectExtractorProtocol <NSObject>

- (void)query:(id)identifier partialResults:(NSArray *)results perCentDone:(NSDictionary *)progress;

@optional
- (void)query:(id)identifier lastResults:(NSArray *)results error:(NSError *)error;


@end
