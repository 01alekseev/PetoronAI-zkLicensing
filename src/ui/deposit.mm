/*
Copyright (c) Ivan Alekseev

Licensed under the PetoronAI Community License (PCL)
or a valid PetoronAI Commercial License.
*/

#import "deposit.hpp"

#include "proof/commitment/petoron_zk_commitment.hpp"

#include <array>
#include <chrono>
#include <cctype>
#include <cstdint>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

static NSString* PetoronNs(const std::string& value) {
    return [NSString stringWithUTF8String:value.c_str()];
}

static std::string PetoronNowStamp() {
    const auto now = std::chrono::system_clock::now();
    const auto time = std::chrono::system_clock::to_time_t(now);

    std::tm tm{};
    localtime_r(&time, &tm);

    std::ostringstream out;
    out << std::put_time(&tm, "%Y%m%d-%H%M%S");

    return out.str();
}

static std::string PetoronHex32(const petoron::zk::PetoronZkCommitment::Digest& digest) {
    std::ostringstream out;
    out << "0x";

    for (std::size_t i = 0; i < 32; ++i) {
        out << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(digest[i]);
    }

    return out.str();
}

static bool PetoronParseMoneyCents(NSString* text, std::uint64_t& outCents) {
    outCents = 0;

    if (text == nil) {
        return false;
    }

    std::string raw([text UTF8String]);
    std::string digits;

    for (char c : raw) {
        if (c >= '0' && c <= '9') {
            digits.push_back(c);
        }
    }

    if (digits.empty()) {
        return false;
    }

    while (digits.size() > 1 && digits[0] == '0') {
        digits.erase(digits.begin());
    }

    if (digits.size() > 15) {
        return false;
    }

    std::uint64_t dollars = 0;

    for (char c : digits) {
        dollars = dollars * 10 + static_cast<std::uint64_t>(c - '0');
    }

    outCents = dollars * 100;
    return true;
}

static NSString* PetoronFormatInputMoney(NSString* text) {
    if (text == nil) {
        return @"";
    }

    std::string raw([text UTF8String]);
    std::string digits;

    for (char c : raw) {
        if (c >= '0' && c <= '9') {
            digits.push_back(c);
        }
    }

    if (digits.empty()) {
        return @"";
    }

    while (digits.size() > 1 && digits[0] == '0') {
        digits.erase(digits.begin());
    }

    for (long long i = static_cast<long long>(digits.size()) - 3; i > 0; i -= 3) {
        digits.insert(static_cast<std::size_t>(i), ",");
    }

    return PetoronNs(digits);
}

static std::string PetoronMoney(std::uint64_t cents) {
    std::uint64_t dollars = cents / 100;
    std::uint64_t frac = cents % 100;

    std::string whole = std::to_string(dollars);

    for (long long i = static_cast<long long>(whole.size()) - 3; i > 0; i -= 3) {
        whole.insert(static_cast<std::size_t>(i), ",");
    }

    std::ostringstream out;
    out << whole
        << "."
        << std::setw(2)
        << std::setfill('0')
        << frac;

    return out.str();
}

static petoron::zk::PetoronZkCommitment::Digest PetoronDigest(
    const std::string& domain,
    const std::vector<std::uint8_t>& data
) {
    std::vector<std::uint8_t> material(domain.begin(), domain.end());
    material.insert(material.end(), data.begin(), data.end());

    return petoron::zk::PetoronZkCommitment::commit_bytes(
        std::span<const std::uint8_t>(material.data(), material.size())
    );
}


static void PetoronAppendU32LE(std::vector<std::uint8_t>& out, std::uint32_t value) {
    for (int i = 0; i < 4; ++i) {
        out.push_back(static_cast<std::uint8_t>((value >> (i * 8)) & 0xff));
    }
}

static void PetoronAppendU64LE(std::vector<std::uint8_t>& out, std::uint64_t value) {
    for (int i = 0; i < 8; ++i) {
        out.push_back(static_cast<std::uint8_t>((value >> (i * 8)) & 0xff));
    }
}

static void PetoronAppendBinaryString(std::vector<std::uint8_t>& out, const std::string& value) {
    PetoronAppendU32LE(out, static_cast<std::uint32_t>(value.size()));
    out.insert(out.end(), value.begin(), value.end());
}

static void PetoronAppendDigest32(
    std::vector<std::uint8_t>& out,
    const petoron::zk::PetoronZkCommitment::Digest& digest
) {
    for (std::size_t i = 0; i < 32; ++i) {
        out.push_back(digest[i]);
    }
}


static void PetoronAppendString(std::vector<std::uint8_t>& out, const std::string& value) {
    out.insert(out.end(), value.begin(), value.end());
}

