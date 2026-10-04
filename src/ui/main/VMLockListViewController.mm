#import "VMLockListViewController.h"
#import "../../core/VMRootViewController.h"
#import "../common/VMFormSheetViewController.h"
#import "../memory/VMStringMemorySession.h"
#import "../../utils/helpers/VMShareHelper.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/managers/VMImportHandler.h"
#import "../../utils/managers/VMScriptManager.h"
#import "../memory/VMHexEditorViewController.h"
#import "../memory/VMMemoryActionSheet.h"
#import "../memory/VMMemoryBrowserViewController.h"
#import "../patch/VMRVAManagerCell.h"
#import "../pointer/VMItemEditViewController.h"
#import "../pointer/VMPointerLockCell.h"
#import "../pointer/VMPointerVerifierViewController.h"
#import "../pointer/VMSignatureLockCell.h"
#import "VMScriptViewController.h"
#import "include/VMDataSession.h"
#import "include/VMLocalization.h"
#import "include/VMLockEngine.h"
#import "include/VMLockManager.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"
#import "include/VMPointerManager.h"
#import "include/VMRVAPatch.h"
#import "include/VMStoragePathHelper.h"
#import "include/VMSignatureModel.h"
#import "../../utils/managers/LockCore.hpp"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <mach/mach.h>
#import <objc/runtime.h>
#include <sys/sysctl.h>
#include <errno.h>
#include <stdlib.h>
#ifdef __cplusplus
extern "C" {
#endif
int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t,
                              boolean_t, vm_prot_t);
kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t, vm_offset_t,
                            mach_msg_type_number_t);
#ifdef __cplusplus
}
#endif
#define TR(key) ([[VMLocalization shared] localizedString:key])
#define kCardCornerRadius 16.0
#define kButtonHeight 44.0
@protocol VMItemCardCellDelegate <NSObject>
@optional
- (void)itemCellDidToggleSwitch:(UITableViewCell *)cell isOn:(BOOL)isOn;
@end
@interface VMItemCardCell : UITableViewCell
@property(nonatomic, strong) UIView *bgView;
@property(nonatomic, strong) UILabel *lblNote;
@property(nonatomic, strong) UILabel *lblAddr;
@property(nonatomic, strong) UILabel *lblValue;
@property(nonatomic, strong) UISwitch *lockSwitch;
@property(nonatomic, strong) UIImageView *favIcon;
@property(nonatomic, weak) id<VMItemCardCellDelegate> delegate;
@property(nonatomic, assign) BOOL isFavMode;
- (void)configureWithDict:(NSDictionary *)item isFavorite:(BOOL)isFav;
@end
@implementation VMItemCardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    UIView *cb = [UIView new];
    cb.backgroundColor = [UIColor clearColor];
    self.selectedBackgroundView = cb;
    [self setupCompactUI];
  }
  return self;
}

- (void)setupCompactUI {
  _bgView = [UIView new];
  [VMUIHelper styleCard:_bgView];
  _bgView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_bgView];
  _lblNote = [UILabel new];
  _lblNote.font = [VMUIHelper scaledFontOfSize:16 weight:UIFontWeightSemibold];
  _lblNote.adjustsFontForContentSizeCategory = YES;
  _lblNote.numberOfLines = 0;
  _lblAddr = [UILabel new];
  _lblAddr.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
      scaledFontForFont:[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]];
  _lblAddr.adjustsFontForContentSizeCategory = YES;
  _lblAddr.textColor = UIColor.secondaryLabelColor;
  _lblAddr.numberOfLines = 0;
  _lblValue = [UILabel new];
  _lblValue.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
      scaledFontForFont:[UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightSemibold]];
  _lblValue.adjustsFontForContentSizeCategory = YES;
  _lblValue.numberOfLines = 0;
  UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[_lblNote, _lblAddr, _lblValue]];
  content.axis = UILayoutConstraintAxisVertical;
  content.spacing = 6;
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:content];
  _lockSwitch = [UISwitch new];
  _lockSwitch.onTintColor = [VMUIHelper accentColor];
  _lockSwitch.accessibilityLabel = TR(@"Act_Lock");
  [_lockSwitch addTarget:self action:@selector(onSwitch:) forControlEvents:UIControlEventValueChanged];
  _lockSwitch.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_lockSwitch];
  _favIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star.fill"]];
  _favIcon.tintColor = UIColor.systemOrangeColor;
  _favIcon.contentMode = UIViewContentModeScaleAspectFit;
  _favIcon.hidden = YES;
  _favIcon.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_favIcon];
  [NSLayoutConstraint activateConstraints:@[
    [_bgView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
    [_bgView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
    [_bgView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
    [_bgView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    [content.topAnchor constraintEqualToAnchor:_bgView.topAnchor constant:16],
    [content.bottomAnchor constraintEqualToAnchor:_bgView.bottomAnchor constant:-16],
    [content.leadingAnchor constraintEqualToAnchor:_bgView.leadingAnchor constant:16],
    [content.trailingAnchor constraintEqualToAnchor:_lockSwitch.leadingAnchor constant:-12],
    [_lockSwitch.trailingAnchor constraintEqualToAnchor:_bgView.trailingAnchor constant:-16],
    [_lockSwitch.centerYAnchor constraintEqualToAnchor:_bgView.centerYAnchor],
    [_favIcon.centerXAnchor constraintEqualToAnchor:_lockSwitch.centerXAnchor],
    [_favIcon.centerYAnchor constraintEqualToAnchor:_lockSwitch.centerYAnchor],
    [_favIcon.widthAnchor constraintEqualToConstant:24],
    [_favIcon.heightAnchor constraintEqualToConstant:24]
  ]];
}

- (void)configureWithDict:(NSDictionary *)item isFavorite:(BOOL)isFav {
  _isFavMode = isFav;

  uint64_t addr = [item[@"addr"] unsignedLongLongValue];
  NSString *valStr = item[@"val"];
  VMDataType t =
      item[@"type"] ? (VMDataType)[item[@"type"] intValue] : VMDataTypeInt32;
  NSString *note = item[@"note"];

  if (!valStr) {
    valStr = [[VMMemoryEngine shared] readAddress:addr type:t];
  }

  _lblNote.text = (note && note.length > 0)
                      ? note
                      : (isFav ? TR(@"Mod_Menu_Fav") : TR(@"Lock_Title"));
  _lblAddr.text = [NSString stringWithFormat:@"%@ · 0x%llX", [self typeName:t], addr];
  _lockSwitch.accessibilityLabel = [NSString stringWithFormat:@"%@ · %@", TR(@"Act_Lock"), _lblNote.text];
  _lblValue.text = valStr ?: @"--";

  if (isFav) {
    _lockSwitch.hidden = YES;
    _favIcon.hidden = NO;
    _bgView.layer.borderColor = [UIColor clearColor].CGColor;
    _bgView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    _lblValue.textColor = [UIColor systemBlueColor];

  } else {
    _lockSwitch.hidden = NO;
    _favIcon.hidden = YES;

    BOOL enabled = item[@"enabled"] ? [item[@"enabled"] boolValue] : NO;
    _lockSwitch.on = enabled;

    if (enabled) {
      _bgView.layer.borderWidth = 0;
      _bgView.layer.borderColor = [UIColor systemGreenColor].CGColor;
      _bgView.backgroundColor = [VMUIHelper cardColor];
      _lblValue.textColor = [VMUIHelper accentColor];
    } else {
      _bgView.layer.borderWidth = 0;
      _bgView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
      _lblValue.textColor = [UIColor labelColor];
    }
  }
}

- (void)onSwitch:(UISwitch *)sender {
  if ([self.delegate respondsToSelector:@selector(itemCellDidToggleSwitch:isOn:)]) {
    [self.delegate itemCellDidToggleSwitch:self isOn:sender.isOn];
  }
}

- (NSString *)typeName:(VMDataType)type {
  switch (type) {
  case VMDataTypeInt8:
    return @"I8";
  case VMDataTypeInt16:
    return @"I16";
  case VMDataTypeInt32:
    return @"I32";
  case VMDataTypeInt64:
    return @"I64";
  case VMDataTypeFloat:
    return @"F32";
  case VMDataTypeDouble:
    return @"F64";
  default:
    return @"??";
  }
}

@end
@interface VMLockListViewController () <
    UIDocumentPickerDelegate, VMPointerLockCellDelegate, VMItemCardCellDelegate,
    VMSignatureLockCellDelegate, VMRVAManagerCellDelegate,
    UICollectionViewDelegate, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout,
    UITableViewDragDelegate, UITableViewDropDelegate>
@property(nonatomic, strong) dispatch_source_t gcdTimer;
@property(nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@property(nonatomic, assign) NSInteger currentTab;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIBarButtonItem *valueSnapshotButton;
@property(nonatomic, strong) UIToolbar *batchToolbar;
@property(nonatomic, assign) BOOL batchToolbarShown;
@property(nonatomic, assign) CGFloat batchOriginalContentBottomInset;
@property(nonatomic, assign) CGFloat batchOriginalIndicatorBottomInset;
@property(nonatomic, assign) BOOL isGlobalSelectAll;
@property(nonatomic, assign) BOOL showAllPointers;
@property(nonatomic, assign) BOOL isProcessingAction;
@property(nonatomic, assign) BOOL isFolderMode;
@property(nonatomic, strong) NSMutableArray *folderList;
@property(nonatomic, strong) NSMutableDictionary *folderMetadata;
@property(nonatomic, copy) NSString *targetBundleID;
@property(nonatomic, copy) NSString *lastAutoNavBundleID;
@property(nonatomic, assign) BOOL manuallyShowFolder;
@property(nonatomic, strong)
    NSArray *activeSignatures; 
@property(nonatomic, strong)
    NSMutableDictionary *signatureRuntimeCache; 
@property(nonatomic, strong) UIView *headerContainer;
@property(nonatomic, copy) NSString *contextHeaderKey;
@property(nonatomic, strong) UICollectionView *tabCollectionView; 
@property(nonatomic, strong) NSArray<NSString *> *tabItems;       
@property(nonatomic, strong) NSMutableArray *scriptList;
@property(nonatomic, strong) NSMutableDictionary *scriptLogs;
@property(nonatomic, strong) NSDictionary *pendingJumpInfo;
@end

@protocol VMScriptCardCellDelegate <NSObject>
- (void)scriptCellDidTapRun:(UITableViewCell *)cell;
- (void)scriptCellDidTapEdit:(UITableViewCell *)cell;
- (void)scriptCellDidTapEditScript:(UITableViewCell *)cell;
@end

@interface VMScriptCardCell : UITableViewCell
@property(nonatomic, weak) id<VMScriptCardCellDelegate> delegate;
@property(nonatomic, strong) UIView *bgView;
@property(nonatomic, strong) UILabel *lblTitle;
@property(nonatomic, strong) UILabel *lblAuthor;
@property(nonatomic, strong) UILabel *lblDesc;
@property(nonatomic, strong) UITextView *consoleView;
@property(nonatomic, strong) UIView *statusIndicator;
@property(nonatomic, strong) UIButton *btnRun;
@property(nonatomic, strong) UIButton *btnEdit;
@property(nonatomic, strong) UIButton *btnEditScript;
@property(nonatomic, strong) UIStackView *btnStack;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, strong) NSLayoutConstraint *btnStackTopToConsole;
@property(nonatomic, strong) NSLayoutConstraint *btnStackTopToDesc;

- (void)configureWithModel:(VMScriptModel *)model log:(NSString *)log;
- (void)setRunning:(BOOL)running;
@end

@implementation VMScriptCardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  _bgView = [[UIView alloc] init];
  _bgView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  [VMUIHelper styleCard:_bgView];
  _bgView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_bgView];

  _lblTitle = [[UILabel alloc] init];
  _lblTitle.font = [VMUIHelper scaledFontOfSize:16 weight:UIFontWeightSemibold];
  _lblTitle.numberOfLines = 0;
  _lblTitle.adjustsFontForContentSizeCategory = YES;
  _lblTitle.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_lblTitle];

  _lblAuthor = [[UILabel alloc] init];
  _lblAuthor.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
  _lblAuthor.numberOfLines = 0;
  _lblAuthor.adjustsFontForContentSizeCategory = YES;
  _lblAuthor.textColor = [UIColor secondaryLabelColor];
  _lblAuthor.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_lblAuthor];

  _lblDesc = [[UILabel alloc] init];
  _lblDesc.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
  _lblDesc.adjustsFontForContentSizeCategory = YES;
  _lblDesc.textColor = [UIColor secondaryLabelColor];
  _lblDesc.numberOfLines = 2;
  _lblDesc.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_lblDesc];

  _statusIndicator = [[UIView alloc] init];
  _statusIndicator.backgroundColor = [UIColor systemGray4Color];
  _statusIndicator.layer.cornerRadius = 3;
  _statusIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_statusIndicator];

  _consoleView = [[UITextView alloc] init];
  _consoleView.showsHorizontalScrollIndicator = NO;
  _consoleView.backgroundColor = [VMUIHelper canvasColor];
  _consoleView.textColor = UIColor.secondaryLabelColor;
  _consoleView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
  _consoleView.editable = NO;
  _consoleView.layer.cornerRadius = 6;
  _consoleView.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_consoleView];

  _btnEdit = [UIButton buttonWithType:UIButtonTypeSystem];
  [_btnEdit setTitle:TR(@"Common_Edit") forState:UIControlStateNormal];
  _btnEdit.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
  _btnEdit.backgroundColor = [[UIColor systemGrayColor] colorWithAlphaComponent:0.1];
  _btnEdit.layer.cornerRadius = 6;
  [_btnEdit addTarget:self action:@selector(onEdit) forControlEvents:UIControlEventTouchUpInside];

  _btnEditScript = [UIButton buttonWithType:UIButtonTypeSystem];
  [_btnEditScript setTitle:TR(@"Script_Btn_EditCode") forState:UIControlStateNormal];
  _btnEditScript.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
  _btnEditScript.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.1];
  [_btnEditScript setTitleColor:[UIColor systemOrangeColor] forState:UIControlStateNormal];
  _btnEditScript.layer.cornerRadius = 6;
  [_btnEditScript addTarget:self action:@selector(onEditScript) forControlEvents:UIControlEventTouchUpInside];

  _btnRun = [UIButton buttonWithType:UIButtonTypeSystem];
  [_btnRun setTitle:TR(@"Script_Btn_Run") forState:UIControlStateNormal];
  _btnRun.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
  _btnRun.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.1];
  _btnRun.layer.cornerRadius = 6;
  [_btnRun addTarget:self action:@selector(onRun) forControlEvents:UIControlEventTouchUpInside];

  _btnStack = [[UIStackView alloc] init];
  _btnStack.axis = UILayoutConstraintAxisHorizontal;
  _btnStack.spacing = 8;
  _btnStack.distribution = UIStackViewDistributionFillEqually;
  _btnStack.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_btnStack];

  [_btnStack addArrangedSubview:_btnEdit];
  [_btnStack addArrangedSubview:_btnEditScript];
  [_btnStack addArrangedSubview:_btnRun];

  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _spinner.hidesWhenStopped = YES;
  _spinner.translatesAutoresizingMaskIntoConstraints = NO;
  [_bgView addSubview:_spinner];

  _btnEdit.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:_btnEdit primary:NO];
  _btnEdit.tintColor = [VMUIHelper accentColor];
  _btnEditScript.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:_btnEditScript primary:NO];
  _btnRun.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:_btnRun primary:YES];
  CGFloat p = 16;
  
  _btnStackTopToConsole = [_btnStack.topAnchor constraintEqualToAnchor:_consoleView.bottomAnchor constant:12];
  _btnStackTopToDesc = [_btnStack.topAnchor constraintEqualToAnchor:_lblDesc.bottomAnchor constant:12];
  
  [NSLayoutConstraint activateConstraints:@[
    [_bgView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
    [_bgView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
    [_bgView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
    [_bgView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:0],
    [_lblTitle.topAnchor constraintEqualToAnchor:_bgView.topAnchor constant:p],
    [_lblTitle.leadingAnchor constraintEqualToAnchor:_bgView.leadingAnchor constant:p],
    [_lblTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_statusIndicator.leadingAnchor constant:-12],
    [_statusIndicator.centerYAnchor constraintEqualToAnchor:_lblTitle.centerYAnchor],
    [_statusIndicator.trailingAnchor constraintEqualToAnchor:_bgView.trailingAnchor constant:-p],
    [_statusIndicator.widthAnchor constraintEqualToConstant:6],
    [_statusIndicator.heightAnchor constraintEqualToConstant:6],
    [_lblAuthor.topAnchor constraintEqualToAnchor:_lblTitle.bottomAnchor constant:4],
    [_lblAuthor.trailingAnchor constraintEqualToAnchor:_statusIndicator.leadingAnchor constant:-6],
    [_lblAuthor.leadingAnchor constraintEqualToAnchor:_lblTitle.leadingAnchor],
    [_lblDesc.topAnchor constraintEqualToAnchor:_lblAuthor.bottomAnchor constant:8],
    [_lblDesc.leadingAnchor constraintEqualToAnchor:_lblTitle.leadingAnchor],
    [_lblDesc.trailingAnchor constraintEqualToAnchor:_bgView.trailingAnchor constant:-p],
    [_consoleView.topAnchor constraintEqualToAnchor:_lblDesc.bottomAnchor constant:8],
    [_consoleView.leadingAnchor constraintEqualToAnchor:_bgView.leadingAnchor constant:p],
    [_consoleView.trailingAnchor constraintEqualToAnchor:_bgView.trailingAnchor constant:-p],
    [_consoleView.heightAnchor constraintEqualToConstant:75],
    [_btnStack.leadingAnchor constraintEqualToAnchor:_bgView.leadingAnchor constant:p],
    [_btnStack.trailingAnchor constraintEqualToAnchor:_bgView.trailingAnchor constant:-p],
    [_btnStack.bottomAnchor constraintEqualToAnchor:_bgView.bottomAnchor constant:-p],
    [_btnStack.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    [_spinner.centerXAnchor constraintEqualToAnchor:_btnRun.centerXAnchor],
    [_spinner.centerYAnchor constraintEqualToAnchor:_btnRun.centerYAnchor]
  ]];
  
  _btnStackTopToConsole.active = YES;
  _btnStackTopToDesc.active = NO;
}

- (void)setRunning:(BOOL)running {
  _isRunning = running;
  [UIView animateWithDuration:0.3 animations:^{
    if (running) {
      self.bgView.layer.borderWidth = 2.0;
      self.bgView.layer.borderColor = [UIColor.systemGreenColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
      self.btnRun.alpha = 0;
      self.statusIndicator.backgroundColor = [UIColor systemGreenColor];
      [self.spinner startAnimating];
    } else {
      self.bgView.layer.borderWidth = 0;
      self.btnRun.alpha = 1.0;
      self.statusIndicator.backgroundColor = [UIColor systemGray4Color];
      [self.spinner stopAnimating];
    }
  }];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if (self.isRunning && [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    self.bgView.layer.borderColor = [UIColor.systemGreenColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
  }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [super setEditing:editing animated:animated];
  self.selectionStyle = editing ? UITableViewCellSelectionStyleDefault
                                : UITableViewCellSelectionStyleNone;
}

- (void)onRun { [self.delegate scriptCellDidTapRun:self]; }
- (void)onEdit { [self.delegate scriptCellDidTapEdit:self]; }
- (void)onEditScript { [self.delegate scriptCellDidTapEditScript:self]; }

- (void)configureWithModel:(VMScriptModel *)model log:(NSString *)log {
  _lblTitle.text = model.note ?: model.fileName;
  _lblDesc.text = model.desc ?: TR(@"Script_Default_Desc");
  _lblAuthor.text = [NSString stringWithFormat:@"@%@", model.author ?: @"?"];
  _consoleView.text = log ?: [NSString stringWithFormat:@"> %@", TR(@"Script_Console_Ready")];
  
  _btnEditScript.hidden = NO;
  
  _consoleView.hidden = NO;
  _btnStackTopToDesc.active = NO;
  _btnStackTopToConsole.active = YES;
}
@end

@interface VMTabMenuCell : UICollectionViewCell
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIView *bgView;
@end
@implementation VMTabMenuCell
- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    
    _bgView = [[UIView alloc] initWithFrame:self.contentView.bounds];
    
    _bgView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    _bgView.layer.cornerRadius = 12;
    _bgView.layer.shadowColor = [UIColor blackColor].CGColor;
    _bgView.layer.shadowOpacity = 0;
    _bgView.layer.shadowOffset = CGSizeMake(0, 1);
    _bgView.layer.shadowRadius = 2;
    _bgView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _bgView.hidden = YES; 
    [self.contentView addSubview:_bgView];

    _titleLabel = [[UILabel alloc] initWithFrame:self.contentView.bounds];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _titleLabel.textColor = [UIColor secondaryLabelColor];
    _titleLabel.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:_titleLabel];
  }
  return self;
}

- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];
  self.bgView.hidden = !selected;
  self.bgView.backgroundColor = [VMUIHelper filledColorForTint:VMUIHelper.accentColor];
  self.titleLabel.textColor = selected ? UIColor.whiteColor : UIColor.secondaryLabelColor;
  self.titleLabel.font = [VMUIHelper scaledFontOfSize:14 weight:selected ? UIFontWeightSemibold : UIFontWeightMedium];
  self.isAccessibilityElement = YES;
  self.accessibilityLabel = self.titleLabel.text;
  self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}

@end

@implementation VMLockListViewController
- (void)checkAndCleanupFolderForBundleID:(NSString *)bid {
  if (!bid || bid.length == 0)
    return;
  NSFileManager *fm = [NSFileManager defaultManager];

  NSString *root = [self getDirectoryForCurrentTab];
  NSString *folderPath = [root stringByAppendingPathComponent:bid];

  BOOL isDir = NO;
  if (![fm fileExistsAtPath:folderPath isDirectory:&isDir] || !isDir)
    return;

  NSArray *contents = [fm contentsOfDirectoryAtPath:folderPath error:nil];

  NSString *ext = @".vmpt";
  if (self.currentTab == 3)
    ext = @".vmrva";
  else if (self.currentTab == 4)
    ext = @".vmsig";
  else if (self.currentTab == 5)
    ext = @".vmvapt";
  else if (self.currentTab == 6)
    ext = @".vmsc";

  NSArray *files = [contents
      filteredArrayUsingPredicate:[NSPredicate
                                      predicateWithFormat:@"self ENDSWITH %@",
                                                          ext]];

  if (files.count == 0) {
    [fm removeItemAtPath:folderPath error:nil];
    if (self.currentTab >= 1 && !self.isFolderMode &&
        [self.targetBundleID isEqualToString:bid]) {
      [self backToFolderList];
    }
  }
}

- (void)refreshVisiblePointerValues {
  if (self.currentTab != 2)
    return;
  if (self.isFolderMode)
    return;
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
  NSArray *dataSrc = [self currentDisplayData];
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *updates = [NSMutableDictionary dictionary];
        for (NSIndexPath *indexPath in visiblePaths) {
          if (indexPath.row >= dataSrc.count)
            continue;
          VMPointerChain *chain = dataSrc[indexPath.row];
          uint64_t finalAddr = [self forceResolveChain:chain];
          NSString *valStr = TR(@"Placeholder_None");
          NSString *addrStr = TR(@"Text_Null");
          if (finalAddr > 0) {
            VMDataType t = (VMDataType)chain.lockType;
            valStr = [engine readAddress:finalAddr type:t];
            addrStr = [NSString stringWithFormat:@"0x%llX", finalAddr];
          } else {
            valStr = TR(@"Status_Disconnected");
          }
          updates[indexPath] = @{@"val" : valStr, @"addr" : addrStr};
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          for (NSIndexPath *indexPath in updates) {
            VMPointerLockCell *cell = (VMPointerLockCell *)[self.tableView
                cellForRowAtIndexPath:indexPath];
            if (cell) {
              NSDictionary *info = updates[indexPath];
              [cell configureWithChain:dataSrc[indexPath.row] address:info[@"addr"] val:info[@"val"] type:[self typeNameForType:(VMDataType)((VMPointerChain *)dataSrc[indexPath.row]).lockType]];
            }
          }
        });
      });
}

