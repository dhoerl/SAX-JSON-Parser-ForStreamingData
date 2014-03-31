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

/**
 Allows the Parser to advise you of various events.
*/
@protocol JSONObjectExtractorProtocol <NSObject>

/**
 As the parser is fed data, after each chunk is processed all parsed objects
 are passed to the delegate.
 @param identifier - your object that uniquely identifies this particular stream
 @param results - an array with one or more objects in it, usually NSDictionaries
 @param progress - a dictionary with three keys in it, as defined above
 There are only a small number of cases that can result in failure. The best strategy
 for these are to log them to your web site and notify Sailthru with the exact message.
 @note There will always be at least one more object after these are sent.
 */
- (void)query:(id)identifier partialResults:(NSArray *)results perCentDone:(NSDictionary *)progress;

#ifdef MONGO_DB
/**
 The delegate must provide a translation for the string originally contained in a "new Date('...')" field.
 @param origDate - the date string enclosed by the single quoted new Date field
 @param returns - you can reformat as desired, or just return the original date.
 @note A sample translation is provided in the DHViewController code.
 */
- (NSString *)dateForDate:(NSString *)origDate;
#endif

@optional
/**
 When the final data fragment is processed, the delegate can either read the last object(s) or
 define this method, in which case it will be used to transfer the last object(s).
 @param identifier - your object that uniquely identifies this particular stream
 @param results - an array with one or more objects in it, usually NSDictionaries
 @param error - if the final chunk is poorly formed an error is sent, otherwise its nil.
 @note Using this method will drain the array of objects, so the delegate will never see any objects in the results property.
 */
- (void)query:(id)identifier lastResults:(NSArray *)results error:(NSError *)error;


@end
