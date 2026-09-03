#import "../memory/VMMemoryBrowserViewController.h"
#import "include/VMMemoryEngine.h"
#import "include/VMLocalization.h"
#import "include/VMFavoriteManager.h"
#import "include/VMLockEngine.h"
#import "../memory/VMHexEditorViewController.h"
#import "../memory/VMMemoryActionSheet.h"
#import "../../utils/helpers/VMUIHelper.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])
#define ROW_HEIGHT 44.0    
#define PAGE_COUNT 100
#define MAX_BUFFER_ROWS 1000
#define PRELOAD_THRESHOLD 400
#define STR_PRELOAD_THRESHOLD 120
#define NUMERIC_REFRESH_INTERVAL 0.5
#define STRING_REFRESH_INTERVAL 1.0

static BOOL VMInputLooksHex(NSString *input) {
    NSCharacterSet *hexLetters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF"];
    return [input rangeOfCharacterFromSet:hexLetters].location != NSNotFound;
}

static uint64_t VMParseAddressInput(NSString *input) {
    NSString *trimmed = [[(input ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (trimmed.length == 0) return 0;

    if ([trimmed.lowercaseString hasPrefix:@"0x"]) {
        return strtoull([trimmed UTF8String], NULL, 16);
    }

    int base = VMInputLooksHex(trimmed) ? 16 : 10;
    return strtoull([trimmed UTF8String], NULL, base);
}

static int64_t VMParseSignedOffsetInput(NSString *input) {
    NSString *trimmed = [[(input ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (trimmed.length == 0) return 0;

    BOOL isNegative = [trimmed hasPrefix:@"-"];
    BOOL hasSign = isNegative || [trimmed hasPrefix:@"+"];
    NSString *body = hasSign ? [trimmed substringFromIndex:1] : trimmed;
    body = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (body.length == 0) return 0;

    int base = 10;
    if ([body.lowercaseString hasPrefix:@"0x"]) {
        body = [body substringFromIndex:2];
        base = 16;
    } else if (VMInputLooksHex(body)) {
        base = 16;
    }

    uint64_t magnitude = strtoull([body UTF8String], NULL, base);
    return isNegative ? -(int64_t)magnitude : (int64_t)magnitude;
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
    UIFont *primaryFont = [UIFont monospacedSystemFontOfSize:12 weight:emphasized ? UIFontWeightBold : UIFontWeightRegular];
    UIFont *secondaryFont = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
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
@end
@implementation VMMemoryBrowserViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.targetAddress = self.address;
    self.isInitialLoad = YES;
    
    self.isMultiSelectMode = NO;
    self.selectedAddresses = [NSMutableSet set];

    NSArray *types = @[TR(@"Type_I8"), TR(@"Type_I16"), TR(@"Type_I32"), TR(@"Type_I64"), TR(@"Type_F32"), TR(@"Type_F64"), @"Str"];
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:types];
    [self.typeSegment setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:11]} forState:UIControlStateNormal];
    
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
    self.navigationItem.titleView = self.typeSegment;

    [self updateTypeSize];

    self.minAddr = self.targetAddress - (PAGE_COUNT * self.typeSize);
    self.maxAddr = self.targetAddress + (PAGE_COUNT * self.typeSize);

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
    [self startAutoRefreshTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopAutoRefreshTimer];
}

- (void)dealloc {
    [self stopAutoRefreshTimer];
}

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO; 
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = ROW_HEIGHT;
    self.tableView.decelerationRate = self.isStrMode
        ? UIScrollViewDecelerationRateFast
        : UIScrollViewDecelerationRateNormal;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone; 
    
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    longPress.delegate = self;
    [self.tableView addGestureRecognizer:longPress];
    
    [self.view addSubview:self.tableView];
    
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor], 
        [self.tableView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor]
    ]];
    
    UIBarButtonItem *moreBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] style:UIBarButtonItemStylePlain target:self action:@selector(showNavMenu)];
    self.navigationItem.rightBarButtonItem = moreBtn;
    self.originalRightBarButton = moreBtn;
    
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
        self.minAddr = self.targetAddress - (PAGE_COUNT * self.typeSize);
        self.maxAddr = self.targetAddress + (PAGE_COUNT * self.typeSize);
        self.dataList = [NSMutableArray array];
        [self loadInitialData];
        [self.tableView reloadData];
        [self scrollToTargetAndHighlight];
    }
}

