#import "VMHexEditorViewController.h"
#import "VMHexRowEditorViewController.h"
#import "VMStringMemorySession.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMHexEditorViewController () <UITableViewDelegate, UITableViewDataSource, VMHexRowEditorDelegate>
@property(nonatomic, strong) UIStackView *mainStackView;
@property(nonatomic, strong) UISegmentedControl *viewModeSegment;
@property(nonatomic, strong) UITableView *hexTableView;
@property(nonatomic, strong) UITableView *asciiTableView;
@property(nonatomic, strong) UILabel *addressLabel;
@property(nonatomic, strong) NSLayoutConstraint *hexWidthConstraint;
@property(nonatomic, strong) NSMutableData *memoryBuffer;
@property(nonatomic) uint64_t startAddress;
@property(nonatomic) NSUInteger bytesPerRow;
@property(nonatomic) NSUInteger loadGeneration;
@property(nonatomic) BOOL isLoading;
@property(nonatomic) BOOL synchronizingScroll;
@property(nonatomic) pid_t browsingPid;
@property(nonatomic) mach_port_t browsingTask;
@end

@implementation VMHexEditorViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"Hex_Title");
  self.view.backgroundColor = [VMUIHelper canvasColor];
  self.bytesPerRow = 8;
  self.browsingPid = [VMMemoryEngine shared].targetPid;
  self.browsingTask = [VMMemoryEngine shared].targetTask;
  self.memoryBuffer = [NSMutableData data];
  UIBarButtonItem *jump = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.turn.down.right"] style:UIBarButtonItemStylePlain target:self action:@selector(promptJump)];
  jump.accessibilityLabel = TR(@"Btn_Jump");
  self.navigationItem.rightBarButtonItem = jump;
  [self setupLayout];
  [self loadInitialData];
}