@interface PetoronDepositViewController () <NSTextFieldDelegate>
@property(nonatomic, strong) NSTextField* statusText;
@property(nonatomic, strong) NSTextField* incomeInput;
@property(nonatomic, strong) NSTextField* licensePriceText;
@property(nonatomic, strong) NSTextField* contractInput;
@property(nonatomic, strong) NSTextField* fileText;
@property(nonatomic, strong) NSTextField* commitmentText;
@property(nonatomic, strong) NSButton* saveButton;
@property(nonatomic, strong) NSButton* commitmentCopyButton;
@property(nonatomic, strong) NSData* currentNoteBytes;
@property(nonatomic, strong) NSData* loadedIncomeBytes;
@property(nonatomic, strong) NSString* loadedIncomeName;
@property(nonatomic, strong) NSString* currentCommitment;
@end

@implementation PetoronDepositViewController

- (NSView*)makeView {
    NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 760, 660)];
    [content setWantsLayer:YES];
    [content.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:0.06 green:0.07 blue:0.09 alpha:1.0] CGColor]];

    NSTextField* title = [self label:@"PetoronAI Licensing" frame:NSMakeRect(30, 590, 620, 36) size:30 bold:YES];
    [content addSubview:title];

    NSTextField* subtitle = [self label:@"Enter net income, load official annual net income file, create license commitment." frame:NSMakeRect(32, 562, 690, 24) size:14 bold:NO];
    [subtitle setTextColor:[NSColor colorWithCalibratedWhite:0.62 alpha:1.0]];
    [content addSubview:subtitle];

    NSView* card = [[NSView alloc] initWithFrame:NSMakeRect(30, 300, 700, 240)];
    [card setWantsLayer:YES];
    [card.layer setCornerRadius:18];
    [card.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.18 alpha:1.0] CGColor]];
    [content addSubview:card];

    [content addSubview:[self label:@"Net income" frame:NSMakeRect(60, 500, 160, 24) size:14 bold:YES]];

    self.incomeInput = [[NSTextField alloc] initWithFrame:NSMakeRect(200, 492, 390, 30)];
    [self.incomeInput setPlaceholderString:@"$10,000,000.00"];
    [self.incomeInput setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
    [self.incomeInput setDelegate:self];
    [content addSubview:self.incomeInput];

    self.licensePriceText = [self label:@"License price 2%: -" frame:NSMakeRect(200, 462, 390, 24) size:13 bold:YES];
    [self.licensePriceText setTextColor:[NSColor colorWithCalibratedRed:1.0 green:0.72 blue:0.28 alpha:1.0]];
    [content addSubview:self.licensePriceText];

    [content addSubview:[self label:@"Contract" frame:NSMakeRect(60, 420, 160, 24) size:14 bold:YES]];

    self.contractInput = [[NSTextField alloc] initWithFrame:NSMakeRect(200, 412, 390, 30)];
    [self.contractInput setPlaceholderString:@"0x..."];
    [self.contractInput setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
    [self.contractInput setDelegate:self];
    [content addSubview:self.contractInput];

    [content addSubview:[self label:@"Income file" frame:NSMakeRect(60, 380, 160, 24) size:14 bold:YES]];

    self.fileText = [self label:@"No official file loaded" frame:NSMakeRect(200, 360, 430, 48) size:13 bold:NO];
    [self.fileText setUsesSingleLineMode:NO];
    [self.fileText setLineBreakMode:NSLineBreakByWordWrapping];
    [self.fileText setTextColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0]];
    [content addSubview:self.fileText];

    NSButton* loadFileButton = [self button:@"Load File" frame:NSMakeRect(605, 490, 100, 32) action:@selector(loadInputFile:)];
    [content addSubview:loadFileButton];

    NSButton* clearButton = [self button:@"Clear" frame:NSMakeRect(605, 450, 100, 32) action:@selector(clearInput:)];
    [content addSubview:clearButton];

    NSButton* generateButton = [self button:@"Create License Note" frame:NSMakeRect(200, 335, 180, 36) action:@selector(generateNote:)];
    [content addSubview:generateButton];

    self.saveButton = [self button:@"Save .pnote" frame:NSMakeRect(410, 335, 180, 36) action:@selector(saveNote:)];
    [self.saveButton setEnabled:NO];
    [self.saveButton setWantsLayer:YES];
    [self.saveButton.layer setCornerRadius:8.0];
    [self.saveButton.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:1.0 green:0.54 blue:0.16 alpha:1.0] CGColor]];
    [self.saveButton setBordered:NO];
    [content addSubview:self.saveButton];

    self.statusText = [self label:@"Ready. Enter net income, contract address, and load official annual net income file." frame:NSMakeRect(30, 260, 690, 24) size:13 bold:NO];
    [self.statusText setTextColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0]];
    [content addSubview:self.statusText];

    self.commitmentText = [self outputField:NSMakeRect(30, 150, 560, 74) value:@"Contract calldata commitment: -"];
    [content addSubview:self.commitmentText];

    self.commitmentCopyButton = [self button:@"Copy" frame:NSMakeRect(605, 172, 90, 30) action:@selector(copyCommitment:)];
    [self.commitmentCopyButton setEnabled:NO];
    [content addSubview:self.commitmentCopyButton];

    NSTextField* info = [self label:@".pnote includes income fingerprint, file fingerprint, contract address, and calldata commitment." frame:NSMakeRect(30, 105, 690, 22) size:12 bold:NO];
    [info setTextColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
    [content addSubview:info];

    NSTextField* warning = [self label:@"IMPORTANT\n\nYou must permanently store:\n1. The original income file used to create this license\n2. The generated .pnote file\n\nIf either file is lost, license proof cannot be regenerated.\nPetoronAI cannot recover lost files." frame:NSMakeRect(30, 10, 690, 95) size:12 bold:YES];
    [warning setUsesSingleLineMode:NO];
    [warning setLineBreakMode:NSLineBreakByWordWrapping];
    [warning setTextColor:[NSColor colorWithCalibratedRed:1.0 green:0.72 blue:0.28 alpha:1.0]];
    [content addSubview:warning];

    return content;
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

- (NSTextField*)outputField:(NSRect)frame value:(NSString*)value {
    NSTextField* field = [[NSTextField alloc] initWithFrame:frame];
    [field setStringValue:value];
    [field setBezeled:YES];
    [field setEditable:NO];
    [field setSelectable:YES];
    [field setFont:[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular]];
    [field setTextColor:[NSColor colorWithCalibratedWhite:0.90 alpha:1.0]];
    [field setBackgroundColor:[NSColor colorWithCalibratedRed:0.09 green:0.10 blue:0.13 alpha:1.0]];
    return field;
}

- (NSButton*)button:(NSString*)title frame:(NSRect)frame action:(SEL)action {
    NSButton* button = [[NSButton alloc] initWithFrame:frame];
    [button setTitle:title];
    [button setBezelStyle:NSBezelStyleRounded];
    [button setTarget:self];
    [button setAction:action];
    [button setFont:[NSFont boldSystemFontOfSize:14]];
    return button;
}

- (void)showError:(NSString*)message {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:@"PetoronAI Licensing"];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert runModal];
}

