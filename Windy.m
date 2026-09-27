#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>

static const unsigned long long WindyMaximumFileSize = 20ULL * 1024ULL * 1024ULL;

static NSString *WindyLogoSVG(void) {
    return @"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 440\"><defs><linearGradient id=\"bg\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\"><stop offset=\"0%\" stop-color=\"#352c48\"/><stop offset=\"40%\" stop-color=\"#a44b5a\"/><stop offset=\"75%\" stop-color=\"#e9a277\"/><stop offset=\"100%\" stop-color=\"#ece2cc\"/></linearGradient><linearGradient id=\"wave1\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\"><stop offset=\"0%\" stop-color=\"#ffffff\" stop-opacity=\"0.9\"/><stop offset=\"100%\" stop-color=\"#ffffff\" stop-opacity=\"0.3\"/></linearGradient><linearGradient id=\"wave2\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\"><stop offset=\"0%\" stop-color=\"#f5ccb0\" stop-opacity=\"0.8\"/><stop offset=\"100%\" stop-color=\"#d46c75\" stop-opacity=\"0.4\"/></linearGradient></defs><rect x=\"64\" y=\"40\" width=\"384\" height=\"384\" rx=\"90\" fill=\"url(#bg)\"/><path d=\"M64 240C180 180 260 320 340 160C380 80 410 40 448 40V424H64Z\" fill=\"url(#wave1)\" opacity=\"0.15\"/><path d=\"M64 280C160 260 220 140 320 220C380 268 410 210 448 160\" fill=\"none\" stroke=\"url(#wave1)\" stroke-width=\"24\" stroke-linecap=\"round\" opacity=\"0.85\"/><path d=\"M90 340C160 330 200 240 300 280C360 304 400 270 430 220\" fill=\"none\" stroke=\"url(#wave2)\" stroke-width=\"14\" stroke-linecap=\"round\" opacity=\"0.9\"/><rect x=\"65\" y=\"41\" width=\"382\" height=\"382\" rx=\"89\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"1.5\" opacity=\"0.25\"/></svg>";
}

static NSString *WindyReadableSize(unsigned long long bytes) {
    if (bytes >= 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL) {
        return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0];
    }
    return [NSString stringWithFormat:@"%llu bytes", bytes];
}

@interface WindyWallpaperView : NSView
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
- (void)displayURL:(NSURL *)url;
@end

@implementation WindyWallpaperView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
    }
    return self;
}

- (void)layout {
    [super layout];
    self.webView.frame = self.bounds;
    self.playerLayer.frame = self.bounds;
}

- (void)clearContent {
    [self.webView stopLoading];
    [self.webView removeFromSuperview];
    self.webView = nil;
    if (self.playerItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    }
    [self.player pause];
    self.player = nil;
    self.playerItem = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
}

- (WKWebView *)makeWebView {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:configuration];
    webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    return webView;
}

- (void)displayURL:(NSURL *)url {
    [self clearContent];
    NSString *extension = url.pathExtension.lowercaseString;
    if ([extension isEqualToString:@"html"] || [extension isEqualToString:@"htm"]) {
        self.webView = [self makeWebView];
        [self addSubview:self.webView];
        NSURL *directoryURL = [url URLByDeletingLastPathComponent];
        [self.webView loadFileURL:url allowingReadAccessToURL:directoryURL];
        return;
    }
    if ([extension isEqualToString:@"gif"]) {
        self.webView = [self makeWebView];
        [self addSubview:self.webView];
        NSString *source = url.absoluteString;
        NSString *document = [NSString stringWithFormat:@"<!doctype html><html><head><style>html,body{width:100%%;height:100%%;margin:0;overflow:hidden;background:#000}img{width:100%%;height:100%%;display:block;object-fit:cover}</style></head><body><img src=\"%@\"></body></html>", source];
        [self.webView loadHTMLString:document baseURL:[url URLByDeletingLastPathComponent]];
        return;
    }
    self.playerItem = [AVPlayerItem playerItemWithURL:url];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.player.muted = YES;
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.playerLayer.frame = self.bounds;
    [self.layer addSublayer:self.playerLayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartVideo:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    [self.player play];
}

- (void)restartVideo:(NSNotification *)notification {
    [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        if (finished) {
            [self.player play];
        }
    }];
}

- (void)dealloc {
    [self clearContent];
}

@end

@interface WindyController : NSObject <NSWindowDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSTextField *fileLabel;
@property (nonatomic, strong) NSTextField *fileDetailLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *applyButton;
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) NSURL *selectedURL;
@property (nonatomic, strong) NSURL *appliedURL;
@property (nonatomic, strong) NSMutableArray<NSWindow *> *wallpaperWindows;
- (void)showWindow;
@end

@implementation WindyController

- (instancetype)init {
    self = [super init];
    if (self) {
        _wallpaperWindows = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenParametersChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    }
    return self;
}

- (NSTextField *)labelWithString:(NSString *)string frame:(NSRect)frame size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = string;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.selectable = NO;
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (NSButton *)buttonWithTitle:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.title = title;
    button.bezelStyle = NSBezelStyleRounded;
    button.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold];
    button.target = self;
    button.action = action;
    return button;
}