- (NSString *)typeNameForType:(VMDataType)type {
  switch (type) {
  case VMDataTypeInt8:
    return @"I8";
  case VMDataTypeInt16:
    return @"I16";
  case VMDataTypeInt32:
    return @"I32";
  case VMDataTypeInt64:
    return @"I64";
  case VMDataTypeUInt8:
    return @"U8";
  case VMDataTypeUInt16:
    return @"U16";
  case VMDataTypeUInt32:
    return @"U32";
  case VMDataTypeUInt64:
    return @"U64";
  case VMDataTypeFloat:
    return @"F32";
  case VMDataTypeDouble:
    return @"F64";
  case VMDataTypeString:
    return @"Str";
  default:
    return @"??";
  }
}

- (BOOL)ensureConnectionForChain:(VMPointerChain *)chain {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  NSString *targetBid = chain.bundleID;
  BOOL isTaskValid = (eng.targetTask != MACH_PORT_NULL);
  BOOL isPidAlive = (eng.targetPid > 0 && kill(eng.targetPid, 0) == 0);
  BOOL isBidMatch = YES;

  if (targetBid && targetBid.length > 0 && eng.currentBundleID) {
    isBidMatch = [eng.currentBundleID isEqualToString:targetBid];
  }

  if (isTaskValid && isPidAlive && isBidMatch) {
    return YES;
  }

  if (targetBid && targetBid.length > 0) {
    if ([self tryReconnectForBundleID:targetBid]) {
      [eng loadRemoteModules];
      [self.tableView reloadData];
      UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
      [gen impactOccurred];
      return YES;
    }
  }

  NSString *appName = targetBid ?: TR(@"App_Unknown");
  NSString *msg = [NSString stringWithFormat:@"%@\n(%@)", TR(@"Err_Not_Connected_Msg"), appName];
  [self showToast:msg];
  return NO;
}

#pragma mark - Robust Auto Reconnect (Ported from Verifier)

- (int)ensureConnectionForBundleID:(NSString *)targetBid {
  VMMemoryEngine *eng = [VMMemoryEngine shared];

  if (eng.targetTask != MACH_PORT_NULL && eng.targetPid > 0 && [eng.currentBundleID isEqualToString:targetBid] && kill(eng.targetPid, 0) == 0) {
    return 1;
  }

  if ([self tryAutoAttach:targetBid]) {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
    [self showToast:[NSString stringWithFormat:TR(@"Ptr_Auto_Attach_Success"), [VMMemoryEngine shared].targetPid]];
    [self.tableView reloadData];
    return 0;
  }

  NSString *appName = targetBid ?: TR(@"App_Unknown");
  NSString *msg = [NSString stringWithFormat:@"%@\n(%@)", TR(@"Err_Not_Connected_Msg"), appName];
  [self showToast:msg];

  return -1; 
}

- (BOOL)tryAutoAttach:(NSString *)targetBid {
  if (!targetBid || targetBid.length == 0)
    return NO;

  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask != MACH_PORT_NULL && 
      eng.targetPid > 0 && 
      kill(eng.targetPid, 0) == 0 &&
      [eng.currentBundleID caseInsensitiveCompare:targetBid] == NSOrderedSame) {
    return YES;
  }

  int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size;
  if (sysctl(mib, 4, NULL, &size, NULL, 0) == -1)
    return NO;

  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (sysctl(mib, 4, procs, &size, NULL, 0) == -1) {
    free(procs);
    return NO;
  }

  int count = size / sizeof(struct kinfo_proc);
  pid_t foundPid = 0;

  for (int i = 0; i < count; i++) {
    pid_t pid = procs[i].kp_proc.p_pid;
    if (pid <= 0)
      continue;

    char pathBuffer[4096];
    memset(pathBuffer, 0, sizeof(pathBuffer));
    proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];

    if ([fullPath containsString:@".app"]) {
      NSString *appDir = [fullPath stringByDeletingLastPathComponent];
      while (![appDir.pathExtension isEqualToString:@"app"] &&
             ![appDir isEqualToString:@"/"]) {
        appDir = [appDir stringByDeletingLastPathComponent];
      }

      NSString *plistPath =
          [appDir stringByAppendingPathComponent:@"Info.plist"];
      NSDictionary *info =
          [NSDictionary dictionaryWithContentsOfFile:plistPath];

      if (info && info[@"CFBundleIdentifier"]) {
        NSString *bid = info[@"CFBundleIdentifier"];
        if ([bid caseInsensitiveCompare:targetBid] == NSOrderedSame) {
          foundPid = pid;
          break;
        }
      }
    }
  }
  free(procs);

  if (foundPid > 0) {
    BOOL success = [[VMMemoryEngine shared] attachToPid:foundPid];
    if (success) {
      [VMMemoryEngine shared].currentBundleID = targetBid;
      [[VMMemoryEngine shared]
          loadRemoteModules]; 
      return YES;
    }
  }
  return NO;
}

- (BOOL)tryReconnectForBundleID:(NSString *)bid {
  if (!bid || bid.length == 0)
    return NO;
  int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size;
  if (sysctl(mib, 4, NULL, &size, NULL, 0) == -1)
    return NO;
  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (sysctl(mib, 4, procs, &size, NULL, 0) == -1) {
    free(procs);
    return NO;
  }
  int count = size / sizeof(struct kinfo_proc);
  pid_t foundPid = 0;
  for (int i = 0; i < count; i++) {
    pid_t pid = procs[i].kp_proc.p_pid;
    if (pid <= 0)
      continue;
    char pathBuffer[4096];
    memset(pathBuffer, 0, sizeof(pathBuffer));
    proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];
    if ([fullPath containsString:@".app"]) {
      NSString *appDir = [fullPath stringByDeletingLastPathComponent];
      while (![appDir.pathExtension isEqualToString:@"app"] &&
             ![appDir isEqualToString:@"/"]) {
        appDir = [appDir stringByDeletingLastPathComponent];
      }
      NSString *plistPath =
          [appDir stringByAppendingPathComponent:@"Info.plist"];
      NSDictionary *info =
          [NSDictionary dictionaryWithContentsOfFile:plistPath];
      if (info && [info[@"CFBundleIdentifier"] caseInsensitiveCompare:bid] ==
                      NSOrderedSame) {
        foundPid = pid;
        break;
      }
    }
  }
  free(procs);
  if (foundPid > 0) {
    BOOL success = [[VMMemoryEngine shared] attachToPid:foundPid];
    if (success) {
      [VMMemoryEngine shared].currentBundleID = bid;
      [[VMMemoryEngine shared] loadRemoteModules];

      NSString *msg =
          [NSString stringWithFormat:TR(@"Sig_Auto_Reconnected"), foundPid];
      [self showToast:msg];

      return YES;
    }
  }
  return NO;
}

- (uint64_t)forceResolveChain:(VMPointerChain *)chain {
  if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL)
    return 0;
  uint64_t (^findBase)(void) = ^uint64_t {
    if ([chain.moduleName isEqualToString:@"virtual"]) {
      return [VMMemoryEngine shared].mainModuleAddress;
    } else {
      return [[VMMemoryEngine shared] findModuleBaseAddress:chain.moduleName];
    }
  };
  uint64_t modBase = findBase();
  if (modBase == 0) {
    [[VMMemoryEngine shared] loadRemoteModules];
    modBase = findBase();
  }
  if (modBase == 0)
    return 0;
  return
      [[VMMemoryEngine shared] resolvePointerChain:(modBase + chain.baseOffset)
                                           offsets:chain.offsets];
}

- (NSArray *)currentDisplayData {
  if (self.currentTab == 0) {
    return [VMMemoryEngine shared].lockedItems;
  }

  if (self.currentTab == 1) {
    return [VMMemoryEngine shared].favoriteItems;
  }

  if (self.currentTab == 2) {
    if (self.isFolderMode)
      return @[];
    if (self.targetBundleID) {
      NSArray *all =
          [[VMLockManager shared] loadLocksForApp:self.targetBundleID];
      NSPredicate *pred =
          [NSPredicate predicateWithFormat:@"isSignatureMode == NO"];
      return [all filteredArrayUsingPredicate:pred];
    }
    return @[];
  }

  if (self.currentTab == 3) {
    if (self.isFolderMode)
      return @[];
    if (self.targetBundleID) {
      NSMutableArray *filtered = [NSMutableArray array];
      for (VMRVAPatch *p in [VMMemoryEngine shared].rvaPatches) {
        if ([p.bundleID isEqualToString:self.targetBundleID]) {
          [filtered addObject:p];
        }
      }

      [filtered sortUsingComparator:^NSComparisonResult(VMRVAPatch *obj1,
                                                        VMRVAPatch *obj2) {
        double s1 = obj1.sortOrder > 0 ? obj1.sortOrder : obj1.createdAt;
        double s2 = obj2.sortOrder > 0 ? obj2.sortOrder : obj2.createdAt;
        return [@(s2) compare:@(s1)];
      }];

      return filtered;
    }
    return @[];
  }

  if (self.currentTab == 4) {
    if (self.isFolderMode)
      return @[];
    
    return self.activeSignatures ?: @[];
  }

  if (self.currentTab == 5) { 
    if (self.isFolderMode)
      return @[];
    if (self.targetBundleID) {
      
      NSString *root = [[VMPointerManager shared] verifierFolder];
      NSString *appDir =
          [root stringByAppendingPathComponent:self.targetBundleID];
      NSFileManager *fm = [NSFileManager defaultManager];
      NSArray *files = [fm contentsOfDirectoryAtPath:appDir error:nil];

      NSArray *vmFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.vmvapt'"]];
      return [vmFiles sortedArrayUsingComparator:^NSComparisonResult(NSString *f1, NSString *f2) {
        NSString *path1 = [appDir stringByAppendingPathComponent:f1];
        NSString *path2 = [appDir stringByAppendingPathComponent:f2];
        NSDictionary *attrs1 = [fm attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attrs2 = [fm attributesOfItemAtPath:path2 error:nil];
        NSDate *date1 = attrs1[NSFileModificationDate];
        NSDate *date2 = attrs2[NSFileModificationDate];
        return [date2 compare:date1];
      }];
    }
    return @[];
  }

  if (self.currentTab == 6) { 
    if (self.isFolderMode)
      return @[];
    
    return self.scriptList ?: @[];
  }

  return @[];
}

- (instancetype)init {
  if (self = [super init]) {
    _folderList = [NSMutableArray array];
    _folderMetadata = [NSMutableDictionary dictionary];
    _scriptLogs = [NSMutableDictionary dictionary];
    _isFolderMode = YES;
    _manuallyShowFolder = NO;
  }
  return self;
}

- (void)setupFloatingHeader {
  
  self.headerContainer = [[UIView alloc] init];
  self.headerContainer.translatesAutoresizingMaskIntoConstraints = NO;
  self.headerContainer.backgroundColor = [UIColor clearColor];
  [self.view addSubview:self.headerContainer];

  UIBlurEffect *blur =
      [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
  UIVisualEffectView *effectView =
      [[UIVisualEffectView alloc] initWithEffect:blur];
  effectView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerContainer addSubview:effectView];

  [NSLayoutConstraint activateConstraints:@[
    [effectView.topAnchor constraintEqualToAnchor:self.headerContainer.topAnchor],
    [effectView.bottomAnchor constraintEqualToAnchor:self.headerContainer.bottomAnchor],
    [effectView.leadingAnchor constraintEqualToAnchor:self.headerContainer.leadingAnchor],
    [effectView.trailingAnchor constraintEqualToAnchor:self.headerContainer.trailingAnchor]
  ]];

  UICollectionViewFlowLayout *layout =
      [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.minimumInteritemSpacing = 5;
  layout.sectionInset = UIEdgeInsetsMake(0, 10, 0, 10); 

  self.tabCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                              collectionViewLayout:layout];
  self.tabCollectionView.showsHorizontalScrollIndicator = NO;
  self.tabCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tabCollectionView.backgroundColor =
      [UIColor clearColor]; 
  self.tabCollectionView.showsHorizontalScrollIndicator = NO;
  self.tabCollectionView.delegate = self;
  self.tabCollectionView.dataSource = self;
  [self.tabCollectionView registerClass:[VMTabMenuCell class] forCellWithReuseIdentifier:@"TabCell"];
  [self.headerContainer addSubview:self.tabCollectionView];

  UILayoutGuide *g = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [self.headerContainer.topAnchor constraintEqualToAnchor:g.topAnchor],
    [self.headerContainer.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
    [self.headerContainer.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
    [self.headerContainer.heightAnchor constraintEqualToConstant:60],
    [self.tabCollectionView.topAnchor constraintEqualToAnchor:self.headerContainer.topAnchor constant:8],
    [self.tabCollectionView.bottomAnchor constraintEqualToAnchor:self.headerContainer.bottomAnchor constant:-8],
    [self.tabCollectionView.leadingAnchor constraintEqualToAnchor:self.headerContainer.leadingAnchor],
    [self.tabCollectionView.trailingAnchor constraintEqualToAnchor:self.headerContainer.trailingAnchor]
  ]];

  [self.tableView.topAnchor constraintEqualToAnchor:self.headerContainer.bottomAnchor].active = YES;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.tabBarItem.title = TR(@"Tab_Toolbox");
  self.navigationItem.title = TR(@"Lock_Tab_Addr");
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

  self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
  self.tableView.showsHorizontalScrollIndicator = NO;
  self.tableView.delegate = self;
  self.tableView.dataSource = (id<UITableViewDataSource>)self;
  [VMUIHelper styleTableView:self.tableView];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  self.tableView.dragInteractionEnabled = YES;
  self.tableView.dragDelegate = self;
  self.tableView.dropDelegate = self;

  if (@available(iOS 15.0, *)) {
    self.tableView.sectionHeaderTopPadding = 0;
  }
  self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
  [self.view addSubview:self.tableView];

  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor]
  ]];

  self.tabItems = @[
    TR(@"Lock_Tab_Addr"),       
    TR(@"Tab_Fav"),             
    TR(@"Lock_Tab_Ptr"),        
    @"RVA",                     
    TR(@"Lock_Tab_Sig"),        
    TR(@"Verifier_Btn_Verify"), 
    TR(@"Tab_Script")           
  ];

  if (self.defaultTabIndex > 0 && self.defaultTabIndex < self.tabItems.count) {
    self.currentTab = self.defaultTabIndex;
  } else {
    self.currentTab = 0;
  }

  [self setupFloatingHeader];

  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *idx = [NSIndexPath indexPathForItem:self.currentTab inSection:0];
    [self.tabCollectionView selectItemAtIndexPath:idx animated:NO scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
  });

  self.navigationItem.leftBarButtonItem = nil;

  UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  [self.tableView addGestureRecognizer:lp];

  [[VMMemoryEngine shared] reloadLockedPointers];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopGCDTimer) name:UIApplicationWillTerminateNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDataResetNotification:) name:@"VMDataDidResetNotification" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onJumpToTabNotification:) name:@"VM_JUMP_TO_TAB" object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLockItemAdded) name:@"VM_LockItemAdded" object:nil];

  [self reloadFolderData];
  [self tabChanged];

  UIRefreshControl *ref = [[UIRefreshControl alloc] init];
  ref.attributedTitle = [[NSAttributedString alloc] initWithString:TR(@"Pull_Idle")];
  [ref addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
  self.tableView.refreshControl = ref;

  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];
  self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

  [self.tableView registerClass:[VMPointerLockCell class] forCellReuseIdentifier:@"VMPointerLockCell"];
  [self.tableView registerClass:[VMSignatureLockCell class] forCellReuseIdentifier:@"VMSignatureLockCell"];
}

- (void)tabChanged {
  
  if (self.tableView.isEditing) {
    [self exitBatchMode];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    if (self->_currentTab >= 2 && self->_currentTab <= 6 && self->_currentTab != 5) {
      [self reloadFolderDataOrFileData];
    }

    if (self->_currentTab >= 2) {
      [self checkSmartNavigation];
    } else {
      self.isFolderMode = NO;
      [self.tableView reloadData];
      [self updateNavBar];
      [self updateFooter];
    }

    if (self->_currentTab == 4) {
      
      if (!self.signatureRuntimeCache) {
        self.signatureRuntimeCache = [NSMutableDictionary dictionary];
      }
      for (VMSignatureModel *m in self.activeSignatures) {
        m.isScanning = NO;
        NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", self.targetBundleID, m.signature];
        NSDictionary *cached = self.signatureRuntimeCache[cacheKey];
        if (cached) {
          m.runtimeResults = cached[@"runtimeResults"];
          m.resultConfig = [cached[@"resultConfig"] mutableCopy];
        }
      }
      [self.tableView reloadData];
      [self updateFooter];
    }

    if (self->_currentTab == 5 && self.autoOpenVerifierPath && self.autoOpenVerifierPath.length > 0) {
      NSString *filePath = self.autoOpenVerifierPath;
      self.autoOpenVerifierPath = nil;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VMPointerVerifierViewController *vc = [[VMPointerVerifierViewController alloc] init];
        vc.filePath = filePath;
        [self.navigationController pushViewController:vc animated:YES];
      });
    }
  });
}

- (void)saveSignatureRuntimeCache:(VMSignatureModel *)sig {
  if (!sig || !sig.signature || !self.targetBundleID) return;
  if (!self.signatureRuntimeCache) self.signatureRuntimeCache = [NSMutableDictionary dictionary];
  NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", self.targetBundleID, sig.signature];
  self.signatureRuntimeCache[cacheKey] = @{@"runtimeResults": sig.runtimeResults ?: @[], @"resultConfig": sig.resultConfig ?: @{}};
}

#pragma mark - [新增] 导入后跳转和刷新

- (void)jumpToTabAndRefresh:(NSInteger)targetTab
                   bundleID:(nullable NSString *)bid
                   fileName:(nullable NSString *)fileName
                      toast:(nullable NSString *)toast {
  dispatch_async(dispatch_get_main_queue(), ^{
    
    self.currentTab = targetTab;

    if (bid && bid.length > 0) {
      self.targetBundleID = bid;
      self.isFolderMode = NO;
    } else {
      self.isFolderMode = YES; 
    }

    [self reloadFolderDataOrFileData];
    [self.tableView reloadData];
    [self.tabCollectionView reloadData]; 
    [self updateNavBar];
    [self updateFooter];

    NSIndexPath *idx = [NSIndexPath indexPathForItem:targetTab inSection:0];
    [self.tabCollectionView selectItemAtIndexPath:idx animated:YES scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];

    if (toast) [self showToast:toast];

    if (fileName && fileName.length > 0) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger targetRow = -1;
        NSArray *dataSource = [self currentDisplayData]; 
        
        if (dataSource) {
          for (NSInteger i = 0; i < dataSource.count; i++) {
            id item = dataSource[i];
            NSString *name = nil;
            
            if (targetTab == 5 && [item isKindOfClass:[NSString class]]) {
              name = (NSString *)item;
            } else if ([item respondsToSelector:@selector(fileName)]) {
              name = [item performSelector:@selector(fileName)];
            }
            
            if (name && ([name isEqualToString:fileName] || [name.lastPathComponent isEqualToString:fileName.lastPathComponent])) {
              targetRow = i;
              break;
            }
          }
        }

        if (targetRow != -1) {
          NSIndexPath *scrollIdx = [NSIndexPath indexPathForRow:targetRow inSection:0];
          [self.tableView scrollToRowAtIndexPath:scrollIdx atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView selectRowAtIndexPath:scrollIdx animated:YES scrollPosition:UITableViewScrollPositionNone];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              [self.tableView deselectRowAtIndexPath:scrollIdx animated:YES];
            });
          });
        }
      });
    }
  });
}

- (void)jumpToTabAndRefresh:(NSInteger)targetTab {
  [self jumpToTabAndRefresh:targetTab bundleID:nil fileName:nil toast:nil];
}

- (void)processPendingJump {
  if (!self.pendingJumpInfo) return;
  NSDictionary *pending = self.pendingJumpInfo;
  self.pendingJumpInfo = nil;
  NSInteger targetTab = [pending[@"targetTab"] integerValue];
  NSString *bid = pending[@"bundleID"];
  NSString *fileName = pending[@"fileName"];
  NSString *toast = pending[@"toast"];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self jumpToTabAndRefresh:targetTab bundleID:bid fileName:fileName toast:toast];
  });
}

- (void)onDataResetNotification:(NSNotification *)noti {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.tableView.isEditing) [self exitBatchMode];
    self.currentTab = 0;
    self.defaultTabIndex = 0;
    self.isFolderMode = NO;
    self.targetBundleID = nil;
    self.activeSignatures = nil;
    self.scriptList = nil;

    [self reloadFolderData];

    [self.tableView reloadData];
    [self updateNavBar];
    [self updateFooter];

    [self.tabCollectionView reloadData];
    NSIndexPath *idx = [NSIndexPath indexPathForItem:0 inSection:0];
    [self.tabCollectionView selectItemAtIndexPath:idx animated:YES scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
  });
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if (![objc_getAssociatedObject(self, @selector(prepareForLanguageRefresh)) boolValue])
    [self stopGCDTimer];
}

- (void)prepareForLanguageRefresh {
  // Language-only page replacement must leave the shared locking engine running.
  objc_setAssociatedObject(self, @selector(prepareForLanguageRefresh), @YES,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController setToolbarHidden:YES animated:NO];
  [self setBatchToolbarVisible:self.tableView.isEditing];

  NSString *engineBid = [VMMemoryEngine shared].currentBundleID;

  if (self.currentTab == 4 && ![self.targetBundleID isEqualToString:engineBid]) {
    self.activeSignatures = nil;
    [self tabChanged];
  }

  if (self.defaultTabIndex > 0 && self.defaultTabIndex < self.tabItems.count) {
    if (self.currentTab != self.defaultTabIndex) {
      self.currentTab = self.defaultTabIndex; 

      NSInteger tempIndex = self.defaultTabIndex;
      self.defaultTabIndex = 0;

      NSIndexPath *idx = [NSIndexPath indexPathForItem:self.currentTab inSection:0];
      [self.tabCollectionView selectItemAtIndexPath:idx animated:YES scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];

      if (tempIndex == 4 || tempIndex == 5) {
        [self tabChanged];
        return;
      }
    }
  }

  if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL ||
      kill([VMMemoryEngine shared].targetPid, 0) != 0) {
    NSString *bid = [VMMemoryEngine shared].currentBundleID;
    if (bid && [self tryReconnectForBundleID:bid]) {
      [[VMMemoryEngine shared] loadRemoteModules];
    }
  }

  if (_currentTab >= 2) {
    [self checkSmartNavigation];
  } else {
    [[VMMemoryEngine shared] reloadLockedPointers];
    [self.tableView reloadData];
  }

  if (self.currentTab == 4) {
    [[VMMemoryEngine shared] loadRemoteModules];
  }

  [self startGCDTimer];
  [self updateFooter];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  if (self.tableView.isEditing) [self exitBatchMode];
  [self.navigationController setToolbarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  if (self.pendingJumpInfo) {
    [self processPendingJump];
  }
}

- (void)updateNavBar {
  self.valueSnapshotButton = nil;
  NSMutableArray *rightBtns = [NSMutableArray array];
  self.navigationItem.leftBarButtonItem = nil;
  self.navigationItem.leftBarButtonItems = nil; 

  self.navigationItem.title = self.currentTab < self.tabItems.count ? self.tabItems[self.currentTab] : TR(@"Tab_Toolbox");
  [self updateContextHeader];

  if (_currentTab == 0) {
    UIBarButtonItem *add = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                             target:self
                             action:@selector(addLock)];
    [rightBtns addObject:add];
  }
  
  else if (_currentTab == 1) {
    UIBarButtonItem *add = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                             target:self
                             action:@selector(addFavoriteManual)];
    [rightBtns addObject:add];
  }

  if ((_currentTab == 0 || _currentTab == 1) &&
      [[VMMemoryEngine shared] canUndoLastManualWriteBatch]) {
    UIBarButtonItem *undo = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"arrow.uturn.backward"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(undoLastManualBatch)];
    [rightBtns addObject:undo];
  }

  if (_currentTab == 0 || _currentTab == 1) {
    UIBarButtonItem *snapshot = [[UIBarButtonItem alloc]
        initWithTitle:TR(@"Snapshot_Button")
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(showValueSnapshotMenu)];
    self.valueSnapshotButton = snapshot;
    [self updateValueSnapshotButton];
    [rightBtns addObject:snapshot];
  }
  
  else {
    
    UIBarButtonItem *importBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"square.and.arrow.down"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(importAction)];

    if (_currentTab == 6) {
      
      if (!self.isFolderMode) {
        UIBarButtonItem *addScriptBtn = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                 target:self
                                 action:@selector(addNewScript)];

        [rightBtns addObject:addScriptBtn];
        [rightBtns addObject:importBtn];
      } else {
        
        UIBarButtonItem *addScriptBtn = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                 target:self
                                 action:@selector(addNewScript)];
        [rightBtns addObject:addScriptBtn];
        [rightBtns addObject:importBtn];
      }
    } else {
      
      [rightBtns addObject:importBtn];
    }

    if (!self.isFolderMode) {
      UIBarButtonItem *back = [[UIBarButtonItem alloc]
          initWithImage:[UIImage systemImageNamed:@"list.bullet"]
                  style:UIBarButtonItemStylePlain
                 target:self
                 action:@selector(backToFolderList)];
      self.navigationItem.leftBarButtonItem = back;
    }
  }

  self.navigationItem.rightBarButtonItems = rightBtns;
  UIBarButtonItem *select = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle"]
      style:UIBarButtonItemStylePlain target:self action:@selector(enterBatchMode)];
  select.accessibilityLabel = TR(@"Btn_Batch_Select");
  UIBarButtonItem *back = self.navigationItem.leftBarButtonItem;
  self.navigationItem.leftBarButtonItems = back ? @[back, select] : @[select];
}

