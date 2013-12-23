#import <MediaPlayer/MediaPlayer.h>
#import <MusicUI/MusicLyricsView.h>
#import <MobileGestalt.h>

static id * lastItem = nil;
static NSString *baseURL = @"http://lyricalizer.ac3xx.com/";

static NSString *NSStringURLEncode(NSString *string) {
    return (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
}

static NSString *uniqueIdentifier() {
    CFPropertyListRef value = MGCopyAnswer(kMGUniqueDeviceID);
	NSString *udid = (NSString*)value;
	CFRelease(value);

    return udid;
}

%hook MusicNowPlayingViewController

// This is called when the user taps the view to view the lyrics. Replaced with custom handler.

- (void)_tapAction:(id)arg1 {
	Class $MusicLyricsView = objc_getClass("MusicLyricsView");
	UIView *cView = MSHookIvar<UIView*>(self, "_contentView");
	MusicLyricsView *lyricsView = MSHookIvar<MusicLyricsView*>(self, "_lyricsView");
	id item = MSHookIvar<id>(self, "_item");
	id mediaItem = MSHookIvar<id>(item, "_mediaItem");
	for (UIView *subv in cView.subviews) {
		if ([subv isKindOfClass:[MusicLyricsView class]])
			lyricsView = (MusicLyricsView*)subv;
	}

	if (lastItem && lastItem != &mediaItem)
		lyricsView = nil;

	if (lyricsView)
		[lyricsView setHidden:!lyricsView.hidden animated:YES];
	else {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *song = [mediaItem valueForProperty:MPMediaItemPropertyTitle];
    	NSString *artist = ([mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist])?:[mediaItem valueForProperty:MPMediaItemPropertyArtist];
		lastItem = &mediaItem;
		CGRect frame = cView.frame;
		lyricsView = [[$MusicLyricsView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
		[lyricsView setHidden:YES animated:NO];
		if ([item lyrics] && ![[item lyrics] isEqualToString:@""])
			[lyricsView setText:[item lyrics]];
		else if ([defaults objectForKey:[NSString stringWithFormat:@"%@-%@", song, artist]])
			[lyricsView setText:[defaults objectForKey:[NSString stringWithFormat:@"%@-%@", song, artist]]];
		else {
			[lyricsView setText:@"Fetching lyrics..."];
			dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
		    dispatch_async(queue, ^{
		    	NSString *format = [NSString stringWithFormat:@"?song=%@&artist=%@&uuid=%@", NSStringURLEncode(song), NSStringURLEncode(artist), uniqueIdentifier()];
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
		
		[cView addSubview:(UIView*)lyricsView];
		[lyricsView release];
	}
}

%end


// Spotify integration, finally!
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

- (void)imageSlideViewWasTapped {
	UIView *imgView = MSHookIvar<UIView*>(self, "artImageView");

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

- (void)viewDidAppear:(BOOL)arg1 {
	%orig;
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
	UIView *imgView = MSHookIvar<UIView*>(self, "artImageView");
	[imgView addSubview:lyricsView];
}

%new
- (void)lyricsViewTapped:(id)sender {
	[self imageSlideViewWasTapped];
}

- (void)toggleInfoPanel {
	%log;
	if ([lyricsView alpha]==1) {
		[lyricsView setAlpha:0];
	}
	%orig;
}

%end