- (NSView *)panelWithFrame:(NSRect)frame {
    NSView *panel = [[NSView alloc] initWithFrame:frame];
    panel.wantsLayer = YES;
    panel.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.08].CGColor;
    panel.layer.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.12].CGColor;
    panel.layer.borderWidth = 1.0;
    panel.layer.cornerRadius = 12.0;
    return panel;
}

- (NSString *)logoHTML {
    return [NSString stringWithFormat:@"<!doctype html><html><head><style>html,body{width:100%%;height:100%%;margin:0;overflow:hidden;background:#1b1526}svg{width:100%%;height:100%%;display:block}</style></head><body>%@</body></html>", WindyLogoSVG()];
}

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 620, 430);
    self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Windy";
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.window.delegate = self;
    self.window.movableByWindowBackground = YES;
    [self.window center];

    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.105 green:0.082 blue:0.15 alpha:1.0].CGColor;
    self.window.contentView = contentView;

    WKWebViewConfiguration *logoConfiguration = [[WKWebViewConfiguration alloc] init];
    WKWebView *logoView = [[WKWebView alloc] initWithFrame:NSMakeRect(38, 292, 100, 86) configuration:logoConfiguration];
    [logoView loadHTMLString:[self logoHTML] baseURL:nil];
    [contentView addSubview:logoView];

    NSColor *primary = [NSColor colorWithCalibratedWhite:1.0 alpha:0.96];
    NSColor *secondary = [NSColor colorWithCalibratedWhite:1.0 alpha:0.68];
    NSColor *muted = [NSColor colorWithCalibratedWhite:1.0 alpha:0.42];
    NSTextField *title = [self labelWithString:@"Windy" frame:NSMakeRect(156, 346, 400, 38) size:31.0 weight:NSFontWeightBold color:primary];
    [contentView addSubview:title];
    NSTextField *subtitle = [self labelWithString:@"Live wallpapers for macOS High Sierra" frame:NSMakeRect(158, 321, 420, 24) size:15.0 weight:NSFontWeightRegular color:secondary];
    [contentView addSubview:subtitle];
    NSTextField *supported = [self labelWithString:@"HTML  ·  GIF  ·  MP4  ·  MOV  ·  M4V    |    20 MB maximum" frame:NSMakeRect(158, 298, 430, 18) size:11.0 weight:NSFontWeightMedium color:muted];
    [contentView addSubview:supported];

    NSView *filePanel = [self panelWithFrame:NSMakeRect(32, 100, 556, 154)];
    [contentView addSubview:filePanel];
    NSTextField *fileHeading = [self labelWithString:@"WALLPAPER FILE" frame:NSMakeRect(20, 116, 250, 18) size:11.0 weight:NSFontWeightBold color:muted];
    [filePanel addSubview:fileHeading];
    self.fileLabel = [self labelWithString:@"Choose a local HTML, GIF or video file" frame:NSMakeRect(20, 77, 355, 25) size:14.0 weight:NSFontWeightSemibold color:primary];
    self.fileLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [filePanel addSubview:self.fileLabel];
    self.fileDetailLabel = [self labelWithString:@"No file selected" frame:NSMakeRect(20, 57, 355, 16) size:11.0 weight:NSFontWeightRegular color:muted];
    [filePanel addSubview:self.fileDetailLabel];
    NSButton *chooseButton = [self buttonWithTitle:@"Choose File…" frame:NSMakeRect(402, 70, 134, 34) action:@selector(chooseFile:)];
    [filePanel addSubview:chooseButton];
    NSView *separator = [[NSView alloc] initWithFrame:NSMakeRect(20, 45, 516, 1)];
    separator.wantsLayer = YES;
    separator.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.1].CGColor;
    [filePanel addSubview:separator];
    self.statusLabel = [self labelWithString:@"Select a file to begin." frame:NSMakeRect(20, 16, 516, 20) size:12.0 weight:NSFontWeightRegular color:secondary];
    [filePanel addSubview:self.statusLabel];

    NSTextField *footer = [self labelWithString:@"Wallpaper windows stay behind your desktop icons and ignore mouse input." frame:NSMakeRect(32, 67, 430, 18) size:11.0 weight:NSFontWeightRegular color:muted];
    [contentView addSubview:footer];
    self.clearButton = [self buttonWithTitle:@"Restore Desktop" frame:NSMakeRect(32, 28, 142, 32) action:@selector(clearWallpaper:)];
    self.clearButton.enabled = NO;
    [contentView addSubview:self.clearButton];
    self.applyButton = [self buttonWithTitle:@"Set Wallpaper" frame:NSMakeRect(442, 28, 146, 32) action:@selector(applyWallpaper:)];
    self.applyButton.enabled = NO;
    self.applyButton.keyEquivalent = @"\r";
    [contentView addSubview:self.applyButton];
}

