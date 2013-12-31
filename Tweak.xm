#import <MediaPlayer/MediaPlayer.h>
#import <MusicUI/MusicLyricsView.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import "LyricalizerHeaders.h"

static MPMediaItem *lastItem = nil;
static NSString *baseURL = @"http://lyricalizer.ac3xx.com/";
static BOOL hasTapped = NO;

static NSString *NSStringURLEncode(NSString *string) {
	return (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]\" "), kCFStringEncodingUTF8);
}


%hook MusicLyricsView

- (void)setText:(NSString*)text {
	%log;
	%orig;
}

%end


%hook MusicNowPlayingViewController

// This is called when the user taps the view to view the lyrics. Replaced with custom handler.

%new
- (void)loadLyricView {
	Class $MusicLyricsView = objc_getClass("MusicLyricsView");
	UIView *cView = MSHookIvar<UIView*>(self, "_contentView");
	MusicLyricsView *lyricsView = MSHookIvar<MusicLyricsView*>(self, "_lyricsView");
	MPAVItem *item = MSHookIvar<MPAVItem*>(self, "_item");
	MPMediaItem *mediaItem = MSHookIvar<MPMediaItem*>(item, "_mediaItem");

	for (UIView *subv in cView.subviews) {
		if ([subv isKindOfClass:[MusicLyricsView class]])
			lyricsView = (MusicLyricsView*)subv;
	}

	if (!hasTapped && lyricsView && !lyricsView.hidden)
		[lyricsView setHidden:YES animated:YES];

	if (!hasTapped)
		return;

	if (lyricsView && lastItem && lastItem == mediaItem)
		[lyricsView setHidden:!lyricsView.hidden animated:YES];
	else {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *song = [[mediaItem valueForProperty:MPMediaItemPropertyTitle] retain];
    	NSString *artist = ([mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist])?:[mediaItem valueForProperty:MPMediaItemPropertyArtist];
    	[artist retain];
    	if (!song) song=@"";
    	if (!artist) artist=@"";
		lastItem = [mediaItem retain];
		CGRect frame = cView.frame;
		if (!lyricsView) {
			lyricsView = [[$MusicLyricsView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
			[lyricsView setHidden:YES animated:NO];
		}
		if ([item lyrics] && ![[item lyrics] isEqualToString:@""])
			[lyricsView setText:[item lyrics]];
		else if ([defaults objectForKey:[NSString stringWithFormat:@"%@-%@", song, artist]])
			[lyricsView setText:[defaults objectForKey:[NSString stringWithFormat:@"%@-%@", song, artist]]];
		else {
			[lyricsView setText:@"Fetching lyrics..."];
			dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
		    dispatch_async(queue, ^{
		    	NSString *format = [NSString stringWithFormat:@"?song=%@&artist=%@&uuid=music", NSStringURLEncode(song), NSStringURLEncode(artist)];
		    	NSString *url = [NSString stringWithFormat:@"%@%@", baseURL, format];

		    	// Send a synchronous request
				NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
				NSURLResponse * response = nil;
				NSError * error = nil;
				NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest
				                                          returningResponse:&response
				                                                      error:&error];
				NSString *lyrs = @"An error occured.";
				if (error == nil)
				{
				    // Parse data here
					lyrs = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
					lyrs = [lyrs stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
					if([lyrs rangeOfString:@"No lyrics found."].location == NSNotFound)
						[defaults setObject:lyrs forKey:[NSString stringWithFormat:@"%@-%@", song, artist]];
						[defaults synchronize];
				}

		        dispatch_sync(dispatch_get_main_queue(), ^{
		            [lyricsView setText:lyrs];
		        });
		    });
		}

		[lyricsView setHidden:NO animated:YES];

		[cView addSubview:lyricsView];
	}
}

- (void)_tapAction:(id)arg1 {
	hasTapped = !hasTapped;
	[self loadLyricView];
}

- (void)_updateTitles {
	[self loadLyricView];
	%orig;
}


%end


// Spotify integration, finally!
// iPhone/iPod Touch only for the moment
// Because Spotify's iPad UI doesn't work well with lyrics


%group SpotifyPhone


static UITextView *lyricsView = nil;
%hook ImageSlideView

- (void)reloadData {
	%orig;
	[[self delegate] reloadLyrics];
}

%end


%hook NowPlayingViewControllerIPhone

%new
- (void)reloadLyrics {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *song = [[self currentTrack] name];
	NSString *artist = [[[self currentTrack] artist] name];
	if ([defaults objectForKey:[NSString stringWithFormat:@"%@-%@", song, artist]])
		[lyricsView setText:[defaults objectForKey:[NSString stringWithFormat:@"%@-%@", song, artist]]];
	else {
		[lyricsView setText:@"Fetching lyrics..."];
		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
	    dispatch_async(queue, ^{
	    	NSString *format = [NSString stringWithFormat:@"?song=%@&artist=%@&uuid=spotify", NSStringURLEncode(song), NSStringURLEncode(artist)];
	    	NSString *url = [NSString stringWithFormat:@"%@%@", baseURL, format];

	    	// Send a synchronous request
			NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
			NSURLResponse * response = nil;
			NSError * error = nil;
			NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest
			                                          returningResponse:&response
			                                                      error:&error];
			NSString *lyrs = @"An error occured.";
			if (error == nil)
			{
			    // Parse data here
				lyrs = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				lyrs = [lyrs stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
				if([lyrs rangeOfString:@"No lyrics found."].location == NSNotFound)
					[defaults setObject:lyrs forKey:[NSString stringWithFormat:@"%@-%@", song, artist]];
					[defaults synchronize];
			}

	        dispatch_sync(dispatch_get_main_queue(), ^{
	        	if ([[[self currentTrack] name] isEqualToString:song]&&[[[[self currentTrack] artist] name] isEqualToString:artist])
		            [lyricsView setText:lyrs];
	        });
	    });
	}
}

%new
- (void)imageSlideViewWasTapped {
	if ([[self infoPanel] alpha]==0 && [lyricsView alpha]==0) {
		[self reloadLyrics];
		[lyricsView setAlpha:1];
	} else if ([lyricsView alpha]==1) {
		[lyricsView setAlpha:0];
		[[self infoPanel] setAlpha:1];
	} else {
		[[self infoPanel] setAlpha:0];
	}
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	if (!lyricsView) {
		lyricsView = [[UITextView alloc] initWithFrame:[(UIView*)[self infoPanel] frame]];
		[lyricsView setAlpha:0];
		[lyricsView setUserInteractionEnabled:YES];
		[lyricsView setEditable:NO];
		[lyricsView setTextColor:[UIColor whiteColor]];
		[lyricsView setTextAlignment:NSTextAlignmentCenter];
		[lyricsView setFont:[UIFont systemFontOfSize:14.0f]];
		[lyricsView setTextContainerInset:UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f)];
		[lyricsView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.8f]];
		UITapGestureRecognizer *tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lyricsViewTapped:)];
		[tapRec setNumberOfTapsRequired:1];
		[lyricsView addGestureRecognizer:tapRec];
	}
	UIView *imgView = MSHookIvar<UIView*>(self, "artImageView");
	[imgView addSubview:lyricsView];
}

- (void)viewDidDisappear:(BOOL)animated {
	%orig;
	[lyricsView setAlpha:0];
}

%new
- (void)lyricsViewTapped:(id)sender {
	[self imageSlideViewWasTapped];
}

- (void)toggleInfoPanel {
	if ([lyricsView alpha]==1) {
		[lyricsView setAlpha:0];
	}
	%orig;
}


%end

%end


%ctor {
	size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char*)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    %init
    if ([platform rangeOfString:@"iPad"].location == NSNotFound)
		%init(SpotifyPhone)
}
