#import "VMMemoryFeedback.h"
#import "../memory/VMMemoryBrowserViewController.h"
#import "include/VMMemoryEngine.h"
#import "include/VMLocalization.h"
#import "include/VMFavoriteManager.h"
#import "include/VMLockEngine.h"
#import "../memory/VMHexEditorViewController.h"
#import "../memory/VMMemoryActionSheet.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "VMStringMemorySession.h"
#include <errno.h>
#define TR(key) ([[VMLocalization shared] localizedString:key])
#define ROW_HEIGHT 60.0
#define PAGE_COUNT 100
#define MAX_BUFFER_ROWS 1000
#define PRELOAD_THRESHOLD 400
#define STR_PRELOAD_THRESHOLD 120
#define NUMERIC_REFRESH_INTERVAL 0.5
#define STRING_REFRESH_INTERVAL 1.0

static BOOL VMParseBrowserInteger(NSString *input, BOOL signedOffset, uint64_t *magnitude, BOOL *negative) {
    NSString *text = [(input ?: @"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL minus = [text hasPrefix:@"-"];
    if ([text hasPrefix:@"+"] || minus) {
        if (!signedOffset) return NO;
        text = [text substringFromIndex:1];
    }
    if (text.length == 0) return NO;
    int base = [text.lowercaseString hasPrefix:@"0x"] ||
        [text rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF"]].location != NSNotFound ? 16 : 10;
    if ([text.lowercaseString hasPrefix:@"0x"]) text = [text substringFromIndex:2];
    if (text.length == 0) return NO;
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:base == 16 ? @"0123456789abcdefABCDEF" : @"0123456789"];
    if ([text rangeOfCharacterFromSet:digits.invertedSet].location != NSNotFound) return NO;
    errno = 0;
    char *end = NULL;
    uint64_t value = strtoull(text.UTF8String, &end, base);
    if (errno == ERANGE || !end || *end) return NO;
    if (magnitude) *magnitude = value;
    if (negative) *negative = minus;
    return YES;
}

static BOOL VMResolveBrowserOffset(NSString *input, uint64_t base, uint64_t *result) {
    uint64_t magnitude = 0;
    BOOL negative = NO;
    if (!VMParseBrowserInteger(input, YES, &magnitude, &negative)) return NO;
    if ((negative && magnitude > base) || (!negative && magnitude > UINT64_MAX - base)) return NO;
    *result = negative ? base - magnitude : base + magnitude;
    return YES;
}

static NSAttributedString *VMBrowserAddressText(uint64_t address, uint64_t targetAddress, BOOL emphasized) {
    int64_t offset = (int64_t)address - (int64_t)targetAddress;
    NSString *line1 = [NSString stringWithFormat:@"0x%llX", address];
    NSString *line2 = nil;

    if (offset == 0) {
        line2 = @"BASE | +0x0 | +0";
    } else {
        uint64_t magnitude = (uint64_t)llabs(offset);
        NSString *hexPart = [NSString stringWithFormat:@"%@0x%llX", offset > 0 ? @"+" : @"-", magnitude];
        NSString *decPart = [NSString stringWithFormat:@"%@%lld", offset > 0 ? @"+" : @"-", magnitude];
        line2 = [NSString stringWithFormat:@"%@ | %@", hexPart, decPart];
    }

    UIColor *primaryColor = emphasized ? [UIColor labelColor] : [UIColor labelColor];
    UIColor *secondaryColor = emphasized ? [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.95] : [UIColor secondaryLabelColor];
    UIFont *primaryFont = [UIFont monospacedSystemFontOfSize:14 weight:emphasized ? UIFontWeightBold : UIFontWeightRegular];
    UIFont *secondaryFont = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineBreakMode = NSLineBreakByTruncatingMiddle;
    style.lineSpacing = 1.0;

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", line1, line2]];
    [text addAttributes:@{
        NSFontAttributeName: primaryFont,
        NSForegroundColorAttributeName: primaryColor,
        NSParagraphStyleAttributeName: style
    } range:NSMakeRange(0, line1.length)];
    [text addAttributes:@{
        NSFontAttributeName: secondaryFont,
        NSForegroundColorAttributeName: secondaryColor,
        NSParagraphStyleAttributeName: style
    } range:NSMakeRange(line1.length + 1, line2.length)];
    return text;
}
@interface VMMemoryBrowserViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataList;
@property (nonatomic, assign) uint64_t minAddr;
@property (nonatomic, assign) uint64_t maxAddr;
@property (nonatomic, assign) int typeSize;
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) uint64_t targetAddress;
@property (nonatomic, assign) BOOL isInitialLoad;
@property (nonatomic, assign) BOOL isStrMode;
@property (nonatomic, strong) NSMutableArray *strDataList;
@property (nonatomic, assign) uint64_t strMinAddr;  // str扫描范围下界
@property (nonatomic, assign) uint64_t strMaxAddr;  // str扫描范围上界

@property (nonatomic, strong) UIBarButtonItem *originalRightBarButton;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) UILabel *baseAddressLabel;
@property (nonatomic, assign) NSUInteger loadGeneration;
@property (nonatomic, assign) pid_t browsingPid;
@property (nonatomic, assign) mach_port_t browsingTask;
@end
@implementation VMMemoryBrowserViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [VMUIHelper canvasColor];
    self.title = TR(@"Mod_Menu_Value");
    self.browsingPid = [VMMemoryEngine shared].targetPid;
    self.browsingTask = [VMMemoryEngine shared].targetTask;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkBrowsingTarget) name:@"VMProcessChangedNotification" object:nil];
    self.targetAddress = self.address;
    self.isInitialLoad = YES;

    self.isMultiSelectMode = NO;
    self.selectedAddresses = [NSMutableSet set];

    NSArray *types = @[TR(@"Type_I8"), TR(@"Type_I16"), TR(@"Type_I32"), TR(@"Type_I64"), TR(@"Type_F32"), TR(@"Type_F64"), @"Str"];
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:types];
    [self.typeSegment setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]} forState:UIControlStateNormal];

    NSInteger segIdx = 2;
    switch (self.type) {
      case VMDataTypeInt8: case VMDataTypeUInt8: segIdx = 0; break;
      case VMDataTypeInt16: case VMDataTypeUInt16: segIdx = 1; break;
      case VMDataTypeInt32: case VMDataTypeUInt32: segIdx = 2; break;
      case VMDataTypeInt64: case VMDataTypeUInt64: segIdx = 3; break;
      case VMDataTypeFloat: segIdx = 4; break;
      case VMDataTypeDouble: segIdx = 5; break;
      case VMDataTypeString: segIdx = 6; break;
      default: segIdx = 2; break;
    }
    self.typeSegment.selectedSegmentIndex = segIdx;
    [self.typeSegment addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];
    self.typeSegment.accessibilityLabel = TR(@"Lock_Select_Type_Title");

    [self updateTypeSize];

    self.minAddr = self.targetAddress - MIN(self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
    self.maxAddr = self.targetAddress + MIN(UINT64_MAX - self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));

    self.dataList = [NSMutableArray array];
    self.strDataList = [NSMutableArray array];

    if (self.isStrMode) {
        [self loadStrData];
    } else {
        [self loadInitialData];
    }
    [self setupUI];

    [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToTargetAndHighlight];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.isInitialLoad = NO;
        });
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkBrowsingTarget];
    if ([self browsingTargetIsValid]) [self startAutoRefreshTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopAutoRefreshTimer];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAutoRefreshTimer];
}

