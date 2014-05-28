@interface MusicNowPlayingViewController : UIViewController
- (void)loadLyricView;
@end

@interface MPAVItem : NSObject {
	MPMediaItem *_mediaItem;
}
@property(readonly, nonatomic) NSString *lyrics;
@end

@interface SPArtist : NSObject
@property(readonly, nonatomic) NSString *name;
@end

@interface SPTrack : NSObject
@property(readonly, nonatomic) SPArtist *artist;
@property(readonly, nonatomic) NSString *name;
@end

@interface NowPlayingViewController : UIViewController
@property(readonly, nonatomic) SPTrack *currentTrack;
@end

@interface NowPlayingViewControllerIPhone : NowPlayingViewController
- (void)reloadLyrics;
- (void)imageSlideViewWasTapped;
@property(retain, nonatomic) UIView *infoPanel;
@end

@interface SPTNowPlayingView : UIView
- (void)reloadLyrics;
- (void)imageSlideViewWasTapped;
- (SPTNowPlayingView*)coverArtView;
@end