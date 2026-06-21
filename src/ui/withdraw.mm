/*
Copyright (c) Ivan Alekseev

Licensed under the PetoronAI Community License (PCL)
or a valid PetoronAI Commercial License.
*/

#import "withdraw.hpp"

#include "proof/commitment/petoron_zk_commitment.hpp"

#include <array>
#include <cctype>
#include <cstdint>
#include <iomanip>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

static NSString* PetoronWithdrawNs(const std::string& value) {
    return [NSString stringWithUTF8String:value.c_str()];
}

template <std::size_t N>
static std::string PetoronWithdrawHex(const std::array<std::uint8_t, N>& data) {
    std::ostringstream out;
    out << "0x";
    for (const auto byte : data) {
        out << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(byte);
    }
    return out.str();
}

static std::array<std::uint8_t, 32> PetoronWithdrawDigest32(const std::string& domain, const std::vector<std::uint8_t>& payload) {
    std::vector<std::uint8_t> input;
    input.insert(input.end(), domain.begin(), domain.end());
    input.insert(input.end(), payload.begin(), payload.end());
    const auto digest = petoron::zk::PetoronZkCommitment::commit_bytes(std::span<const std::uint8_t>(input.data(), input.size()));
    std::array<std::uint8_t, 32> out{};
    for (std::size_t i = 0; i < out.size(); ++i) {
        out[i] = digest[i];
    }
    return out;
}

static std::uint32_t PetoronReadU32(const std::vector<std::uint8_t>& data, std::size_t& offset) {
    if (offset + 4 > data.size()) {
        throw std::runtime_error("bad note");
    }
    std::uint32_t value = 0;
    for (int i = 0; i < 4; ++i) {
        value |= static_cast<std::uint32_t>(data[offset++]) << (i * 8);
    }
    return value;
}

static std::uint64_t PetoronReadU64(const std::vector<std::uint8_t>& data, std::size_t& offset) {
    if (offset + 8 > data.size()) {
        throw std::runtime_error("bad note");
    }
    std::uint64_t value = 0;
    for (int i = 0; i < 8; ++i) {
        value |= static_cast<std::uint64_t>(data[offset++]) << (i * 8);
    }
    return value;
}

static std::string PetoronReadString(const std::vector<std::uint8_t>& data, std::size_t& offset) {
    const auto size = PetoronReadU32(data, offset);
    if (offset + size > data.size()) {
        throw std::runtime_error("bad note");
    }
    std::string value(reinterpret_cast<const char*>(data.data() + offset), size);
    offset += size;
    return value;
}

static void PetoronAppendU64(std::vector<std::uint8_t>& out, std::uint64_t value) {
    for (int i = 0; i < 8; ++i) {
        out.push_back(static_cast<std::uint8_t>((value >> (i * 8)) & 0xff));
    }
}

static void PetoronAppendU32(std::vector<std::uint8_t>& out, std::uint32_t value) {
    for (int i = 0; i < 4; ++i) {
        out.push_back(static_cast<std::uint8_t>((value >> (i * 8)) & 0xff));
    }
}

static void PetoronAppendString(std::vector<std::uint8_t>& out, const std::string& value) {
    PetoronAppendU32(out, static_cast<std::uint32_t>(value.size()));
    out.insert(out.end(), value.begin(), value.end());
}

static std::string PetoronMoneyText(std::uint64_t cents) {
    std::ostringstream out;
    out << "$" << (cents / 100) << "." << std::setw(2) << std::setfill('0') << (cents % 100);
    return out.str();
}


static std::string PetoronTextValue(const std::string& text, const std::string& key) {
    const std::string prefix = key + "=";
    std::size_t pos = text.find(prefix);

    if (pos == std::string::npos) {
        return "";
    }

    pos += prefix.size();
    std::size_t end = text.find('\n', pos);

    if (end == std::string::npos) {
        end = text.size();
    }

    return text.substr(pos, end - pos);
}

static int PetoronHexNibble(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }

    if (c >= 'a' && c <= 'f') {
        return 10 + c - 'a';
    }

    if (c >= 'A' && c <= 'F') {
        return 10 + c - 'A';
    }

    return -1;
}

static bool PetoronParseHex32(const std::string& hex, std::array<std::uint8_t, 32>& out) {
    if (hex.size() != 66 || hex[0] != '0' || hex[1] != 'x') {
        return false;
    }

    for (std::size_t i = 0; i < 32; ++i) {
        const int hi = PetoronHexNibble(hex[2 + i * 2]);
        const int lo = PetoronHexNibble(hex[3 + i * 2]);

        if (hi < 0 || lo < 0) {
            return false;
        }

        out[i] = static_cast<std::uint8_t>((hi << 4) | lo);
    }

    return true;
}