- (BOOL)browsingTargetIsValid {
    return self.browsingTask != MACH_PORT_NULL && self.browsingPid == [VMMemoryEngine shared].targetPid && self.browsingTask == [VMMemoryEngine shared].targetTask;
}

- (void)checkBrowsingTarget {
    if ([self browsingTargetIsValid]) return;
    self.loadGeneration++;
    self.isLoading = NO;
    [self stopAutoRefreshTimer];
    [self.dataList removeAllObjects];
    [self.strDataList removeAllObjects];
    self.typeSegment.superview.userInteractionEnabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.tableView.allowsSelection = NO;
    self.tableView.backgroundView = [VMUIHelper emptyStateWithTitle:TR(@"Err_Not_Connected") message:TR(@"Str_Target_Changed") symbol:@"link.badge.plus"];
    [self.tableView reloadData];
}

- (void)setupUI {
    UIView *card = [UIView new];
    [VMUIHelper styleCard:card];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:card];
    self.baseAddressLabel = [UILabel new];
    self.baseAddressLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightSemibold];
    self.baseAddressLabel.textColor = [VMUIHelper accentColor];
    self.baseAddressLabel.numberOfLines = 1;
    self.baseAddressLabel.adjustsFontSizeToFitWidth = YES;
    self.baseAddressLabel.minimumScaleFactor = 0.85;
    UIButton *jump = [UIButton buttonWithType:UIButtonTypeSystem];
    [jump setTitle:TR(@"Btn_Jump") forState:UIControlStateNormal];
    [VMUIHelper styleButton:jump primary:NO];
    [jump addTarget:self action:@selector(promptJump) forControlEvents:UIControlEventTouchUpInside];
    [jump.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    UIStackView *addressRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.baseAddressLabel, jump]];
    addressRow.spacing = 12;
    [jump setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[addressRow, self.typeSegment]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = ROW_HEIGHT;
    self.tableView.backgroundColor = [VMUIHelper canvasColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    self.tableView.tableFooterView = [UIView new];
    self.tableView.decelerationRate = self.isStrMode ? UIScrollViewDecelerationRateFast : UIScrollViewDecelerationRateNormal;
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0;
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    longPress.delegate = self;
    [self.tableView addGestureRecognizer:longPress];
    [self.view addSubview:self.tableView];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:g.topAnchor constant:12],
        [card.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [self.typeSegment.heightAnchor constraintEqualToConstant:44],
        [self.tableView.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:8],
        [self.tableView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor]
    ]];
    UIBarButtonItem *moreBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] style:UIBarButtonItemStylePlain target:self action:@selector(showNavMenu)];
    moreBtn.accessibilityLabel = TR(@"Common_More");
    self.navigationItem.rightBarButtonItem = moreBtn;
    self.originalRightBarButton = moreBtn;
    [self updateBaseAddressLabel];
}

- (void)updateBaseAddressLabel {
    self.baseAddressLabel.text = [NSString stringWithFormat:@"0x%llX", self.targetAddress];
}

- (void)updateTypeSize {

    static const VMDataType typeMap[] = {
      VMDataTypeInt8, VMDataTypeInt16, VMDataTypeInt32, VMDataTypeInt64,
      VMDataTypeFloat, VMDataTypeDouble, VMDataTypeString
    };
    NSInteger idx = self.typeSegment.selectedSegmentIndex;
    if (idx >= 0 && idx < 7) {
      self.type = typeMap[idx];
    }
    self.isStrMode = (self.type == VMDataTypeString);
    if (self.tableView) {
      self.tableView.decelerationRate = self.isStrMode
          ? UIScrollViewDecelerationRateFast
          : UIScrollViewDecelerationRateNormal;
    }

    switch (self.type) {
      case VMDataTypeInt8: self.typeSize = 1; break;
      case VMDataTypeInt16: self.typeSize = 2; break;
      case VMDataTypeInt64: case VMDataTypeDouble: self.typeSize = 8; break;
      case VMDataTypeString: self.typeSize = 1; break;
      default: self.typeSize = 4; break;
    }
}

