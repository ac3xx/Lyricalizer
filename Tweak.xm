/*
 * Lyricalizer              *
 * v1.3.4                   *
 * (c) James Long 2011-2014 *
*/

#import <MediaPlayer/MediaPlayer.h>
#import <MusicUI/MPULyricsView.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import "LyricalizerHeaders.h"
#import "LYManager.h"

#define IOS_80 (kCFCoreFoundationVersionNumber >= 1129.15)

static MPMediaItem *lastItem = nil;
static BOOL hasTapped = NO;




%group iOS7
%hook MusicNowPlayingViewController

// This is called when the user taps the view to view the lyrics. Replaced with custom handler.

%new
- (void)lyricsReturned:(NSDictionary*)lyricsDict {
	Class $MusicLyricsView = objc_getClass("MusicLyricsView");
	MPAVItem *item = MSHookIvar<MPAVItem*>(self, "_item");
	MPMediaItem *mediaItem = MSHookIvar<MPMediaItem*>(item, "_mediaItem");
	NSString *song = [mediaItem valueForProperty:MPMediaItemPropertyTitle];
	NSString *artist = ([mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist])?:[mediaItem valueForProperty:MPMediaItemPropertyArtist];
	NSArray *lyrArray = [lyricsDict objectForKey:@"lyrics"];
	if (lyrArray && (![artist isEqualToString:[lyricsDict objectForKey:@"artist"]] && ![song isEqualToString:[lyricsDict objectForKey:@"song"]])) return;

	NSString *lyrics = [lyrArray componentsJoinedByString:@"\n"];
	if (!lyrics) lyrics = @"No lyrics found.";

	id lyricsView = MSHookIvar<id>(self, "_lyricsView");
	UIView *cView = MSHookIvar<UIView*>(self, "_contentView");

	for (UIView *subv in cView.subviews) {
		if ([subv isKindOfClass:[$MusicLyricsView class]])
			lyricsView = subv;
	}

	[lyricsView setText:lyrics];
	[lyricsView setHidden:NO animated:YES];
}

%new
- (void)loadLyricView {
	Class $MusicLyricsView = objc_getClass("MusicLyricsView");
	UIView *cView = MSHookIvar<UIView*>(self, "_contentView");
	id lyricsView = MSHookIvar<id>(self, "_lyricsView");
	MPAVItem *item = MSHookIvar<MPAVItem*>(self, "_item");
	MPMediaItem *mediaItem = MSHookIvar<MPMediaItem*>(item, "_mediaItem");

	for (UIView *subv in cView.subviews) {
		if ([subv isKindOfClass:[$MusicLyricsView class]])
			lyricsView = subv;
	}

	if (!hasTapped && lyricsView && ![lyricsView isHidden])
		[lyricsView setHidden:YES animated:YES];

	if (!hasTapped)
		return;

	if (lyricsView && lastItem && lastItem == mediaItem)
		[lyricsView setHidden:YES animated:YES];
	else {
		NSString *song = [[mediaItem valueForProperty:MPMediaItemPropertyTitle] retain];
    	NSString *artist = [([mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist])?:[mediaItem valueForProperty:MPMediaItemPropertyArtist] retain];
    	if (!song) song=@"";
    	if (!artist) artist=@"";
		lastItem = [mediaItem retain];
		CGRect frame = cView.frame;
		if (!lyricsView) {
			lyricsView = [[$MusicLyricsView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
			[lyricsView setHidden:NO animated:NO];
		}

		if ([lyricsView superview] != cView)
			[cView addSubview:lyricsView];
		[lyricsView setText:@"Fetching lyrics..."];

		if ([item lyrics] && ![[item lyrics] isEqualToString:@""])
			[lyricsView setText:[item lyrics]];
		else {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[[LYManager sharedInstance] fetchLyricsWithSong:song andArtist:artist andTarget:self andSelector:@selector(lyricsReturned:)];
			});
		}
	}
}

- (void)_tapAction:(id)arg1 {
	hasTapped = !hasTapped;
	[self loadLyricView];
}

- (void)_updateTitles {
	%orig;
	[self loadLyricView];
}


%end
%end

%group iOS8
%hook MPUNowPlayingViewController

// This is called when the user taps the view to view the lyrics. Replaced with custom handler.