- (void)copyText:(NSString*)value {
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:value forType:NSPasteboardTypeString];
}

- (void)copyCommitment:(id)sender {
    if (self.currentCommitment == nil || [self.currentCommitment length] == 0) {
        return;
    }

    [self copyText:self.currentCommitment];
    [self.statusText setStringValue:@"Contract calldata commitment copied."];
}

- (void)controlTextDidChange:(NSNotification*)notification {
    if ([notification object] == self.incomeInput) {
        NSString* formatted = PetoronFormatInputMoney([self.incomeInput stringValue]);

        if (![formatted isEqualToString:[self.incomeInput stringValue]]) {
            [self.incomeInput setStringValue:formatted];
            [[self.incomeInput currentEditor] setSelectedRange:NSMakeRange([formatted length], 0)];
        }
    }

    [self refreshLicensePrice];
}

- (void)refreshLicensePrice {
    std::uint64_t incomeCents = 0;

    if (!PetoronParseMoneyCents([self.incomeInput stringValue], incomeCents)) {
        [self.licensePriceText setStringValue:@"License price 2%: invalid amount"];
        return;
    }

    const std::uint64_t licenseCents = incomeCents / 50;

    if (incomeCents == 0) {
        [self.licensePriceText setStringValue:@"License price 2%: -"];
        return;
    }

    [self.licensePriceText setStringValue:PetoronNs("License price 2%: $" + PetoronMoney(licenseCents))];
}

- (void)loadInputFile:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];

    if ([panel runModal] != NSModalResponseOK) {
        return;
    }

    NSError* error = nil;
    NSData* data = [NSData dataWithContentsOfURL:[panel URL] options:0 error:&error];

    if (error != nil || data == nil || [data length] == 0) {
        [self showError:@"Could not load official income file."];
        return;
    }

    self.loadedIncomeBytes = data;
    self.loadedIncomeName = [[[panel URL] path] lastPathComponent];

    [self.fileText setStringValue:
        [NSString stringWithFormat:
            @"Attached: %@\nSize: %lu bytes",
            self.loadedIncomeName,
            (unsigned long)[data length]]
    ];
    [self.statusText setStringValue:@"Official income file loaded. Now create License Note."];
}