- (void)typeChanged:(UISegmentedControl *)seg {
    [self updateTypeSize];
    [self restartAutoRefreshTimerIfNeeded];
    if (self.isStrMode) {
        [self loadStrData];
        [self.tableView reloadData];
        [self scrollToTargetAndHighlight];
    } else {
        self.minAddr = self.targetAddress - MIN(self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
        self.maxAddr = self.targetAddress + MIN(UINT64_MAX - self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
        self.dataList = [NSMutableArray array];
        [self loadInitialData];
        [self.tableView reloadData];
        [self scrollToTargetAndHighlight];
    }
}

- (void)loadInitialData {
    self.loadGeneration++;
    self.isLoading = NO;
    [self updateBaseAddressLabel];
    int totalRows = (int)((self.maxAddr - self.minAddr) / self.typeSize);
    for (int i = 0; i <= totalRows; i++) {
        uint64_t addr = self.minAddr + (i * self.typeSize);
        NSString *val = [[VMMemoryEngine shared] readAddress:addr type:self.type];
        VMScanResultItem *item = [VMScanResultItem new];
        item.address = addr;
        item.valueStr = val;
        [self.dataList addObject:item];
    }
}

#define STR_SCAN_RANGE 0x10000
#define STR_MIN_LEN 4
#define STR_MAX_LEN 256

- (void)loadStrData {
    self.loadGeneration++;
    self.isLoading = NO;
    [self updateBaseAddressLabel];
    self.strDataList = [NSMutableArray array];

    uint64_t scanStart = (self.targetAddress > STR_SCAN_RANGE) ? (self.targetAddress - STR_SCAN_RANGE) : 0;
    uint64_t scanEnd = self.targetAddress + MIN(UINT64_MAX - self.targetAddress, (uint64_t)STR_SCAN_RANGE);

    self.strMinAddr = scanStart;
    self.strMaxAddr = scanEnd;

    VMScanResultItem *targetItem = [self stringItemAtAddress:self.targetAddress fallback:nil];
    if (targetItem) {
        [self.strDataList addObject:targetItem];
    }

    NSArray *results = [self scanStringsFrom:scanStart to:scanEnd];
    for (VMScanResultItem *item in results) {
        if (item.address == self.targetAddress) {
            if (self.strDataList.count > 0) {
                VMScanResultItem *existing = self.strDataList[0];
                existing.valueStr = item.valueStr;
                existing.originalSize = item.originalSize;
            } else {
                [self.strDataList addObject:item];
            }
            continue;
        }
        [self.strDataList addObject:item];
    }
    [self.strDataList sortUsingComparator:^NSComparisonResult(VMScanResultItem *a, VMScanResultItem *b) {
        return [@(a.address) compare:@(b.address)];
    }];
}

- (void)loadMoreStrData:(BOOL)next {
    if (self.isLoading) return;
    self.isLoading = YES;

    uint64_t rangeSize = STR_SCAN_RANGE;
    uint64_t scanStart, scanEnd;

    if (next) {
        scanStart = self.strMaxAddr;
        scanEnd = self.strMaxAddr + MIN(UINT64_MAX - self.strMaxAddr, rangeSize);
        self.strMaxAddr = scanEnd;
    } else {
        scanEnd = self.strMinAddr;
        scanStart = (self.strMinAddr > rangeSize) ? (self.strMinAddr - rangeSize) : 0;
        self.strMinAddr = scanStart;
    }

    NSUInteger generation = self.loadGeneration;
    pid_t targetPid = [VMMemoryEngine shared].targetPid;
    mach_port_t targetTask = [VMMemoryEngine shared].targetTask;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *results = [self scanStringsFrom:scanStart to:scanEnd];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.loadGeneration) return;
            if (targetPid != [VMMemoryEngine shared].targetPid || targetTask != [VMMemoryEngine shared].targetTask) { self.isLoading = NO; return; }
            if (results.count > 0) {
                if (next) {
                    [self.strDataList addObjectsFromArray:results];
                } else {
                    NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, results.count)];
                    [self.strDataList insertObjects:results atIndexes:idxSet];
                    // 保持滚动位置
                    CGFloat addedHeight = results.count * ROW_HEIGHT;
                    CGPoint offset = self.tableView.contentOffset;
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    [self.tableView reloadData];
                    [self.tableView setContentOffset:CGPointMake(offset.x, offset.y + addedHeight) animated:NO];
                    [CATransaction commit];
                    self.isLoading = NO;
                    return;
                }
                [self.tableView reloadData];
            }
            self.isLoading = NO;
        });
    });
}

- (NSArray *)scanStringsFrom:(uint64_t)scanStart to:(uint64_t)scanEnd {
    NSMutableArray *results = [NSMutableArray array];
    VMMemoryEngine *eng = [VMMemoryEngine shared];

    uint64_t pageSize = 0x4000;
    NSMutableData *fullData = [NSMutableData data];
    uint64_t actualStart = scanEnd;

    for (uint64_t addr = scanStart; addr < scanEnd; addr += MIN(pageSize, scanEnd - addr)) {
        uint64_t chunkLen = MIN(pageSize, scanEnd - addr);
        NSData *chunk = [eng readRawMemory:addr length:(NSUInteger)chunkLen];
        if (chunk && chunk.length > 0) {
            if (addr < actualStart) actualStart = addr;
            NSUInteger expectedLen = (NSUInteger)(addr - actualStart);
            if (fullData.length < expectedLen) {
                NSUInteger gapSize = expectedLen - fullData.length;
                void *zeros = calloc(1, gapSize);
                [fullData appendBytes:zeros length:gapSize];
                free(zeros);
            }
            [fullData appendData:chunk];
        }
    }

    if (fullData.length == 0) return results;

    NSArray<VMStringMemoryRecord *> *records = [VMStringMemorySession
        recordsInData:fullData atAddress:actualStart stringEncoding:self.stringEncoding
        alignmentAddress:self.targetAddress];
    for (VMStringMemoryRecord *record in records) {
        NSData *prefix = [record.bytes subdataWithRange:NSMakeRange(0, MIN(record.bytes.length, (NSUInteger)STR_MAX_LEN))];
        NSUInteger byteLength = 0;
        NSString *text = [VMStringMemorySession textPrefixInData:prefix stringEncoding:self.stringEncoding
                                                    byteLength:&byteLength terminated:NULL];
        if (byteLength < STR_MIN_LEN || !text) continue;
        VMScanResultItem *item = [VMScanResultItem new];
        item.address = record.address;
        item.valueStr = text;
        item.type = VMDataTypeString;
        item.stringEncoding = self.stringEncoding;
        item.originalSize = byteLength;
        [results addObject:item];
    }
    return results;
}