- (void)backToFolderList {
  self.manuallyShowFolder = YES;
  self.isFolderMode = YES;
  self.targetBundleID = nil;
  [self reloadFolderDataOrFileData];
  [self updateNavBar];
  [self.tableView reloadData];
  [self updateFooter];
}

- (void)openScriptEngine {
  VMScriptViewController *vc = [[VMScriptViewController alloc] init];
  [self.navigationController pushViewController:vc animated:YES];
}

- (void)addNewScript {
  NSString *currentBid = [[VMMemoryEngine shared] currentBundleID];
  if (!currentBid || currentBid.length == 0) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Err_Not_Connected") message:TR(@"Err_Not_Connected_Msg") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Go_Connect") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      for (UIViewController *page in self.tabBarController.viewControllers) {
        if (page.tabBarItem.tag == 0) { self.tabBarController.selectedViewController = page; break; }
      }
    }]];

    [self presentViewController:alert animated:YES completion:nil];
    return;
  }

  VMFormSheetViewController *form = [[VMFormSheetViewController alloc] initWithTitle:TR(@"Script_New_Title") submitTitle:TR(@"Btn_Save")];
  UITextField *name = [form addTextFieldWithLabel:TR(@"Script_Name_Label") value:nil placeholder:TR(@"Script_Name_Placeholder") keyboardType:UIKeyboardTypeDefault];
  UITextField *author = [form addTextFieldWithLabel:TR(@"Label_Author") value:TR(@"Placeholder_Author_Default") placeholder:TR(@"Placeholder_Author") keyboardType:UIKeyboardTypeDefault];
  __block VMScriptModel *created = nil;
  __weak __typeof(self) weakSelf = self;
  form.submitHandler = ^NSString *(VMFormSheetViewController *editor) {
    __typeof(self) strongSelf = weakSelf;
    if (!strongSelf) return TR(@"Err_Write_Permission");
    VMScriptModel *model = [VMScriptModel new];
    model.note = name.text.length ? name.text : TR(@"Script_Default_Name");
    model.author = author.text.length ? author.text : TR(@"Placeholder_Author_Default");
    model.bundleID = currentBid;
    model.scriptContent = @"";
    model.createdAt = NSDate.date.timeIntervalSince1970;
    model.isImported = NO;
    NSString *dir = [[strongSelf getDirectoryForCurrentTab] stringByAppendingPathComponent:currentBid];
    model.fileName = [NSString stringWithFormat:@"%@-script.vmsc", currentBid];
    NSUInteger counter = 1;
    while ([[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:model.fileName]])
      model.fileName = [NSString stringWithFormat:@"%@-script-%lu.vmsc", currentBid, (unsigned long)counter++];
    if (![strongSelf saveScriptModel:model]) return TR(@"Err_Write_Permission");
    created = model;
    return nil;
  };
  form.didSubmit = ^{
    [weakSelf reloadFolderDataOrFileData];
    [weakSelf.tableView reloadData];
    [weakSelf updateFooter];
    if (created) [weakSelf openScriptEditor:created];
  };
  [form presentFrom:self];
}

- (BOOL)saveScriptModel:(VMScriptModel *)model {
  NSString *dir = [[self getDirectoryForCurrentTab] stringByAppendingPathComponent:model.bundleID];
  if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]) return NO;
  }
  NSString *path = [dir stringByAppendingPathComponent:model.fileName];
  VMDataSession *s = [VMDataSession sessionWithData:@[model] bundleID:model.bundleID dataType:@"script"];
  return [[s toJSONData] writeToFile:path atomically:YES];
}

- (void)openScriptEditor:(VMScriptModel *)model {
  VMScriptViewController *vc = [[VMScriptViewController alloc] init];
  vc.scriptModel = model; 
  
  [self.navigationController pushViewController:vc animated:YES];
}

- (void)importAction {
  if (_currentTab == 2)
    [self importPointers];
  else if (_currentTab == 3)
    [self importRVA];
  else if (_currentTab == 4)
    [self importSig];
  else if (_currentTab == 5)
    [self importVerifier];
  else if (_currentTab == 6)
    [self importScript]; 
}

- (void)importScript {
  NSArray *types = @[
    [UTType typeWithFilenameExtension:@"vmsc"] ?: UTTypeData,
    UTTypeData 
  ];
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types
                                                                  asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)importRVA {
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:@[ UTTypeData ]];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)importSig {
  
  NSArray *types = @[
    [UTType typeWithFilenameExtension:@"vmsig"] ?: UTTypeData,
    UTTypeData 
  ];
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types
                                                                  asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)importVerifier {
  NSArray *types = @[
    [UTType typeWithFilenameExtension:@"vmvapt"] ?: UTTypeData,
    UTTypeData 
  ];
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types
                                                                  asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)checkSmartNavigation {
  NSString *currBid = [VMMemoryEngine shared].currentBundleID;

  BOOL autoEnter = (currBid && currBid.length > 0 && !self.manuallyShowFolder);

  if (autoEnter) {
    NSString *typeDir = [self getDirectoryForCurrentTab];
    NSString *appPath = [typeDir stringByAppendingPathComponent:currBid];

    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:appPath
                                             isDirectory:&isDir] &&
        isDir) {
      self.targetBundleID = currBid;
      self.isFolderMode = NO;
    } else {
      self.targetBundleID = nil;
      self.isFolderMode = YES;
    }
  } else {
    self.targetBundleID = nil;
    self.isFolderMode = YES;
  }

  [self reloadFolderDataOrFileData];
  [self updateNavBar];
  [self.tableView reloadData];
  [self updateFooter];
}

- (NSString *)getDirectoryForCurrentTab {
  NSString *doc = [NSSearchPathForDirectoriesInDomains(
      NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *base = [doc stringByAppendingPathComponent:@"VansonMod"];

  switch (_currentTab) {
  case 2:
    return [base stringByAppendingPathComponent:@"PTR"];
  case 3:
    return [base stringByAppendingPathComponent:@"RVA"];
  case 4:
    return [base stringByAppendingPathComponent:@"SIG"];
  case 5:
    return [base stringByAppendingPathComponent:@"ValidatePtr"]; 
  case 6:
    return [base stringByAppendingPathComponent:@"Script"]; 
  default:
    return base;
  }
}

- (void)reloadFolderDataOrFileData {
  NSString *bid = self.targetBundleID;
  BOOL isFolder = self.isFolderMode;
  NSInteger tab = self.currentTab;

  if (isFolder) {
    [self reloadFolderData]; 
  } else {
    if (tab == 2) { 
      
      [[VMLockManager shared] reloadLocksFromDiskForApp:bid];
      NSArray *all = [[VMLockManager shared] loadLocksForApp:bid];
      NSPredicate *pred = [NSPredicate predicateWithFormat:@"isSignatureMode == NO"];
      self.activeSignatures = [all filteredArrayUsingPredicate:pred];
    } else if (tab == 3) { 
      [[VMMemoryEngine shared] loadRVAPatchesForApp:bid];
    } else if (tab == 4) { 
      
      [[VMLockManager shared] reloadLocksFromDiskForApp:bid];
      self.activeSignatures = [[VMLockManager shared] loadSignaturesForApp:bid];
    } else if (tab == 6) { 
      self.scriptList = [NSMutableArray array];
      if (bid) {
        NSString *dir = [[self getDirectoryForCurrentTab] stringByAppendingPathComponent:bid];
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
        NSArray *scFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.vmsc'"]];
        for (NSString *f in scFiles) {
          NSData *d = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:f]];
          if (!d || d.length < 4) continue;

          VMDataSession *s = [VMDataSession fromJSONData:d];
          if (s && s.dataItems.count > 0) {
            for (VMScriptModel *m in s.dataItems) {
              m.fileName = f;
              if (!m.bundleID) m.bundleID = bid;
              [self.scriptList addObject:m];
            }
            continue;
          }

          NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
          if (!dict) continue;
          VMScriptModel *m = [VMScriptModel fromDictionary:dict];
          if (m) {
            m.fileName = f;
            if (!m.bundleID) m.bundleID = bid;
            [self.scriptList addObject:m];
          }
        }
        
        [self.scriptList sortUsingComparator:^NSComparisonResult(
                             VMScriptModel *o1, VMScriptModel *o2) {
          double s1 = o1.sortOrder > 0 ? o1.sortOrder : o1.createdAt;
          double s2 = o2.sortOrder > 0 ? o2.sortOrder : o2.createdAt;
          return [@(s2) compare:@(s1)];
        }];
      }
    }
  }
}

- (void)reloadFolderData {
  [self.folderList removeAllObjects];
  [self.folderMetadata removeAllObjects];

  NSString *dir = [self getDirectoryForCurrentTab];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:dir]) {
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  }

  NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];

  for (NSString *name in contents) {
    if ([name hasPrefix:@"."]) continue;

    NSString *fullPath = [dir stringByAppendingPathComponent:name];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
      NSString *bid = name;
      [self.folderList addObject:bid];

      NSArray *files = [fm contentsOfDirectoryAtPath:fullPath error:nil];
      NSUInteger count = 0;
      NSString *appName = [self getAppNameForBundleID:bid];
      NSString *ver = [self getAppVersionForBundleID:bid];

      NSString *suffix = nil;
      if (_currentTab == 2) suffix = @".vmpt";
      else if (_currentTab == 3) suffix = @".vmrva";
      else if (_currentTab == 4) suffix = @".vmsig";
      else if (_currentTab == 5) suffix = @".vmvapt";
      else if (_currentTab == 6) suffix = @".vmsc";

      if (suffix) {
        for (NSString *f in files) {
          if (![f hasSuffix:suffix]) continue;
          if (_currentTab == 5) {
            
            count++;
          } else {
            
            NSData *d = [NSData dataWithContentsOfFile:[fullPath stringByAppendingPathComponent:f]];
            if (d) {
              VMDataSession *s = [VMDataSession fromJSONData:d];
              if (s && s.dataItems.count > 0) {
                count += s.dataItems.count;
              } else {
                
                count++;
              }
            }
          }
        }
      }

      self.folderMetadata[bid] = @{@"name" : appName, @"ver" : ver, @"count" : @(count)};
    }
  }

  if (_currentTab >= 2 && _currentTab <= 6) {
    [self.folderList sortUsingComparator:^NSComparisonResult(NSString *bid1,
                                                             NSString *bid2) {
      NSString *path1 = [dir stringByAppendingPathComponent:bid1];
      NSString *path2 = [dir stringByAppendingPathComponent:bid2];

      NSFileManager *fm = [NSFileManager defaultManager];
      NSDictionary *attrs1 = [fm attributesOfItemAtPath:path1 error:nil];
      NSDictionary *attrs2 = [fm attributesOfItemAtPath:path2 error:nil];
      NSDate *date1 = attrs1[NSFileModificationDate];
      NSDate *date2 = attrs2[NSFileModificationDate];
      return [date2 compare:date1];
    }];
  } else {
    [self.folderList sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  }
}