- (void)loadInitialData {
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
    self.strDataList = [NSMutableArray array];
    
    uint64_t scanStart = (self.targetAddress > STR_SCAN_RANGE) ? (self.targetAddress - STR_SCAN_RANGE) : 0x100000000;
    uint64_t scanEnd = self.targetAddress + STR_SCAN_RANGE;
    
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
}

- (void)loadMoreStrData:(BOOL)next {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    uint64_t rangeSize = STR_SCAN_RANGE;
    uint64_t scanStart, scanEnd;
    
    if (next) {
        scanStart = self.strMaxAddr;
        scanEnd = self.strMaxAddr + rangeSize;
        self.strMaxAddr = scanEnd;
    } else {
        scanEnd = self.strMinAddr;
        scanStart = (self.strMinAddr > rangeSize) ? (self.strMinAddr - rangeSize) : 0x100000000;
        self.strMinAddr = scanStart;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *results = [self scanStringsFrom:scanStart to:scanEnd];
        
        dispatch_async(dispatch_get_main_queue(), ^{
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
    
    for (uint64_t addr = scanStart; addr < scanEnd; addr += pageSize) {
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
    
    const uint8_t *bytes = (const uint8_t *)fullData.bytes;
    NSUInteger len = fullData.length;
    NSUInteger i = 0;
    
    while (i < len) {
        if ([self isPrintableByte:bytes[i]]) {
            NSUInteger start = i;
            while (i < len && i - start < STR_MAX_LEN && bytes[i] != '\0' && [self isPrintableByte:bytes[i]]) {
                i++;
            }
            NSUInteger strLen = i - start;
            if (strLen >= STR_MIN_LEN) {
                uint64_t addr = actualStart + start;
                NSString *str = [[NSString alloc] initWithBytes:bytes + start length:strLen encoding:NSUTF8StringEncoding];
                if (str) {
                    VMScanResultItem *item = [VMScanResultItem new];
                    item.address = addr;
                    item.valueStr = str;
                    item.originalSize = strLen;
                    [results addObject:item];
                }
            }
            if (i < len && bytes[i] == '\0') i++;
        } else {
            i++;
        }
    }
    return results;
}

- (BOOL)isPrintableByte:(uint8_t)b {
    return (b >= 0x20 && b <= 0x7E) || b >= 0xC0;
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
    NSUInteger fallbackLen = [fallback lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSUInteger readLength = MIN(MAX(fallbackLen + 1, (NSUInteger)64), (NSUInteger)STR_MAX_LEN);
    NSData *data = [[VMMemoryEngine shared] readRawMemory:address length:readLength];
    if (data.length == 0) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback ?: @"";
    }

    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger len = 0;
    while (len < data.length && len < STR_MAX_LEN) {
        if (bytes[len] == '\0') break;
        if (![self isPrintableByte:bytes[len]]) break;
        len++;
    }

    if (len == 0) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback ?: @"";
    }

    NSString *str = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding];
    if (!str) {
        if (lengthOut) *lengthOut = fallbackLen;
        return fallback ?: @"";
    }

    if (lengthOut) *lengthOut = len;
    return str;
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Btn_Jump") message:@"0x..." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.keyboardType = UIKeyboardTypeASCIICapable;
        tf.placeholder = @"0x1234 / 1234";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        
        NSString *txt = alert.textFields.firstObject.text;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            uint64_t addr = VMParseAddressInput(txt);
            self.targetAddress = addr;
            if (self.isStrMode) {
                [self loadStrData];
            } else {
                self.minAddr = self.targetAddress - (PAGE_COUNT * self.typeSize);
                self.maxAddr = self.targetAddress + (PAGE_COUNT * self.typeSize);
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
    NSString *msg = [NSString stringWithFormat:TR(@"Browser_Jump_Offset_Msg"), self.targetAddress];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Browser_Jump_Offset") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"+8, -16, +0x40, 0x1A2B";
        tf.keyboardType = UIKeyboardTypeASCIICapable;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *input = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) return;
        
        int64_t offset = VMParseSignedOffsetInput(input);
        
        uint64_t newAddr = self.targetAddress + offset;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.targetAddress = newAddr;
            if (self.isStrMode) {
                [self loadStrData];
            } else {
                self.minAddr = self.targetAddress - (PAGE_COUNT * self.typeSize);
                self.maxAddr = self.targetAddress + (PAGE_COUNT * self.typeSize);
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
    self.isLoading = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newRows = [NSMutableArray array];
        int count = PAGE_COUNT;
        
        if (next) {
            
            for (int i = 1; i <= count; i++) {
                uint64_t addr = self.maxAddr + (i * self.typeSize);
                NSString *val = [[VMMemoryEngine shared] readAddress:addr type:self.type];
                VMScanResultItem *item = [VMScanResultItem new];
                item.address = addr; item.valueStr = val;
                [newRows addObject:item];
            }
        } else {
            
            for (int i = count; i >= 1; i--) {
                uint64_t addr = self.minAddr - (i * self.typeSize);
                NSString *val = [[VMMemoryEngine shared] readAddress:addr type:self.type];
                VMScanResultItem *item = [VMScanResultItem new];
                item.address = addr; item.valueStr = val;
                [newRows addObject:item];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (newRows.count == 0) {
                self.isLoading = NO;
                return;
            }
            
            if (next) {
                
                NSInteger startIdx = self.dataList.count;
                [self.dataList addObjectsFromArray:newRows];
                self.maxAddr = ((VMScanResultItem *)newRows.lastObject).address;
                
                NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newRows.count];
                for (NSInteger i = 0; i < newRows.count; i++) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:startIdx + i inSection:0]];
                }
                
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                [CATransaction commit];
                
                if (self.dataList.count > MAX_BUFFER_ROWS) {
                    NSInteger removeCount = self.dataList.count - MAX_BUFFER_ROWS;
                    [self.dataList removeObjectsInRange:NSMakeRange(0, removeCount)];
                    self.minAddr = ((VMScanResultItem *)self.dataList.firstObject).address;
                    
                    CGFloat removedHeight = removeCount * ROW_HEIGHT;
                    CGPoint curr = self.tableView.contentOffset;
                    CGFloat newY = MAX(0, curr.y - removedHeight);
                    
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    [self.tableView reloadData];
                    [self.tableView setContentOffset:CGPointMake(curr.x, newY) animated:NO];
                    [CATransaction commit];
                }
                
            } else {
                
                NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newRows.count)];
                [self.dataList insertObjects:newRows atIndexes:idxSet];
                self.minAddr = ((VMScanResultItem *)newRows.firstObject).address;
                
                NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newRows.count];
                for (NSInteger i = 0; i < newRows.count; i++) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                [CATransaction commit];
                
                if (self.dataList.count > MAX_BUFFER_ROWS) {
                    [self.dataList removeObjectsInRange:NSMakeRange(MAX_BUFFER_ROWS, self.dataList.count - MAX_BUFFER_ROWS)];
                    self.maxAddr = ((VMScanResultItem *)self.dataList.lastObject).address;
                    [self.tableView reloadData];
                }
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.isLoading = NO;
            });
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
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:strIdent];
            cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
            cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        }
        VMScanResultItem *item = self.strDataList[indexPath.row];
        BOOL isTargetRow = (item.address == self.targetAddress);
        cell.textLabel.text = [NSString stringWithFormat:@"0x%llX [%lu]", item.address, (unsigned long)item.originalSize];
        NSString *display = item.valueStr;
        if (display.length > 40) display = [[display substringToIndex:40] stringByAppendingString:@"..."];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"\"%@\"", display];
        cell.detailTextLabel.textColor = [UIColor systemGreenColor];
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
        [cell.contentView addSubview:addrLabel];

        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.tag = 302;
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [cell.contentView addSubview:valueLabel];
    }
    
    VMScanResultItem *item = self.dataList[indexPath.row];
    UILabel *addrLabel = [cell.contentView viewWithTag:301];
    UILabel *valueLabel = [cell.contentView viewWithTag:302];

    CGFloat contentWidth = tableView.bounds.size.width - 16;
    CGFloat valueWidth = MIN(140.0, MAX(96.0, contentWidth * 0.34));
    CGFloat addrWidth = MAX(80.0, contentWidth - valueWidth - 8.0);
    addrLabel.frame = CGRectMake(8, 2, addrWidth, ROW_HEIGHT - 4);
    valueLabel.frame = CGRectMake(8 + addrWidth + 8, 0, valueWidth - 8, ROW_HEIGHT);

    valueLabel.text = item.valueStr;
    BOOL isSelected = self.isMultiSelectMode && [self.selectedAddresses containsObject:@(item.address)];
    BOOL isTargetRow = item.address == self.targetAddress;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (isTargetRow) {
        UIColor *targetColor = isSelected
            ? [[UIColor systemOrangeColor] colorWithAlphaComponent:0.22]
            : [[UIColor systemYellowColor] colorWithAlphaComponent:0.2];
        cell.backgroundColor = targetColor;
        addrLabel.attributedText = VMBrowserAddressText(item.address, self.targetAddress, YES);
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
        valueLabel.textColor = [UIColor labelColor];
    } else if (isSelected) {
        cell.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.12];
        addrLabel.attributedText = VMBrowserAddressText(item.address, self.targetAddress, YES);
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold];
        valueLabel.textColor = [UIColor labelColor];
    } else {
        cell.backgroundColor = [UIColor clearColor];
        addrLabel.attributedText = VMBrowserAddressText(item.address, self.targetAddress, NO);
        valueLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        valueLabel.textColor = [UIColor systemBlueColor];
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

- (void)showStrEditAlert:(VMScanResultItem *)item indexPath:(NSIndexPath *)indexPath {
    NSString *msg = [NSString stringWithFormat:@"0x%llX\n%@ %lu", item.address, TR(@"Browser_Str_OrigLen"), (unsigned long)item.originalSize];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Browser_Str_Edit") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = item.valueStr;
        tf.keyboardType = UIKeyboardTypeDefault;
        tf.clearButtonMode = UITextFieldViewModeAlways;
    }];
    
    __weak __typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *newVal = alert.textFields.firstObject.text ?: @"";
        NSUInteger newLen = [newVal lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        
        if (newLen > item.originalSize) {
            NSString *warnMsg = [NSString stringWithFormat:TR(@"Browser_Str_Overflow_Msg"), (unsigned long)item.originalSize, (unsigned long)newLen];
            UIAlertController *warn = [UIAlertController alertControllerWithTitle:TR(@"Browser_Str_Overflow") message:warnMsg preferredStyle:UIAlertControllerStyleAlert];
            [warn addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
            [warn addAction:[UIAlertAction actionWithTitle:TR(@"Browser_Str_Force_Write") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a2) {
                [weakSelf writeStr:newVal toItem:item indexPath:indexPath];
            }]];
            [weakSelf presentViewController:warn animated:YES completion:nil];
        } else {
            [weakSelf writeStr:newVal toItem:item indexPath:indexPath];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)writeStr:(NSString *)newVal toItem:(VMScanResultItem *)item indexPath:(NSIndexPath *)indexPath {
    const char *cstr = [newVal UTF8String];
    NSUInteger writeLen = strlen(cstr) + 1;
    NSMutableData *data = [NSMutableData dataWithBytes:cstr length:writeLen];
    [[VMMemoryEngine shared] writeRawData:data toAddress:item.address];
    
    item.valueStr = newVal;
    item.originalSize = writeLen - 1;
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
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
        int64_t offset = VMParseSignedOffsetInput(alert.textFields.firstObject.text);
        uint64_t finalAddr = offset >= 0 ? basePtr + (uint64_t)offset : basePtr - (uint64_t)(-offset);
        
        [self performJumpToAddress:finalAddr];
        [self showToast:[NSString stringWithFormat:TR(@"Msg_Jump_To_Fmt"), finalAddr]];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performJumpToAddress:(uint64_t)addr {
    self.targetAddress = addr;
    self.minAddr = self.targetAddress - (100 * self.typeSize);
    self.maxAddr = self.targetAddress + (100 * self.typeSize);
    self.dataList = [NSMutableArray array];
    
    [self loadInitialData];
    [self.tableView reloadData];
    
    [self scrollToTargetAndHighlight];
}

- (void)showToast:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)showEditAlertForItem:(VMScanResultItem *)item indexPath:(NSIndexPath *)indexPath {
    NSString *msg = [NSString stringWithFormat:TR(@"Alert_Edit_Addr_Msg"), item.address];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Edit_Val") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.text = item.valueStr;
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
    self.isMultiSelectMode = YES;
    [self.selectedAddresses removeAllObjects];
    
    self.navigationItem.titleView = nil;
    [self updateMultiSelectTitle];
    
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle"] style:UIBarButtonItemStylePlain target:self action:@selector(showMultiSelectActions)];
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(exitMultiSelectMode)];
    self.navigationItem.rightBarButtonItems = @[actionBtn, cancelBtn];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Browser_Select_All") style:UIBarButtonItemStylePlain target:self action:@selector(selectAllVisible)];
    
    [self.tableView reloadData];
}

- (void)exitMultiSelectMode {
    self.isMultiSelectMode = NO;
    [self.selectedAddresses removeAllObjects];
    
    self.navigationItem.titleView = self.typeSegment;
    self.navigationItem.rightBarButtonItems = nil;
    self.navigationItem.rightBarButtonItem = self.originalRightBarButton;
    self.navigationItem.leftBarButtonItem = nil;
    self.title = nil;
    
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
