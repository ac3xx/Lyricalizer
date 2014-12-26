/*
 * Lyricalizer              *
 * v1.3.4                   *
 * (c) James Long 2011-2014 *
*/

#define LYRICS_API @"http://gitlab.evolse.com:3000"
#define LYRICS_DIR @"/Library/Application Support/Lyricalizer/"
#define LYRICS_PATH [NSString stringWithFormat:@"%@Lyrics.cache", LYRICS_DIR]
#define LYFORMAT(name, artist) [NSString stringWithFormat:@"%@-%@", name, artist]

@interface LYManager : NSObject {
	NSMutableDictionary *lyricsDict;
}

+ (LYManager*)sharedInstance;
- (void)fetchLyricsWithSong:(NSString*)song andArtist:(NSString*)artist andTarget:(id)target andSelector:(SEL)selector;

@end