- (NSString *)getAppNameForBundleID:(NSString *)bundleID {
  if (!bundleID || bundleID.length == 0 || [bundleID isEqualToString:@"unknown.app"]) {
    return TR(@"App_Unknown");
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id proxy = [NSClassFromString(@"LSApplicationProxy")
      performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:")
           withObject:bundleID];
  if (proxy) {
    NSString *appName =
        [proxy performSelector:NSSelectorFromString(@"localizedName")];
    if (appName && appName.length > 0) {
      return appName;
    }
  }
#pragma clang diagnostic pop

  return bundleID;
}

- (NSString *)getAppVersionForBundleID:(NSString *)bundleID {
  if (!bundleID || bundleID.length == 0) {
    return @"";
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id proxy = [NSClassFromString(@"LSApplicationProxy")
      performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:")
           withObject:bundleID];
  if (proxy) {
    NSString *version =
        [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
    if (!version || version.length == 0) {
      version = [proxy performSelector:NSSelectorFromString(@"bundleVersion")];
    }
    if (version && version.length > 0) {
      return version;
    }
  }
#pragma clang diagnostic pop

  return @"";
}

- (NSArray *)buildDisplayListForSignatures {
  NSMutableArray *displayList = [NSMutableArray array];

  for (VMPointerChain *chain in self.activeSignatures) {
    [displayList addObject:chain];

    if (chain.isExpanded && chain.multiRuntimeAddresses.count > 0) {
      int index = 1;

      long long centerOffset = 0;
      if (chain.offsets.count > 0) {
        centerOffset = [chain.offsets[0] longLongValue];
      }

      for (NSNumber *addrNum in chain.multiRuntimeAddresses) {
        VMPointerChain *child = [[VMPointerChain alloc] init];
        child.isSignatureMode = NO;
        child.bundleID = @"_CHILD_NODE_";
        child.note =
            [NSString stringWithFormat:TR(@"Child_Node_Format"), index++];
        child.lockType = chain.lockType;
        child.lockValue = chain.lockValue;
        child.lockEnabled = chain.lockEnabled;

        uint64_t finalAddr = [addrNum unsignedLongLongValue] + centerOffset;
        child.moduleName = @"virtual";
        child.baseOffset = finalAddr;
        child.offsets = @[];

        child.uniqueId =
            [NSString stringWithFormat:@"%@_child_%llu", chain.uniqueId,
                                       child.baseOffset];

        [displayList addObject:child];
      }
    }
  }
  return displayList;
}

- (void)updateContextHeader {
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  NSString *bundleID = self.currentTab >= 2 && !self.isFolderMode ? self.targetBundleID : engine.currentBundleID;
  pid_t pid = bundleID.length && [bundleID isEqualToString:engine.currentBundleID] && engine.targetTask != MACH_PORT_NULL ? engine.targetPid : 0;
  NSString *name = bundleID.length ? ([self.folderMetadata[bundleID][@"name"] length] ? self.folderMetadata[bundleID][@"name"] : [self getAppNameForBundleID:bundleID]) : @"";
  if ([bundleID isEqualToString:engine.currentBundleID] && engine.currentProcessName.length)
    name = engine.currentProcessName;
  NSString *key = [NSString stringWithFormat:@"%@|%@|%d", bundleID ?: @"", name, pid];
  if ([key isEqualToString:self.contextHeaderKey]) return;
  self.contextHeaderKey = key;
  if (bundleID.length) {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 48)];
    UIView *process = [VMUIHelper processHeaderWithName:name bundleID:bundleID pid:pid];
    process.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:process];
    [NSLayoutConstraint activateConstraints:@[
      [process.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
      [process.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
      [process.topAnchor constraintEqualToAnchor:container.topAnchor],
      [process.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    self.tableView.tableHeaderView = container;
  } else {
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
  }
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
  if ([self.tabBarController isKindOfClass:VMRootViewController.class])
    [(VMRootViewController *)self.tabBarController refreshBrandingOverlay];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 8; }
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return CGFLOAT_MIN; }

- (void)updateFooter {
  [self updateContextHeader];
  [self updateValueSnapshotButton];
  NSUInteger count = self.isFolderMode && self.currentTab >= 2 ? self.folderList.count : [self currentDisplayData].count;
  if (count > 0) {
    self.tableView.backgroundView = nil;
    return;
  }
  NSArray *keys = @[@"Lock_Empty", @"Fav_Empty", @"No_Pointer_Items", @"No_RVA_Items", @"No_Signature_Items", @"No_Verifier_Items", @"No_Script_Items"];
  NSArray *icons = @[@"lock", @"star", @"point.topleft.down.curvedto.point.bottomright.up", @"cpu", @"waveform.path", @"checkmark.shield", @"curlybraces"];
  NSInteger index = MIN(MAX(self.currentTab, 0), (NSInteger)keys.count - 1);
  self.tableView.backgroundView = [VMUIHelper emptyStateWithTitle:self.tabItems[index] message:TR(keys[index]) symbol:icons[index]];
}

- (void)startGCDTimer {
  
  [[VMLockEngine shared] startEngine];
}

- (void)stopGCDTimer {
  
  [[VMLockEngine shared] stopEngine];
}

- (void)onLockItemAdded {
  dispatch_async(dispatch_get_main_queue(), ^{
    
    [[VMLockEngine shared] startEngine];
    if (self.currentTab == 0) {
      [self.tableView reloadData];
    } else if (self.currentTab >= 2 && self.isFolderMode) {
      [self reloadFolderData];
      [self.tableView reloadData];
    }
    [self updateFooter];
  });
}

- (void)performLockLogic {
  
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  if (_currentTab >= 2 && self.isFolderMode) {
    return self.folderList.count;
  }
  return [self currentDisplayData].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

  if (_currentTab >= 2 && self.isFolderMode) {
    static NSString *cid = @"folder";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:cid];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *bid = self.folderList[indexPath.row];
    NSDictionary *meta = self.folderMetadata[bid];
    NSString *name = meta[@"name"];
    NSString *ver = meta[@"ver"];
    NSUInteger count = [meta[@"count"] unsignedIntegerValue];
    if (ver.length > 0)
      cell.textLabel.text = [NSString stringWithFormat:@"%@ - v%@", name, ver];
    else
      cell.textLabel.text = name;
    cell.detailTextLabel.text =
        [NSString stringWithFormat:@"%@ (%lu)", bid, (unsigned long)count];
    cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
    cell.imageView.tintColor = [VMUIHelper accentColor];
    cell.textLabel.font = [VMUIHelper scaledFontOfSize:17 weight:UIFontWeightSemibold];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    return cell;
  }

  NSArray *dataSrc = [self currentDisplayData];
  if (indexPath.row >= dataSrc.count)
    return [UITableViewCell new];

  if (self.currentTab == 0) {
    static NSString *cid = @"VMItemCardCell_Lock";
    VMItemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[VMItemCardCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:cid];
      cell.delegate = self;
    }
    NSMutableDictionary *item = [dataSrc[indexPath.row] mutableCopy];
    if (![item[@"enabled"] boolValue]) {
      uint64_t addr = [item[@"addr"] unsignedLongLongValue];
      VMDataType type = (VMDataType)[item[@"type"] intValue];
      NSString *realVal = [[VMMemoryEngine shared] readAddress:addr type:type];
      item[@"val"] = realVal;
    }
    [cell configureWithDict:item isFavorite:NO];

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;

    return cell;
  }

  else if (self.currentTab == 1) {
    static NSString *cid = @"VMItemCardCell_Fav";
    VMItemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[VMItemCardCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:cid];
      cell.delegate = self;
    }
    NSMutableDictionary *item = [dataSrc[indexPath.row] mutableCopy];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    VMDataType type =
        item[@"type"] ? (VMDataType)[item[@"type"] intValue] : VMDataTypeInt32;
    NSString *realVal = [[VMMemoryEngine shared] readAddress:addr type:type];
    item[@"val"] = realVal;
    [cell configureWithDict:item isFavorite:YES];

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;

    return cell;
  }

  else if (self.currentTab == 2) {
    
    VMPointerLockCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"VMPointerLockCell"
                                        forIndexPath:indexPath];
    cell.delegate = self;

    VMPointerChain *chain = dataSrc[indexPath.row];

    NSString *addrStr = TR(@"Placeholder_None");
    NSString *valStr = TR(@"Placeholder_None");
    BOOL isConnected = ([VMMemoryEngine shared].targetTask != MACH_PORT_NULL);
    if (isConnected) {
      uint64_t finalAddr = [self forceResolveChain:chain];
      if (finalAddr > 0) {
        addrStr = [NSString stringWithFormat:@"0x%llX", finalAddr];
        VMDataType t = (VMDataType)chain.lockType;
        valStr = [[VMMemoryEngine shared] readAddress:finalAddr type:t];
      } else {
        addrStr = TR(@"Text_Null");
      }
    } else {
      valStr = TR(@"Status_Disconnected");
    }

    VMDataType type =
        (VMDataType)chain.lockType;
    NSString *typeStr = [self typeNameForType:type];
    [cell configureWithChain:chain address:addrStr val:valStr type:typeStr];

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;

    return cell;
  }

  else if (self.currentTab == 3) {
    static NSString *rvaCellID = @"VMRVAManagerCell";
    VMRVAManagerCell *cell =
        [tableView dequeueReusableCellWithIdentifier:rvaCellID];
    if (!cell) {
      cell = [[VMRVAManagerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:rvaCellID];
      cell.delegate = (id<VMRVAManagerCellDelegate>)self;
    }
    VMRVAPatch *patch = dataSrc[indexPath.row];
    [cell configureWithPatch:patch];

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;

    return cell;
  }

  else if (self.currentTab == 4) {
    
    VMSignatureLockCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"VMSignatureLockCell"
                                        forIndexPath:indexPath];
    cell.delegate = (id<VMSignatureLockCellDelegate>)
        self; 

    VMSignatureModel *sig = self.activeSignatures[indexPath.row];
    [cell configureWithSignature:sig]; 

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;

    return cell;
  }

  if (self.currentTab == 5) {
    static NSString *cid = @"verifyFileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:cid];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSString *fileName = [self currentDisplayData][indexPath.row];
    cell.textLabel.text = fileName;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.imageView.image =
        [UIImage systemImageNamed:@"doc.text.magnifyingglass"];

    NSString *fullPath = [[[self getDirectoryForCurrentTab]
        stringByAppendingPathComponent:self.targetBundleID]
        stringByAppendingPathComponent:fileName];
    NSDictionary *attr =
        [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath
                                                         error:nil];
    if (attr) {
      NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
      [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
      cell.detailTextLabel.text =
          [fmt stringFromDate:attr.fileModificationDate];
      cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }

    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;

    return cell;
  }

  else if (self.currentTab == 6) {
    VMScriptCardCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"VMScriptCardCell"];
    if (!cell) {
      cell = [[VMScriptCardCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:@"VMScriptCardCell"];
    }
    VMScriptModel *model = dataSrc[indexPath.row];
    cell.delegate = (id<VMScriptCardCellDelegate>)self;
    [cell configureWithModel:model log:self.scriptLogs[model.fileName]];
    
    cell.selectionStyle = tableView.isEditing
                              ? UITableViewCellSelectionStyleDefault
                              : UITableViewCellSelectionStyleNone;
    
    return cell;
  }

  return [UITableViewCell new];
}

- (void)scriptCellDidTapEdit:(UITableViewCell *)cell {
  NSIndexPath *ip = [self.tableView indexPathForCell:cell];
  if (ip) {
    VMScriptModel *m = [self currentDisplayData][ip.row];
    [self showEditScriptInfoAlert:m];
  }
}

- (void)scriptCellDidTapEditScript:(UITableViewCell *)cell {
  NSIndexPath *ip = [self.tableView indexPathForCell:cell];
  if (ip) {
    VMScriptModel *m = [self currentDisplayData][ip.row];
    
    [self openScriptEditor:m];
  }
}

- (void)scriptCellDidTapRun:(UITableViewCell *)cell {
  NSIndexPath *ip = [self.tableView indexPathForCell:cell];
  if (!ip)
    return;
  VMScriptModel *m = [self currentDisplayData][ip.row];

  if (m.bundleID) {
    [self tryAutoAttach:m.bundleID];
  }

  self.scriptLogs[m.fileName] =
      [NSString stringWithFormat:@"> %@...", TR(@"Script_Console_Running")];

  VMScriptCardCell *cardCell = [self.tableView cellForRowAtIndexPath:ip];
  if ([cardCell respondsToSelector:@selector(setRunning:)]) {
    [cardCell setRunning:YES];
  }

  [[VMScriptManager shared] runScript:m.scriptContent completion:^(NSString *log) {
    dispatch_async(dispatch_get_main_queue(), ^{
      
      self.scriptLogs[m.fileName] = log;
      VMScriptCardCell *doneCell = [self.tableView cellForRowAtIndexPath:ip];
      if ([doneCell respondsToSelector:@selector(setRunning:)]) {
        [doneCell setRunning:NO];
      }
      [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
    });
  }];
}

- (void)itemCellDidToggleSwitch:(UITableViewCell *)cell isOn:(BOOL)isOn {
  [self didChangeLockState:cell isOn:isOn];
}

- (void)updateButtonState:(UIButton *)btn isLocked:(BOOL)locked {
  NSString *title = locked ? TR(@"Btn_Unlock") : TR(@"Btn_Lock");
  UIColor *color = locked ? [UIColor systemRedColor] : [UIColor systemGreenColor];
  [UIView performWithoutAnimation:^{
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:color forState:UIControlStateNormal];
    btn.backgroundColor = [color colorWithAlphaComponent:0.1];
    [btn layoutIfNeeded];
  }];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:
        (NSIndexPath *)indexPath {
  
  if (self.isFolderMode && self.currentTab >= 2) {
    NSString *bid = self.folderList[indexPath.row];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:TR(@"Act_Delete") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      NSString *dir = [[self getDirectoryForCurrentTab] stringByAppendingPathComponent:bid];
      [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
      [self.folderList removeObjectAtIndex:indexPath.row];
      if (self.folderList.count == 0) {
        self.isFolderMode = NO;
        self.targetBundleID = nil;
        [self updateNavBar];
        [self.tableView reloadData];
        [self updateFooter];
      } else {
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      }
      c(YES);
    }];
    del.title = TR(@"Act_Delete");
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
  }

  if (self.currentTab == 5) {
    NSString *fileName = [self currentDisplayData][indexPath.row];

    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:TR(@"Act_Delete") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      NSString *path = [[[self getDirectoryForCurrentTab] stringByAppendingPathComponent:self.targetBundleID] stringByAppendingPathComponent:fileName];
      [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
      [self.tableView reloadData];
      c(YES);
    }];

    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:TR(@"Act_Export") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      NSString *path = [[[self getDirectoryForCurrentTab] stringByAppendingPathComponent:self.targetBundleID] stringByAppendingPathComponent:fileName];
      NSString *newName = [NSString stringWithFormat:@"VansonMod_%@_VERIFY.vmvapt", self.targetBundleID];
      NSString *exportPath = [VMShareHelper generateUniqueExportPathForName:[newName stringByDeletingPathExtension] extension:@"vmvapt"];
      [[NSFileManager defaultManager] copyItemAtPath:path toPath:exportPath error:nil];
      [VMShareHelper shareContent:[NSURL fileURLWithPath:exportPath] fromViewController:self sourceView:self.view sourceRect:[tableView rectForRowAtIndexPath:indexPath]];
      c(YES);
    }];
    share.backgroundColor = [UIColor systemBlueColor];

    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:TR(@"Common_Rename") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      [self showRenameAlertForItem:fileName atIndexPath:indexPath];
      c(YES);
    }];
    rename.backgroundColor = [UIColor systemOrangeColor];

    return [UISwipeActionsConfiguration configurationWithActions:@[del, rename, share]];
  }

  if (self.currentTab == 2 || self.currentTab == 3 || self.currentTab == 4 || self.currentTab == 6) {
    NSArray *data = [self currentDisplayData];
    if (indexPath.row >= data.count) return nil;
    id item = data[indexPath.row];

    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:TR(@"Act_Delete") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      NSString *fileName = [item valueForKey:@"fileName"];
      NSString *bid = [item valueForKey:@"bundleID"];
      if (fileName && fileName.length > 0 && bid && bid.length > 0) {
        NSString *typeDir = [self getDirectoryForCurrentTab];
        NSString *fullPath = [[typeDir stringByAppendingPathComponent:bid] stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
      }
      if (self.currentTab == 2) {
        if (bid) {
          [[NSClassFromString(@"VMLockManager") performSelector:@selector(shared)] performSelector:@selector(saveLocks:forApp:) withObject:@[] withObject:bid];
        }
        [[VMLockManager shared] removePointer:item];
      } else if (self.currentTab == 3) {
        [[VMMemoryEngine shared].rvaPatches removeObject:item];
        [[VMMemoryEngine shared] saveRVAPatches];
      } else if (self.currentTab == 4) {
        [[VMLockManager shared] removeSignature:item];
      } else if (self.currentTab == 6) {
        [self.scriptList removeObject:item];
      }
      if (bid) [self checkAndCleanupFolderForBundleID:bid];
      [self reloadFolderDataOrFileData];
      [self.tableView reloadData];
      [self updateFooter];
      c(YES);
    }];

    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:TR(@"Act_Export") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
      CGRect rawRect = [tableView convertRect:rect toView:self.view];
      [self shareSingleItemDirectly:item sourceView:self.view sourceRect:rawRect];
      c(YES);
    }];
    share.backgroundColor = [UIColor systemBlueColor];
    share.title = TR(@"Act_Export");

    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:TR(@"Common_Rename") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      [self showRenameAlertForItem:item atIndexPath:indexPath];
      c(YES);
    }];
    rename.backgroundColor = [UIColor systemOrangeColor];
    rename.title = TR(@"Common_Rename");

    UIContextualAction *editInfo = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:TR(@"Common_Edit") handler:^(UIContextualAction *a, UIView *v, void (^c)(BOOL)) {
      if (self.currentTab == 2) {
        VMPointerChain *chain = (VMPointerChain *)item;
        [self showEditChainInfoAlert:chain];
      } else if (self.currentTab == 3) {
        VMRVAPatch *patch = (VMRVAPatch *)item;
        [self showEditRVAInfoAlert:patch];
      } else if (self.currentTab == 4) {
        VMSignatureModel *sig = (VMSignatureModel *)item;
        [self showEditSignatureInfoAlert:sig];
      } else if (self.currentTab == 6) {
        VMScriptModel *model = (VMScriptModel *)item;
        [self showEditScriptInfoAlert:model];
      }
      c(YES);
    }];
    editInfo.backgroundColor = [UIColor systemGrayColor];
    editInfo.title = TR(@"Common_Edit");

    if (self.currentTab == 6) {
      return [UISwipeActionsConfiguration configurationWithActions:@[del, rename, share]];
    }
    return [UISwipeActionsConfiguration configurationWithActions:@[del, rename, editInfo, share]];
  }

  return nil;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView.isEditing) {
    [self updateSelectionTitle];
    return;
  }
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (_currentTab >= 2 && self.isFolderMode) {
    self.targetBundleID = self.folderList[indexPath.row];
    self.isFolderMode = NO;
    [self reloadFolderDataOrFileData];
    [self updateNavBar];
    [self.tableView reloadData];
    [self updateFooter];
    return;
  }

  if (self.currentTab == 5) {
    if (self.isFolderMode) {
      
      self.targetBundleID = self.folderList[indexPath.row];
      self.isFolderMode = NO;
      [self.tableView reloadData];
      [self updateNavBar];
    } else {
      
      NSString *fileName = [self currentDisplayData][indexPath.row];
      NSString *fullPath = [[[self getDirectoryForCurrentTab]
          stringByAppendingPathComponent:self.targetBundleID]
          stringByAppendingPathComponent:fileName];

      VMPointerVerifierViewController *vc =
          [[VMPointerVerifierViewController alloc] init];
      vc.filePath = fullPath;
      [self.navigationController pushViewController:vc animated:YES];
    }
    return;
  }

  else if (self.currentTab == 6) {
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row < dataSrc.count) {
      VMScriptModel *m = dataSrc[indexPath.row];

      if (m.bundleID) {
        [self tryAutoAttach:m.bundleID]; 
      }

      [self openScriptEditor:m];
    }
    return;
  }

  if (self.currentTab == 0) {
    if (indexPath.row < [VMMemoryEngine shared].lockedItems.count) {
      NSMutableDictionary *item =
          [VMMemoryEngine shared].lockedItems[indexPath.row];
      [VMMemoryActionSheet
          showActionSheetForAddress:[item[@"addr"] unsignedLongLongValue]
                              value:item[@"val"]
                           dataType:(VMDataType)[item[@"type"] intValue]
                 fromViewController:self
                         sourceView:tableView
                         sourceRect:[tableView rectForRowAtIndexPath:indexPath]
                          extraItem:item];
    }
    return;
  } else if (self.currentTab == 1) {
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row >= dataSrc.count)
      return;
    NSDictionary *favItem = dataSrc[indexPath.row];

    NSMutableDictionary *favMut = nil;
    if ([favItem isKindOfClass:[NSMutableDictionary class]]) {
      favMut = (NSMutableDictionary *)favItem;
    } else {
      favMut = [favItem mutableCopy];
      [[VMMemoryEngine shared].favoriteItems replaceObjectAtIndex:indexPath.row
                                                       withObject:favMut];
    }

    [VMMemoryActionSheet
        showActionSheetForAddress:[favMut[@"addr"] unsignedLongLongValue]
                            value:favMut[@"val"]
                         dataType:(VMDataType)[favMut[@"type"] intValue]
               fromViewController:self
                       sourceView:tableView
                       sourceRect:[tableView rectForRowAtIndexPath:indexPath]
                        extraItem:favMut];
    return;
  } else if (self.currentTab == 4) {
    
    VMSignatureModel *sig = self.activeSignatures[indexPath.row];

    NSString *targetBid = sig.bundleID ?: self.targetBundleID;
    int connResult = [self ensureConnectionForBundleID:targetBid];
    if (connResult < 0) {
      return; 
    }
    if (connResult == 0) {
      return; 
    }

    if (self.presentedViewController)
      return;

    NSString *displayMsg = [NSString stringWithFormat:@"%@ + 0x%X", sig.signature, sig.offset];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:sig.note message:displayMsg preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Common_Edit") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
      [self showEditSignatureAlert:sig];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Export") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
      CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
      [self shareSingleItemDirectly:sig sourceView:tableView sourceRect:rect];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
      [[VMLockManager shared] removeSignature:sig];
      [self reloadFolderDataOrFileData];
      [self.tableView reloadData];
      [self updateFooter];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
      alert.popoverPresentationController.sourceView = tableView;
      alert.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    }

    [self presentViewController:alert animated:YES completion:nil];
  } else if (self.currentTab == 2) {
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row < dataSrc.count) {
      VMPointerChain *chain = dataSrc[indexPath.row];

      NSString *bid = chain.bundleID ?: [[VMMemoryEngine shared] currentBundleID];
      int connResult = [self ensureConnectionForBundleID:bid];
      if (connResult < 0) return;
      if (connResult == 0) return;

      [self showPointerActions:chain];
    }
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView
    estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.currentTab == 0 || self.currentTab == 1)
    return 118;
  if (self.currentTab == 2 || self.currentTab == 3 || self.currentTab == 4)
    return 160;
  return 100;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  return tableView.isEditing ? UITableViewCellEditingStyleNone
                             : UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {

    if (_currentTab >= 2 && self.isFolderMode) {
      NSString *bid = self.folderList[indexPath.row];
      NSString *dirPath =
          [[self getDirectoryForCurrentTab] stringByAppendingPathComponent:bid];

      [[NSFileManager defaultManager] removeItemAtPath:dirPath error:nil];

      [self.folderList removeObjectAtIndex:indexPath.row];
      [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                       withRowAnimation:UITableViewRowAnimationFade];

      if (self.folderList.count == 0) {
        [self backToFolderList];
      }

      [self updateFooter];
      return;
    }

    if (self.currentTab == 0) {
      NSMutableArray *items = [VMMemoryEngine shared].lockedItems;
      if (indexPath.row < items.count) {
        [items removeObjectAtIndex:indexPath.row];

        [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationFade];

        if (items.count == 0)
          [self stopGCDTimer];
      }
    }

    else if (self.currentTab == 1) {
      NSMutableArray *items = [VMMemoryEngine shared].favoriteItems;
      if (indexPath.row < items.count) {
        [items removeObjectAtIndex:indexPath.row];

        [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationFade];
      }
    }

    else if (self.currentTab == 2) {
      NSArray *dataSrc = [self currentDisplayData];
      if (indexPath.row >= dataSrc.count)
        return;

      VMPointerChain *chain = dataSrc[indexPath.row];
      NSString *bid = chain.bundleID ?: self.targetBundleID;
      NSString *fname = chain.fileName;

      if (fname && fname.length > 0 && bid) {
        NSString *doc = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [[[doc stringByAppendingPathComponent:@"VansonMod/PTR"]
            stringByAppendingPathComponent:bid]
            stringByAppendingPathComponent:fname];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
      }

      [[VMLockManager shared] removePointer:chain];
      [[VMMemoryEngine shared] reloadLockedPointers];

      [self checkAndCleanupFolderForBundleID:bid];
      [self.tableView reloadData];
    }

    else if (self.currentTab == 3) {
      NSArray *dataSrc = [self currentDisplayData];
      if (indexPath.row >= dataSrc.count)
        return;

      VMRVAPatch *patch = dataSrc[indexPath.row];
      NSString *bid = patch.bundleID ?: self.targetBundleID;

      if (patch.fileName && patch.fileName.length > 0 && bid) {
        NSString *dir = [VMStoragePathHelper pathForSubdirectory:@"RVA"
                                                        bundleID:bid
                                                          create:NO];
        NSString *filePath = [dir stringByAppendingPathComponent:patch.fileName];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
      }

      [[VMMemoryEngine shared] reloadLockedPointers];
      [[VMMemoryEngine shared].rvaPatches removeObject:patch];
      [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

      if (bid) {
        [self checkAndCleanupFolderForBundleID:bid];
        [self checkAndCleanupRVAFolder:bid];
      }

      [self.tableView reloadData];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateFooter];
      });
    }
  }

  else if (self.currentTab == 4) {
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row >= dataSrc.count) return;

    VMPointerChain *chain = dataSrc[indexPath.row];
    NSString *bid = chain.bundleID ?: self.targetBundleID;

    if (bid && chain.fileName) {
      NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
      NSString *path = [[[doc stringByAppendingPathComponent:@"VansonMod/SIG"] stringByAppendingPathComponent:bid] stringByAppendingPathComponent:chain.fileName];
      [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }

    self.activeSignatures = [[VMLockManager shared] loadSignaturesForApp:bid];
    [self checkAndCleanupSigFolder:bid];
    [self.tableView reloadData];
    [self updateFooter];
  }

  else if (self.currentTab == 5) {
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row >= dataSrc.count) return;

    NSString *fname = dataSrc[indexPath.row];
    NSString *bid = self.targetBundleID;

    if (bid && fname) {
      NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
      NSString *path = [[[doc stringByAppendingPathComponent:@"VansonMod/ValidatePtr"] stringByAppendingPathComponent:bid] stringByAppendingPathComponent:fname];
      [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }

    [self reloadFolderDataOrFileData];
    [self.tableView reloadData];
    [self updateFooter];
  }

  if (self.currentTab == 6) {
    if (indexPath.row < self.scriptList.count) {
      VMScriptModel *model = self.scriptList[indexPath.row];
      if (model.fileName && model.bundleID) {
        NSString *dir = [[self getDirectoryForCurrentTab] stringByAppendingPathComponent:model.bundleID];
        NSString *path = [dir stringByAppendingPathComponent:model.fileName];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
      }
      [self.scriptList removeObjectAtIndex:indexPath.row];
      [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      [self checkAndCleanupFolderForBundleID:model.bundleID];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateFooter];
      });
    }
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self updateFooter];
  });
}

- (void)doRefreshValues {
  if (self.currentTab != 4) {
    [self.tableView reloadData];
    return;
  }

  VMMemoryEngine *engine = [VMMemoryEngine shared];
  if (engine.targetTask == MACH_PORT_NULL) return;

  BOOL hasChanges = NO;
  for (VMSignatureModel *sig in self.activeSignatures) {
    
    if (sig.runtimeResults.count > 0) {
      NSMutableArray *newResults = [NSMutableArray array];
      for (NSDictionary *res in sig.runtimeResults) {
        
        uint64_t addr = [res[@"addr"] unsignedLongLongValue];
        NSString *note = res[@"note"];

        NSString *newVal = [engine readAddress:addr type:VMDataTypeInt32];
        if (!newVal)
          newVal = @"--";

        [newResults addObject:@{
          @"addr" : @(addr),
          @"val" : newVal,
          @"note" : note ?: @"VansonMod"
        }];
      }
      
      sig.runtimeResults = newResults;
      hasChanges = YES;
    }
  }
  if (hasChanges) {
    [self.tableView reloadData];
  }
}

- (void)addLock {
  VMFormSheetViewController *form = [[VMFormSheetViewController alloc] initWithTitle:TR(@"Lock_Add_Manual_Title") submitTitle:TR(@"Btn_Save")];
  UITextField *address = [form addTextFieldWithLabel:TR(@"Placeholder_Addr_Hex") value:nil placeholder:TR(@"Placeholder_Addr_Hex") keyboardType:UIKeyboardTypeASCIICapable];
  UITextField *value = [form addTextFieldWithLabel:TR(@"Lab_Value_Colon") value:nil placeholder:TR(@"Lock_Input_Val_Hint") keyboardType:UIKeyboardTypeNumbersAndPunctuation];
  [form addSectionWithTitle:TR(@"Lock_Select_Type_Title")];
  UISegmentedControl *types = [[UISegmentedControl alloc] initWithItems:@[@"I8", @"I16", @"I32", @"I64", @"F32"]];
  types.selectedSegmentIndex = 2;
  [types.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [form addView:types];
  form.submitHandler = ^NSString *(VMFormSheetViewController *editor) {
    uint64_t addr = 0;
    if (![VMStringMemorySession parseAddress:address.text value:&addr] || addr == 0) return TR(@"Err_Invalid_Base_Ptr");
    NSString *val = [value.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!val.length) return TR(@"Err_Target_Empty");
    NSScanner *scanner = [NSScanner scannerWithString:val];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double number = 0;
    if (![scanner scanDouble:&number] || !scanner.isAtEnd || !isfinite(number)) return TR(@"Set_Invalid_Value");
    static const VMDataType map[] = {VMDataTypeInt8, VMDataTypeInt16, VMDataTypeInt32, VMDataTypeInt64, VMDataTypeFloat};
    NSInteger selection = types.selectedSegmentIndex;
    VMDataType type = selection >= 0 && selection < 5 ? map[selection] : VMDataTypeInt32;
    if (type == VMDataTypeFloat) {
      if (!isfinite((float)number)) return TR(@"Set_Invalid_Value");
    } else {
      const char *input = val.UTF8String;
      NSUInteger byteCount = [val lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      if (!input) return TR(@"Set_Invalid_Value");
      char *end = NULL;
      errno = 0;
      long long integer = strtoll(input, &end, 10);
      if (errno == ERANGE || end == input || (NSUInteger)(end - input) != byteCount)
        return TR(@"Set_Invalid_Value");
      if ((type == VMDataTypeInt8 && (integer < INT8_MIN || integer > INT8_MAX)) ||
          (type == VMDataTypeInt16 && (integer < INT16_MIN || integer > INT16_MAX)) ||
          (type == VMDataTypeInt32 && (integer < INT32_MIN || integer > INT32_MAX))) return TR(@"Set_Invalid_Value");
    }
    VMMemoryEngine *engine = [VMMemoryEngine shared];
    if (!engine.lockedItems) engine.lockedItems = [NSMutableArray array];
    [engine.lockedItems addObject:[@{@"addr":@(addr), @"val":val, @"type":@(type), @"enabled":@NO} mutableCopy]];
    return nil;
  };
  __weak __typeof(self) weakSelf = self;
  form.didSubmit = ^{ [weakSelf.tableView reloadData]; [weakSelf updateFooter]; };
  [form presentFrom:self];
}

- (void)importPointers {
  NSArray *types = @[[UTType typeWithFilenameExtension:@"vmpt"] ?: UTTypeData, UTTypeData];
  UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  for (NSURL *url in urls) {
    [[VMImportHandler shared] handleImportWithData:nil url:url];
  }
}

- (void)showToast:(NSString *)msg {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[self.view viewWithTag:999000] removeFromSuperview];

    UIView *toastView = [[UIView alloc] init];
    toastView.tag = 999000;
    toastView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    toastView.layer.cornerRadius = 20;
    toastView.clipsToBounds = YES;
    toastView.translatesAutoresizingMaskIntoConstraints = NO;
    toastView.alpha = 0.0;
    [self.view addSubview:toastView];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = msg;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.numberOfLines = 0;
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [toastView addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
      [lbl.topAnchor constraintEqualToAnchor:toastView.topAnchor constant:10],
      [lbl.bottomAnchor constraintEqualToAnchor:toastView.bottomAnchor constant:-10],
      [lbl.leadingAnchor constraintEqualToAnchor:toastView.leadingAnchor constant:20],
      [lbl.trailingAnchor constraintEqualToAnchor:toastView.trailingAnchor constant:-20],
      [toastView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
      [toastView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-80],
      [toastView.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-60]
    ]];

    [UIView animateWithDuration:0.2 animations:^{
      toastView.alpha = 1.0;
    } completion:^(BOOL finished) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
          toastView.alpha = 0.0;
        } completion:^(BOOL finished) {
          [toastView removeFromSuperview];
        }];
      });
    }];
  });
}

- (void)addFavoriteManual {
  VMFormSheetViewController *form = [[VMFormSheetViewController alloc] initWithTitle:TR(@"Fav_Add_Title") submitTitle:TR(@"Btn_Save")];
  UITextField *address = [form addTextFieldWithLabel:TR(@"Placeholder_Addr_Hex") value:nil placeholder:TR(@"Placeholder_Addr_Hex") keyboardType:UIKeyboardTypeASCIICapable];
  form.submitHandler = ^NSString *(VMFormSheetViewController *editor) {
    uint64_t addr = 0;
    if (![VMStringMemorySession parseAddress:address.text value:&addr] || addr == 0) return TR(@"Err_Invalid_Base_Ptr");
    VMMemoryEngine *engine = [VMMemoryEngine shared];
    if (!engine.favoriteItems) engine.favoriteItems = [NSMutableArray array];
    [engine.favoriteItems addObject:[@{@"addr":@(addr), @"type":@(VMDataTypeInt32)} mutableCopy]];
    return nil;
  };
  __weak __typeof(self) weakSelf = self;
  form.didSubmit = ^{ [weakSelf.tableView reloadData]; [weakSelf updateFooter]; };
  [form presentFrom:self];
}

- (void)showEditNoteAlertForDict:(NSMutableDictionary *)item {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Ptr_Action_Edit_Note") message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = item[@"note"];
    tf.placeholder = TR(@"Placeholder_Note");
  }];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    item[@"note"] = alert.textFields.firstObject.text;
    [self.tableView reloadData];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
  if (gesture.state == UIGestureRecognizerStateBegan) {
    if (!self.tableView.isEditing) {
      [self enterBatchMode];
    }
  }
}