%new
- (void)lyricsReturned:(NSDictionary*)lyricsDict {
	MPAVItem *item = MSHookIvar<MPAVItem*>(self, "_item");
	MPMediaItem *mediaItem = MSHookIvar<MPMediaItem*>(item, "_mediaItem");
	NSString *song = [mediaItem valueForProperty:MPMediaItemPropertyTitle];
	NSString *artist = ([mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist])?:[mediaItem valueForProperty:MPMediaItemPropertyArtist];
	NSArray *lyrArray = [lyricsDict objectForKey:@"lyrics"];
	if (lyrArray && (![artist isEqualToString:[lyricsDict objectForKey:@"artist"]] && ![song isEqualToString:[lyricsDict objectForKey:@"song"]])) return;

	NSString *lyrics = [lyrArray componentsJoinedByString:@"\n"];
	if (!lyrics) lyrics = @"No lyrics found.";

	MPULyricsView *lyricsView = MSHookIvar<MPULyricsView*>(self, "_lyricsView");
	UIView *cView = MSHookIvar<UIView*>(self, "_contentView");

	for (UIView *subv in cView.subviews) {
		if ([subv isKindOfClass:[MPULyricsView class]])
			lyricsView = (MPULyricsView*)subv;
	}

	[lyricsView setText:lyrics];
	[lyricsView setHidden:NO animated:YES];
}

%new
- (void)loadLyricView {
	Class $MPULyricsView = objc_getClass("MPULyricsView");
	UIView *cView = MSHookIvar<UIView*>(self, "_contentView");
	MPULyricsView *lyricsView = MSHookIvar<MPULyricsView*>(self, "_lyricsView");
	MPAVItem *item = MSHookIvar<MPAVItem*>(self, "_item");
	MPMediaItem *mediaItem = MSHookIvar<MPMediaItem*>(item, "_mediaItem");

	for (UIView *subv in cView.subviews) {
		if ([subv isKindOfClass:[MPULyricsView class]])
			lyricsView = (MPULyricsView*)subv;
	}

	if (!hasTapped && lyricsView && !lyricsView.hidden)
		[lyricsView setHidden:YES animated:YES];

	if (!hasTapped)
		return;

	if (lyricsView && lastItem && lastItem == mediaItem)
		[lyricsView setHidden:YES animated:YES];
	else {
		NSString *song = [[mediaItem valueForProperty:MPMediaItemPropertyTitle] retain];
    	NSString *artist = [([mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist])?:[mediaItem valueForProperty:MPMediaItemPropertyArtist] retain];
    	if (!song) song=@"";
    	if (!artist) artist=@"";
		lastItem = [mediaItem retain];
		CGRect frame = cView.frame;
		if (!lyricsView) {
			lyricsView = [[$MPULyricsView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
			[lyricsView setHidden:NO animated:NO];
		}

		if (lyricsView.superview != cView)
			[cView addSubview:lyricsView];
		[lyricsView setText:@"Fetching lyrics..."];

		if ([item lyrics] && ![[item lyrics] isEqualToString:@""])
			[lyricsView setText:[item lyrics]];
		else {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[[LYManager sharedInstance] fetchLyricsWithSong:song andArtist:artist andTarget:self andSelector:@selector(lyricsReturned:)];
			});
		}
	}
}

- (void)_tapAction:(id)arg1 {
	hasTapped = !hasTapped;
	[self loadLyricView];
}

- (void)_updateTitles {
	%orig;
	[self loadLyricView];
}


%end
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


%hook SPTNowPlayingView

static NSString *artistName = nil;
static NSString *songName = nil;

%new
- (void)initLyricsView {
	if (!lyricsView) {
		lyricsView = [[UITextView alloc] initWithFrame:[[self coverArtView] frame]];
		[lyricsView setAlpha:0];
		[lyricsView setUserInteractionEnabled:YES];
		[lyricsView setEditable:NO];
		[lyricsView setTextColor:[UIColor whiteColor]];
		[lyricsView setTextAlignment:NSTextAlignmentCenter];
		[lyricsView setFont:[UIFont systemFontOfSize:14.0f]];
		[lyricsView setTextContainerInset:UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f)];
		[lyricsView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.8f]];
	}
	UITapGestureRecognizer *tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lyricsViewTapped:)];
	[tapRec setNumberOfTapsRequired:1];
	[lyricsView addGestureRecognizer:tapRec];
	UITapGestureRecognizer *tapRec2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lyricsViewTapped:)];
	[tapRec2 setNumberOfTapsRequired:1];
	[[[self coverArtView] coverArtView] addGestureRecognizer:tapRec2];
	[self addSubview:lyricsView];
}

