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