- (void)enterBatchMode {
  self.isGlobalSelectAll = NO;
  self.tableView.allowsMultipleSelectionDuringEditing = YES;
  [self.tableView setEditing:YES animated:YES];
  [self.tableView reloadData];
  self.navigationItem.leftBarButtonItems = nil;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Batch_Sel_All")
      style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelectAll)];
  self.navigationItem.rightBarButtonItems = nil;
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel")
      style:UIBarButtonItemStylePlain target:self action:@selector(exitBatchMode)];
  NSMutableArray *items = [NSMutableArray array];
  NSArray *icons = @[@"square.and.arrow.up", @"doc.on.doc", @"pencil", @"trash"];
  NSArray *titles = @[TR(@"Act_Export"), TR(@"Pop_Copy_Addr"), TR(@"Batch_Mod_Sel"), TR(@"Act_Delete")];
  NSArray *selectors = @[NSStringFromSelector(@selector(performBatchShare)), NSStringFromSelector(@selector(performBatchCopy)),
      NSStringFromSelector(@selector(performBatchModify)), NSStringFromSelector(@selector(performBatchDelete))];
  for (NSUInteger index = 0; index < icons.count; index++) {
    if (index == 1 && (self.isFolderMode || self.currentTab > 2)) continue;
    if (index == 2 && self.currentTab > 1) continue;
    if (items.count) [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:icons[index]]
        style:UIBarButtonItemStylePlain target:self action:NSSelectorFromString(selectors[index])];
    item.accessibilityLabel = titles[index];
    item.tintColor = index == 3 ? UIColor.systemRedColor : [VMUIHelper accentColor];
    if (@available(iOS 26.0, *)) item.hidesSharedBackground = YES;
    [items addObject:item];
  }
  self.toolbarItems = items;
  [self.navigationController setToolbarHidden:YES animated:NO];
  [self setBatchToolbarVisible:YES];
  self.batchToolbar.items = items;
  [self updateSelectionTitle];
}

- (void)setBatchToolbarVisible:(BOOL)visible {
  if (visible && !self.batchToolbar) {
    self.batchToolbar = [UIToolbar new];
    self.batchToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.batchToolbar.tintColor = [VMUIHelper accentColor];
    self.batchToolbar.backgroundColor = [VMUIHelper cardColor];
    self.batchToolbar.layer.cornerRadius = 16;
    self.batchToolbar.clipsToBounds = YES;
    UIToolbarAppearance *appearance = [UIToolbarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [VMUIHelper cardColor];
    appearance.shadowColor = UIColor.clearColor;
    appearance.buttonAppearance.normal.titleTextAttributes = @{
      NSForegroundColorAttributeName: [VMUIHelper accentColor]
    };
    appearance.buttonAppearance.highlighted.titleTextAttributes =
        appearance.buttonAppearance.normal.titleTextAttributes;
    appearance.buttonAppearance.disabled.titleTextAttributes = @{
      NSForegroundColorAttributeName: UIColor.secondaryLabelColor
    };
    self.batchToolbar.standardAppearance = appearance;
    self.batchToolbar.compactAppearance = appearance;
    if (@available(iOS 15.0, *)) {
      self.batchToolbar.scrollEdgeAppearance = appearance;
      self.batchToolbar.compactScrollEdgeAppearance = appearance;
    }
    [self.view addSubview:self.batchToolbar];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
      [self.batchToolbar.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
      [self.batchToolbar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
      [self.batchToolbar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],
      [self.batchToolbar.heightAnchor constraintEqualToConstant:52]
    ]];
  }

  if (visible != self.batchToolbarShown) {
    UIEdgeInsets contentInset = self.tableView.contentInset;
    UIEdgeInsets indicatorInset = self.tableView.verticalScrollIndicatorInsets;
    if (visible) {
      self.batchOriginalContentBottomInset = contentInset.bottom;
      self.batchOriginalIndicatorBottomInset = indicatorInset.bottom;
    }
    contentInset.bottom = self.batchOriginalContentBottomInset + (visible ? 68 : 0);
    indicatorInset.bottom = self.batchOriginalIndicatorBottomInset + (visible ? 68 : 0);
    self.tableView.contentInset = contentInset;
    self.tableView.verticalScrollIndicatorInsets = indicatorInset;
    self.batchToolbarShown = visible;
  }
  self.batchToolbar.hidden = !visible;
  if (visible) [self.view bringSubviewToFront:self.batchToolbar];
  if ([self.tabBarController isKindOfClass:VMRootViewController.class])
    [(VMRootViewController *)self.tabBarController refreshBrandingOverlay];
}

- (void)updateSelectionTitle {
  if (!self.tableView.isEditing) return;
  NSUInteger selectedCount = self.tableView.indexPathsForSelectedRows.count;
  self.isGlobalSelectAll = selectedCount > 0 && selectedCount == [self.tableView numberOfRowsInSection:0];
  self.navigationItem.leftBarButtonItem.title = self.isGlobalSelectAll ? TR(@"Btn_Deselect_All") : TR(@"Batch_Sel_All");
  self.navigationItem.title = [NSString stringWithFormat:@"%@ · %lu", TR(@"Btn_Batch_Select"),
      (unsigned long)selectedCount];
  for (UIBarButtonItem *item in self.toolbarItems) {
    if (item.action) {
      item.enabled = selectedCount > 0;
      item.tintColor = item.enabled
          ? (item.action == @selector(performBatchDelete) ? UIColor.systemRedColor : [VMUIHelper accentColor])
          : UIColor.secondaryLabelColor;
    }
  }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
  [self updateSelectionTitle];
}

- (void)exitBatchMode {
  [self.navigationController setToolbarHidden:YES animated:NO];
  [self setBatchToolbarVisible:NO];
  [self.tableView setEditing:NO animated:YES];
  self.navigationItem.titleView = nil;
  [self updateNavBar];
  [self updateFooter];
  [self.tableView reloadData];
}

- (void)toggleSelectAll {
  self.isGlobalSelectAll = !self.isGlobalSelectAll;
  self.navigationItem.leftBarButtonItem.title = self.isGlobalSelectAll ? TR(@"Btn_Deselect_All") : TR(@"Batch_Sel_All");
  NSInteger count = [self.tableView numberOfRowsInSection:0];
  for (int i = 0; i < count; i++) {
    NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
    if (self.isGlobalSelectAll) {
      [self.tableView selectRowAtIndexPath:ip animated:NO scrollPosition:UITableViewScrollPositionNone];
    } else {
      [self.tableView deselectRowAtIndexPath:ip animated:NO];
    }
  }
  [self updateSelectionTitle];
}

- (void)performBatchShare {
  NSArray *selectedPaths = [self.tableView indexPathsForSelectedRows];
  if (selectedPaths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }

  if (self.currentTab == 0 || self.currentTab == 1) {
    [self exportSelectedAsBackup:selectedPaths];
    return;
  }

  if (self.isFolderMode && self.currentTab >= 2) {
    [self exportSelectedFolders:selectedPaths];
    return;
  }

  NSMutableArray *items = [NSMutableArray array];
  NSArray *dataSrc = [self currentDisplayData];
  for (NSIndexPath *ip in selectedPaths) {
    if (ip.row < dataSrc.count)
      [items addObject:dataSrc[ip.row]];
  }

  if (self.currentTab == 2)
    [self exportDataItems:items type:@"pointer"];
  else if (self.currentTab == 3)
    [self exportDataItems:items type:@"rva"];
  else if (self.currentTab == 4)
    [self exportDataItems:items type:@"signature"];
  else if (self.currentTab == 5)
    [self exportVerifierFiles:items]; 
  else if (self.currentTab == 6)
    [self exportDataItems:items type:@"script"];
}

- (void)exportSelectedFolders:(NSArray *)selectedPaths {
  NSString *dir = [self getDirectoryForCurrentTab];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray *tempFiles = [NSMutableArray array];

  NSString *ext = @"vmpt";
  NSString *typeStr = @"pointer";
  NSString *fileSuffix = @".vmpt";
  if (self.currentTab == 3) {
    ext = @"vmrva"; typeStr = @"rva"; fileSuffix = @".vmrva";
  } else if (self.currentTab == 4) {
    ext = @"vmsig"; typeStr = @"signature"; fileSuffix = @".vmsig";
  } else if (self.currentTab == 5) {
    ext = @"vmvapt"; typeStr = @"verifier"; fileSuffix = @".vmvapt";
  } else if (self.currentTab == 6) {
    ext = @"vmsc"; typeStr = @"script"; fileSuffix = @".vmsc";
  }

  for (NSIndexPath *ip in selectedPaths) {
    if (ip.row >= self.folderList.count)
      continue;
    NSString *bid = self.folderList[ip.row];
    NSString *folderPath = [dir stringByAppendingPathComponent:bid];

    if (self.currentTab == 5) {
      NSArray *files = [fm contentsOfDirectoryAtPath:folderPath error:nil];
      for (NSString *f in files) {
        if ([f hasSuffix:fileSuffix]) {
          NSString *fullPath = [folderPath stringByAppendingPathComponent:f];
          if ([fm fileExistsAtPath:fullPath])
            [tempFiles addObject:[NSURL fileURLWithPath:fullPath]];
        }
      }
      continue;
    }

    NSArray *files = [fm contentsOfDirectoryAtPath:folderPath error:nil];
    NSMutableArray *allItems = [NSMutableArray array];
    NSString *appName = nil;
    NSString *appVer = nil;
    for (NSString *f in files) {
      if (![f hasSuffix:fileSuffix])
        continue;
      NSData *fileData = [NSData
          dataWithContentsOfFile:[folderPath stringByAppendingPathComponent:f]];
      if (!fileData || fileData.length < 4)
        continue;

      VMDataSession *s = [VMDataSession fromJSONData:fileData];
      if (s && s.dataItems.count > 0) {
        [allItems addObjectsFromArray:s.dataItems];
        if (s.appName) appName = s.appName;
        if (s.appVersion) appVer = s.appVersion;
        continue;
      }

      NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:nil];
      if (!dict) continue;

      if (self.currentTab == 2) {
        VMPointerChain *chain = [VMPointerChain fromDictionary:dict];
        if (chain) {
          [allItems addObject:chain];
          if (dict[@"appName"]) appName = dict[@"appName"];
          if (dict[@"appVersion"]) appVer = dict[@"appVersion"];
        }
      } else if (self.currentTab == 3) {
        VMRVAPatch *patch = [VMRVAPatch fromDictionary:dict];
        if (patch) {
          [allItems addObject:patch];
          if (dict[@"appName"]) appName = dict[@"appName"];
          if (dict[@"appVersion"]) appVer = dict[@"appVersion"];
        }
      } else if (self.currentTab == 4) {
        VMSignatureModel *sig = [VMSignatureModel fromDictionary:dict];
        if (sig) {
          [allItems addObject:sig];
          if (dict[@"appName"]) appName = dict[@"appName"];
          if (dict[@"appVersion"]) appVer = dict[@"appVersion"];
        }
      } else if (self.currentTab == 6) {
        VMScriptModel *sc = [VMScriptModel fromDictionary:dict];
        if (sc) {
          [allItems addObject:sc];
          if (dict[@"appName"]) appName = dict[@"appName"];
          if (dict[@"appVersion"]) appVer = dict[@"appVersion"];
        }
      }
    }

    if (allItems.count == 0)
      continue;

    NSString *displayName = appName ?: (self.folderMetadata[bid][@"name"] ?: bid);
    NSString *baseName =
        [NSString stringWithFormat:@"VansonMod_%@_%@", displayName,
                                   typeStr.uppercaseString];
    NSString *savePath =
        [VMShareHelper generateUniqueExportPathForName:baseName extension:ext];

    VMDataSession *session = [VMDataSession sessionWithData:allItems
                                                   bundleID:bid
                                                   dataType:typeStr];
    if (appName) session.appName = appName;
    if (appVer) session.appVersion = appVer;
    NSData *data = [session toJSONDataForExport];
    if (data && [data writeToFile:savePath atomically:YES]) {
      [tempFiles addObject:[NSURL fileURLWithPath:savePath]];
    }
  }

  if (tempFiles.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }

  UIView *sourceView = self.navigationController.navigationBar;
  CGRect sourceRect =
      CGRectMake(sourceView.bounds.size.width - 50, 0, 50, 44);
  id shareContent =
      (tempFiles.count == 1) ? tempFiles.firstObject : tempFiles;
  [VMShareHelper shareContent:shareContent
           fromViewController:self
                   sourceView:sourceView
                   sourceRect:sourceRect];
  [self exitBatchMode];
}

- (void)performBatchCopy {
  NSArray *selectedPaths = [self.tableView indexPathsForSelectedRows];
  if (!selectedPaths || selectedPaths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }

  NSArray *sortedPaths = [selectedPaths
      sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a,
                                                     NSIndexPath *b) {
        return [a compare:b];
      }];

  NSArray *dataSrc = [self currentDisplayData];
  NSMutableString *resultStr = [NSMutableString string];
  int successCount = 0;

  for (NSIndexPath *ip in sortedPaths) {
    if (ip.row >= dataSrc.count)
      continue;

    uint64_t addr = 0;
    if (self.currentTab == 0 || self.currentTab == 1) {
      NSDictionary *item = dataSrc[ip.row];
      addr = [item[@"addr"] unsignedLongLongValue];
    } else if (self.currentTab == 2) {
      VMPointerChain *chain = dataSrc[ip.row];
      addr = [self forceResolveChain:chain];
    }
    
    else if (self.currentTab == 3) {
      VMRVAPatch *patch = dataSrc[ip.row];
      uint64_t modBase =
          [[VMMemoryEngine shared] findModuleBaseAddress:patch.moduleName];
      if (modBase > 0) {
        addr = modBase + patch.offset;
      }
    }
    
    else if (self.currentTab == 4) {
      
      VMSignatureModel *sig = dataSrc[ip.row];
      if (sig.runtimeResults.count > 0) {
        
        addr = [sig.runtimeResults.firstObject[@"addr"] unsignedLongLongValue];
      }
    }

    if (addr > 0) {
      [resultStr appendFormat:@"0x%llX\n", addr];
      successCount++;
    } else {
      if (addr > 0) {
        [resultStr appendFormat:@"0x%llX\n", addr];
        successCount++;
      } else {
        
        [resultStr appendString:@"0x0\n"];
      }
    }
  }

  if (resultStr.length > 0) {
    [resultStr deleteCharactersInRange:NSMakeRange(resultStr.length - 1, 1)];
    [[UIPasteboard generalPasteboard] setString:resultStr];
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
    [self showToast:[NSString stringWithFormat:@"%@ %d", TR(@"Msg_Copy_Success"), successCount]];
    [self exitBatchMode];
  } else {
    [self showToast:TR(@"Msg_Nothing_Copy")];
  }
}

- (void)performBatchDelete {
  NSUInteger count = self.tableView.indexPathsForSelectedRows.count;
  if (count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }
  NSString *message = [NSString stringWithFormat:@"%@ · %lu", self.tabItems[self.currentTab], (unsigned long)count];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Act_Delete") message:message preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    [self executeBatchDelete];
  }]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)executeBatchDelete {
  NSArray *selectedPaths = [self.tableView indexPathsForSelectedRows];
  if (!selectedPaths || selectedPaths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }

  if (self.isFolderMode && self.currentTab >= 2) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self getDirectoryForCurrentTab];

    for (NSIndexPath *ip in selectedPaths) {
      if (ip.row < self.folderList.count) {
        NSString *bid = self.folderList[ip.row];
        NSString *folderPath = [dir stringByAppendingPathComponent:bid];
        [fm removeItemAtPath:folderPath error:nil];
      }
    }

    [self reloadFolderData];

    if (self.folderList.count == 0) {
      self.isFolderMode = NO;
      self.targetBundleID = nil;
      [self updateNavBar];
      [self updateFooter];
      [self.tableView reloadData];
    } else {
      [self.tableView reloadData];
    }

    [self exitBatchMode];
    return;
  }

  if (self.currentTab == 0 || self.currentTab == 1) {
    NSMutableArray *targetArray = (self.currentTab == 0)
                                      ? [VMMemoryEngine shared].lockedItems
                                      : [VMMemoryEngine shared].favoriteItems;

    NSArray *sorted = [selectedPaths
        sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a,
                                                       NSIndexPath *b) {
          return [b compare:a];
        }];

    for (NSIndexPath *ip in sorted) {
      if (ip.row < targetArray.count) {
        [targetArray removeObjectAtIndex:ip.row];
      }
    }

    if (self.currentTab == 0 && targetArray.count == 0) {
      [self stopGCDTimer];
    }

    [self.tableView deleteRowsAtIndexPaths:selectedPaths
                          withRowAnimation:UITableViewRowAnimationFade];
    [self updateFooter];
    [self exitBatchMode];

    if (self.currentTab == 1) {
      [[VMMemoryEngine shared] saveFavorites];
    }
    return;
  }

  if (self.currentTab == 2) {
    NSArray *dataSrc = [self currentDisplayData];
    
    NSMutableArray *itemsToDelete = [NSMutableArray array];
    for (NSIndexPath *ip in selectedPaths) {
      if (ip.row < dataSrc.count)
        [itemsToDelete addObject:dataSrc[ip.row]];
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *rootDir = [self getDirectoryForCurrentTab];
    NSMutableSet *affectedBIDs = [NSMutableSet set];

    for (VMPointerChain *chain in itemsToDelete) {
      NSString *bid = chain.bundleID;
      if (!bid)
        bid = [[VMMemoryEngine shared] currentBundleID];

      if (bid && chain.fileName) {
        NSString *path = [[rootDir stringByAppendingPathComponent:bid]
            stringByAppendingPathComponent:chain.fileName];
        [fm removeItemAtPath:path error:nil];
        [affectedBIDs addObject:bid];
      }
    }

    for (NSString *bid in affectedBIDs) {
      [[NSClassFromString(@"VMLockManager") performSelector:@selector(shared)]
          performSelector:@selector(saveLocks:forApp:)
               withObject:@[]
               withObject:bid];
    }

    [[VMMemoryEngine shared] reloadLockedPointers];

    BOOL triggeredExit = NO;
    for (NSString *bid in affectedBIDs) {
      [self checkAndCleanupFolderForBundleID:bid];
      
      if (self.currentTab == 2 && !self.isFolderMode &&
          [self.targetBundleID isEqualToString:bid]) {
        triggeredExit = YES;
      }
    }

    [self exitBatchMode];

    if (!triggeredExit) {
      [self.tableView reloadData];
      [self updateFooter];
    }
    return;
  }

  if (_currentTab == 3) {
    NSArray *dataSrc = [self currentDisplayData];
    NSMutableArray *itemsToDelete = [NSMutableArray array];

    for (NSIndexPath *ip in selectedPaths) {
      if (ip.row < dataSrc.count) {
        [itemsToDelete addObject:dataSrc[ip.row]];
      }
    }

    NSString *rootDir = [self getDirectoryForCurrentTab];
    NSMutableSet *bidsToCheck = [NSMutableSet set];

    for (VMRVAPatch *p in itemsToDelete) {
      if (p.bundleID && p.fileName) {
        
        NSString *path = [[rootDir stringByAppendingPathComponent:p.bundleID]
            stringByAppendingPathComponent:p.fileName];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [bidsToCheck addObject:p.bundleID];
      }
      [[VMMemoryEngine shared].rvaPatches removeObject:p];
    }

    for (NSString *bid in bidsToCheck) {
      [self checkAndCleanupRVAFolder:bid];
    }

    BOOL triggeredExit = NO;
    for (NSString *bid in bidsToCheck) {
      if (self.currentTab == 3 && !self.isFolderMode &&
          [self.targetBundleID isEqualToString:bid]) {
        triggeredExit = YES;
      }
    }

    [self exitBatchMode];

    if (!triggeredExit) {
      [self.tableView reloadData];
      [self updateFooter];
    }
  } else {
    
    if (self.currentTab == 4) {
      NSArray *dataSrc = [self currentDisplayData];
      NSMutableArray *itemsToDelete = [NSMutableArray array];

      for (NSIndexPath *ip in selectedPaths) {
        if (ip.row < dataSrc.count) {
          [itemsToDelete addObject:dataSrc[ip.row]];
        }
      }

      NSString *rootDir = [self getDirectoryForCurrentTab];
      NSMutableSet *affectedBIDs = [NSMutableSet set];
      NSFileManager *fm = [NSFileManager defaultManager];

      for (VMSignatureModel *sig in itemsToDelete) {
        if (sig.bundleID && sig.fileName) {
          NSString *path =
              [[rootDir stringByAppendingPathComponent:sig.bundleID]
                  stringByAppendingPathComponent:sig.fileName];
          [fm removeItemAtPath:path error:nil];
          [affectedBIDs addObject:sig.bundleID];
        }
        [[VMLockManager shared] removeSignature:sig];
      }

      [self reloadFolderDataOrFileData];

      BOOL triggeredExit = NO;
      for (NSString *bid in affectedBIDs) {
        [self checkAndCleanupSigFolder:bid];
        
        if (self.currentTab == 4 && !self.isFolderMode &&
            [self.targetBundleID isEqualToString:bid]) {
          triggeredExit = YES;
        }
      }

      [self exitBatchMode];

      if (!triggeredExit) {
        [self.tableView reloadData];
        [self updateFooter];
      }
    }

    if (self.currentTab == 5 && !self.isFolderMode) {
      
      NSArray *dataSrc = [self currentDisplayData];
      NSMutableArray *filesToDelete = [NSMutableArray array];

      for (NSIndexPath *ip in selectedPaths) {
        if (ip.row < dataSrc.count) {
          [filesToDelete addObject:dataSrc[ip.row]];
        }
      }

      NSString *root = [[VMPointerManager shared] verifierFolder];
      NSString *appDir =
          [root stringByAppendingPathComponent:self.targetBundleID];
      NSFileManager *fm = [NSFileManager defaultManager];

      for (NSString *fileName in filesToDelete) {
        NSString *fullPath = [appDir stringByAppendingPathComponent:fileName];
        [fm removeItemAtPath:fullPath error:nil];
      }

      [self reloadFolderDataOrFileData];
      [self checkAndCleanupFolderForBundleID:self.targetBundleID];

      if (!self.isFolderMode) {
        [self.tableView reloadData];
        [self updateFooter];
      }

      [self exitBatchMode];
      return;
    }

    if (self.currentTab == 6 && !self.isFolderMode) {
      NSArray *dataSrc = [self currentDisplayData];
      NSMutableArray *itemsToDelete = [NSMutableArray array];

      for (NSIndexPath *ip in selectedPaths) {
        if (ip.row < dataSrc.count) {
          [itemsToDelete addObject:dataSrc[ip.row]];
        }
      }

      NSFileManager *fm = [NSFileManager defaultManager];
      NSMutableSet *bids = [NSMutableSet set];

      for (VMScriptModel *m in itemsToDelete) {
        if (m.fileName && m.bundleID) {
          NSString *dir = [[self getDirectoryForCurrentTab]
              stringByAppendingPathComponent:m.bundleID];
          NSString *path = [dir stringByAppendingPathComponent:m.fileName];
          [fm removeItemAtPath:path error:nil];
          [bids addObject:m.bundleID];
        }
      }

      [self reloadFolderDataOrFileData];

      BOOL triggeredExit = NO;
      for (NSString *bid in bids) {
        NSString *dir = [[self getDirectoryForCurrentTab] stringByAppendingPathComponent:bid];
        NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
        NSArray *scs = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.vmsc'"]];
        if (scs.count == 0) {
          [fm removeItemAtPath:dir error:nil];
          if ([self.targetBundleID isEqualToString:bid]) triggeredExit = YES;
        }
      }

      [self exitBatchMode];
      if (triggeredExit) {
        [self backToFolderList];
      }
      return;
    }
  }
}

- (void)showEditChainInfoAlert:(VMPointerChain *)chain {
  [VMItemEditViewController presentInController:self model:chain onSave:^(VMPointerChain *updatedChain) {
    [[VMLockManager shared] addPointerToLock:updatedChain];
    [[VMMemoryEngine shared] reloadLockedPointers];
    [self.tableView reloadData];
  }];
}

- (void)showEditSignatureInfoAlert:(VMSignatureModel *)sig {
  [VMItemEditViewController presentInController:self model:sig onSave:^(VMSignatureModel *updatedSig) {
    [[VMLockManager shared] updateSignature:updatedSig];
    [self reloadFolderDataOrFileData];
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Saved")];
  }];
}

- (void)showEditRVAInfoAlert:(VMRVAPatch *)patch {
  [VMItemEditViewController presentInController:self model:patch onSave:^(VMRVAPatch *updatedPatch) {
    [[VMMemoryEngine shared] saveRVAPatches];
    [self reloadFolderDataOrFileData];
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Saved")];
  }];
}

- (void)onCopyChainText:(UIButton *)sender {
  NSString *text = objc_getAssociatedObject(sender, "chainText");
  if (text.length > 0) {
    [UIPasteboard generalPasteboard].string = text;
    [self showToast:TR(@"Msg_Copied")];
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
  }
}

- (void)onQuickCopyOffset:(UIButton *)sender {
  VMPointerChain *chain = objc_getAssociatedObject(sender, "chainRef");
  UIAlertController *alert = objc_getAssociatedObject(sender, "alertRef");
  [alert dismissViewControllerAnimated:YES completion:^{
    [self showCopyOffsetAlert:chain];
  }];
}