static std::string PetoronFormatProofMoney(std::uint64_t cents) {
    const std::uint64_t dollars = cents / 100;
    const std::uint64_t frac = cents % 100;

    std::string whole = std::to_string(dollars);

    for (long long i = static_cast<long long>(whole.size()) - 3; i > 0; i -= 3) {
        whole.insert(static_cast<std::size_t>(i), ",");
    }

    std::ostringstream out;
    out << "$" << whole << "." << std::setw(2) << std::setfill('0') << frac;
    return out.str();
}

@interface PetoronWithdrawViewController ()
@property(nonatomic, strong) NSTextField* notePathText;
@property(nonatomic, strong) NSTextField* incomePathText;
@property(nonatomic, strong) NSTextField* statusText;
@property(nonatomic, strong) NSTextField* noteInfoText;
@property(nonatomic, strong) NSTextField* poolInfoText;
@property(nonatomic, strong) NSTextField* commitmentText;
@property(nonatomic, strong) NSTextField* nullifierText;
@property(nonatomic, strong) NSScrollView* outputScrollView;
@property(nonatomic, strong) NSTextView* outputTextView;
@property(nonatomic, strong) NSString* currentCallPreview;
@property(nonatomic, strong) NSButton* buildButton;
@property(nonatomic, strong) NSButton* resultCopyButton;
@property(nonatomic, strong) NSData* noteBytes;
@property(nonatomic, strong) NSData* incomeBytes;
@property(nonatomic, strong) NSString* incomeFileName;
@property(nonatomic) std::array<std::uint8_t, 32> noteFileDigest;
@property(nonatomic) std::array<std::uint8_t, 32> noteAmountDigest;
@property(nonatomic) std::uint64_t licenseCents;
@property(nonatomic) std::string contractAddress;
@property(nonatomic) std::string calldataCommitment;
@property(nonatomic) std::string noteIncomeFileName;
@end

@implementation PetoronWithdrawViewController

- (NSView*)makeView {
    NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 760, 660)];
    [content setWantsLayer:YES];
    [content.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:0.06 green:0.07 blue:0.09 alpha:1.0] CGColor]];

    NSTextField* title = [self label:@"Verify License" frame:NSMakeRect(30, 590, 520, 36) size:30 bold:YES];
    [content addSubview:title];

    NSTextField* subtitle = [self label:@"Load original income file and .pnote to generate local license proof." frame:NSMakeRect(32, 562, 650, 24) size:14 bold:NO];
    [subtitle setTextColor:[NSColor colorWithCalibratedWhite:0.62 alpha:1.0]];
    [content addSubview:subtitle];

    NSView* card = [[NSView alloc] initWithFrame:NSMakeRect(30, 300, 700, 210)];
    [card setWantsLayer:YES];
    [card.layer setCornerRadius:18];
    [card.layer setBackgroundColor:[[NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.18 alpha:1.0] CGColor]];
    [content addSubview:card];

    [content addSubview:[self label:@"Note file" frame:NSMakeRect(60, 455, 120, 24) size:14 bold:YES]];
    self.notePathText = [self outputField:NSMakeRect(200, 452, 390, 28) value:@"No .pnote loaded"];
    [content addSubview:self.notePathText];

    NSButton* loadButton = [self button:@"Load .pnote" frame:NSMakeRect(605, 450, 110, 32) action:@selector(loadNote:)];
    [content addSubview:loadButton];

    [content addSubview:[self label:@"Income file" frame:NSMakeRect(60, 410, 120, 24) size:14 bold:YES]];

    self.incomePathText = [self label:@"No income file loaded" frame:NSMakeRect(200, 382, 430, 46) size:13 bold:NO];
    [self.incomePathText setUsesSingleLineMode:NO];
    [self.incomePathText setLineBreakMode:NSLineBreakByWordWrapping];
    [self.incomePathText setTextColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0]];
    [content addSubview:self.incomePathText];
    NSButton* loadIncomeButton = [self button:@"Load File" frame:NSMakeRect(605, 405, 110, 32) action:@selector(loadIncomeFile:)];
    [content addSubview:loadIncomeButton];

    self.buildButton = [self button:@"Generate Proof" frame:NSMakeRect(60, 340, 210, 36) action:@selector(buildWithdraw:)];
    [self.buildButton setEnabled:NO];
    [content addSubview:self.buildButton];

    self.noteInfoText = [self label:@"Loaded note: -" frame:NSMakeRect(60, 300, 620, 24) size:13 bold:NO];
    [self.noteInfoText setTextColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0]];
    [content addSubview:self.noteInfoText];

    self.poolInfoText = [self label:@"License proof input: -" frame:NSMakeRect(30, 248, 690, 24) size:13 bold:NO];
    [self.poolInfoText setTextColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0]];
    [content addSubview:self.poolInfoText];

    self.commitmentText = [self outputField:NSMakeRect(30, 206, 560, 34) value:@"Income file fingerprint: -"];
    [content addSubview:self.commitmentText];

    self.nullifierText = [self outputField:NSMakeRect(30, 158, 560, 42) value:@"Amount fingerprint: -"];
    [content addSubview:self.nullifierText];

    self.statusText = [self label:@"Ready. Load .pnote and original income file." frame:NSMakeRect(30, 130, 690, 24) size:13 bold:NO];
    [self.statusText setTextColor:[NSColor colorWithCalibratedWhite:0.70 alpha:1.0]];
    [content addSubview:self.statusText];

    self.outputScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(30, 66, 560, 70)];
    [self.outputScrollView setHasVerticalScroller:YES];
    [self.outputScrollView setHasHorizontalScroller:YES];
    [self.outputScrollView setBorderType:NSBezelBorder];

    self.outputTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 540, 70)];
    [self.outputTextView setEditable:NO];
    [self.outputTextView setSelectable:YES];
    [self.outputTextView setFont:[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular]];
    [self.outputTextView setString:@"Proof output: -"];

    [self.outputScrollView setDocumentView:self.outputTextView];
    [content addSubview:self.outputScrollView];

    self.resultCopyButton = [self button:@"Copy" frame:NSMakeRect(605, 86, 90, 30) action:@selector(copyResult:)];
    [self.resultCopyButton setEnabled:NO];
    [content addSubview:self.resultCopyButton];

    NSTextField* warning = [self label:@"Proof can be generated only when the original income file matches the .pnote fingerprint." frame:NSMakeRect(30, 20, 690, 20) size:12 bold:YES];
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
    return button;
}

