#import "VMScriptToolsViewController.h"
#import "../../../include/VMLocalization.h"
#import "VMScriptGuideGenerator.h"
#import <WebKit/WebKit.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMShortcutCell : UICollectionViewCell
@property(nonatomic, strong) UILabel *label;
@end

@implementation VMShortcutCell
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.contentView.backgroundColor =
        [UIColor tertiarySystemGroupedBackgroundColor];
    self.contentView.layer.cornerRadius = 8;

    _label = [[UILabel alloc] init];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _label.textColor = [UIColor labelColor];
    _label.numberOfLines = 2; 
    _label.adjustsFontSizeToFitWidth = YES;
    _label.minimumScaleFactor = 0.8;
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_label];

    [NSLayoutConstraint activateConstraints:@[
      [_label.topAnchor constraintEqualToAnchor:self.contentView.topAnchor
                                       constant:4],
      [_label.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor
                                          constant:-4],
      [_label.leadingAnchor
          constraintEqualToAnchor:self.contentView.leadingAnchor
                         constant:4],
      [_label.trailingAnchor
          constraintEqualToAnchor:self.contentView.trailingAnchor
                         constant:-4]
    ]];
  }
  return self;
}
@end

@interface VMScriptShortcutViewController () <
    UICollectionViewDelegate, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout>
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) NSArray *shortcuts;
@end

@implementation VMScriptShortcutViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.title = TR(@"Script_Btn_Shortcut") ?: @"Shortcut Commands";

  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel") ?: @"Close"
                                       style:UIBarButtonItemStyleDone
                                      target:self
                                      action:@selector(dismissSelf)];

  self.shortcuts = @[
    @{@"name" : TR(@"Script_Shortcut_Search"), @"code" : @"vm.search('100', 'I32', '0x100000000', '0x200000000');"},
    @{@"name" : TR(@"Script_Shortcut_Refine"), @"code" : @"vm.refine('100', 'I32', 'eq');"},
    @{@"name" : TR(@"Script_Shortcut_Fuzzy"), @"code" : @"vm.searchFuzzy('I32');"},
    @{@"name" : TR(@"Script_Shortcut_Group"), @"code" : @"vm.searchGroup('1; *; 3::50', 'I32', '0x100000000', '0x200000000');\nvm.search('4:100 w:8 4:50', 'I32');"},
    @{@"name" : TR(@"Script_Shortcut_Nearby"), @"code" : @"vm.nearby('100', 'I32', 50);"},
    @{@"name" : TR(@"Script_Shortcut_Sign"), @"code" : @"vm.searchSign('E0 03 ?? 2A', '0x100000000', '0x200000000');"},
    @{@"name" : TR(@"Script_Shortcut_Between"), @"code" : @"vm.searchBetween('90', '100', 'I32');"},
    @{@"name" : TR(@"Script_Shortcut_GetResults"), @"code" : @"var results = vm.getResults(10, 0);"},
    @{@"name" : TR(@"Script_Shortcut_Count"), @"code" : @"var count = vm.getResultsCount();"},
    @{@"name" : TR(@"Script_Shortcut_EditAll"), @"code" : @"vm.editAll('9999', 'I32');"},
    @{@"name" : TR(@"Script_Shortcut_EditAllAdv"), @"code" : @"vm.editAll('999', 'I32', '1.3,5=10@ABC//+4');"},
    @{@"name" : TR(@"Script_Shortcut_Write"), @"code" : @"vm.write('999', 'I32', 0);"},
    @{@"name" : TR(@"Script_Shortcut_Lock"), @"code" : @"vm.lock('9999', 'I32', 0);"},
    @{@"name" : TR(@"Script_Shortcut_Unlock"), @"code" : @"vm.unlock(0);"},
    @{@"name" : TR(@"Script_Shortcut_LockAll"), @"code" : @"vm.lockAll('9999', 'I32');"},
    @{@"name" : TR(@"Script_Shortcut_LockAllAdv"), @"code" : @"vm.lockAll('9999', 'I32', '1=10@ABC//+0x8');"},
    @{@"name" : TR(@"Script_Shortcut_UnlockAll"), @"code" : @"vm.unlockAll();"},
    @{@"name" : TR(@"Script_Shortcut_Clear"), @"code" : @"vm.clear();"},
    @{@"name" : TR(@"Script_Shortcut_GetVal"), @"code" : @"var v = vm.getValue('0x1000', 'I32');"},
    @{@"name" : TR(@"Script_Shortcut_SetVal"), @"code" : @"vm.setValue('0x1000', '999', 'I32');"},
    @{@"name" : TR(@"Script_Shortcut_Ranges"), @"code" : @"var list = vm.getRangesList(0);"},
    @{@"name" : TR(@"Script_Shortcut_BaseAddr"), @"code" : @"vm.setBaseAddress('0x100000000');"},
    @{@"name" : TR(@"Script_Shortcut_Tol"), @"code" : @"vm.setFloatTolerance(2.0);"},
    @{@"name" : TR(@"Script_Shortcut_Log"), @"code" : @"vm.log('msg');"},
    @{@"name" : TR(@"Script_Shortcut_Toast"), @"code" : @"vm.toast('msg');"},
    @{@"name" : TR(@"Script_Shortcut_Sleep"), @"code" : @"vm.sleep(1.0);"}
  ];

  UICollectionViewFlowLayout *layout =
      [[UICollectionViewFlowLayout alloc] init];
  layout.minimumInteritemSpacing = 12;
  layout.minimumLineSpacing = 12;
  layout.sectionInset = UIEdgeInsetsMake(20, 12, 20, 12);

  _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                       collectionViewLayout:layout];
  _collectionView.backgroundColor = [UIColor clearColor];
  _collectionView.delegate = self;
  _collectionView.dataSource = self;
  _collectionView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [_collectionView registerClass:[VMShortcutCell class]
      forCellWithReuseIdentifier:@"Cell"];
  [self.view addSubview:_collectionView];
}