- (void)showSliderConfigAlert:(VMPointerChain *)chain {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Slider_Config_Title") message:nil preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = TR(@"Slider_Min_Label");
    textField.text = [NSString stringWithFormat:@"%.2f", chain.uiMin];
    textField.keyboardType = UIKeyboardTypeDecimalPad;
  }];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = TR(@"Slider_Max_Label");
    textField.text = [NSString stringWithFormat:@"%.2f", chain.uiMax];
    textField.keyboardType = UIKeyboardTypeDecimalPad;
  }];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    float min = [alert.textFields[0].text floatValue];
    float max = [alert.textFields[1].text floatValue];
    if (min >= max) {
      [self showToast:TR(@"Slider_Err_Min_Less_Max")];
      [self showSliderConfigAlert:chain];
      return;
    }
    chain.uiMin = min;
    chain.uiMax = max;
    [[VMLockManager shared] addPointerToLock:chain];
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Saved")];
  }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)typeSegmentChanged:(UISegmentedControl *)sender {
  UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
  [gen impactOccurred];
}

- (void)showCopyOffsetAlert:(VMPointerChain *)originalChain {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Ptr_Action_Copy_Offset") message:TR(@"Ptr_Copy_Offset_Msg") preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Offset_Input_Placeholder");
    tf.keyboardType = UIKeyboardTypeASCIICapable;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Placeholder_Note");
    tf.text = [NSString stringWithFormat:TR(@"Copy_Name_Format"), originalChain.note];
  }];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    NSString *offsetStr = alert.textFields[0].text;
    offsetStr = [offsetStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    BOOL isNegative = NO;
    if ([offsetStr hasPrefix:@"-"]) {
      isNegative = YES;
      offsetStr = [offsetStr substringFromIndex:1];
    } else if ([offsetStr hasPrefix:@"+"]) {
      offsetStr = [offsetStr substringFromIndex:1];
    }
    offsetStr = [offsetStr stringByReplacingOccurrencesOfString:@"0x" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, offsetStr.length)];
    long long offsetToAdd = strtoull([offsetStr UTF8String], NULL, 16);
    if (isNegative) offsetToAdd = -offsetToAdd;

    NSString *newNote = alert.textFields[1].text;
    VMPointerChain *newChain = [[VMPointerChain alloc] init];
    newChain.moduleName = originalChain.moduleName;
    newChain.baseOffset = originalChain.baseOffset;
    NSMutableArray *newOffsets = [originalChain.offsets mutableCopy];
    if (newOffsets.count > 0) {
      long long lastOff = [[newOffsets lastObject] longLongValue];
      [newOffsets replaceObjectAtIndex:(newOffsets.count - 1) withObject:@(lastOff + offsetToAdd)];
    } else {
      [newOffsets addObject:@(offsetToAdd)];
    }
    newChain.offsets = newOffsets;
    newChain.author = originalChain.author;
    newChain.isImported = originalChain.isImported;
    newChain.note = newNote;
    newChain.bundleID = originalChain.bundleID;
    if (!newChain.bundleID) {
      [self showToast:TR(@"Err_No_BundleID")];
      return;
    }
    newChain.lockEnabled = NO;
    newChain.lockType = originalChain.lockType;
    newChain.lockValue = originalChain.lockValue;
    newChain.createdAt = [[NSDate date] timeIntervalSince1970] + 0.001;
    [[VMLockManager shared] addPointerToLock:newChain];
    [self.tableView reloadData];
    [self showToast:TR(@"Alert_Success")];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showEditTypeAlert:(VMPointerChain *)chain {
  VMFormSheetViewController *form = [[VMFormSheetViewController alloc] initWithTitle:TR(@"Lock_Select_Type_Title") submitTitle:TR(@"Btn_Save")];
  NSArray *items = @[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str"];
  UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
  seg.translatesAutoresizingMaskIntoConstraints = NO;
  NSInteger current = chain.lockType;
  seg.selectedSegmentIndex = current >= VMDataTypeInt8 && current <= VMDataTypeString ? current : VMDataTypeInt32;
  seg.accessibilityLabel = TR(@"Lock_Select_Type_Title");
  UIScrollView *types = [UIScrollView new];
  types.showsHorizontalScrollIndicator = NO;
  [types addSubview:seg];
  [NSLayoutConstraint activateConstraints:@[
    [types.heightAnchor constraintEqualToConstant:44],
    [seg.topAnchor constraintEqualToAnchor:types.contentLayoutGuide.topAnchor],
    [seg.bottomAnchor constraintEqualToAnchor:types.contentLayoutGuide.bottomAnchor],
    [seg.leadingAnchor constraintEqualToAnchor:types.contentLayoutGuide.leadingAnchor],
    [seg.trailingAnchor constraintEqualToAnchor:types.contentLayoutGuide.trailingAnchor],
    [seg.heightAnchor constraintEqualToAnchor:types.frameLayoutGuide.heightAnchor],
    [seg.widthAnchor constraintEqualToConstant:616]
  ]];
  [form addView:types];
  form.submitHandler = ^NSString *(VMFormSheetViewController *editor) {
    chain.lockType = seg.selectedSegmentIndex;
    if (!chain.bundleID.length) chain.bundleID = [VMMemoryEngine shared].currentBundleID;
    if (chain.bundleID.length) [[VMLockManager shared] addPointerToLock:chain];
    return nil;
  };
  __weak __typeof(self) weakSelf = self;
  form.didSubmit = ^{ [weakSelf.tableView reloadData]; };
  [form presentFrom:self];
  dispatch_async(dispatch_get_main_queue(), ^{
    [types layoutIfNeeded];
    [types scrollRectToVisible:CGRectMake(seg.selectedSegmentIndex * 56, 0, 56, 44) animated:NO];
  });
}

- (void)showParentMenu:(VMPointerChain *)parent {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Sig_Options") message:nil preferredStyle:UIAlertControllerStyleActionSheet];

  if (!parent.isImported) {
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Common_Edit") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
      [self showEditChainInfoAlert:parent];
    }]];
  }

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Export") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self shareSingleItemDirectly:parent sourceView:self.view sourceRect:CGRectZero];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
    [[VMLockManager shared] removePointer:parent];
    [self reloadFolderDataOrFileData];
    [self.tableView reloadData];
    [self updateFooter];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    alert.popoverPresentationController.sourceView = self.tableView;
    NSUInteger row = [[self currentDisplayData] indexOfObjectIdenticalTo:parent];
    alert.popoverPresentationController.sourceRect = row != NSNotFound && row < [self.tableView numberOfRowsInSection:0]
        ? [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]]
        : CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showChildMenu:(VMPointerChain *)child {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Result_Options") message:nil preferredStyle:UIAlertControllerStyleActionSheet];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Menu_Modify") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [VMMemoryActionSheet showActionSheetForAddress:child.baseOffset value:@"" dataType:(VMDataType)child.lockType fromViewController:self sourceView:self.tableView sourceRect:CGRectZero extraItem:nil];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Menu_Lock_Top") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    VMPointerChain *newPtr = [[VMPointerChain alloc] init];
    newPtr.isSignatureMode = NO;
    newPtr.bundleID = [[VMMemoryEngine shared] currentBundleID];
    newPtr.moduleName = TR(@"Module_Virtual");
    newPtr.baseOffset = child.baseOffset;
    newPtr.offsets = @[];
    newPtr.note = child.note;
    newPtr.lockType = child.lockType;
    newPtr.lockValue = child.lockValue;
    newPtr.lockEnabled = child.lockEnabled;
    newPtr.author = TR(@"Sig_Author_Default");
    [[VMLockManager shared] addPointerToLock:newPtr];
    [self showToast:TR(@"Ptr_Lock_Success")];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    alert.popoverPresentationController.sourceView = self.tableView;
    NSUInteger row = [[self currentDisplayData] indexOfObjectIdenticalTo:child];
    alert.popoverPresentationController.sourceRect = row != NSNotFound && row < [self.tableView numberOfRowsInSection:0]
        ? [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]]
        : CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleRefresh:(UIRefreshControl *)sender {
  sender.attributedTitle = [[NSAttributedString alloc] initWithString:TR(@"Pull_Loading")];

  [[VMMemoryEngine shared] reloadLockedPointers];

  if (self.currentTab == 2) {
    if (!self.isFolderMode && self.targetBundleID) {
      [[VMLockManager shared] reloadLocksFromDiskForApp:self.targetBundleID];
    }
    [self reloadFolderData];
  } else if (self.currentTab == 4) {
    self.activeSignatures = [[VMLockManager shared] loadSignaturesForApp:self.targetBundleID];
  }

  [self.tableView reloadData];
  [self updateFooter];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [sender endRefreshing];
    sender.attributedTitle = [[NSAttributedString alloc] initWithString:TR(@"Pull_Idle")];
  });
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (scrollView != self.tableView || self.tableView.refreshControl.isRefreshing) return;
  CGFloat baseOffset = scrollView.adjustedContentInset.top;
  CGFloat pullDistance = -(scrollView.contentOffset.y + baseOffset);
  CGFloat triggerHeight = 45.0;
  NSString *currentText = self.tableView.refreshControl.attributedTitle.string;
  if (pullDistance > triggerHeight) {
    if (![currentText isEqualToString:TR(@"Pull_Ready")]) {
      self.tableView.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:TR(@"Pull_Ready")];
    }
  } else if (pullDistance > 0) {
    if (![currentText isEqualToString:TR(@"Pull_Idle")]) {
      self.tableView.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:TR(@"Pull_Idle")];
    }
  }
}

- (BOOL)isConnectedToBundle:(NSString *)targetBid {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  BOOL isAlive = (eng.targetTask != MACH_PORT_NULL && kill(eng.targetPid, 0) == 0);
  BOOL isMatch = targetBid ? [eng.currentBundleID isEqualToString:targetBid] : YES;
  return isAlive && isMatch;
}

- (void)didClickSettings:(UITableViewCell *)cell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath) return;

  if (self.currentTab == 2) {
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row >= dataSrc.count) return;
    VMPointerChain *chain = dataSrc[indexPath.row];
    [self showEditChainInfoAlert:chain];
  } else if (self.currentTab == 4) {
    if (indexPath.row >= self.activeSignatures.count) return;
    id item = self.activeSignatures[indexPath.row];

    if ([item isKindOfClass:NSClassFromString(@"VMSignatureModel")]) {
      [self showEditSignatureAlert:(VMSignatureModel *)item];
    }
  }
}

- (void)didClickSet:(UITableViewCell *)cell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  NSArray *dataSrc = [self currentDisplayData];
  if (indexPath.row >= dataSrc.count) return;
  VMPointerChain *chain = dataSrc[indexPath.row];
  if (![self ensureConnectionForChain:chain]) return;
  NSString *valToWrite = chain.lockValue ?: TR(@"Default_Value");
  VMDataType type = (VMDataType)chain.lockType;
  uint64_t finalAddr = [self forceResolveChain:chain];
  if (finalAddr == 0 && chain.bundleID.length > 0 &&
      [self tryReconnectForBundleID:chain.bundleID]) {
    [[VMMemoryEngine shared] loadRemoteModules];
    finalAddr = [self forceResolveChain:chain];
  }
  if (finalAddr > 0) {
    [[VMMemoryEngine shared] writeAddress:finalAddr value:valToWrite type:type];
    NSString *typeStr = [self typeNameForType:type];
    [self showToast:[NSString stringWithFormat:TR(@"Lock_Set_Success_Format"), typeStr, valToWrite]];
    [self refreshVisiblePointerValues];
  } else {
    [self showToast:TR(@"Ptr_Err_Resolve")];
  }
}

- (void)didChangeLockState:(UITableViewCell *)cell isOn:(BOOL)isOn {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath) return;

  NSArray *displayList = [self currentDisplayData];
  if (indexPath.row >= displayList.count) return;

  if (self.currentTab == 0) {
    NSMutableDictionary *item = displayList[indexPath.row];
    uint64_t addr = [item[@"addr"] unsignedLongLongValue];
    
    [[VMLockEngine shared] setAddressLock:addr enabled:isOn];
    
    if (isOn) {
      UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
      [gen impactOccurred];
      [self showToast:TR(@"Lock_Title")];
    } else {
      [self showToast:TR(@"Btn_Unlock")];
    }
    
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    return;
  }

  if (self.currentTab != 2 && self.currentTab != 4) return;

  VMPointerChain *uiChain = displayList[indexPath.row];
  if (isOn) {
    if (![self ensureConnectionForChain:uiChain]) {
      [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
      return;
    }
  }

  uiChain.lockEnabled = isOn;

  VMMemoryEngine *engine = [VMMemoryEngine shared];
  NSMutableArray *activeList = engine.activeLockedPointers;

  VMPointerChain *foundInEngine = nil;
  for (VMPointerChain *c in activeList) {
    if ([c.uniqueId isEqualToString:uiChain.uniqueId]) {
      foundInEngine = c;
      break;
    }
  }

  if (isOn) {
    if (!foundInEngine) [activeList addObject:uiChain];
    else foundInEngine.lockEnabled = YES;

    [[VMLockEngine shared] setPointerLock:uiChain.uniqueId enabled:YES];

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
  } else {
    if (foundInEngine) foundInEngine.lockEnabled = NO;
    
    [[VMLockEngine shared] setPointerLock:uiChain.uniqueId enabled:NO];
  }

  NSString *bid = uiChain.bundleID;
  if (bid) {
    if (self.currentTab == 4) {
      [[VMLockManager shared] addPointerToLock:uiChain];
    } else {
      [[VMLockManager shared] addPointerToLock:uiChain];
    }
  }

  if ([cell respondsToSelector:@selector(updateLockStateVisuals:animated:)]) {
    [(id)cell updateLockStateVisuals:isOn animated:YES];
  }

  if (isOn) {
    NSString *typeName = [self typeNameForType:(VMDataType)uiChain.lockType];
    NSString *msg = [NSString stringWithFormat:TR(@"Lock_Status_Format"), typeName, uiChain.lockValue ?: @"0"];
    [self showToast:msg];
  } else {
    [self showToast:TR(@"Btn_Unlock")];
  }
}

- (void)didChangeSliderValue:(UITableViewCell *)cell value:(NSString *)val {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath)
    return;

  NSArray *dataSrc = [self currentDisplayData];
  if (indexPath.row >= dataSrc.count)
    return;

  id item = dataSrc[indexPath.row];

  if ([item isKindOfClass:[VMPointerChain class]]) {
    VMPointerChain *chain = (VMPointerChain *)item;

    chain.lockValue = val;

    NSString *bid = chain.bundleID ?: [[VMMemoryEngine shared] currentBundleID];
    if (bid) {
      [[VMLockManager shared] addPointerToLock:chain];
    }

    if ([self ensureConnectionForBundleID:bid] >= 0) {
      uint64_t finalAddr = [self forceResolveChain:chain];
      if (finalAddr > 0) {
        VMDataType type = (VMDataType)chain.lockType;
        [[VMMemoryEngine shared] writeAddress:finalAddr value:val type:type];
        
        [self showToast:TR(@"Common_Update_Success")];
      }
    }
  }
}

- (void)didChangeSwitchState:(UITableViewCell *)cell isOn:(BOOL)isOn {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath)
    return;

  NSArray *dataSrc = [self currentDisplayData];
  if (indexPath.row >= dataSrc.count)
    return;

  id item = dataSrc[indexPath.row];

  if ([item isKindOfClass:[VMPointerChain class]]) {
    VMPointerChain *chain = (VMPointerChain *)item;

    NSString *val = isOn ? chain.switchOnValue : chain.switchOffValue;
    chain.lockValue = val;

    NSString *bid = chain.bundleID ?: [[VMMemoryEngine shared] currentBundleID];
    if (bid) {
      [[VMLockManager shared] addPointerToLock:chain];
    }

    if ([self ensureConnectionForBundleID:bid] >= 0) {
      uint64_t finalAddr = [self forceResolveChain:chain];
      if (finalAddr > 0) {
        VMDataType type = (VMDataType)chain.lockType;
        [[VMMemoryEngine shared] writeAddress:finalAddr value:val type:type];
        
        [self showToast:TR(@"Common_Update_Success")];
      }
    }
  }
}

- (void)didClickScan:(UITableViewCell *)cell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath || indexPath.row >= self.activeSignatures.count)
    return;

  id item = self.activeSignatures[indexPath.row];

  BOOL isSignatureModel =
      [item isKindOfClass:NSClassFromString(@"VMSignatureModel")];

  NSString *bid = [item valueForKey:@"bundleID"];
  if ([self ensureConnectionForBundleID:bid] <= 0) {
    return; 
  }

  if ([item respondsToSelector:@selector(setIsScanning:)]) {
    [item setValue:@(YES) forKey:@"isScanning"];
    [item setValue:nil forKey:@"scanError"];
  }
  [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];

  if (isSignatureModel) {
    VMSignatureModel *signature = (VMSignatureModel *)item;
    [self performSignatureVerification:signature completion:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        if (indexPath.row < self.activeSignatures.count) {
          [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
      });
    }];
  } else {
    [self performSingleSignatureScan:item completion:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        if (indexPath.row < self.activeSignatures.count) {
          [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
      });
    }];
  }
}

- (void)performSingleSignatureScan:(id)chain completion:(void (^)(void))comp {
  VMMemoryEngine *engine = [VMMemoryEngine shared];

  NSString *bundleID = [chain valueForKey:@"bundleID"];
  NSString *moduleName = [chain valueForKey:@"moduleName"];
  NSString *signature = [chain valueForKey:@"signature"];

  if (engine.targetTask == MACH_PORT_NULL) {
    if (bundleID && [self tryReconnectForBundleID:bundleID]) {
      [[VMMemoryEngine shared] loadRemoteModules];
    } else {
      
      if ([chain respondsToSelector:@selector(setIsScanning:)])
        [chain setValue:@(NO) forKey:@"isScanning"];
      if ([chain respondsToSelector:@selector(setScanError:)])
        [chain setValue:TR(@"Err_Not_Connected") forKey:@"scanError"];
      if (comp)
        comp();
      return;
    }
  }

  void (^handleScanResult)(NSArray *) = ^(NSArray *results) {
    
    if ([chain respondsToSelector:@selector(setIsScanning:)])
      [chain setValue:@(NO) forKey:@"isScanning"];

    if (results.count > 0) {
      
      long long offset = 0;

      if ([chain isKindOfClass:NSClassFromString(@"VMSignatureModel")]) {
        offset = [[chain valueForKey:@"offset"] longLongValue];
      }
      
      else if ([chain respondsToSelector:@selector(offsets)]) {
        NSArray *offs = [chain valueForKey:@"offsets"];
        if (offs && offs.count > 0) {
          offset = [offs[0] longLongValue];
        }
      }

      NSMutableArray *finalAddresses = [NSMutableArray array];
      for (VMScanResultItem *item in results) {
        uint64_t finalAddr = item.address + offset;
        [finalAddresses addObject:@(finalAddr)];
      }

      if ([chain isKindOfClass:NSClassFromString(@"VMSignatureModel")]) {
        
        NSMutableArray *dicts = [NSMutableArray array];
        for (NSNumber *addrNum in finalAddresses) {
          uint64_t addr = [addrNum unsignedLongLongValue];
          
          NSString *val = [engine readAddress:addr type:VMDataTypeInt32];
          if (!val)
            val = @"--";
          [dicts addObject:@{
            @"addr" : @(addr),
            @"val" : val,
            @"note" : @"VansonMod"
          }];
        }
        [chain setValue:dicts forKey:@"runtimeResults"];
        [chain setValue:nil forKey:@"scanError"];
      } else {
        
        if ([chain respondsToSelector:@selector(setMultiRuntimeAddresses:)]) {
          [chain setValue:finalAddresses forKey:@"multiRuntimeAddresses"];
        }
        if ([chain respondsToSelector:@selector(setCachedRuntimeAddress:)] &&
            finalAddresses.count > 0) {
          [chain setValue:finalAddresses[0] forKey:@"cachedRuntimeAddress"];
        }
        if ([chain respondsToSelector:@selector(setScanError:)]) {
          [chain setValue:nil forKey:@"scanError"];
        }
      }

    } else {
      
      if ([chain isKindOfClass:NSClassFromString(@"VMSignatureModel")]) {
        [chain setValue:@[] forKey:@"runtimeResults"];
      } else if ([chain
                     respondsToSelector:@selector(setMultiRuntimeAddresses:)]) {
        [chain setValue:@[] forKey:@"multiRuntimeAddresses"];
      }

      if ([chain respondsToSelector:@selector(setScanError:)]) {
        [chain setValue:TR(@"Sig_No_Match") forKey:@"scanError"];
      }
    }

    if (comp)
      comp();
  };

  if (moduleName && moduleName.length > 0) {
    [engine loadRemoteModules];
    [engine fastScanSignature:signature inModule:moduleName completion:handleScanResult];
  } else {
    [engine scanSignature:signature rangeStart:0 rangeEnd:0 completion:handleScanResult];
  }
}

#pragma mark - [新增] 特征码专用验证方法（与指针逻辑解耦）

- (void)performSignatureVerification:(VMSignatureModel *)signature completion:(void (^)(void))completion {
  if (!signature || ![signature isKindOfClass:NSClassFromString(@"VMSignatureModel")]) {
    if (completion) completion();
    return;
  }

  VMMemoryEngine *engine = [VMMemoryEngine shared];

  if (engine.targetTask == MACH_PORT_NULL) {
    if (signature.bundleID && signature.bundleID.length > 0) {
      if ([self tryReconnectForBundleID:signature.bundleID]) {
        [engine loadRemoteModules];
      } else {
        signature.isScanning = NO;
        signature.scanError = TR(@"Err_Not_Connected");
        if (completion) completion();
        return;
      }
    } else {
      signature.isScanning = NO;
      signature.scanError = TR(@"Err_No_BundleID");
      if (completion) completion();
      return;
    }
  }

  void (^handleResults)(NSArray *) = ^(NSArray *results) {
    signature.isScanning = NO;

    if (results && results.count > 0) {
      NSMutableArray *runtimeResults = [NSMutableArray array];

      for (VMScanResultItem *item in results) {
        uint64_t finalAddr = item.address + signature.offset;
        NSString *value = [engine readAddress:finalAddr type:VMDataTypeInt32] ?: @"--";
        [runtimeResults addObject:@{@"addr": @(finalAddr), @"val": value, @"note": @"VansonMod"}];
      }
      signature.runtimeResults = runtimeResults;
      signature.scanError = nil;
    } else {
      signature.runtimeResults = @[];
      signature.scanError = TR(@"Sig_No_Match");
    }

    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
    }
  };

  if (signature.moduleName && signature.moduleName.length > 0) {
    [engine loadRemoteModules];
    [engine fastScanSignature:signature.signature inModule:signature.moduleName completion:handleResults];
  } else {
    [engine scanSignature:signature.signature rangeStart:0 rangeEnd:0 completion:handleResults];
  }
}