- (void)copyText:(NSString*)text {
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];
}

- (void)refreshBuildState {
    [self.buildButton setEnabled:(self.noteBytes != nil && self.incomeBytes != nil)];
}

- (void)loadIncomeFile:(id)sender {
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
        [self.statusText setStringValue:@"Could not load income file."];
        return;
    }
    self.incomeBytes = data;
    self.incomeFileName = [[[panel URL] path] lastPathComponent];

    [self.incomePathText setStringValue:
        [NSString stringWithFormat:
            @"Attached: %@\nSize: %lu bytes",
            self.incomeFileName,
            (unsigned long)[data length]]
    ];

    [self.statusText setStringValue:
        [NSString stringWithFormat:
            @"Income file loaded: %@ (%lu bytes).",
            self.incomeFileName,
            (unsigned long)[data length]]
    ];

    [self refreshBuildState];
}

- (void)loadNote:(id)sender {
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
        [self.statusText setStringValue:@"Could not load .pnote."];
        return;
    }

    try {
        const auto* raw = static_cast<const std::uint8_t*>([data bytes]);
        std::vector<std::uint8_t> bytes(raw, raw + [data length]);

        const std::string magic = "PNOTE_LICENSE_V1";

        if (bytes.size() < magic.size() + 4 + 32 + 32 + 8 + 4 + 32) {
            [self.statusText setStringValue:@"Invalid binary .pnote size."];
            return;
        }

        std::size_t offset = 0;

        for (char c : magic) {
            if (bytes[offset++] != static_cast<std::uint8_t>(c)) {
                [self.statusText setStringValue:@"Invalid .pnote magic. Expected binary PNOTE_LICENSE_V1."];
                return;
            }
        }

        const auto version = PetoronReadU32(bytes, offset);

        if (version != 1) {
            [self.statusText setStringValue:@"Unsupported .pnote version."];
            return;
        }

        std::array<std::uint8_t, 32> parsedFileDigest{};
        std::array<std::uint8_t, 32> parsedAmountDigest{};
        std::array<std::uint8_t, 32> parsedCommitmentDigest{};

        for (std::size_t i = 0; i < 32; ++i) {
            parsedFileDigest[i] = bytes[offset++];
        }

        for (std::size_t i = 0; i < 32; ++i) {
            parsedAmountDigest[i] = bytes[offset++];
        }

        const auto parsedLicenseCents = PetoronReadU64(bytes, offset);
        const auto parsedContract = PetoronReadString(bytes, offset);

        if (offset + 32 > bytes.size()) {
            [self.statusText setStringValue:@"Invalid .pnote commitment field."];
            return;
        }

        for (std::size_t i = 0; i < 32; ++i) {
            parsedCommitmentDigest[i] = bytes[offset++];
        }

        if (parsedLicenseCents == 0 || parsedContract.empty()) {
            [self.statusText setStringValue:@"Invalid .pnote fields."];
            return;
        }

        self.noteFileDigest = parsedFileDigest;
        self.noteAmountDigest = parsedAmountDigest;
        self.licenseCents = parsedLicenseCents;
        self.contractAddress = parsedContract;
        self.calldataCommitment = PetoronWithdrawHex(parsedCommitmentDigest);
        self.noteIncomeFileName = "Original income file required";
        self.noteBytes = data;

        [self.notePathText setStringValue:[[[panel URL] path] lastPathComponent]];
        [self.noteInfoText setStringValue:PetoronWithdrawNs("Loaded note: license " + PetoronMoneyText(self.licenseCents) + " | contract " + self.contractAddress)];
        [self.poolInfoText setStringValue:@"Expected input: attach the original official income file used to create this .pnote."];
        [self.commitmentText setStringValue:PetoronWithdrawNs("Income file fingerprint: " + PetoronWithdrawHex(self.noteFileDigest))];
        [self.nullifierText setStringValue:PetoronWithdrawNs("Amount fingerprint: " + PetoronWithdrawHex(self.noteAmountDigest))];
        [self.statusText setStringValue:@"Binary .pnote loaded. Now load original income file."];
        [self refreshBuildState];
    } catch (...) {
        [self.statusText setStringValue:@"Invalid binary .pnote."];
        return;
    }
}