- (BOOL)targetIsValid {
  return self.browsingTask != MACH_PORT_NULL && self.browsingPid == [VMMemoryEngine shared].targetPid && self.browsingTask == [VMMemoryEngine shared].targetTask;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  if ([self targetIsValid]) return;
  self.loadGeneration++;
  self.isLoading = NO;
  [self.memoryBuffer setLength:0];
  [self reloadBothTables];
  self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (UITableView *)makeTable {
  UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  table.showsHorizontalScrollIndicator = NO;
  table.delegate = self;
  table.dataSource = self;
  table.rowHeight = 60;
  table.backgroundColor = [VMUIHelper cardColor];
  table.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
  table.tableFooterView = [UIView new];
  table.layer.cornerRadius = 16;
  table.layer.cornerCurve = kCACornerCurveContinuous;
  table.clipsToBounds = YES;
  return table;
}

- (void)setupLayout {
  UIView *card = [UIView new];
  [VMUIHelper styleCard:card];
  card.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:card];
  self.addressLabel = [UILabel new];
  self.addressLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightSemibold];
  self.addressLabel.textColor = [VMUIHelper accentColor];
  self.addressLabel.numberOfLines = 0;
  self.viewModeSegment = [[UISegmentedControl alloc] initWithItems:@[TR(@"Hex_Mode_Hex"), TR(@"Hex_Mode_Split"), TR(@"Hex_Mode_Ascii")]];
  self.viewModeSegment.selectedSegmentIndex = 0;
  self.viewModeSegment.accessibilityLabel = TR(@"Hex_Title");
  [self.viewModeSegment addTarget:self action:@selector(viewModeChanged:) forControlEvents:UIControlEventValueChanged];
  UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[self.addressLabel, self.viewModeSegment]];
  header.axis = UILayoutConstraintAxisVertical;
  header.spacing = 12;
  header.translatesAutoresizingMaskIntoConstraints = NO;
  [card addSubview:header];
  self.hexTableView = [self makeTable];
  self.asciiTableView = [self makeTable];
  self.asciiTableView.hidden = YES;
  self.mainStackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.hexTableView, self.asciiTableView]];
  self.mainStackView.axis = UILayoutConstraintAxisHorizontal;
  self.mainStackView.spacing = 8;
  self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.mainStackView];
  self.hexWidthConstraint = [self.hexTableView.widthAnchor constraintEqualToAnchor:self.mainStackView.widthAnchor multiplier:0.67 constant:-4];
  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [card.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
    [card.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
    [card.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
    [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
    [header.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
    [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
    [self.viewModeSegment.heightAnchor constraintEqualToConstant:44],
    [self.mainStackView.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:12],
    [self.mainStackView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
    [self.mainStackView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
    [self.mainStackView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12]
  ]];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGFloat width = self.view.safeAreaLayoutGuide.layoutFrame.size.width;
  BOOL split = self.viewModeSegment.selectedSegmentIndex == 1;
  NSUInteger count = width >= 700 ? 16 : (split && width < 390 ? 4 : 8);
  if (count != self.bytesPerRow) {
    UITableView *visible = self.hexTableView.hidden ? self.asciiTableView : self.hexTableView;
    NSUInteger firstByte = MAX(0, floor(visible.contentOffset.y / 60)) * self.bytesPerRow;
    self.bytesPerRow = count;
    self.synchronizingScroll = YES;
    [self reloadBothTables];
    CGPoint offset = CGPointMake(0, (firstByte / count) * 60);
    self.hexTableView.contentOffset = offset;
    self.asciiTableView.contentOffset = offset;
    self.synchronizingScroll = NO;
  }
}

- (void)viewModeChanged:(UISegmentedControl *)segment {
  CGPoint offset = self.hexTableView.hidden ? self.asciiTableView.contentOffset : self.hexTableView.contentOffset;
  self.hexWidthConstraint.active = NO;
  self.hexTableView.hidden = segment.selectedSegmentIndex == 2;
  self.asciiTableView.hidden = segment.selectedSegmentIndex == 0;
  self.hexWidthConstraint.active = segment.selectedSegmentIndex == 1;
  self.synchronizingScroll = YES;
  self.hexTableView.contentOffset = offset;
  self.asciiTableView.contentOffset = offset;
  self.synchronizingScroll = NO;
  [self.view setNeedsLayout];
  [self reloadBothTables];
}

- (void)loadInitialData {
  self.loadGeneration++;
  self.isLoading = NO;
  self.startAddress = self.address;
  NSData *data = [[VMMemoryEngine shared] readRawMemory:self.address length:MIN((uint64_t)960, UINT64_MAX - self.address)];
  self.memoryBuffer = data ? [data mutableCopy] : [NSMutableData data];
  self.synchronizingScroll = YES;
  [self reloadBothTables];
  self.hexTableView.contentOffset = CGPointZero;
  self.asciiTableView.contentOffset = CGPointZero;
  self.synchronizingScroll = NO;
}

- (void)loadMoreData:(BOOL)next {
  if (![self targetIsValid]) return;
  if (self.isLoading) return;
  NSUInteger length = next ? MIN((uint64_t)960, UINT64_MAX - self.startAddress - self.memoryBuffer.length) : MIN((uint64_t)960, self.startAddress);
  if (length == 0) return;
  uint64_t address = next ? self.startAddress + self.memoryBuffer.length : self.startAddress - length;
  NSUInteger generation = self.loadGeneration;
  pid_t pid = [VMMemoryEngine shared].targetPid;
  mach_port_t task = [VMMemoryEngine shared].targetTask;
  self.isLoading = YES;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSData *data = [[VMMemoryEngine shared] readRawMemory:address length:length];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.loadGeneration) return;
      self.isLoading = NO;
      if (pid != [VMMemoryEngine shared].targetPid || task != [VMMemoryEngine shared].targetTask || data.length == 0) return;
      // Prepending requires a contiguous full read so the existing byte addresses remain exact.
      if (!next && data.length != length) return;
      CGPoint offset = self.hexTableView.hidden ? self.asciiTableView.contentOffset : self.hexTableView.contentOffset;
      if (next) [self.memoryBuffer appendData:data];
      else {
        NSMutableData *combined = [data mutableCopy];
        [combined appendData:self.memoryBuffer];
        self.memoryBuffer = combined;
        self.startAddress = address;
        offset.y += ((CGFloat)data.length / self.bytesPerRow) * 60;
      }
      self.synchronizingScroll = YES;
      [self reloadBothTables];
      [self.hexTableView layoutIfNeeded];
      [self.asciiTableView layoutIfNeeded];
      self.hexTableView.contentOffset = offset;
      self.asciiTableView.contentOffset = offset;
      self.synchronizingScroll = NO;
    });
  });
}