- (void)didClickModifyResult:(UITableViewCell *)cell atAddress:(uint64_t)address currentType:(VMDataType)type {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath) return;

  VMPointerChain *chain = self.activeSignatures[indexPath.row];
  NSString *currentVal = [[VMMemoryEngine shared] readAddress:address type:type];

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Mod_Menu_Modify") message:[NSString stringWithFormat:@"0x%llX", address] preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = currentVal;
    tf.placeholder = TR(@"Default_Value");
  }];

  UIViewController *contentVC = [[UIViewController alloc] init];
  contentVC.preferredContentSize = CGSizeMake(270, 100);
  contentVC.view.backgroundColor = [UIColor clearColor];
  NSArray *items = @[@"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str"];
  UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
  seg.frame = CGRectMake(0, 0, 550, 44);
  NSInteger currentIdx = type;
  if (currentIdx < VMDataTypeInt8 || currentIdx > VMDataTypeString) currentIdx = VMDataTypeInt32;
  seg.selectedSegmentIndex = currentIdx;
  seg.accessibilityLabel = TR(@"Lock_Select_Type_Title");
  UIScrollView *types = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 8, 270, 52)];
  types.showsHorizontalScrollIndicator = NO;
  types.contentSize = CGSizeMake(550, 44);
  [types addSubview:seg];
  [types scrollRectToVisible:CGRectMake(currentIdx * 50, 0, 50, 44) animated:NO];
  [contentVC.view addSubview:types];
  [alert setValue:contentVC forKey:@"contentViewController"];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    NSString *newVal = alert.textFields[0].text;
    VMDataType newType = (VMDataType)seg.selectedSegmentIndex;
    [[VMMemoryEngine shared] writeAddress:address value:newVal type:newType];
    if (newType != chain.lockType) {
      chain.lockType = newType;
      NSString *bid = chain.bundleID ?: [[VMMemoryEngine shared] currentBundleID];
      if (bid) {
        [[VMLockManager shared] saveLocks:[VMMemoryEngine shared].activeLockedPointers forApp:bid];
      }
    }
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Batch Modify Logic
- (void)performBatchModify {
  NSArray *selectedPaths = [self.tableView indexPathsForSelectedRows];
  if (selectedPaths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }

  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:TR(@"Mod_Batch_Menu_Title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Batch_Fixed_Btn") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self showBatchInputAlertWithMode:0 paths:selectedPaths];
  }]];

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Batch_Seq_Btn") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self showBatchInputAlertWithMode:1 paths:selectedPaths];
  }]];

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    UIBarButtonItem *modifyButton = nil;
    for (UIBarButtonItem *item in self.toolbarItems) {
      if (item.action == @selector(performBatchModify)) { modifyButton = item; break; }
    }
    if (modifyButton) {
      sheet.popoverPresentationController.barButtonItem = modifyButton;
    } else {
      sheet.popoverPresentationController.sourceView = self.view;
      sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
  }
  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showBatchInputAlertWithMode:(int)mode paths:(NSArray *)paths {
  NSString *title = (mode == 0) ? TR(@"Mod_Batch_Fixed") : TR(@"Title_Inc_Val");
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = (mode == 0) ? TR(@"Common_Val") : TR(@"Mod_Input_Val_Start");
    tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
  }];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
    NSString *inputVal = alert.textFields[0].text;
    if (inputVal.length == 0) return;
    [self executeBatchWrite:inputVal mode:mode paths:paths];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)executeBatchWrite:(NSString *)inputVal mode:(int)mode paths:(NSArray *)paths {
  double startDouble = [inputVal doubleValue];
  long long startInt = [inputVal longLongValue];

  NSArray *dataSrc = [self currentDisplayData];
  NSMutableArray<NSDictionary *> *writes = [NSMutableArray array];

  NSArray *sortedPaths = [paths sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
    return [a compare:b];
  }];

  for (int i = 0; i < sortedPaths.count; i++) {
    NSIndexPath *ip = sortedPaths[i];
    if (ip.row >= dataSrc.count) continue;
    NSString *writeStr = inputVal;

    if (self.currentTab == 4) {
      VMSignatureModel *sig = dataSrc[ip.row];

      VMDataType type = VMDataTypeInt32;

      if (mode == 1) {
        writeStr = [NSString stringWithFormat:@"%lld", startInt + (long long)i];
      }

      if (sig.runtimeResults.count > 0) {
        for (NSDictionary *res in sig.runtimeResults) {
          uint64_t addr = [res[@"addr"] unsignedLongLongValue];
          if (addr > 0) {
            [writes addObject:@{
              @"address" : @(addr),
              @"type" : @(type),
              @"value" : writeStr
            }];
          }
        }
      }
      continue; 
    }

    uint64_t targetAddr = 0;
    VMDataType type = VMDataTypeInt32;

    if (self.currentTab == 0 || self.currentTab == 1) {
      NSDictionary *item = dataSrc[ip.row];
      targetAddr = [item[@"addr"] unsignedLongLongValue];
      type = (VMDataType)[item[@"type"] intValue];

      if (self.currentTab == 0 &&
          [item isKindOfClass:[NSMutableDictionary class]]) {
        NSMutableDictionary *mItem = (NSMutableDictionary *)item;
        NSString *newUIVal = inputVal;
        
        if (mode == 1)
          newUIVal = [NSString stringWithFormat:@"%.0f", startDouble + i];
        mItem[@"val"] = newUIVal;
      }

    } else if (self.currentTab == 2) {
      VMPointerChain *chain = dataSrc[ip.row];
      targetAddr = [self forceResolveChain:chain];
      type =
          (VMDataType)chain.lockType;

      NSString *newLockVal = inputVal;
      if (mode == 1) {
        if (type == VMDataTypeFloat || type == VMDataTypeDouble) {
          newLockVal = [NSString stringWithFormat:@"%f", startDouble + i];
        } else {
          newLockVal = [NSString stringWithFormat:@"%lld", startInt + i];
        }
      }
      chain.lockValue = newLockVal;
    }

    if (mode == 1) {
      if (type == VMDataTypeFloat || type == VMDataTypeDouble) {
        writeStr = [NSString stringWithFormat:@"%f", startDouble + (double)i];
      } else {
        writeStr = [NSString stringWithFormat:@"%lld", startInt + (long long)i];
      }
    }

    if (targetAddr > 0) {
      [writes addObject:@{
        @"address" : @(targetAddr),
        @"type" : @(type),
        @"value" : writeStr
      }];
    }
  }

  NSUInteger successCount =
      [[VMMemoryEngine shared] performManualBatchWrites:writes];

  NSString *bid = [[VMMemoryEngine shared] currentBundleID];
  if (bid) {
    if (self.currentTab == 2) {
      [[VMLockManager shared] saveLocks:[self currentDisplayData] forApp:bid];
    } else if (self.currentTab == 4) {
      
    }
  }

  [self exitBatchMode];
  [self.tableView reloadData];
  [self showToast:[NSString stringWithFormat:@"%@ %lu", TR(@"Msg_Mod_Success"),
                                             (unsigned long)successCount]];
}

- (void)undoLastManualBatch {
  NSUInteger restored = [[VMMemoryEngine shared] undoLastManualWriteBatch];
  [self.tableView reloadData];
  [self updateNavBar];
  [self showToast:restored > 0 ? TR(@"Undo_Success") : TR(@"Undo_Failed")];
}

- (NSString *)currentValueSnapshotKey {
  return self.currentTab == 0 ? @"locked-addresses" : @"favorites";
}

- (void)updateValueSnapshotButton {
  if (self.currentTab > 1) return;
  self.valueSnapshotButton.enabled = [self currentDisplayData].count > 0 ||
      [[VMMemoryEngine shared] hasValueSnapshotForKey:[self currentValueSnapshotKey]];
}

- (void)showValueSnapshotMenu {
  NSString *key = [self currentValueSnapshotKey];
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  BOOL hasItems = [self currentDisplayData].count > 0;
  if (!hasItems && ![engine hasValueSnapshotForKey:key]) return;
  UIAlertController *sheet = [UIAlertController
      alertControllerWithTitle:TR(@"Snapshot_Title")
                       message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];

  UIAlertAction *capture = [UIAlertAction
                       actionWithTitle:TR(@"Snapshot_Save")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 NSMutableArray<NSDictionary *> *items =
                                     [NSMutableArray array];
                                 for (NSDictionary *entry in [self currentDisplayData]) {
                                   [items addObject:@{
                                     @"address" : entry[@"addr"] ?: @0,
                                     @"type" : entry[@"type"] ?: @(VMDataTypeInt32)
                                   }];
                                 }
                                 NSUInteger count =
                                     [engine captureValueSnapshotForKey:key items:items];
                                 NSString *message = count > 0
                                     ? [NSString stringWithFormat:TR(@"Snapshot_Saved_Fmt"),
                                                                  (unsigned long)count]
                                     : TR(@"Snapshot_Empty");
                                 [self showToast:message];
                                 [self updateNavBar];
                               }];
  capture.enabled = hasItems;
  [sheet addAction:capture];

  if ([engine hasValueSnapshotForKey:key]) {
    NSString *restoreTitle =
        [NSString stringWithFormat:@"%@ (%lu)", TR(@"Btn_Restore"),
                                   (unsigned long)[engine valueSnapshotCountForKey:key]];
    [sheet addAction:[UIAlertAction
                         actionWithTitle:restoreTitle
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   NSUInteger restored =
                                       [engine restoreValueSnapshotForKey:key];
                                   [self.tableView reloadData];
                                   [self showToast:restored > 0
                                                       ? TR(@"Undo_Success")
                                                       : TR(@"Timeline_Restore_Failed")];
                                 }]];
  }

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    sheet.popoverPresentationController.barButtonItem =
        self.navigationItem.rightBarButtonItems.lastObject;
  }
  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)exportSelectedAsBackup:(NSArray *)selectedPaths {
  NSMutableArray *itemsToShare = [NSMutableArray array];
  NSArray *currentDataSrc = [self currentDisplayData];

  if (self.currentTab == 0 || self.currentTab == 1) {
    NSMutableString *text = [NSMutableString string];
    for (NSIndexPath *ip in selectedPaths) {
      if (ip.row < currentDataSrc.count) {
        NSDictionary *item = currentDataSrc[ip.row];
        [text appendFormat:@"0x%llX [%@] %@%@\n", [item[@"addr"] unsignedLongLongValue],
            [self typeNameForType:(VMDataType)[item[@"type"] integerValue]], item[@"val"] ?: @"—",
            [item[@"note"] length] ? [NSString stringWithFormat:@" · %@", item[@"note"]] : @""];
      }
    }
    [VMShareHelper shareContent:text fromViewController:self sourceView:self.navigationController.navigationBar sourceRect:CGRectMake(self.navigationController.navigationBar.bounds.size.width - 50, 0, 50, 44)];
    [self exitBatchMode];
    return;
  }

  for (NSIndexPath *ip in selectedPaths) {
    if (ip.row < currentDataSrc.count) {
      [itemsToShare addObject:currentDataSrc[ip.row]];
    }
  }

  if (itemsToShare.count == 0) return;

  NSMutableDictionary *groupedByBid = [NSMutableDictionary dictionary];
  for (VMPointerChain *chain in itemsToShare) {
    NSString *bid = chain.bundleID;
    if (!bid) {
      [self showToast:TR(@"Err_No_BundleID")];
      return;
    }
    if (!groupedByBid[bid])
      groupedByBid[bid] = [NSMutableArray array];
    [groupedByBid[bid] addObject:chain];
  }

  if (groupedByBid.count == 1) {
    NSString *bid = groupedByBid.allKeys.firstObject;
    NSArray *chains = groupedByBid[bid];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyMMddHHmmss"];
    NSString *safeBid = [bid stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *fileName = [NSString stringWithFormat:@"Batch_Ptrs_%@_%@.vmpt", safeBid, [df stringFromDate:[NSDate date]]];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    VMDataSession *session = [VMDataSession sessionWithData:chains bundleID:bid dataType:@"pointer"];
    NSData *data = [session toJSONDataForExport];
    if (data && [data writeToFile:tempPath atomically:YES]) {
      [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions : @(0666)} ofItemAtPath:tempPath error:nil];
      NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
      [VMShareHelper shareContent:fileURL fromViewController:self sourceView:self.navigationController.navigationBar sourceRect:CGRectMake(self.navigationController.navigationBar.bounds.size.width - 50, 0, 50, 44)];
      [self exitBatchMode];
    }
  } else {
    [self showToast:[NSString stringWithFormat:TR(@"Lock_Export_Multi_App"), groupedByBid.count]];
  }
}

#pragma mark - RVA Manager Delegate & Logic
- (void)didClickRVAEdit:(UITableViewCell *)cell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  NSArray *dataSrc = [self currentDisplayData];
  if (indexPath.row >= dataSrc.count) return;

  VMRVAPatch *patch = dataSrc[indexPath.row];
  if ([self ensureConnectionForBundleID:patch.bundleID] <= 0) return;

  [self showEditRVAAlert:patch];
}

- (void)didClickRVAToggle:(UITableViewCell *)cell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  NSArray *dataSrc = [self currentDisplayData];
  if (indexPath.row >= dataSrc.count)
    return;

  VMRVAPatch *patch = dataSrc[indexPath.row];

  if ([self ensureConnectionForBundleID:patch.bundleID] <= 0) {
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    return;
  }

  uint64_t modBase = [[VMMemoryEngine shared] findModuleBaseAddress:patch.moduleName];
  if (modBase == 0) {
    [self showToast:TR(@"Patch_Err_Module_Not_Found")];
    return;
  }

  uint64_t absAddr = modBase + patch.offset;
  NSString *patchHex = [self normalizeHex:patch.patchHex];
  NSString *origHex = [self normalizeHex:patch.originalHex];

  NSData *pData = [[VMMemoryEngine shared] dataFromHexString:patchHex];
  NSData *currentData = [[VMMemoryEngine shared] readRawMemory:absAddr length:pData.length];
  NSString *currentHex = [self normalizeHex:[[VMMemoryEngine shared] hexStringFromData:currentData]];

  if (!currentHex) {
    [self showToast:TR(@"Err_Read_Fail")];
    return;
  }

  BOOL targetState = !patch.isOn;
  NSString *targetHex = targetState ? patchHex : origHex;

  if (targetState) {
    if ([currentHex isEqualToString:patchHex]) {
      [self updatePatchState:patch isOn:YES];
      return;
    }
    if (![currentHex isEqualToString:origHex]) {
      [self showIntegrityAlert:patch current:currentHex target:targetHex addr:absAddr state:YES];
      return;
    }
  } else {
    if ([currentHex isEqualToString:origHex]) {
      [self updatePatchState:patch isOn:NO];
      return;
    }
    if (![currentHex isEqualToString:patchHex]) {
      [self showIntegrityAlert:patch current:currentHex target:targetHex addr:absAddr state:NO];
      return;
    }
  }

  [self performWritePatch:patch targetHex:targetHex address:absAddr newState:targetState];
}

- (NSString *)normalizeHex:(NSString *)hex {
  NSString *clean = [[hex stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
  clean = [clean stringByReplacingOccurrencesOfString:@"0X" withString:@""];
  return clean;
}

- (void)performWritePatch:(VMRVAPatch *)patch targetHex:(NSString *)hex address:(uint64_t)addr newState:(BOOL)isOn {
  NSData *data = [[VMMemoryEngine shared] dataFromHexString:hex];
  if (!data || data.length == 0) {
    [self showToast:TR(@"Patch_Hex_Err")];
    return;
  }

  mach_port_t task = [VMMemoryEngine shared].targetTask;
  mach_msg_type_number_t size = (mach_msg_type_number_t)data.length;
  vm_address_t targetAddr = (vm_address_t)addr;

  mach_vm_protect(task, targetAddr, size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
  kern_return_t kr_write = mach_vm_write(task, targetAddr, (vm_offset_t)data.bytes, size);
  mach_vm_protect(task, targetAddr, size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);

  BOOL writeSuccess = NO;
  if (kr_write == KERN_SUCCESS) {
    usleep(2000); 
    NSData *readBack = [[VMMemoryEngine shared] readRawMemory:addr
                                                       length:data.length];
    if (readBack && [readBack isEqualToData:data]) {
      writeSuccess = YES;
    }
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    if (writeSuccess) {
      patch.isOn = isOn;
      [[VMMemoryEngine shared] saveRVAPatches];
      [self showToast:isOn ? TR(@"Msg_Mod_Success") : TR(@"Msg_Saved")];
      UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
      [gen impactOccurred];
      [self.tableView reloadData];
    } else {
      if (kr_write != KERN_SUCCESS) {
        [self showToast:[NSString stringWithFormat:@"%@: %d", TR(@"Err_File_Write"), kr_write]];
      } else {
        [self showToast:TR(@"Err_Write_Protection")];
      }
      [self.tableView reloadData];
    }
  });
}

- (void)updatePatchState:(VMRVAPatch *)patch isOn:(BOOL)isOn {
  patch.isOn = isOn;
  [[VMMemoryEngine shared] saveRVAPatches];
  [self.tableView reloadData];
}

- (void)showIntegrityAlert:(VMRVAPatch *)patch current:(NSString *)curr target:(NSString *)tgt addr:(uint64_t)addr state:(BOOL)newState {
  NSString *msg = [NSString stringWithFormat:TR(@"RVA_Warn_Mismatch_Msg"), curr, patch.originalHex];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"RVA_Warn_Mismatch_Title") message:msg preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Force_Cont") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
    [self performWritePatch:patch targetHex:tgt address:addr newState:newState];
  }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showEditRVAAlert:(VMRVAPatch *)patch {
  [VMItemEditViewController presentInController:self model:patch onSave:^(VMRVAPatch *updated) {
    if (updated.fileName && updated.fileName.length > 0) {
      NSString *dir = [VMStoragePathHelper pathForSubdirectory:@"RVA"
                                                      bundleID:updated.bundleID
                                                        create:YES];
      NSString *path = [dir stringByAppendingPathComponent:updated.fileName];
      VMDataSession *s = [VMDataSession sessionWithData:@[updated] bundleID:updated.bundleID dataType:@"rva"];
      [[s toJSONData] writeToFile:path atomically:YES];
    } else {
      [[VMMemoryEngine shared] saveRVAPatches];
    }
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Saved")];
  }];
}

- (void)checkAndCleanupRVAFolder:(NSString *)bid {
  if (!bid) return;
  NSString *dir = [VMStoragePathHelper pathForSubdirectory:@"RVA"
                                                  bundleID:bid
                                                    create:NO];

  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
  NSArray *validFiles = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.vmrva'"]];

  if (validFiles.count == 0) {
    [fm removeItemAtPath:dir error:nil];
    if (self.currentTab == 3 && !self.isFolderMode && [self.targetBundleID isEqualToString:bid]) {
      [self backToFolderList];
    }
  }
}

- (void)checkAndCleanupSigFolder:(NSString *)bid {
  if (!bid) return;
  NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *dir = [[doc stringByAppendingPathComponent:@"VansonMod/SIG"] stringByAppendingPathComponent:bid];

  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
  NSArray *validFiles = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.vmsig'"]];

  if (validFiles.count == 0) {
    [fm removeItemAtPath:dir error:nil];
    if (self.currentTab == 4 && !self.isFolderMode && [self.targetBundleID isEqualToString:bid]) {
      [self backToFolderList];
    }
  }
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  if (textField.tag == 999) {
    if (textField.text.length > 0) {
      [[UIPasteboard generalPasteboard] setString:textField.text];
      UIColor *originalColor = textField.textColor;
      textField.textColor = [UIColor systemBlueColor];
      UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
      [gen impactOccurred];
      [self showToast:TR(@"Msg_Copied")];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            textField.textColor = originalColor;
          });
    }
    return NO;
  }
  return YES;
}

#pragma mark - 统一导出逻辑
#pragma mark - Smart Share Logic

- (void)shareSingleItemDirectly:(id)item
                     sourceView:(UIView *)view
                     sourceRect:(CGRect)rect {
  
  NSString *typeStr = @"pointer";
  if (self.currentTab == 3) typeStr = @"rva";
  else if (self.currentTab == 4) typeStr = @"signature";
  else if (self.currentTab == 6) typeStr = @"script";

  NSString *bundleID = [item valueForKey:@"bundleID"];
  if (!bundleID) bundleID = [[VMMemoryEngine shared] currentBundleID];
  if (!bundleID) bundleID = @"UnknownApp";

  NSString *ext = @"vmpt";
  if ([typeStr isEqualToString:@"rva"]) ext = @"vmrva";
  else if ([typeStr isEqualToString:@"signature"]) ext = @"vmsig";
  else if ([typeStr isEqualToString:@"script"]) ext = @"vmsc";

  NSString *baseName = [NSString stringWithFormat:@"VansonMod_%@_%@", bundleID, typeStr.uppercaseString];
  NSString *savePath = [VMShareHelper generateUniqueExportPathForName:baseName extension:ext];

  VMDataSession *session = [VMDataSession sessionWithData:@[item] bundleID:bundleID dataType:typeStr];
  NSData *data = [session toJSONDataForExport];

  if (data && [data writeToFile:savePath atomically:YES]) {
    [VMShareHelper shareContent:[NSURL fileURLWithPath:savePath] fromViewController:self sourceView:view sourceRect:rect];
  } else {
    [self showToast:TR(@"Err_Export_Write_Fail")];
  }
}

#pragma mark - Export Methods

- (void)exportDataItems:(NSArray *)items type:(NSString *)typeString {
  if (items.count == 0) return;

  NSString *bid = [[VMMemoryEngine shared] currentBundleID];
  if (!bid) {
    id first = items.firstObject;
    if ([first respondsToSelector:@selector(bundleID)]) {
      bid = [first performSelector:@selector(bundleID)];
    }
  }
  if (!bid) bid = @"UnknownApp";

  NSString *ext = @"vmpt";
  if ([typeString isEqualToString:@"rva"]) ext = @"vmrva";
  else if ([typeString isEqualToString:@"signature"]) ext = @"vmsig";
  else if ([typeString isEqualToString:@"script"]) ext = @"vmsc";

  NSString *baseName = [NSString stringWithFormat:@"VansonMod_%@_%@", bid, typeString.uppercaseString];
  NSString *savePath = [VMShareHelper generateUniqueExportPathForName:baseName extension:ext];

  VMDataSession *session = [VMDataSession sessionWithData:items bundleID:bid dataType:typeString];
  NSData *data = [session toJSONDataForExport];

  if ([data writeToFile:savePath atomically:YES]) {
    UIView *sourceView = self.navigationController.navigationBar;
    CGRect sourceRect = CGRectMake(sourceView.bounds.size.width - 50, 0, 50, 44);
    [VMShareHelper shareContent:[NSURL fileURLWithPath:savePath] fromViewController:self sourceView:sourceView sourceRect:sourceRect];
    if (self.tableView.isEditing) [self exitBatchMode];
  } else {
    [self showToast:TR(@"Err_Export_Write_Fail")];
  }
}

- (void)exportVerifierFiles:(NSArray *)fileNames {
  if (fileNames.count == 0) return;
  
  NSString *root = [[VMPointerManager shared] verifierFolder];
  NSString *appDir = [root stringByAppendingPathComponent:self.targetBundleID];
  
  NSMutableArray *fileURLs = [NSMutableArray array];
  for (NSString *fileName in fileNames) {
    NSString *fullPath = [appDir stringByAppendingPathComponent:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
      [fileURLs addObject:[NSURL fileURLWithPath:fullPath]];
    }
  }
  
  if (fileURLs.count == 0) {
    [self showToast:TR(@"Err_No_Files")];
    return;
  }
  
  UIView *sourceView = self.navigationController.navigationBar;
  CGRect sourceRect = CGRectMake(sourceView.bounds.size.width - 50, 0, 50, 44);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *topVC = self;
    while (topVC.presentedViewController) {
      topVC = topVC.presentedViewController;
    }
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
      
      UIDocumentPickerViewController *picker;
      if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:fileURLs asCopy:YES];
      } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithURLs:fileURLs inMode:UIDocumentPickerModeExportToService];
#pragma clang diagnostic pop
      }
      picker.modalPresentationStyle = UIModalPresentationFormSheet;
      [topVC presentViewController:picker animated:YES completion:nil];
    } else {
      
      UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:fileURLs applicationActivities:nil];
      avc.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypeAddToReadingList];
      avc.popoverPresentationController.sourceView = sourceView;
      avc.popoverPresentationController.sourceRect = sourceRect;
      [topVC presentViewController:avc animated:YES completion:nil];
    }
  });
  
  if (self.tableView.isEditing) [self exitBatchMode];
}

#pragma mark - Signature Methods (VMSignatureModel)