- (void)dismissSelf {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
  return self.shortcuts.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  VMShortcutCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell"
                                                forIndexPath:indexPath];
  
  cell.contentView.backgroundColor = [UIColor systemBlueColor]; 
  cell.label.textColor = [UIColor whiteColor];                  
  cell.label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
  cell.label.text = self.shortcuts[indexPath.item][@"name"];
  return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  NSString *code = self.shortcuts[indexPath.item][@"code"];
  if (self.didSelectShortcut) {
    self.didSelectShortcut(code);
  }
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                    layout:(UICollectionViewLayout *)collectionViewLayout
    sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat totalWidth = collectionView.bounds.size.width;
  CGFloat padding = 24.0; 
  CGFloat spacing = 12.0;

  int cols = 3;
  if (totalWidth > 600) { 
    cols = 5;
  } else if (totalWidth > 400) { 
    cols = 4;
  }

  CGFloat availableWidth = totalWidth - padding - (spacing * (cols - 1));
  CGFloat width = availableWidth / cols;
  return CGSizeMake(floorf(width), 50);
}

@end

@interface VMScriptExampleViewController () <WKNavigationDelegate,
                                             WKScriptMessageHandler>
@property(nonatomic, strong) WKWebView *webView;
@end

@implementation VMScriptExampleViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.title = TR(@"Script_Btn_Template") ?: @"Script Examples";

  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Common_Done")
                                       style:UIBarButtonItemStyleDone
                                      target:self
                                      action:@selector(dismissSelf)];

  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  
  [config.userContentController addScriptMessageHandler:self name:@"vmHandler"];

  self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds
                                    configuration:config];
  self.webView.navigationDelegate = self;
  self.webView.backgroundColor = [UIColor clearColor];
  self.webView.opaque = NO;
  self.webView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.view addSubview:self.webView];

  NSString *guideHtml = VMGenerateScriptGuideHTMLComplete();
  [self.webView loadHTMLString:guideHtml baseURL:nil];
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  NSDictionary *body = message.body;
  if (![body isKindOfClass:[NSDictionary class]])
    return;

  NSString *action = body[@"action"];
  NSString *content = body[@"content"];

  if ([action isEqualToString:@"copy"]) {
    UIPasteboard.generalPasteboard.string = content;
    [self showSimpleToast:TR(@"Status_Copied") ?: @"Copied"];
  } else if ([action isEqualToString:@"insert"]) {
    if (self.didSelectShortcut) {
      self.didSelectShortcut(content);
      [self dismissViewControllerAnimated:YES completion:nil];
    }
  }
}

- (void)showSimpleToast:(NSString *)msg {
  UIAlertController *ac =
      [UIAlertController alertControllerWithTitle:nil
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:ac animated:YES completion:nil];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [ac dismissViewControllerAnimated:YES completion:nil];
      });
}

- (void)dismissSelf {
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
