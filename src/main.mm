/*
Copyright (c) Ivan Alekseev

Licensed under the PetoronAI Community License (PCL)
or a valid PetoronAI Commercial License.
*/

#import <Cocoa/Cocoa.h>

#include "ui/deposit.hpp"
#include "ui/withdraw.hpp"

@interface PetoronWalletApp : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow* window;
@property(nonatomic, strong) NSView* root;
@property(nonatomic, strong) NSView* host;
@property(nonatomic, strong) NSButton* depositButton;
@property(nonatomic, strong) NSButton* withdrawButton;
@property(nonatomic, strong) PetoronDepositViewController* depositController;
@property(nonatomic, strong) PetoronWithdrawViewController* withdrawController;
@property(nonatomic, strong) NSView* depositView;
@property(nonatomic, strong) NSView* withdrawView;
@end

static void PetoronInstallEditMenu() {
    NSMenu* menubar = [[NSMenu alloc] init];

    NSMenuItem* appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];

    NSMenuItem* editItem = [[NSMenuItem alloc] init];
    [menubar addItem:editItem];

    [NSApp setMainMenu:menubar];

    NSMenu* editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    [menubar setSubmenu:editMenu forItem:editItem];
}

@implementation PetoronWalletApp

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    PetoronInstallEditMenu();
    [self buildWindow];
    [self showDeposit:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    return YES;
}

- (NSTextField*)label:(NSString*)text frame:(NSRect)frame size:(CGFloat)size bold:(BOOL)bold {
    NSTextField* label = [[NSTextField alloc] initWithFrame:frame];
    [label setStringValue:text];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size]];
    [label setTextColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
    return label;
}

- (NSButton*)navButton:(NSString*)title frame:(NSRect)frame action:(SEL)action {
    NSButton* button = [[NSButton alloc] initWithFrame:frame];
    [button setTitle:title];
    [button setBordered:NO];
    [button setTarget:self];
    [button setAction:action];
    [button setAlignment:NSTextAlignmentLeft];
    [button setFont:[NSFont boldSystemFontOfSize:16]];
    return button;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 980, 660)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered
        defer:NO
    ];

    [self.window center];
    [self.window setTitle:@"PetoronAI Licensing"];

    self.root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 980, 660)];
    [self.root setWantsLayer:YES];
    [self.root.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:0.06 green:0.07 blue:0.09 alpha:1.0] CGColor]];

    NSView* sidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 220, 660)];
    [sidebar setWantsLayer:YES];
    [sidebar.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:0.10 green:0.11 blue:0.14 alpha:1.0] CGColor]];
    [self.root addSubview:sidebar];

    NSTextField* logo = [self label:@"zkPetoron" frame:NSMakeRect(28, 590, 170, 36) size:26 bold:YES];
    [logo setTextColor:[NSColor colorWithCalibratedRed:1.0 green:0.54 blue:0.16 alpha:1.0]];
    [sidebar addSubview:logo];

    self.depositButton = [self navButton:@"● Create License" frame:NSMakeRect(28, 525, 170, 30) action:@selector(showDeposit:)];
    self.withdrawButton = [self navButton:@"○ Verify License" frame:NSMakeRect(28, 485, 170, 30) action:@selector(showWithdraw:)];
    [sidebar addSubview:self.depositButton];
    [sidebar addSubview:self.withdrawButton];

    NSTextField* note = [self label:@"PetoronAI licensing\nBinary .pnote\nPetoronHash2 proofs"
                                  frame:NSMakeRect(28, 60, 170, 80)
                                   size:12
                                   bold:NO];
    [note setTextColor:[NSColor colorWithCalibratedWhite:0.55 alpha:1.0]];
    [sidebar addSubview:note];

    self.host = [[NSView alloc] initWithFrame:NSMakeRect(220, 0, 760, 660)];
    [self.root addSubview:self.host];

    self.depositController = [[PetoronDepositViewController alloc] init];
    self.withdrawController = [[PetoronWithdrawViewController alloc] init];
    self.depositView = [self.depositController makeView];
    self.withdrawView = [self.withdrawController makeView];

    [self.window setContentView:self.root];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)clearHost {
    for (NSView* view in [self.host.subviews copy]) {
        [view removeFromSuperview];
    }
}

- (void)showDeposit:(id)sender {
    [self clearHost];
    [self.depositButton setTitle:@"● Create License"];
    [self.withdrawButton setTitle:@"○ Verify License"];
    [self.host addSubview:self.depositView];
}

- (void)showWithdraw:(id)sender {
    [self clearHost];
    [self.depositButton setTitle:@"○ Create License"];
    [self.withdrawButton setTitle:@"● Verify License"];
    [self.host addSubview:self.withdrawView];
}

@end

int main(int argc, const char* argv[]) {
    @autoreleasepool {

        NSApplication* app = [NSApplication sharedApplication];

        if (@available(macOS 10.14, *)) {
            [app setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
        }

        PetoronWalletApp* delegate = [[PetoronWalletApp alloc] init];

        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }

    return 0;
}