- (void)clearInput:(id)sender {
    self.loadedIncomeBytes = nil;
    self.loadedIncomeName = nil;
    self.currentNoteBytes = nil;
    self.currentCommitment = nil;

    [self.incomeInput setStringValue:@""];
    [self.contractInput setStringValue:@""];
    [self.fileText setStringValue:@"No official file loaded"];
    [self.licensePriceText setStringValue:@"License price 2%: -"];
    [self.commitmentText setStringValue:@"Contract calldata commitment: -"];
    [self.statusText setStringValue:@"Cleared."];
    [self.saveButton setEnabled:NO];
    [self.commitmentCopyButton setEnabled:NO];
}

- (void)generateNote:(id)sender {
    std::uint64_t incomeCents = 0;

    if (!PetoronParseMoneyCents([self.incomeInput stringValue], incomeCents)) {
        [self showError:@"Net income is too large. Maximum supported value is $999,999,999,999,999.99."];
        return;
    }

    const std::uint64_t licenseCents = incomeCents / 50;

    if (incomeCents == 0) {
        [self showError:@"Enter net income first."];
        return;
    }

    if (self.loadedIncomeBytes == nil || [self.loadedIncomeBytes length] == 0) {
        [self showError:@"Load official annual net income file first."];
        return;
    }

    NSString* contractNs = [[self.contractInput stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (contractNs == nil || [contractNs length] < 3) {
        [self showError:@"Enter smart contract address first."];
        return;
    }

    std::vector<std::uint8_t> fileBytes;
    const auto* rawFileBytes = static_cast<const std::uint8_t*>([self.loadedIncomeBytes bytes]);
    fileBytes.assign(rawFileBytes, rawFileBytes + [self.loadedIncomeBytes length]);

    const auto fileDigest = PetoronDigest("PETORON_LICENSE_FILE_V1:", fileBytes);

    std::vector<std::uint8_t> amountBytes;
    PetoronAppendString(amountBytes, std::to_string(incomeCents));
    const auto amountDigest = PetoronDigest("PETORON_LICENSE_AMOUNT_V1:", amountBytes);

    std::vector<std::uint8_t> material;
    PetoronAppendString(material, "PETORON_LICENSE_NOTE_V1|");
    PetoronAppendString(material, std::to_string(incomeCents));
    PetoronAppendString(material, "|");
    PetoronAppendString(material, std::to_string(licenseCents));
    PetoronAppendString(material, "|");
    PetoronAppendString(material, std::string([contractNs UTF8String]));
    PetoronAppendString(material, "|");
    PetoronAppendString(material, PetoronHex32(fileDigest));
    PetoronAppendString(material, "|");
    PetoronAppendString(material, PetoronHex32(amountDigest));

    const auto commitmentDigest = PetoronDigest("PETORON_LICENSE_CALLDATA_COMMITMENT_V1:", material);
    const std::string commitmentHex = PetoronHex32(commitmentDigest);

    std::vector<std::uint8_t> note;
    PetoronAppendString(note, "PNOTE_LICENSE_V1");
    PetoronAppendU32LE(note, 1);
    PetoronAppendDigest32(note, fileDigest);
    PetoronAppendDigest32(note, amountDigest);
    PetoronAppendU64LE(note, licenseCents);
    PetoronAppendBinaryString(note, std::string([contractNs UTF8String]));
    PetoronAppendDigest32(note, commitmentDigest);

    self.currentNoteBytes = [NSData dataWithBytes:note.data() length:note.size()];
    self.currentCommitment = PetoronNs(commitmentHex);

    [self.commitmentText setStringValue:PetoronNs("Contract calldata commitment:\n" + commitmentHex)];
    [self.statusText setStringValue:PetoronNs("License note ready. License price: $" + PetoronMoney(licenseCents) + ". Copy commitment into contract calldata.")];

    [self.saveButton setEnabled:YES];
    [self.commitmentCopyButton setEnabled:YES];
}

- (void)saveNote:(id)sender {
    if (self.currentNoteBytes == nil || [self.currentNoteBytes length] == 0) {
        [self showError:@"Create License Note first."];
        return;
    }

    NSSavePanel* panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:[NSString stringWithFormat:@"petoron-license-%s.pnote", PetoronNowStamp().c_str()]];

    if ([panel runModal] != NSModalResponseOK) {
        return;
    }

    NSError* error = nil;
    [self.currentNoteBytes writeToURL:[panel URL] options:NSDataWritingAtomic error:&error];

    if (error != nil) {
        [self showError:@"Could not save .pnote file."];
        return;
    }

    [self.statusText setStringValue:@"License .pnote saved. Keep it together with the original income file."];
}

@end