- (void)buildWithdraw:(id)sender {
    if (self.noteBytes == nil || self.incomeBytes == nil) {
        [self.statusText setStringValue:@"Load .pnote and original income file first."];
        return;
    }

    const auto* raw = static_cast<const std::uint8_t*>([self.incomeBytes bytes]);
    const std::vector<std::uint8_t> filePayload(raw, raw + [self.incomeBytes length]);
    const auto fileDigest = PetoronWithdrawDigest32("PETORON_LICENSE_FILE_V1:", filePayload);

    if (fileDigest != self.noteFileDigest) {
        [self.statusText setStringValue:@"Income file does not match .pnote fingerprint."];
        [self.outputTextView setString:@"Proof output: rejected"];
        [self.resultCopyButton setEnabled:NO];
        return;
    }

    const auto noteFileDigest = self.noteFileDigest;
    const auto noteAmountDigest = self.noteAmountDigest;
    const auto licenseCents = self.licenseCents;
    const auto contractAddress = self.contractAddress;

    std::vector<std::uint8_t> proofPayload;
    proofPayload.insert(proofPayload.end(), noteFileDigest.begin(), noteFileDigest.end());
    proofPayload.insert(proofPayload.end(), noteAmountDigest.begin(), noteAmountDigest.end());
    PetoronAppendU64(proofPayload, licenseCents);
    PetoronAppendString(proofPayload, contractAddress);

    const auto proofId = PetoronWithdrawDigest32("PETORON_LICENSE_PROOF_V1:", proofPayload);

    const std::string proof =
        "PetoronAI License Proof\n"
        "notice=requires_original_income_file_and_matching_pnote\n"
        "warning=if_either_file_is_lost_license_proof_cannot_be_regenerated\n"
        "license_price=" + PetoronFormatProofMoney(licenseCents) +
        "\ncontract=" + contractAddress +
        "\ncalldata_commitment=" + self.calldataCommitment +
        "\nincome_file_fingerprint=" + PetoronWithdrawHex(noteFileDigest) +
        "\namount_fingerprint=" + PetoronWithdrawHex(noteAmountDigest) +
        "\nproof_id=" + PetoronWithdrawHex(proofId);

    self.currentCallPreview = PetoronWithdrawNs(proof);
    [self.outputTextView setString:self.currentCallPreview];
    [self.resultCopyButton setEnabled:YES];
    [self.statusText setStringValue:@"License proof generated locally."];
}

- (void)copyResult:(id)sender {
    [self copyText:[self.outputTextView string]];
    [self.statusText setStringValue:@"Proof copied."];
}

@end
