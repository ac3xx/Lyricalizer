/*
 * Lyricalizer              *
 * v1.3.4                   *
 * (c) James Long 2011-2014 *
*/

#import "LYManager.h"

@implementation LYManager

static NSString *NSStringURLEncode(NSString *string) {
	return (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]\" "), kCFStringEncodingUTF8);
}

+ (LYManager*)sharedInstance {
	static LYManager *sharedInstance = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[LYManager alloc] init];
	});
	return sharedInstance;
}

- (id)init {
	if (self = [super init]) {
		NSFileManager *manager = [NSFileManager defaultManager];
		if ([manager fileExistsAtPath:LYRICS_PATH])
			lyricsDict = [[NSDictionary dictionaryWithContentsOfFile:LYRICS_PATH] mutableCopy];
		else
			lyricsDict = [NSMutableDictionary new];
	}
	return self;
}

- (void)saveLyrics {
	NSDictionary *toSave = [lyricsDict copy];
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir;
	BOOL dirExists = [manager fileExistsAtPath:LYRICS_DIR isDirectory:&isDir];
	if (!dirExists || !isDir) {
		BOOL ret = [manager createDirectoryAtPath:LYRICS_DIR withIntermediateDirectories:YES attributes:nil error:nil];
		// if (!ret) return;
	}
	[toSave writeToFile:LYRICS_PATH atomically:YES];
}

- (void)addCachedLyric:(NSString*)lyrics withSong:(NSString*)name andArtist:(NSString*)artist {
	[lyricsDict setObject:lyrics forKey:LYFORMAT(name, artist)];
	[self saveLyrics];
}

- (NSDictionary*)cachedLyricsWithSong:(NSString*)song andArtist:(NSString*)artist {
	if ([lyricsDict objectForKey:LYFORMAT(song, artist)])
		return @{@"lyrics":[lyricsDict objectForKey:LYFORMAT(song, artist)],@"song":song,@"artist":artist};
	return nil;
}

- (void)fetchLyricsWithSong:(NSString*)song andArtist:(NSString*)artist andTarget:(id)target andSelector:(SEL)selector {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
	NSDictionary *cachedLyrics = [self cachedLyricsWithSong:song andArtist:artist];
	if (cachedLyrics && [target respondsToSelector:selector])
		[target performSelectorOnMainThread:selector withObject:cachedLyrics waitUntilDone:NO];
	if (!cachedLyrics) {
			// Fetch lyrics in the background
			NSString *queryString = [NSString stringWithFormat:@"/metrolyrics/%@/%@", NSStringURLEncode(artist), NSStringURLEncode(song)];
			NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", LYRICS_API, queryString]];
			NSLog(@"Requesting %@", requestURL);

			NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];
			NSURLResponse *response = nil;
			NSError *error = nil;

			NSData *respData = [NSURLConnection sendSynchronousRequest:request
												returningResponse:&response
												error:&error];
			// NSString *respString = @"No lyrics found.";
			if (!error) {
				NSDictionary *respDict = [NSJSONSerialization JSONObjectWithData:respData options:NSJSONReadingMutableContainers error:nil];
				NSLog(@"%@", respDict);
				// respString = [[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding];
				// respString = [respString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
				// [respString release];
				// if ([respString rangeOfString:@"No lyrics found"].location == NSNotFound)
				// 	[self addCachedLyric:respString withSong:song andArtist:artist];
				if (![respDict objectForKey:@"statusCode"] && [respDict objectForKey:@"lyrics"])
					[self addCachedLyric:[respDict objectForKey:@"lyrics"] withSong:song andArtist:artist];
				NSLog(@"resp %@", respDict);

				if ([target respondsToSelector:selector]) {
					NSLog(@"Responds");
					[target performSelectorOnMainThread:selector withObject:respDict waitUntilDone:NO];
				}
			}
		}
	});
}


@end