- (void)startAutoRefreshTimer {
    if (self.refreshTimer) return;
    NSTimeInterval interval = self.isStrMode ? STRING_REFRESH_INTERVAL : NUMERIC_REFRESH_INTERVAL;
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                         target:self
                                                       selector:@selector(refreshVisibleDataSilently)
                                                       userInfo:nil
                                                        repeats:YES];
    if ([self.refreshTimer respondsToSelector:@selector(setTolerance:)]) {
        self.refreshTimer.tolerance = 0.2;
    }
}

- (void)stopAutoRefreshTimer {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)restartAutoRefreshTimerIfNeeded {
    if (!self.refreshTimer) return;
    [self stopAutoRefreshTimer];
    [self startAutoRefreshTimer];
}

- (NSString *)readVisibleStringAtAddress:(uint64_t)address
                                fallback:(NSString *)fallback
                               lengthOut:(NSUInteger *)lengthOut {
    NSStringEncoding encoding = VMFoundationStringEncoding(self.stringEncoding);
    NSUInteger fallbackLen = [fallback lengthOfBytesUsingEncoding:encoding];
    NSUInteger terminatorSize = self.stringEncoding == VMStringEncodingUTF8 ? 1 : 2;
    NSUInteger readLength = MIN(MAX(fallbackLen + terminatorSize, (NSUInteger)64), (NSUInteger)STR_MAX_LEN);
    NSString *text = [[VMMemoryEngine shared] readStringAtAddress:address
                                                      encoding:self.stringEncoding maxBytes:readLength];
    if (!text) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback;
    }
    if (lengthOut) *lengthOut = [text lengthOfBytesUsingEncoding:encoding];
    return text;
}

- (VMScanResultItem *)stringItemAtAddress:(uint64_t)address fallback:(NSString *)fallback {
    NSUInteger len = 0;
    NSString *value = [self readVisibleStringAtAddress:address
                                             fallback:fallback
                                            lengthOut:&len];
    if (!value && !fallback) return nil;

    VMScanResultItem *item = [VMScanResultItem new];
    item.address = address;
    item.valueStr = value ?: (fallback ?: @"");
    item.type = VMDataTypeString;
    item.stringEncoding = self.stringEncoding;
    item.originalSize = len;
    return item;
}

- (void)refreshVisibleDataSilently {
    if (!self.isViewLoaded || !self.view.window || self.isLoading || self.isInitialLoad) return;
    if (self.tableView.dragging || self.tableView.decelerating) return;

    NSArray<NSIndexPath *> *visibleRows = [self.tableView indexPathsForVisibleRows];
    if (visibleRows.count == 0) return;

    NSMutableArray<NSIndexPath *> *changedRows = [NSMutableArray array];

    if (self.isStrMode) {
        for (NSIndexPath *indexPath in visibleRows) {
            if (indexPath.row >= self.strDataList.count) continue;
            VMScanResultItem *item = self.strDataList[indexPath.row];
            NSUInteger newLen = item.originalSize;
            NSString *newVal = [self readVisibleStringAtAddress:item.address
                                                       fallback:item.valueStr
                                                      lengthOut:&newLen];
            NSString *oldVal = item.valueStr ?: @"";
            NSString *safeNewVal = newVal ?: @"";
            if (item.originalSize != newLen || ![oldVal isEqualToString:safeNewVal]) {
                item.valueStr = safeNewVal;
                item.originalSize = newLen;
                [changedRows addObject:indexPath];
            }
        }
    } else {
        for (NSIndexPath *indexPath in visibleRows) {
            if (indexPath.row >= self.dataList.count) continue;
            VMScanResultItem *item = self.dataList[indexPath.row];
            NSString *newVal = [[VMMemoryEngine shared] readAddress:item.address type:self.type] ?: @"";
            NSString *oldVal = item.valueStr ?: @"";
            if (![oldVal isEqualToString:newVal]) {
                item.valueStr = newVal;
                [changedRows addObject:indexPath];
            }
        }
    }

    if (changedRows.count == 0) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.tableView reloadRowsAtIndexPaths:changedRows withRowAnimation:UITableViewRowAnimationNone];
    [CATransaction commit];
}

- (void)doRefreshValues {
    [self refreshCurrentData];
}

- (void)refreshCurrentData {
    if (self.isStrMode) {
        [self loadStrData];
        [self.tableView reloadData];
        return;
    }
    for (VMScanResultItem *item in self.dataList) {
        item.valueStr = [[VMMemoryEngine shared] readAddress:item.address type:self.type];
    }
    [self.tableView reloadData];
}