- (id)initWithFrame:(CGRect)arg1 andConnectButton:(id)arg2 imageLoaderFactory:(id)arg3 {
	if ((self = %orig)) {
		[self initLyricsView];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame andConnectButton:(id)button {
	if ((self = %orig)) {
		[self initLyricsView];
	}
	return self;
}

%new
- (void)lyricsReturned:(NSDictionary*)lyricsDict {
	NSArray *lyrArray = [lyricsDict objectForKey:@"lyrics"];
	if (lyrArray && (![artistName isEqualToString:[lyricsDict objectForKey:@"artist"]] && ![songName isEqualToString:[lyricsDict objectForKey:@"song"]])) return;

	NSString *lyrics = [lyrArray componentsJoinedByString:@"\n"];
	if (!lyrics) lyrics = @"No lyrics found.";

	[lyricsView setText:lyrics];
}

%new
- (void)reloadLyrics {
	NSString *song = songName;
	NSString *artist = artistName;

	NSLog(@"Song: %@, Artist: %@", song, artist);

	[[LYManager sharedInstance] fetchLyricsWithSong:song andArtist:artist andTarget:self andSelector:@selector(lyricsReturned:)];
}

%new
- (void)imageSlideViewWasTapped {
	CGRect fr = [[self coverArtView] frame];
	// fr.origin.x = 5;
	// fr.origin.y = 0;
	// fr.size.width = [[UIScreen mainScreen] fixedCoordinateSpace].bounds.size.width - 10;
	[lyricsView setFrame:fr];
	if ([lyricsView alpha]==0) {
		[self reloadLyrics];
		[lyricsView setAlpha:1];
	} else if ([lyricsView alpha]==1) {
		[lyricsView setAlpha:0];
	}
}

- (void)updateMetadataLabelsWithTrackTitle:(id)arg1 artistTitle:(id)arg2 advertiserTitle:(id)arg3 {
	[lyricsView setText:@"Fetching lyrics..."];
	songName = [arg1 retain];
	artistName = [arg2 retain];
	%orig;
	[self reloadLyrics];
}

- (void)updateMetadataLabelsWithTrackTitle:(id)arg1 subtitle:(id)arg2 {
	[lyricsView setText:@"Fetching lyrics..."];
	songName = [arg1 retain];
	artistName = [arg2 retain];
	%orig(arg1, arg2);
	[self reloadLyrics];
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


%hook NowPlayingViewControllerIPhone

- (void)lyricsReturned:(NSDictionary*)lyricsDict {
	NSArray *lyrArray = [lyricsDict objectForKey:@"lyrics"];
	if (lyrArray && (![artistName isEqualToString:[lyricsDict objectForKey:@"artist"]] && ![songName isEqualToString:[lyricsDict objectForKey:@"song"]])) return;

	NSString *lyrics = [lyrArray componentsJoinedByString:@"\n"];
	if (!lyrics) lyrics = @"No lyrics found.";

	[lyricsView setText:lyrics];
}

%new
- (void)reloadLyrics {
	NSString *song = [[self currentTrack] name];
	NSString *artist = [[[self currentTrack] artist] name];

	NSLog(@"Song: %@, Artist: %@", song, artist);

	[[LYManager sharedInstance] fetchLyricsWithSong:song andArtist:artist andTarget:self andSelector:@selector(lyricsReturned:)];
}

%new
- (void)imageSlideViewWasTapped {
	if ([[self infoPanel] alpha]==0 && [lyricsView alpha]==0) {
		[lyricsView setText:@"Fetching lyrics..."];
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
    NSString *platform = [[UIDevice currentDevice] model];
    if (IOS_80) {
    	%init(iOS8);
    } else {
    	%init(iOS7);
    }
    %init;
    if ([platform rangeOfString:@"iPad"].location == NSNotFound)
		%init(SpotifyPhone)
}