- (void)reloadBothTables {
  self.addressLabel.text = [NSString stringWithFormat:TR(@"Hex_Start_Addr"), self.startAddress];
  for (UITableView *table in @[self.hexTableView, self.asciiTableView]) {
    table.backgroundView = self.memoryBuffer.length ? nil : [VMUIHelper emptyStateWithTitle:TR(@"Snapshot_Empty") message:TR(@"Str_Read_Failed") symbol:@"doc.text.magnifyingglass"];
    [table reloadData];
  }
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
  return (self.memoryBuffer.length + self.bytesPerRow - 1) / self.bytesPerRow;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
  UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"Bytes"];
  if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Bytes"];
  NSUInteger location = path.row * self.bytesPerRow;
  if (location >= self.memoryBuffer.length) return cell;
  NSUInteger length = MIN(self.bytesPerRow, self.memoryBuffer.length - location);
  uint64_t address = self.startAddress + location;
  const uint8_t *bytes = (const uint8_t *)self.memoryBuffer.bytes + location;
  NSMutableString *text = [NSMutableString string];
  for (NSUInteger i = 0; i < length; i++) {
    if (table == self.hexTableView) [text appendFormat:i ? @" %02X" : @"%02X", bytes[i]];
    else [text appendFormat:@"%c", bytes[i] >= 0x20 && bytes[i] <= 0x7e ? bytes[i] : '.'];
  }
  cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", address];
  cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
  cell.textLabel.textColor = [UIColor secondaryLabelColor];
  cell.detailTextLabel.text = text;
  cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
  cell.detailTextLabel.textColor = table == self.hexTableView ? [UIColor labelColor] : [VMUIHelper accentColor];
  cell.layoutMargins = UIEdgeInsetsMake(0, 10, 0, 10);
  cell.backgroundColor = [VMUIHelper cardColor];
  cell.accessibilityTraits = UIAccessibilityTraitButton;
  cell.accessibilityHint = TR(@"Hex_Row_Editor");
  return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scroll {
  if (self.synchronizingScroll) return;
  self.synchronizingScroll = YES;
  if (self.viewModeSegment.selectedSegmentIndex == 1) {
    (scroll == self.hexTableView ? self.asciiTableView : self.hexTableView).contentOffset = scroll.contentOffset;
  }
  self.synchronizingScroll = NO;
  if (self.isLoading || (!scroll.dragging && !scroll.decelerating)) return;
  if (scroll.contentOffset.y < 120) [self loadMoreData:NO];
  else if (scroll.contentOffset.y + scroll.bounds.size.height > scroll.contentSize.height - 200) [self loadMoreData:YES];
}

- (void)promptJump {
  if (![self targetIsValid]) { [self showError:TR(@"Str_Target_Changed")]; return; }
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Btn_Jump") message:TR(@"Prompt_Addr_Input") preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.keyboardType = UIKeyboardTypeASCIICapable;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.text = [NSString stringWithFormat:@"0x%llX", self.address];
    field.placeholder = TR(@"Placeholder_Addr_Hex");
  }];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Jump") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    uint64_t address = 0;
    BOOL valid = [VMStringMemorySession parseAddress:alert.textFields.firstObject.text value:&address] && address > 0;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (valid) { self.address = address; [self loadInitialData]; }
      else [self showError:TR(@"Ptr_Error_Invalid_Target")];
    });
  }]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
  [table deselectRowAtIndexPath:path animated:YES];
  if (![self targetIsValid]) { [self showError:TR(@"Str_Target_Changed")]; return; }
  NSUInteger location = path.row * self.bytesPerRow;
  if (location >= self.memoryBuffer.length) return;
  VMHexRowEditorViewController *editor = [VMHexRowEditorViewController new];
  editor.address = self.startAddress + location;
  NSUInteger length = MIN(self.bytesPerRow, self.memoryBuffer.length - location);
  NSData *current = [[VMMemoryEngine shared] readRawMemory:editor.address length:length];
  if (current.length != length) { [self showError:TR(@"Str_Read_Failed")]; return; }
  [self.memoryBuffer replaceBytesInRange:NSMakeRange(location, length) withBytes:current.bytes];
  [self reloadBothTables];
  editor.originalData = current;
  editor.delegate = self;
  [self.navigationController pushViewController:editor animated:YES];
}

- (void)rowEditorDidSaveData:(NSData *)data atAddress:(uint64_t)address completion:(void (^)(BOOL, NSString *))completion {
  UIViewController *presenter = self.navigationController.topViewController ?: self;
  NSData *baseline = [presenter isKindOfClass:VMHexRowEditorViewController.class] ? ((VMHexRowEditorViewController *)presenter).originalData : nil;
  void (^write)(void) = ^{
    if (![self targetIsValid]) { if (completion) completion(NO, @"Str_Target_Changed"); return; }
    NSData *current = [[VMMemoryEngine shared] readRawMemory:address length:baseline.length];
    if (!baseline || ![current isEqualToData:baseline]) { if (completion) completion(NO, @"Str_Conflict"); return; }
    BOOL success = [[VMMemoryEngine shared] writeRawData:data toAddress:address];
    NSString *error = success ? nil : @"Err_Write_Permission";
    if (success && ![[[VMMemoryEngine shared] readRawMemory:address length:data.length] isEqualToData:data]) {
      success = NO;
      error = @"Str_Write_Unverified";
    }
    if (success && address >= self.startAddress && address - self.startAddress <= self.memoryBuffer.length && data.length <= self.memoryBuffer.length - (address - self.startAddress)) {
      [self.memoryBuffer replaceBytesInRange:NSMakeRange(address - self.startAddress, data.length) withBytes:data.bytes];
      [self reloadBothTables];
    }
    if (completion) completion(success, error);
  };
  if ([[VMMemoryEngine shared] isRegionExecutable:address] && ![[VMMemoryEngine shared] isDeviceJailbroken]) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Exec_Warn_Title") message:TR(@"Alert_Exec_Warn_Msg") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
      if (completion) completion(NO, nil);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Continue") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { write(); }]];
    [presenter presentViewController:alert animated:YES completion:nil];
  } else write();
}

- (void)showError:(NSString *)message {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Error") message:message preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}
@end