- (void)showNavMenu {
    if (![self browsingTargetIsValid]) { [self checkBrowsingTarget]; return; }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:TR(@"Pop_Options") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    VMMemoryEngine *engine = [VMMemoryEngine shared];
    if ([engine canUndoLastManualWriteBatch]) {
        NSString *title = [NSString stringWithFormat:@"%@ (%lu)",
                                                     TR(@"Undo_Last_Modify"),
                                                     (unsigned long)[engine lastManualWriteBatchCount]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            NSUInteger restored = [engine undoLastManualWriteBatch];
            [self refreshCurrentData];
            [self showToast:restored > 0 ? TR(@"Undo_Success") : TR(@"Undo_Failed")];
        }]];
    }
    if (!self.isStrMode) {
        [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Batch_Select") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self enterMultiSelectMode];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Results_Refreshed") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self refreshCurrentData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Jump") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self promptJump];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Browser_Jump_Offset") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self promptJumpOffset];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)promptJump {
    if (![self browsingTargetIsValid]) { [self checkBrowsingTarget]; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Btn_Jump") message:@"0x..." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.keyboardType = UIKeyboardTypeASCIICapable;
        tf.placeholder = @"0x1234 / 1234";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {

        NSString *txt = alert.textFields.firstObject.text;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            uint64_t addr = 0;
            if (!VMParseBrowserInteger(txt, NO, &addr, NULL) || addr == 0) {
                [self showToast:TR(@"Ptr_Error_Invalid_Target")];
                return;
            }
            self.targetAddress = addr;
            if (self.isStrMode) {
                [self loadStrData];
            } else {
                self.minAddr = self.targetAddress - MIN(self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
                self.maxAddr = self.targetAddress + MIN(UINT64_MAX - self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
                self.dataList = [NSMutableArray array];
                [self loadInitialData];
            }
            [self.tableView reloadData];
            [self scrollToTargetAndHighlight];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptJumpOffset {
    if (![self browsingTargetIsValid]) { [self checkBrowsingTarget]; return; }
    NSString *msg = [NSString stringWithFormat:TR(@"Browser_Jump_Offset_Msg"), self.targetAddress];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Browser_Jump_Offset") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"+8, -16, +0x40, 0x1A2B";
        tf.keyboardType = UIKeyboardTypeASCIICapable;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *input = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) return;

        uint64_t newAddr = 0;
        if (!VMResolveBrowserOffset(input, self.targetAddress, &newAddr) || newAddr == 0) {
            [self showToast:TR(@"Ptr_Error_Invalid_Target")];
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.targetAddress = newAddr;
            if (self.isStrMode) {
                [self loadStrData];
            } else {
                self.minAddr = self.targetAddress - MIN(self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
                self.maxAddr = self.targetAddress + MIN(UINT64_MAX - self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
                self.dataList = [NSMutableArray array];
                [self loadInitialData];
            }
            [self.tableView reloadData];
            [self scrollToTargetAndHighlight];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.isLoading || self.isInitialLoad) return;

    CGFloat y = scrollView.contentOffset.y;
    CGFloat h = scrollView.frame.size.height;
    CGFloat contentH = scrollView.contentSize.height;

    if (self.isStrMode) {
        if (!scrollView.isDragging) return;
        CGFloat velocityY = [scrollView.panGestureRecognizer velocityInView:scrollView].y;
        if (y < STR_PRELOAD_THRESHOLD && velocityY > 0) {
            [self loadMoreStrData:NO];
        } else if (y > contentH - h - STR_PRELOAD_THRESHOLD && velocityY < 0) {
            [self loadMoreStrData:YES];
        }
        return;
    }

    if (y < PRELOAD_THRESHOLD) {
        [self loadMoreData:NO];
    }
    else if (y > contentH - h - PRELOAD_THRESHOLD) {
        [self loadMoreData:YES];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
    if (!self.isStrMode || !targetContentOffset) return;

    CGFloat currentY = scrollView.contentOffset.y;
    CGFloat maxTravel = MAX(ROW_HEIGHT * 3.0, scrollView.bounds.size.height * 0.75);
    CGFloat minY = -scrollView.adjustedContentInset.top;
    CGFloat maxY = MAX(minY, scrollView.contentSize.height - scrollView.bounds.size.height +
                             scrollView.adjustedContentInset.bottom);
    CGFloat limitedY = MIN(MAX(targetContentOffset->y, currentY - maxTravel),
                           currentY + maxTravel);
    targetContentOffset->y = MIN(MAX(limitedY, minY), maxY);
}

- (void)loadMoreData:(BOOL)next {
    if (self.isLoading) return;
    const int step = self.typeSize;
    const VMDataType type = self.type;
    const uint64_t boundary = next ? self.maxAddr : self.minAddr;
    NSUInteger count = MIN((uint64_t)PAGE_COUNT, (next ? UINT64_MAX - boundary : boundary) / step);
    if (count == 0) return;
    self.isLoading = YES;
    const NSUInteger generation = self.loadGeneration;
    const pid_t pid = [VMMemoryEngine shared].targetPid;
    const mach_port_t task = [VMMemoryEngine shared].targetTask;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newRows = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger i = 0; i < count; i++) {
            if (pid != [VMMemoryEngine shared].targetPid || task != [VMMemoryEngine shared].targetTask) break;
            uint64_t addr = next ? boundary + (i + 1) * step : boundary - (count - i) * step;
            VMScanResultItem *item = [VMScanResultItem new];
            item.address = addr;
            item.valueStr = [[VMMemoryEngine shared] readAddress:addr type:type];
            [newRows addObject:item];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.loadGeneration) return;
            self.isLoading = NO;
            if (pid != [VMMemoryEngine shared].targetPid || task != [VMMemoryEngine shared].targetTask || newRows.count == 0) return;
            CGPoint offset = self.tableView.contentOffset;
            NSInteger offsetRows = 0;
            if (next) [self.dataList addObjectsFromArray:newRows];
            else {
                [self.dataList insertObjects:newRows atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newRows.count)]];
                offsetRows = newRows.count;
            }
            if (self.dataList.count > MAX_BUFFER_ROWS) {
                NSUInteger extra = self.dataList.count - MAX_BUFFER_ROWS;
                [self.dataList removeObjectsInRange:NSMakeRange(next ? 0 : MAX_BUFFER_ROWS, extra)];
                if (next) offsetRows -= extra;
            }
            self.minAddr = ((VMScanResultItem *)self.dataList.firstObject).address;
            self.maxAddr = ((VMScanResultItem *)self.dataList.lastObject).address;
            self.isLoading = YES;
            [UIView performWithoutAnimation:^{
                [self.tableView reloadData];
                [self.tableView layoutIfNeeded];
                self.tableView.contentOffset = CGPointMake(offset.x, offset.y + offsetRows * ROW_HEIGHT);
            }];
            self.isLoading = NO;
        });
    });
}