- (void)showWindow {
    [self buildWindow];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)validateURL:(NSURL *)url message:(NSString **)message {
    if (!url.isFileURL || ![[NSFileManager defaultManager] isReadableFileAtPath:url.path]) {
        if (message) {
            *message = @"The selected file cannot be read.";
        }
        return NO;
    }
    NSString *extension = url.pathExtension.lowercaseString;
    NSSet *extensions = [NSSet setWithObjects:@"html", @"htm", @"gif", @"mp4", @"mov", @"m4v", nil];
    if (![extensions containsObject:extension]) {
        if (message) {
            *message = @"Use an HTML, GIF, MP4, MOV or M4V file.";
        }
        return NO;
    }
    NSNumber *size = nil;
    if (![url getResourceValue:&size forKey:NSURLFileSizeKey error:nil]) {
        if (message) {
            *message = @"The file size could not be read.";
        }
        return NO;
    }
    if (size.unsignedLongLongValue > WindyMaximumFileSize) {
        if (message) {
            *message = @"The selected file is larger than 20 MB.";
        }
        return NO;
    }
    return YES;
}

- (void)setStatus:(NSString *)status error:(BOOL)error {
    self.statusLabel.stringValue = status;
    self.statusLabel.textColor = error ? [NSColor colorWithCalibratedRed:1.0 green:0.42 blue:0.43 alpha:0.95] : [NSColor colorWithCalibratedWhite:1.0 alpha:0.68];
}

- (void)chooseFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"Choose a Windy wallpaper";
    panel.message = @"Select an HTML, GIF, MP4, MOV or M4V file up to 20 MB.";
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedFileTypes = @[@"html", @"htm", @"gif", @"mp4", @"mov", @"m4v"];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        NSString *message = nil;
        if (![self validateURL:panel.URL message:&message]) {
            [self setStatus:message error:YES];
            return;
        }
        self.selectedURL = panel.URL;
        NSNumber *size = nil;
        [self.selectedURL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        self.fileLabel.stringValue = self.selectedURL.lastPathComponent;
        self.fileDetailLabel.stringValue = [NSString stringWithFormat:@"%@  ·  %@", self.selectedURL.pathExtension.uppercaseString, WindyReadableSize(size.unsignedLongLongValue)];
        self.applyButton.enabled = YES;
        [self setStatus:@"Ready to set this wallpaper." error:NO];
    }];
}

- (void)applyWallpaper:(id)sender {
    if (!self.selectedURL) {
        [self setStatus:@"Choose a wallpaper file first." error:YES];
        return;
    }
    NSString *message = nil;
    if (![self validateURL:self.selectedURL message:&message]) {
        [self setStatus:message error:YES];
        return;
    }
    self.appliedURL = self.selectedURL;
    [self displayWallpaper:self.appliedURL];
    self.clearButton.enabled = YES;
    [self setStatus:@"Wallpaper is active on all connected displays." error:NO];
}

- (void)clearWallpaper:(id)sender {
    self.appliedURL = nil;
    [self removeWallpaperWindows];
    self.clearButton.enabled = NO;
    [self setStatus:@"Desktop wallpaper restored." error:NO];
}

- (void)displayWallpaper:(NSURL *)url {
    [self removeWallpaperWindows];
    for (NSScreen *screen in NSScreen.screens) {
        NSWindow *wallpaperWindow = [[NSWindow alloc] initWithContentRect:screen.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO screen:screen];
        wallpaperWindow.releasedWhenClosed = NO;
        wallpaperWindow.opaque = YES;
        wallpaperWindow.backgroundColor = NSColor.blackColor;
        wallpaperWindow.hasShadow = NO;
        wallpaperWindow.ignoresMouseEvents = YES;
        wallpaperWindow.level = CGWindowLevelForKey(kCGDesktopWindowLevelKey);
        wallpaperWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle;
        WindyWallpaperView *view = [[WindyWallpaperView alloc] initWithFrame:wallpaperWindow.contentView.bounds];
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [wallpaperWindow setContentView:view];
        [view displayURL:url];
        [wallpaperWindow orderFrontRegardless];
        [self.wallpaperWindows addObject:wallpaperWindow];
    }
}

- (void)removeWallpaperWindows {
    for (NSWindow *wallpaperWindow in self.wallpaperWindows) {
        [wallpaperWindow orderOut:nil];
        [wallpaperWindow close];
    }
    [self.wallpaperWindows removeAllObjects];
}

- (void)screenParametersChanged:(NSNotification *)notification {
    if (self.appliedURL && self.wallpaperWindows.count > 0) {
        [self displayWallpaper:self.appliedURL];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.window) {
        [self removeWallpaperWindows];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeWallpaperWindows];
}

@end

@interface WindyAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) WindyController *controller;
@end

@implementation WindyAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
    NSMenuItem *applicationItem = [[NSMenuItem alloc] initWithTitle:@"Windy" action:nil keyEquivalent:@""];
    NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@"Windy"];
    [applicationMenu addItemWithTitle:@"Quit Windy" action:@selector(terminate:) keyEquivalent:@"q"];
    [mainMenu addItem:applicationItem];
    [mainMenu setSubmenu:applicationMenu forItem:applicationItem];
    NSApp.mainMenu = mainMenu;
    self.controller = [[WindyController alloc] init];
    [self.controller showWindow];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        WindyAppDelegate *delegate = [[WindyAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