- (void)refreshSignatures {
  if (self.currentTab != 4) return;
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  NSArray<VMSignatureModel *> *sigs = [self.activeSignatures copy];
  if (sigs.count == 0) return;

  for (int i = 0; i < sigs.count; i++) {
    VMSignatureModel *sig = sigs[i];
    if (sig.isScanning) continue;

    sig.isScanning = YES;
    sig.scanError = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
      if (i < [self.tableView numberOfRowsInSection:0]) {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
      }
    });

    void (^finish)(NSArray *) = ^(NSArray *results) {
      sig.isScanning = NO;
      if (results.count > 0) {
        NSMutableArray *temp = [NSMutableArray array];
        for (VMScanResultItem *item in results) {
          uint64_t finalAddr = item.address + sig.offset;
          NSString *val = [engine readAddress:finalAddr type:VMDataTypeInt32];
          if (!val)
            val = @"--";

          [temp addObject:@{
            @"addr" : @(finalAddr),
            @"val" : val,
            @"note" : @"VansonMod"
          }];
        }
        sig.runtimeResults = temp;
        sig.scanError = nil;
      } else {
        sig.runtimeResults = @[];
        sig.scanError = TR(@"Sig_No_Match");
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger currentIndex = [self.activeSignatures indexOfObject:sig];
        if (currentIndex != NSNotFound && currentIndex < [self.tableView numberOfRowsInSection:0]) {
          NSIndexPath *idxPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
          NSArray *vis = [self.tableView indexPathsForVisibleRows];
          if ([vis containsObject:idxPath]) {
            [self.tableView reloadRowsAtIndexPaths:@[idxPath] withRowAnimation:UITableViewRowAnimationNone];
          }
        }
      });
    };

    if (sig.moduleName.length > 0) {
      [engine fastScanSignature:sig.signature inModule:sig.moduleName completion:finish];
    } else {
      [engine scanSignature:sig.signature rangeStart:0 rangeEnd:0 completion:finish];
    }
  }
}

- (void)showEditSignatureAlert:(VMSignatureModel *)sig {
  [VMItemEditViewController presentInController:self model:sig onSave:^(VMSignatureModel *updated) {
    [[VMLockManager shared] addSignatureToLock:updated];
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Saved")];
  }];
}

#pragma mark - VMSignatureLockCellDelegate Implementation

- (void)signatureCellDidTapVerify:(UITableViewCell *)cell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath || indexPath.row >= self.activeSignatures.count) return;

  VMSignatureModel *sig = (VMSignatureModel *)self.activeSignatures[indexPath.row];
  VMMemoryEngine *engine = [VMMemoryEngine shared];

  if ([cell respondsToSelector:NSSelectorFromString(@"setStatus:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [cell performSelector:NSSelectorFromString(@"setStatus:") withObject:@(1)];
#pragma clang diagnostic pop
  }

  void (^finish)(NSArray *) = ^(NSArray *results) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (results.count > 0) {
        NSMutableArray *temp = [NSMutableArray array];
        for (VMScanResultItem *item in results) {
          uint64_t finalAddr = item.address + sig.offset;
          NSString *val = [engine readAddress:finalAddr type:VMDataTypeInt32];
          [temp addObject:@{@"addr": @(finalAddr), @"val": val ?: @"??", @"note": @"VansonMod"}];
        }
        sig.runtimeResults = temp;
        sig.scanError = nil;
      } else {
        sig.runtimeResults = @[];
        sig.scanError = TR(@"Sig_No_Match");
      }
      [self saveSignatureRuntimeCache:sig];

      NSInteger idx = [self.activeSignatures indexOfObject:sig];
      if (idx != NSNotFound) {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
      }
    });
  };

  if (sig.moduleName && sig.moduleName.length > 0) {
    [engine fastScanSignature:sig.signature inModule:sig.moduleName completion:finish];
  } else {
    [engine scanSignature:sig.signature rangeStart:0 rangeEnd:0 completion:finish];
  }
}

- (void)didClickResultMore:(UITableViewCell *)cell atIndex:(NSInteger)index {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath || indexPath.row >= self.activeSignatures.count) return;

  VMSignatureModel *sig = (VMSignatureModel *)self.activeSignatures[indexPath.row];
  if (index >= sig.runtimeResults.count) return;

  NSDictionary *rawDict = sig.runtimeResults[index];
  NSMutableDictionary *itemDict = [rawDict isKindOfClass:[NSMutableDictionary class]] ? (NSMutableDictionary *)rawDict : [rawDict mutableCopy];

  uint64_t addr = [itemDict[@"addr"] unsignedLongLongValue];
  NSString *val = itemDict[@"val"];
  CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];

  UIAlertController *menu = [UIAlertController alertControllerWithTitle:TR(@"Common_More") message:[NSString stringWithFormat:@"0x%llX", addr] preferredStyle:UIAlertControllerStyleActionSheet];

  [menu addAction:[UIAlertAction actionWithTitle:TR(@"Menu_MemoryTools") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [VMMemoryActionSheet showActionSheetForAddress:addr value:val dataType:VMDataTypeInt32 fromViewController:self sourceView:self.tableView sourceRect:rect extraItem:itemDict];
  }]];

  [menu addAction:[UIAlertAction actionWithTitle:TR(@"Result_Edit_UI_Mode") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self showEditResultConfigAlert:sig address:addr index:index];
  }]];

  [menu addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  menu.popoverPresentationController.sourceView = self.tableView;
  menu.popoverPresentationController.sourceRect = rect;

  [self presentViewController:menu animated:YES completion:nil];
}

- (void)showEditResultConfigAlert:(VMSignatureModel *)sig address:(uint64_t)addr index:(NSInteger)index {
  if (!sig.resultConfig) {
    sig.resultConfig = [NSMutableDictionary dictionary];
  }

  NSDictionary *config = sig.resultConfig[@(addr)] ?: @{@"type" : @"card"};
  BOOL isSlider = [config[@"type"] isEqualToString:@"slider"];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Result_Config_UI_Title") message:[NSString stringWithFormat:@"0x%llX", addr] preferredStyle:UIAlertControllerStyleAlert];

  if (isSlider) {
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
      tf.placeholder = TR(@"Slider_Min_Placeholder");
      tf.text = [NSString stringWithFormat:@"%@", config[@"min"] ?: @"0"];
      tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
      tf.placeholder = TR(@"Slider_Max_Placeholder");
      tf.text = [NSString stringWithFormat:@"%@", config[@"max"] ?: @"100"];
      tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
  }

  [alert addAction:[UIAlertAction actionWithTitle:isSlider ? TR(@"Result_Switch_Card") : TR(@"Result_Switch_Slider") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    NSMutableDictionary *newConfig = [config mutableCopy];
    if (isSlider) {
      newConfig[@"type"] = @"card";
    } else {
      newConfig[@"type"] = @"slider";
      newConfig[@"min"] = @0;
      newConfig[@"max"] = @100;
    }
    sig.resultConfig[@(addr)] = newConfig;
    [self showEditResultConfigAlert:sig address:addr index:index];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    if (isSlider) {
      NSMutableDictionary *newConfig = [config mutableCopy];
      newConfig[@"min"] = @([alert.textFields[0].text floatValue]);
      newConfig[@"max"] = @([alert.textFields[1].text floatValue]);
      sig.resultConfig[@(addr)] = newConfig;
    }
    [self.tableView reloadData];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    alert.popoverPresentationController.sourceView = self.tableView;
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    alert.popoverPresentationController.sourceRect = cellRect;
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)didClickResultMore:(UITableViewCell *)cell atAddress:(uint64_t)address currentType:(VMDataType)type {
  NSIndexPath *ip = [self.tableView indexPathForCell:cell];
  NSString *val = [[VMMemoryEngine shared] readAddress:address type:type];
  CGRect rect = [self.tableView rectForRowAtIndexPath:ip];
  [VMMemoryActionSheet showActionSheetForAddress:address value:val dataType:type fromViewController:self sourceView:self.tableView sourceRect:rect extraItem:nil];
}

- (void)didClickResultValue:(UITableViewCell *)cell atIndex:(NSInteger)index address:(uint64_t)addr currentValue:(NSString *)val {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Edit_Val") message:[NSString stringWithFormat:@"0x%llX", addr] preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = val;
    tf.keyboardType = UIKeyboardTypeDecimalPad;
  }];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *newVal = alert.textFields.firstObject.text;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    VMDataType type = VMDataTypeInt32; 
    if (indexPath && indexPath.row < self.activeSignatures.count) {
      VMSignatureModel *sig = self.activeSignatures[indexPath.row];
      type = (VMDataType)sig.lockType;
      
      if (index < sig.runtimeResults.count) {
        NSMutableDictionary *item = [sig.runtimeResults[index] mutableCopy];
        item[@"val"] = newVal;
        NSMutableArray *results = [sig.runtimeResults mutableCopy];
        results[index] = item;
        sig.runtimeResults = results;
        [self saveSignatureRuntimeCache:sig];
      }
    }
    
    [[VMMemoryEngine shared] writeAddress:addr value:newVal type:type];
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Mod_Success")];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)didChangeModeSegment:(UITableViewCell *)cell atIndex:(NSInteger)index isSlider:(BOOL)isSlider isSwitch:(BOOL)isSwitch {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath || indexPath.row >= self.activeSignatures.count) return;

  VMSignatureModel *sig = self.activeSignatures[indexPath.row];
  if (index >= sig.runtimeResults.count) return;

  NSDictionary *rawDict = sig.runtimeResults[index];
  uint64_t addr = [rawDict[@"addr"] unsignedLongLongValue];

  if (!sig.resultConfig) {
    sig.resultConfig = [NSMutableDictionary dictionary];
  }

  if (isSlider) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Mode_Switch_Slider") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
      tf.placeholder = TR(@"Slider_Min_Placeholder");
      tf.text = @"0";
      tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
      tf.placeholder = TR(@"Slider_Max_Placeholder");
      tf.text = @"100";
      tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      float min = [alert.textFields[0].text floatValue];
      float max = [alert.textFields[1].text floatValue];
      if (min >= max) {
        [self showToast:TR(@"Slider_Err_Min_Less_Max")];
        return;
      }
      sig.resultConfig[@(addr)] = @{@"type": @"slider", @"min": @(min), @"max": @(max)};
      [self saveSignatureRuntimeCache:sig];
      [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
      [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
  } else if (isSwitch) {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Toggle_Config_Title") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
      tf.placeholder = TR(@"Toggle_On_Value");
      tf.text = @"1";
      tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
      tf.placeholder = TR(@"Toggle_Off_Value");
      tf.text = @"0";
      tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      NSString *onVal = alert.textFields[0].text ?: @"1";
      NSString *offVal = alert.textFields[1].text ?: @"0";
      sig.resultConfig[@(addr)] = @{@"type": @"switch", @"switchOnValue": onVal, @"switchOffValue": offVal};
      [self saveSignatureRuntimeCache:sig];
      [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
      [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
  } else {
    sig.resultConfig[@(addr)] = @{@"type": @"card"};
    [self saveSignatureRuntimeCache:sig];
    [self.tableView reloadData];
  }
}

- (void)didChangeResultSliderValue:(UITableViewCell *)cell atIndex:(NSInteger)index value:(NSString *)value {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath || indexPath.row >= self.activeSignatures.count) return;

  VMSignatureModel *sig = (VMSignatureModel *)self.activeSignatures[indexPath.row];
  if (index >= sig.runtimeResults.count) return;

  NSDictionary *rawDict = sig.runtimeResults[index];
  uint64_t addr = [rawDict[@"addr"] unsignedLongLongValue];

  VMDataType type = (VMDataType)sig.lockType;
  [[VMMemoryEngine shared] writeAddress:addr value:value type:type];
  
  NSMutableDictionary *item = [rawDict mutableCopy];
  item[@"val"] = value;
  NSMutableArray *results = [sig.runtimeResults mutableCopy];
  results[index] = item;
  sig.runtimeResults = results;
  [self saveSignatureRuntimeCache:sig];
  
  [self showToast:TR(@"Common_Update_Success")];
}

- (void)didChangeResultSwitchState:(UITableViewCell *)cell atIndex:(NSInteger)index isOn:(BOOL)isOn {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
  if (!indexPath || indexPath.row >= self.activeSignatures.count) return;

  VMSignatureModel *sig = (VMSignatureModel *)self.activeSignatures[indexPath.row];
  if (index >= sig.runtimeResults.count) return;

  NSDictionary *rawDict = sig.runtimeResults[index];
  uint64_t addr = [rawDict[@"addr"] unsignedLongLongValue];
  
  NSDictionary *config = sig.resultConfig[@(addr)];
  NSString *switchOnValue = config[@"switchOnValue"] ?: @"1";
  NSString *switchOffValue = config[@"switchOffValue"] ?: @"0";
  
  NSString *value = isOn ? switchOnValue : switchOffValue;

  VMDataType type = (VMDataType)sig.lockType;
  [[VMMemoryEngine shared] writeAddress:addr value:value type:type];
  
  NSMutableDictionary *item = [rawDict mutableCopy];
  item[@"val"] = value;
  NSMutableArray *results = [sig.runtimeResults mutableCopy];
  results[index] = item;
  sig.runtimeResults = results;
  [self saveSignatureRuntimeCache:sig];
  
  [self showToast:TR(@"Common_Update_Success")];
}

#pragma mark - Tab CollectionView Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  if (collectionView == self.tabCollectionView) {
    return self.tabItems.count;
  }
  return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  
  if (collectionView == self.tabCollectionView) {
    VMTabMenuCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"TabCell"
                                                  forIndexPath:indexPath];
    cell.titleLabel.text = self.tabItems[indexPath.item];

    BOOL isSelected = (indexPath.item == self.currentTab);
    [cell setSelected:isSelected];

    return cell;
  }
  return [UICollectionViewCell new];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                    layout:(UICollectionViewLayout *)collectionViewLayout
    sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  if (collectionView == self.tabCollectionView) {
    NSString *text = self.tabItems[indexPath.item];
    CGSize size = [text sizeWithAttributes:@{NSFontAttributeName: [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightSemibold]}];
    return CGSizeMake(MAX(76, size.width + 32), 44);
  }
  return CGSizeZero;
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (collectionView == self.tabCollectionView) {
    if (self.currentTab == indexPath.item) return;
    if (self.tableView.isEditing) [self exitBatchMode];
    self.currentTab = indexPath.item;
    self.defaultTabIndex = 0;
    [self tabChanged];
    [collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
  }
}

- (void)showRenameAlertForItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
  NSString *currentFileName = nil;
  NSString *bundleID = nil;

  if (self.currentTab == 5) {
    
    currentFileName = (NSString *)item;
    
    bundleID = self.targetBundleID;
  } else {
    
    currentFileName = [item valueForKey:@"fileName"];
    bundleID = [item valueForKey:@"bundleID"];
  }

  if (!currentFileName || currentFileName.length == 0) {
    [self showToast:TR(@"Err_File_Not_Found")];
    return;
  }

  NSString *fileExt = [currentFileName pathExtension];
  NSString *nameNoExt = [currentFileName stringByDeletingPathExtension];

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Common_Rename") message:nil preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = nameNoExt;
    tf.placeholder = TR(@"Rename_New_File_Name");
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *newName = alert.textFields.firstObject.text;
    if (newName.length > 0 && ![newName isEqualToString:nameNoExt]) {
      [self performRename:item oldName:currentFileName newName:newName extension:fileExt bundleID:bundleID indexPath:indexPath];
    }
  }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)performRename:(id)item
              oldName:(NSString *)oldName
              newName:(NSString *)newName
            extension:(NSString *)ext
             bundleID:(NSString *)bid
            indexPath:(NSIndexPath *)indexPath {
  
  NSString *subDir = @"";
  if (self.currentTab == 2)
    subDir = @"PTR";
  else if (self.currentTab == 3)
    subDir = @"RVA";
  else if (self.currentTab == 4)
    subDir = @"SIG";
  else if (self.currentTab == 5)
    subDir = @"ValidatePtr"; 
  else if (self.currentTab == 6)
    subDir = @"Script"; 

  NSString *doc = [NSSearchPathForDirectoriesInDomains(
      NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *dirPath = [[doc stringByAppendingPathComponent:@"VansonMod"]
      stringByAppendingPathComponent:subDir];
  if (bid && bid.length > 0) {
    dirPath = [dirPath stringByAppendingPathComponent:bid];
  }

  NSString *oldPath = [dirPath stringByAppendingPathComponent:oldName];
  NSString *newFileName = [NSString stringWithFormat:@"%@.%@", newName, ext];
  NSString *newPath = [dirPath stringByAppendingPathComponent:newFileName];

  NSFileManager *fm = [NSFileManager defaultManager];

  if (![fm fileExistsAtPath:oldPath]) {
    [self showToast:TR(@"Err_File_Read")];
    return;
  }

  if ([fm fileExistsAtPath:newPath]) {
    [self showToast:TR(@"Err_File_Exists")];
    return;
  }

  NSError *error;
  if ([fm moveItemAtPath:oldPath toPath:newPath error:&error]) {
    
    if (self.currentTab != 5) {
      
      [item setValue:newFileName forKey:@"fileName"];

      if ([item respondsToSelector:@selector(setNote:)]) {
        [item setValue:newName forKey:@"note"];
      }

      if (self.currentTab == 2) {
        [[VMLockManager shared]
            addPointerToLock:item]; 
      } else if (self.currentTab == 3) {
        [[VMMemoryEngine shared] saveRVAPatches];
      } else if (self.currentTab == 4) {
        [[VMLockManager shared] addSignatureToLock:item];
      } else if (self.currentTab == 6) {
        [self saveScriptModel:item];
      }
    }

    if (self.currentTab == 5) {
      [self.tableView reloadData];
    } else {
      [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }

    [self showToast:TR(@"Msg_Saved")];

    if (self.currentTab == 3) {
      [[VMMemoryEngine shared] saveRVAPatches];
    }
  } else {
    [self showToast:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
  }
}

- (void)showEditScriptInfoAlert:(VMScriptModel *)model {
  [VMItemEditViewController presentInController:self model:model onSave:^(VMScriptModel *updated) {
    [self saveScriptModel:updated];
    [self.tableView reloadData];
    [self showToast:TR(@"Msg_Saved")];
  }];
}

- (void)showPointerActions:(VMPointerChain *)chain {
  NSString *title = chain.note;
  NSString *message = [chain displayString];

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Title_Edit_Ptr_Info") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self showEditChainInfoAlert:chain];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_View_Memory") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    uint64_t finalAddr = [self forceResolveChain:chain];
    if (finalAddr > 0) {
      VMMemoryBrowserViewController *browser = [VMMemoryBrowserViewController new];
      browser.address = finalAddr;
      browser.type = (VMDataType)chain.lockType;
      [self.navigationController pushViewController:browser animated:YES];
    }
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_View_Hex") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    uint64_t finalAddr = [self forceResolveChain:chain];
    if (finalAddr > 0) {
      VMHexEditorViewController *hex = [VMHexEditorViewController new];
      hex.address = finalAddr;
      [self.navigationController pushViewController:hex animated:YES];
    }
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Pop_Copy_Addr") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    uint64_t finalAddr = [self forceResolveChain:chain];
    if (finalAddr > 0) {
      [[UIPasteboard generalPasteboard] setString:[NSString stringWithFormat:@"0x%llX", finalAddr]];
      [self showToast:TR(@"Msg_Addr_Copied")];
    }
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Ptr_Action_Copy_Offset") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self showCopyOffsetAlert:chain];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Export") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    [self shareSingleItemDirectly:chain sourceView:self.view sourceRect:CGRectZero];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
    [[VMLockManager shared] removePointer:chain];
    [self.tableView reloadData];
  }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)onJumpToTabNotification:(NSNotification *)note {
  NSDictionary *info = note.userInfo;
  NSInteger targetTab = [info[@"targetTab"] ?: info[@"tab"] integerValue];
  NSString *bid = info[@"bundleID"];
  NSString *fileName = info[@"fileName"];
  NSString *toast = info[@"toast"];

  if (!self.isViewLoaded || !self.view.window) {
    self.pendingJumpInfo = info;
    return;
  }

  if (targetTab >= 0 && targetTab < self.tabItems.count) {
    [self jumpToTabAndRefresh:targetTab bundleID:bid fileName:fileName toast:toast];
  }
}

- (void)scanAndProcessImports {
}

#pragma mark - Drag & Drop Reorder

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    
    if (self.isFolderMode) return @[];
    if (self.currentTab < 2 || self.currentTab == 5) return @[];
    
    NSArray *dataSrc = [self currentDisplayData];
    if (indexPath.row >= (NSInteger)dataSrc.count) return @[];
    
    id item = dataSrc[indexPath.row];
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:@""];
    UIDragItem *dragItem = [[UIDragItem alloc] initWithItemProvider:provider];
    dragItem.localObject = item;
    return @[dragItem];
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    if (self.isFolderMode) return;
    if (self.currentTab < 2 || self.currentTab == 5) return;
    
    NSIndexPath *destIndexPath = coordinator.destinationIndexPath;
    if (!destIndexPath) return;
    
    NSMutableArray *dataSrc = [[self currentDisplayData] mutableCopy];
    
    if (!dataSrc || dataSrc.count == 0) return;
    
    for (id<UITableViewDropItem> dropItem in coordinator.items) {
        id draggedItem = dropItem.dragItem.localObject;
        if (!draggedItem) continue;
        
        NSInteger sourceIdx = NSNotFound;
        for (NSInteger i = 0; i < (NSInteger)dataSrc.count; i++) {
            id obj = dataSrc[i];
            if (self.currentTab == 2) {
                NSString *dragId = [draggedItem valueForKey:@"uniqueId"];
                NSString *objId = [obj valueForKey:@"uniqueId"];
                if (dragId && objId && [dragId isEqualToString:objId]) { sourceIdx = i; break; }
            } else if (self.currentTab == 4) {
                NSString *dragSig = [draggedItem valueForKey:@"signature"];
                NSString *objSig = [obj valueForKey:@"signature"];
                if (dragSig && objSig && [dragSig isEqualToString:objSig]) { sourceIdx = i; break; }
            } else {
                if (obj == draggedItem) { sourceIdx = i; break; }
            }
        }
        if (sourceIdx == NSNotFound) continue;
        
        NSInteger destIdx = destIndexPath.row;
        if (destIdx > (NSInteger)dataSrc.count) destIdx = dataSrc.count;
        if (destIdx == sourceIdx) continue;
        
        id movedItem = dataSrc[sourceIdx];
        [dataSrc removeObjectAtIndex:sourceIdx];
        
        NSInteger insertIdx;
        if (destIdx > sourceIdx) {
            insertIdx = destIdx - 1;
            
            if (insertIdx <= sourceIdx) {
                insertIdx = sourceIdx + 1;
                if (insertIdx > (NSInteger)dataSrc.count) insertIdx = dataSrc.count;
            }
        } else {
            insertIdx = destIdx;
        }
        if (insertIdx > (NSInteger)dataSrc.count) insertIdx = dataSrc.count;
        if (insertIdx < 0) insertIdx = 0;
        [dataSrc insertObject:movedItem atIndex:insertIdx];
        
        [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:[NSIndexPath indexPathForRow:insertIdx inSection:0]];
    }
    
    double baseTime = [[NSDate date] timeIntervalSince1970];
    for (NSInteger i = 0; i < (NSInteger)dataSrc.count; i++) {
        double newOrder = baseTime + (double)(dataSrc.count - i);
        [dataSrc[i] setValue:@(newOrder) forKey:@"sortOrder"];
    }
    
    if (self.currentTab == 2 || self.currentTab == 4) {
        
        std::string bid = [self.targetBundleID UTF8String];
        auto allItems = VMCore::LockCore::shared().getLocks(bid);
        
        NSMutableDictionary *updatedOrders = [NSMutableDictionary dictionary];
        for (id obj in dataSrc) {
            double newSort = [[obj valueForKey:@"sortOrder"] doubleValue];
            if (self.currentTab == 2) {
                NSString *uid = [obj valueForKey:@"uniqueId"];
                if (uid) updatedOrders[uid] = @(newSort);
            } else {
                NSString *sig = [obj valueForKey:@"signature"];
                if (sig) updatedOrders[sig] = @(newSort);
            }
        }
        
        for (auto &item : allItems) {
            if (self.currentTab == 2 && !item.isSignatureMode) {
                NSString *uid = [NSString stringWithUTF8String:item.uniqueId.c_str()];
                NSNumber *newVal = updatedOrders[uid];
                if (newVal) item.sortOrder = [newVal doubleValue];
            } else if (self.currentTab == 4 && item.isSignatureMode) {
                NSString *sig = [NSString stringWithUTF8String:item.signature.c_str()];
                NSNumber *newVal = updatedOrders[sig];
                if (newVal) item.sortOrder = [newVal doubleValue];
            }
        }
        
        VMCore::LockCore::shared().saveLocks(bid, allItems);
    } else if (self.currentTab == 3) {
        [[VMMemoryEngine shared] saveRVAPatches];
    } else if (self.currentTab == 6) {
        for (VMScriptModel *m in dataSrc) {
            [self saveScriptModel:m];
        }
    }
    
    [self.tableView reloadData];
}

@end