- (void)scrollToTargetAndHighlight {
    NSInteger targetIndex = -1;
    NSArray *list = self.isStrMode ? self.strDataList : self.dataList;
    for (int i = 0; i < list.count; i++) {
        VMScanResultItem *item = list[i];
        if (item.address == self.targetAddress) { targetIndex = i; break; }
    }

    if (targetIndex >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:targetIndex inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (cell) {
                UIView *bgView = [[UIView alloc] initWithFrame:cell.bounds];
                bgView.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.3];
                [cell insertSubview:bgView atIndex:0];

                [UIView animateWithDuration:1.0 delay:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    bgView.alpha = 0;
                } completion:^(BOOL finished) {
                    [bgView removeFromSuperview];
                }];
            }
        });
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isStrMode ? self.strDataList.count : self.dataList.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isStrMode) {
        static NSString *strIdent = @"BrowserStrCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:strIdent];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:strIdent];
            cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
            cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        }
        VMScanResultItem *item = self.strDataList[indexPath.row];
        BOOL isTargetRow = (item.address == self.targetAddress);
        cell.textLabel.text = [NSString stringWithFormat:@"0x%llX [%lu]", item.address, (unsigned long)item.originalSize];
        NSString *display = item.valueStr;
        if (display.length > 40) display = [[display substringToIndex:40] stringByAppendingString:@"..."];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"\"%@\"", display];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        cell.backgroundColor = isTargetRow
            ? [[UIColor systemYellowColor] colorWithAlphaComponent:0.2]
            : [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    static NSString *ident = @"BrowserValueCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident];
        UILabel *addrLabel = [[UILabel alloc] init];
        addrLabel.tag = 301;
        addrLabel.numberOfLines = 2;
        addrLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        addrLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:addrLabel];

        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.tag = 302;
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        valueLabel.adjustsFontSizeToFitWidth = YES;
        valueLabel.minimumScaleFactor = 0.9;
        valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:valueLabel];
        [valueLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [addrLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        NSLayoutConstraint *minimumValueWidth = [valueLabel.widthAnchor constraintGreaterThanOrEqualToConstant:104];
        minimumValueWidth.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            [addrLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [addrLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [addrLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            [addrLabel.trailingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor constant:-8],
            [valueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [valueLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [valueLabel.widthAnchor constraintLessThanOrEqualToAnchor:cell.contentView.widthAnchor multiplier:0.58 constant:-16],
            minimumValueWidth
        ]];
    }

    VMScanResultItem *item = self.dataList[indexPath.row];
    UILabel *addrLabel = [cell.contentView viewWithTag:301];
    UILabel *valueLabel = [cell.contentView viewWithTag:302];

    valueLabel.text = item.valueStr;
    BOOL isSelected = self.isMultiSelectMode && [self.selectedAddresses containsObject:@(item.address)];
    BOOL isTargetRow = item.address == self.targetAddress;
    cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.isAccessibilityElement = YES;
    cell.accessibilityLabel = [NSString stringWithFormat:@"0x%llX, %@", item.address, item.valueStr ?: @""];
    cell.accessibilityTraits = UIAccessibilityTraitButton | (isSelected ? UIAccessibilityTraitSelected : 0);

    if (isTargetRow) {
        UIColor *targetColor = isSelected
            ? [[UIColor systemOrangeColor] colorWithAlphaComponent:0.22]
            : [[UIColor systemYellowColor] colorWithAlphaComponent:0.2];
        cell.backgroundColor = targetColor;
        addrLabel.attributedText = VMBrowserAddressText(item.address, self.targetAddress, YES);
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
        valueLabel.textColor = [UIColor labelColor];
    } else if (isSelected) {
        cell.backgroundColor = [[VMUIHelper accentColor] colorWithAlphaComponent:0.12];
        addrLabel.attributedText = VMBrowserAddressText(item.address, self.targetAddress, YES);
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold];
        valueLabel.textColor = [UIColor labelColor];
    } else {
        cell.backgroundColor = [UIColor clearColor];
        addrLabel.attributedText = VMBrowserAddressText(item.address, self.targetAddress, NO);
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        valueLabel.textColor = [VMUIHelper accentColor];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.isStrMode) {
        VMScanResultItem *item = self.strDataList[indexPath.row];
        NSString *liveVal = [self readVisibleStringAtAddress:item.address
                                                    fallback:item.valueStr
                                                   lengthOut:NULL];
        item.valueStr = liveVal ?: (item.valueStr ?: @"");
        [tableView reloadRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationNone];
        [VMMemoryActionSheet showActionSheetForAddress:item.address
                                                value:item.valueStr
                                             dataType:VMDataTypeString
                                       stringEncoding:self.stringEncoding
                                   fromViewController:self
                                           sourceView:tableView
                                           sourceRect:[tableView rectForRowAtIndexPath:indexPath]
                                            extraItem:nil];
        return;
    }

    VMScanResultItem *item = self.dataList[indexPath.row];

    if (self.isMultiSelectMode) {
        NSNumber *addrNum = @(item.address);
        if ([self.selectedAddresses containsObject:addrNum]) {
            [self.selectedAddresses removeObject:addrNum];
        } else {
            [self.selectedAddresses addObject:addrNum];
        }
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateMultiSelectTitle];
        return;
    }

    NSString *liveVal = [[VMMemoryEngine shared] readAddress:item.address type:self.type];

    CGRect rect = [tableView rectForRowAtIndexPath:indexPath];

    if (CGRectIsEmpty(rect) || CGRectIsNull(rect)) {
        rect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }

    [VMMemoryActionSheet showActionSheetForAddress:item.address
                                             value:liveVal
                                          dataType:self.type
                                fromViewController:self
                                        sourceView:tableView
                                        sourceRect:rect
                                         extraItem:nil];
}

- (void)showPointerOffsetJumpAlert:(uint64_t)currentAddr {
    NSString *ptrValStr = [[VMMemoryEngine shared] readAddress:currentAddr type:VMDataTypeInt64];
    uint64_t basePtr = strtoull([ptrValStr UTF8String], NULL, 10);

    if (basePtr < 0x10000) {
        [self showToast:TR(@"Err_Invalid_Base_Ptr")];
        return;
    }

    NSString *msg = [NSString stringWithFormat:TR(@"Browser_Ptr_Base_Msg"), basePtr];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Browser_Jump_Ptr_Offset") message:msg preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = TR(@"Browser_Jump_Chain_Hint");
        tf.keyboardType = UIKeyboardTypeASCIICapable;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Jump") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        uint64_t finalAddr = 0;
        if (!VMResolveBrowserOffset(alert.textFields.firstObject.text, basePtr, &finalAddr) || finalAddr == 0) {
            [self showToast:TR(@"Ptr_Error_Invalid_Target")];
            return;
        }

        [self performJumpToAddress:finalAddr];
        [self showToast:[NSString stringWithFormat:TR(@"Msg_Jump_To_Fmt"), finalAddr]];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performJumpToAddress:(uint64_t)addr {
    self.targetAddress = addr;
    self.minAddr = self.targetAddress - MIN(self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
    self.maxAddr = self.targetAddress + MIN(UINT64_MAX - self.targetAddress, (uint64_t)(PAGE_COUNT * self.typeSize));
    self.dataList = [NSMutableArray array];

    [self loadInitialData];
    [self.tableView reloadData];

    [self scrollToTargetAndHighlight];
}

- (void)showToast:(NSString *)msg {
    VMMemoryShowFeedback(self, msg);
}

- (void)showEditAlertForItem:(VMScanResultItem *)item indexPath:(NSIndexPath *)indexPath {
    NSString *msg = [NSString stringWithFormat:TR(@"Alert_Edit_Addr_Msg"), item.address];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Edit_Val") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.text = item.valueStr;
        tf.placeholder = TR(@"Mod_Input_Value_Placeholder");
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newVal = alert.textFields.firstObject.text;
        [[VMMemoryEngine shared] writeAddress:item.address value:newVal type:self.type];
        item.valueStr = newVal;
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Multi-Select Mode

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (![self browsingTargetIsValid]) return;
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (self.isMultiSelectMode) return;
    if (self.isStrMode) return;

    CGPoint point = [gesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
    if (!indexPath) return;

    [self enterMultiSelectMode];

    VMScanResultItem *item = self.dataList[indexPath.row];
    [self.selectedAddresses addObject:@(item.address)];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self updateMultiSelectTitle];
}

- (void)enterMultiSelectMode {
    if (![self browsingTargetIsValid]) return;
    self.isMultiSelectMode = YES;
    [self.selectedAddresses removeAllObjects];

    self.typeSegment.enabled = NO;
    [self updateMultiSelectTitle];

    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle"] style:UIBarButtonItemStylePlain target:self action:@selector(showMultiSelectActions)];
    actionBtn.accessibilityLabel = TR(@"Common_More");
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(exitMultiSelectMode)];
    self.navigationItem.rightBarButtonItems = @[actionBtn, cancelBtn];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Browser_Select_All") style:UIBarButtonItemStylePlain target:self action:@selector(selectAllVisible)];

    [self.tableView reloadData];
}

- (void)exitMultiSelectMode {
    self.isMultiSelectMode = NO;
    [self.selectedAddresses removeAllObjects];

    self.typeSegment.enabled = YES;
    self.navigationItem.rightBarButtonItems = nil;
    self.navigationItem.rightBarButtonItem = self.originalRightBarButton;
    self.navigationItem.leftBarButtonItem = nil;
    self.title = TR(@"Mod_Menu_Value");

    [self.tableView reloadData];
}

- (void)updateMultiSelectTitle {
    NSUInteger count = self.selectedAddresses.count;
    self.title = [NSString stringWithFormat:TR(@"Browser_Selected_Count"), (unsigned long)count];
}

- (void)selectAllVisible {
    for (VMScanResultItem *item in self.dataList) {
        [self.selectedAddresses addObject:@(item.address)];
    }
    [self.tableView reloadData];
    [self updateMultiSelectTitle];
}

- (void)showMultiSelectActions {
    if (self.selectedAddresses.count == 0) {
        [self showToast:TR(@"Browser_No_Selection")];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:TR(@"Browser_Selected_Count"), (unsigned long)self.selectedAddresses.count] message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Batch_Fixed_Btn") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showBatchModifyInputWithMode:0];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Batch_Seq_Btn") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self showBatchModifyInputWithMode:1];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Browser_Batch_Fav") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self batchAddToFavorites];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Browser_Batch_Lock") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self batchAddToLock];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Browser_Copy_Addrs") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self copySelectedAddresses];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (NSArray<NSNumber *> *)sortedSelectedBrowserAddresses {
    return [[self.selectedAddresses allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [a compare:b];
    }];
}

- (NSString *)batchBrowserWriteValueFromInput:(NSString *)input offset:(NSUInteger)offset mode:(NSInteger)mode {
    if (mode == 0) return input;
    if (self.type == VMDataTypeFloat || self.type == VMDataTypeDouble) {
        return [NSString stringWithFormat:@"%f", [input doubleValue] + (double)offset];
    }
    return [NSString stringWithFormat:@"%lld", [input longLongValue] + (long long)offset];
}

- (void)showBatchModifyInputWithMode:(NSInteger)mode {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(mode == 0 ? TR(@"Mod_Batch_Fixed") : TR(@"Title_Inc_Val"))
                                                                   message:[NSString stringWithFormat:TR(@"Browser_Selected_Count"), (unsigned long)self.selectedAddresses.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = (mode == 0) ? TR(@"Common_Val") : TR(@"Mod_Input_Val_Start");
        tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *input = alert.textFields.firstObject.text;
        if (input.length == 0) return;
        [self executeBatchModifyWithInput:input mode:mode];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)executeBatchModifyWithInput:(NSString *)input mode:(NSInteger)mode {
    if (![self browsingTargetIsValid]) { [self checkBrowsingTarget]; return; }
    NSArray<NSNumber *> *sortedAddrs = [self sortedSelectedBrowserAddresses];
    NSMutableArray<NSDictionary *> *writes = [NSMutableArray arrayWithCapacity:sortedAddrs.count];

    for (NSUInteger i = 0; i < sortedAddrs.count; i++) {
        NSNumber *addrNum = sortedAddrs[i];
        NSString *writeValue = [self batchBrowserWriteValueFromInput:input offset:i mode:mode];
        [writes addObject:@{
            @"address": addrNum,
            @"type": @(self.type),
            @"value": writeValue
        }];
    }
    NSUInteger successCount = [[VMMemoryEngine shared] performManualBatchWrites:writes];

    NSMutableArray<NSIndexPath *> *visibleUpdates = [NSMutableArray array];
    for (NSIndexPath *ip in [self.tableView indexPathsForVisibleRows]) {
        if (ip.row >= self.dataList.count) continue;
        VMScanResultItem *item = self.dataList[ip.row];
        if ([self.selectedAddresses containsObject:@(item.address)]) {
            NSString *liveVal = [[VMMemoryEngine shared] readAddress:item.address type:self.type];
            if (liveVal) item.valueStr = liveVal;
            [visibleUpdates addObject:ip];
        }
    }
    if (visibleUpdates.count > 0) {
        [self.tableView reloadRowsAtIndexPaths:visibleUpdates withRowAnimation:UITableViewRowAnimationNone];
    }

    [self showToast:[NSString stringWithFormat:@"%@ %lu", TR(@"Msg_Mod_Success"), (unsigned long)successCount]];
    [self exitMultiSelectMode];
}

- (void)batchAddToFavorites {
    NSString *bundleID = [[VMMemoryEngine shared] currentBundleID];
    NSUInteger addedCount = 0;

    for (NSNumber *addrNum in self.selectedAddresses) {
        uint64_t addr = [addrNum unsignedLongLongValue];
        if (![[VMFavoriteManager shared] isFavorite:addr forApp:bundleID]) {
            NSMutableDictionary *favItem = [NSMutableDictionary dictionaryWithDictionary:@{
                @"addr": addrNum,
                @"note": @"",
                @"type": @(self.type)
            }];
            [[VMFavoriteManager shared] addFavorite:favItem forApp:bundleID];
            addedCount++;
        }
    }

    [self showToast:[NSString stringWithFormat:TR(@"Browser_Batch_Added"), (unsigned long)addedCount]];
    [self exitMultiSelectMode];
}

- (void)batchAddToLock {
    NSUInteger addedCount = 0;
    NSMutableArray *lockedItems = [VMMemoryEngine shared].lockedItems;

    for (NSNumber *addrNum in self.selectedAddresses) {
        uint64_t addr = [addrNum unsignedLongLongValue];

        BOOL alreadyLocked = NO;
        for (NSDictionary *item in lockedItems) {
            if ([item[@"addr"] unsignedLongLongValue] == addr) {
                alreadyLocked = YES;
                break;
            }
        }

        if (!alreadyLocked) {
            NSString *val = [[VMMemoryEngine shared] readAddress:addr type:self.type];

            [[VMLockEngine shared] addAddressLock:addr
                                            value:val ?: @"0"
                                             type:(int)self.type
                                             note:TR(@"App_Title")];
            addedCount++;
        }
    }

    [self showToast:[NSString stringWithFormat:TR(@"Browser_Batch_Added"), (unsigned long)addedCount]];
    [self exitMultiSelectMode];
}

- (void)copySelectedAddresses {
    NSMutableArray *addrStrings = [NSMutableArray array];

    NSArray *sortedAddrs = [self sortedSelectedBrowserAddresses];

    for (NSNumber *addrNum in sortedAddrs) {
        [addrStrings addObject:[NSString stringWithFormat:@"0x%llX", [addrNum unsignedLongLongValue]]];
    }

    NSString *result = [addrStrings componentsJoinedByString:@"\n"];
    [[UIPasteboard generalPasteboard] setString:result];

    [self showToast:[NSString stringWithFormat:TR(@"Browser_Addrs_Copied"), (unsigned long)self.selectedAddresses.count]];
    [self exitMultiSelectMode];
}

@end
