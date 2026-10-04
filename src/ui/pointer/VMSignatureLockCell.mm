#import "../../utils/helpers/VMUIHelper.h"
#import "VMSignatureLockCell.h"
#import "include/VMLocalization.h"
#import "include/VMSignatureModel.h" // 使用新模型
#import <objc/runtime.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])
#define kCardCornerRadius 16.0

@interface VMSignatureLockCell ()
@property(nonatomic, strong) UIView *cardContainer;
@property(nonatomic, strong) UIColor *cardBorderColor;
@property(nonatomic, strong) UIView *statusIndicator;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *authorLabel;
@property(nonatomic, strong) UILabel *moduleLabel;
@property(nonatomic, strong) UILabel *sigCodeLabel;
@property(nonatomic, strong) UIView *separatorLine;
@property(nonatomic, strong) UIStackView *resultsStack;
@property(nonatomic, strong) UIButton *btnEdit;
@property(nonatomic, strong) UIButton *btnScan;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation VMSignatureLockCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    [self setupUI];
  }
  return self;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [super setEditing:editing animated:animated];
  self.selectionStyle = editing ? UITableViewCellSelectionStyleDefault
                                : UITableViewCellSelectionStyleNone;
}

- (void)setCardBorderColor:(UIColor *)color {
  _cardBorderColor = color;
  self.cardContainer.layer.borderColor = [color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    self.cardBorderColor = self.cardBorderColor ?: UIColor.clearColor;
  }
}

- (void)setupUI {
  _cardContainer = [[UIView alloc] init];
  _cardContainer.backgroundColor =
      [UIColor secondarySystemGroupedBackgroundColor];
  [VMUIHelper styleCard:_cardContainer];
  _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_cardContainer];

  _titleLabel = [self createLabelFont:15
                               weight:UIFontWeightBold
                                color:[UIColor labelColor]];
  [_cardContainer addSubview:_titleLabel];

  _authorLabel = [self createLabelFont:13
                                weight:UIFontWeightMedium
                                 color:[UIColor secondaryLabelColor]];
  _authorLabel.textAlignment = NSTextAlignmentNatural;
  [_cardContainer addSubview:_authorLabel];

  _statusIndicator = [[UIView alloc] init];
  _statusIndicator.backgroundColor = [UIColor systemGray4Color];
  _statusIndicator.layer.cornerRadius = 4;
  _statusIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_statusIndicator];

  _moduleLabel = [self createLabelFont:11
                                weight:UIFontWeightRegular
                                 color:[UIColor secondaryLabelColor]];
  [_cardContainer addSubview:_moduleLabel];

  _sigCodeLabel = [self createLabelFont:11
                                 weight:UIFontWeightRegular
                                  color:[UIColor systemIndigoColor]];
  _sigCodeLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]];
  _sigCodeLabel.numberOfLines = 0;
  _sigCodeLabel.adjustsFontForContentSizeCategory = YES;
  [_cardContainer addSubview:_sigCodeLabel];

  _separatorLine = [[UIView alloc] init];
  _separatorLine.backgroundColor = [UIColor separatorColor];
  _separatorLine.alpha = 0.5;
  _separatorLine.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_separatorLine];

  _resultsStack = [[UIStackView alloc] init];
  _resultsStack.axis = UILayoutConstraintAxisVertical;
  _resultsStack.spacing = 8; 
  _resultsStack.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_resultsStack];

  UIStackView *btnStack = [[UIStackView alloc] init];
  btnStack.axis = UILayoutConstraintAxisHorizontal;
  btnStack.spacing = 10;
  btnStack.distribution = UIStackViewDistributionFillEqually;
  btnStack.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:btnStack];

  _btnEdit = [self createButton:TR(@"Common_Edit")
                          color:[UIColor systemGrayColor]];
  [_btnEdit addTarget:self
                action:@selector(onEditTap)
      forControlEvents:UIControlEventTouchUpInside];

  _btnScan = [self createButton:TR(@"Sig_Btn_Verify")
                          color:[VMUIHelper accentColor]];
  [_btnScan addTarget:self
                action:@selector(onScanTap)
      forControlEvents:UIControlEventTouchUpInside];

  _spinner = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  _spinner.translatesAutoresizingMaskIntoConstraints = NO;
  [_btnScan addSubview:_spinner];
  [_spinner.centerXAnchor constraintEqualToAnchor:_btnScan.centerXAnchor]
      .active = YES;
  [_spinner.centerYAnchor constraintEqualToAnchor:_btnScan.centerYAnchor]
      .active = YES;

  [btnStack addArrangedSubview:_btnEdit];
  [btnStack addArrangedSubview:_btnScan];

  CGFloat p = 16.0;
  [NSLayoutConstraint activateConstraints:@[
    [_cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor
                                             constant:6],
    [_cardContainer.bottomAnchor
        constraintEqualToAnchor:self.contentView.bottomAnchor
                       constant:-6],
    [_cardContainer.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor
                       constant:0],
    [_cardContainer.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:0],

    [_titleLabel.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor
                                          constant:p],
    [_titleLabel.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_titleLabel.trailingAnchor
        constraintLessThanOrEqualToAnchor:_statusIndicator.leadingAnchor
                                 constant:-8],

    [_authorLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
    [_authorLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
    [_authorLabel.trailingAnchor
        constraintEqualToAnchor:_statusIndicator.leadingAnchor
                       constant:-8],

    [_statusIndicator.centerYAnchor
        constraintEqualToAnchor:_titleLabel.centerYAnchor],
    [_statusIndicator.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],
    [_statusIndicator.widthAnchor constraintEqualToConstant:8],
    [_statusIndicator.heightAnchor constraintEqualToConstant:8],

    [_moduleLabel.topAnchor constraintEqualToAnchor:_authorLabel.bottomAnchor
                                           constant:4],
    [_moduleLabel.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_moduleLabel.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],

    [_sigCodeLabel.topAnchor constraintEqualToAnchor:_moduleLabel.bottomAnchor
                                            constant:6],
    [_sigCodeLabel.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_sigCodeLabel.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],

    [_separatorLine.topAnchor constraintEqualToAnchor:_sigCodeLabel.bottomAnchor
                                             constant:10],
    [_separatorLine.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_separatorLine.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],
    [_separatorLine.heightAnchor constraintEqualToConstant:0.5],

    [_resultsStack.topAnchor constraintEqualToAnchor:_separatorLine.bottomAnchor
                                            constant:10],
    [_resultsStack.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_resultsStack.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],

    [btnStack.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor
                                           constant:p],
    [btnStack.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],
    [btnStack.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    [btnStack.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor
                                          constant:-p]
  ]];

  [btnStack.topAnchor
      constraintGreaterThanOrEqualToAnchor:_resultsStack.bottomAnchor
                                  constant:16]
      .active = YES;
}

- (void)configureWithSignature:(VMSignatureModel *)sig {
  self.currentSig = sig;

  _titleLabel.text = sig.note ?: TR(@"Sig_Default_Title");
  _authorLabel.text =
      [NSString stringWithFormat:@"@%@", sig.author ?: @"VansonMod"];
  _moduleLabel.text =
      (sig.moduleName.length > 0)
          ? [NSString
                stringWithFormat:TR(@"Sig_Label_Module"), sig.moduleName]
          : TR(@"Sig_Global_Search");
  _sigCodeLabel.text =
      [NSString stringWithFormat:TR(@"Sig_Label_Code"), sig.signature];

  _btnEdit.enabled = YES;
  _btnEdit.alpha = 1.0;

  if (sig.isImported) {
    
    _titleLabel.text =
        [NSString stringWithFormat:@"%@", sig.note ?: TR(@"Sig_Default_Title")];

    _cardContainer.layer.borderWidth = 1.0;
    self.cardBorderColor = UIColor.systemGray4Color;
  } else {
    
    _cardContainer.layer.borderWidth = 0;
  }

  for (UIView *v in _resultsStack.arrangedSubviews)
    [v removeFromSuperview];

  if (sig.isScanning) {
    [_spinner startAnimating];
    [_btnScan setTitle:@"" forState:UIControlStateNormal];
    _statusIndicator.backgroundColor = [VMUIHelper accentColor];

    UILabel *loading = [self createLabelFont:12
                                      weight:UIFontWeightMedium
                                       color:[VMUIHelper accentColor]];
    loading.text = TR(@"Sig_Status_Scanning");
    loading.textAlignment = NSTextAlignmentCenter;
    [_resultsStack addArrangedSubview:loading];

  } else {
    [_spinner stopAnimating];
    [_btnScan setTitle:TR(@"Sig_Btn_Verify") forState:UIControlStateNormal];

    if (sig.runtimeResults.count > 0) {
      _statusIndicator.backgroundColor = [UIColor systemGreenColor];

      NSInteger maxDisplay = 5;
      NSInteger total = sig.runtimeResults.count;

      for (int i = 0; i < total; i++) {
        if (i >= maxDisplay) {
          UILabel *moreLabel =
              [self createLabelFont:11
                             weight:UIFontWeightBold
                              color:[UIColor secondaryLabelColor]];
          moreLabel.text =
              [NSString stringWithFormat:@"... %@ %ld", TR(@"Ptr_Auto_More"),
                                         (long)(total - maxDisplay)];
          moreLabel.textAlignment = NSTextAlignmentCenter;
          [_resultsStack addArrangedSubview:moreLabel];
          break;
        }

        @try {
          NSDictionary *res = sig.runtimeResults[i];
          
          if (![res isKindOfClass:[NSDictionary class]])
            continue;

          NSString *note = res[@"note"] ?: @"VansonMod";
          NSNumber *addrNum = res[@"addr"];
          uint64_t addr =
              [addrNum respondsToSelector:@selector(unsignedLongLongValue)]
                  ? [addrNum unsignedLongLongValue]
                  : 0;
          NSString *val = res[@"val"] ?: @"--";

          NSDictionary *config = sig.resultConfig[@(addr)];

          UIView *row = [self createResultRowWithNote:note addr:addr val:val index:i config:config maskAddress:NO];
          [_resultsStack addArrangedSubview:row];
        } @catch (NSException *e) {
          
        }
      }
    } else {
      
      if (sig.scanError) {
        _statusIndicator.backgroundColor = [UIColor systemRedColor];
        UILabel *err = [self createLabelFont:12
                                      weight:UIFontWeightMedium
                                       color:[UIColor systemRedColor]];
        err.text = sig.scanError;
        err.textAlignment = NSTextAlignmentCenter;
        [_resultsStack addArrangedSubview:err];
      } else {
        _statusIndicator.backgroundColor = [UIColor systemGray4Color];
        UILabel *idle = [self createLabelFont:12
                                       weight:UIFontWeightMedium
                                        color:[UIColor secondaryLabelColor]];
        idle.text = TR(@"Sig_Status_Waiting");
        idle.textAlignment = NSTextAlignmentCenter;
        [_resultsStack addArrangedSubview:idle];
      }
    }
  }
}

- (UIView *)createResultRowWithNote:(NSString *)note
                               addr:(uint64_t)addr
                                val:(NSString *)val
                              index:(NSInteger)idx
                             config:(NSDictionary *)config
                        maskAddress:(BOOL)maskAddr {
  UIView *row = [UIView new];
  row.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
  row.layer.cornerRadius = 12;
  row.layer.cornerCurve = kCACornerCurveContinuous;
  row.tag = idx;
  BOOL isSlider = [config[@"type"] isEqualToString:@"slider"];
  BOOL isSwitch = [config[@"type"] isEqualToString:@"switch"];
  UIStackView *content = [UIStackView new];
  content.axis = UILayoutConstraintAxisVertical;
  content.spacing = 10;
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [row addSubview:content];
  UIStackView *top = [UIStackView new];
  top.axis = UILayoutConstraintAxisHorizontal;
  top.spacing = 8;
  top.alignment = UIStackViewAlignmentCenter;
  UILabel *address = [self createLabelFont:12 weight:UIFontWeightRegular color:[UIColor secondaryLabelColor]];
  address.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  address.text = maskAddr ? @"0x********" : [NSString stringWithFormat:@"0x%llX", addr];
  address.numberOfLines = 0;
  address.lineBreakMode = NSLineBreakByCharWrapping;
  [top addArrangedSubview:address];
  UIButton *value = [UIButton buttonWithType:UIButtonTypeSystem];
  [value setTitle:val forState:UIControlStateNormal];
  value.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:value primary:NO];
  value.accessibilityLabel = [NSString stringWithFormat:@"%@ · %@", note.length ? note : TR(@"Lock_Label_Value"), address.text];
  value.accessibilityValue = val;
  value.tag = idx;
  [value.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [value addTarget:self action:@selector(onValueTap:) forControlEvents:UIControlEventTouchUpInside];
  objc_setAssociatedObject(value, "addr", @(addr), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [top addArrangedSubview:value];
  [content addArrangedSubview:top];
  UISegmentedControl *mode = [[UISegmentedControl alloc] initWithItems:@[TR(@"Mode_Switch_Card"), TR(@"Mode_Switch_Slider"), TR(@"Mode_Switch_Toggle")]];
  mode.selectedSegmentIndex = isSlider ? 1 : isSwitch ? 2 : 0;
  mode.accessibilityLabel = TR(@"Display_Mode");
  mode.tag = idx;
  [mode.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [mode addTarget:self action:@selector(onModeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
  [content addArrangedSubview:mode];
  if (isSlider) {
    float minimum = [config[@"min"] floatValue];
    float maximum = [config[@"max"] floatValue];
    if (minimum >= maximum) { minimum = 0; maximum = 100; }
    UIStackView *sliderRow = [UIStackView new];
    sliderRow.axis = UILayoutConstraintAxisHorizontal;
    sliderRow.spacing = 8;
    sliderRow.alignment = UIStackViewAlignmentCenter;
    UILabel *min = [self createLabelFont:12 weight:UIFontWeightRegular color:[UIColor secondaryLabelColor]];
    min.text = [NSString stringWithFormat:@"%g", minimum];
    UILabel *max = [self createLabelFont:12 weight:UIFontWeightRegular color:[UIColor secondaryLabelColor]];
    max.text = [NSString stringWithFormat:@"%g", maximum];
    UISlider *slider = [UISlider new];
    slider.minimumValue = minimum;
    slider.maximumValue = maximum;
    slider.value = val.floatValue;
    slider.tag = idx;
    slider.accessibilityLabel = value.accessibilityLabel;
    slider.accessibilityValue = val;
    [slider.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [slider addTarget:self action:@selector(onResultSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(onResultSliderTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [sliderRow addArrangedSubview:min];
    [sliderRow addArrangedSubview:slider];
    [sliderRow addArrangedSubview:max];
    [content addArrangedSubview:sliderRow];
  } else if (isSwitch) {
    UIStackView *switchRow = [UIStackView new];
    switchRow.axis = UILayoutConstraintAxisHorizontal;
    switchRow.alignment = UIStackViewAlignmentCenter;
    switchRow.spacing = 8;
    UILabel *title = [self createLabelFont:13 weight:UIFontWeightRegular color:[UIColor secondaryLabelColor]];
    title.text = note.length ? note : TR(@"Mode_Switch_Toggle");
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = [VMUIHelper accentColor];
    toggle.tag = idx;
    toggle.on = [val isEqualToString:config[@"switchOnValue"] ?: @"1"];
    toggle.accessibilityLabel = value.accessibilityLabel;
    [toggle addTarget:self action:@selector(onResultSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(toggle, "addr", @(addr), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [switchRow addArrangedSubview:title];
    [switchRow addArrangedSubview:toggle];
    [switchRow.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [content addArrangedSubview:switchRow];
  }
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
    [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
    [content.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
    [content.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12]
  ]];
  return row;
}

- (void)onValueTap:(UIButton *)btn {
  NSInteger idx = btn.tag;
  NSNumber *addrNum = objc_getAssociatedObject(btn, "addr");
  uint64_t addr = [addrNum unsignedLongLongValue];
  
  if ([self.delegate respondsToSelector:@selector(didClickResultValue:atIndex:address:currentValue:)]) {
    [self.delegate didClickResultValue:self atIndex:idx address:addr currentValue:btn.titleLabel.text];
  }
}

- (void)onModeSegmentChanged:(UISegmentedControl *)seg {
  NSInteger idx = seg.tag;
  BOOL isSlider = (seg.selectedSegmentIndex == 1);
  BOOL isSwitch = (seg.selectedSegmentIndex == 2);
  
  if ([self.delegate respondsToSelector:@selector(didChangeModeSegment:atIndex:isSlider:isSwitch:)]) {
    [self.delegate didChangeModeSegment:self atIndex:idx isSlider:isSlider isSwitch:isSwitch];
  }
}

- (void)onResultSliderChanged:(UISlider *)slider {
  NSInteger idx = slider.tag;
  NSString *val = [NSString stringWithFormat:@"%.2f", slider.value];
  
  if (idx < _resultsStack.arrangedSubviews.count) {
    UIView *row = _resultsStack.arrangedSubviews[idx];
    
    for (UIView *sub in row.subviews) {
      if ([sub isKindOfClass:[UIStackView class]]) {
        for (UIView *inner in ((UIStackView *)sub).arrangedSubviews) {
          if ([inner isKindOfClass:[UIStackView class]]) {
            for (UIView *item in ((UIStackView *)inner).arrangedSubviews) {
              if ([item isKindOfClass:[UIButton class]] && item.tag == idx) {
                [(UIButton *)item setTitle:val forState:UIControlStateNormal];
                break;
              }
            }
          }
        }
      }
    }
  }
  
  if (idx < self.currentSig.runtimeResults.count) {
    NSMutableDictionary *item = [self.currentSig.runtimeResults[idx] mutableCopy];
    item[@"val"] = val;
    NSMutableArray *results = [self.currentSig.runtimeResults mutableCopy];
    results[idx] = item;
    self.currentSig.runtimeResults = results;
  }
}

- (void)onResultSliderTouchUp:(UISlider *)slider {
  NSInteger idx = slider.tag;
  NSString *val = [NSString stringWithFormat:@"%.2f", slider.value];
  
  if ([self.delegate respondsToSelector:@selector(didChangeResultSliderValue:atIndex:value:)]) {
    [self.delegate didChangeResultSliderValue:self atIndex:idx value:val];
  }
}

- (void)onResultSwitchChanged:(UISwitch *)sender {
  NSInteger idx = sender.tag;
  BOOL isOn = sender.isOn;
  
  if (idx < self.currentSig.runtimeResults.count) {
    NSDictionary *res = self.currentSig.runtimeResults[idx];
    NSNumber *addrNum = res[@"addr"];
    uint64_t addr = [addrNum unsignedLongLongValue];
    
    NSDictionary *config = self.currentSig.resultConfig[@(addr)];
    NSString *switchOnValue = config[@"switchOnValue"] ?: @"1";
    NSString *switchOffValue = config[@"switchOffValue"] ?: @"0";
    
    NSString *newVal = isOn ? switchOnValue : switchOffValue;
    
    NSMutableDictionary *item = [res mutableCopy];
    item[@"val"] = newVal;
    NSMutableArray *results = [self.currentSig.runtimeResults mutableCopy];
    results[idx] = item;
    self.currentSig.runtimeResults = results;
    
    [self updateValueButtonAtIndex:idx withValue:newVal];
  }
  
  if ([self.delegate respondsToSelector:@selector(didChangeResultSwitchState:atIndex:isOn:)]) {
    [self.delegate didChangeResultSwitchState:self atIndex:idx isOn:isOn];
  }
}

- (void)updateValueButtonAtIndex:(NSInteger)idx withValue:(NSString *)val {
  if (idx < _resultsStack.arrangedSubviews.count) {
    UIView *row = _resultsStack.arrangedSubviews[idx];
    for (UIView *sub in row.subviews) {
      if ([sub isKindOfClass:[UIStackView class]]) {
        for (UIView *inner in ((UIStackView *)sub).arrangedSubviews) {
          if ([inner isKindOfClass:[UIStackView class]]) {
            for (UIView *item in ((UIStackView *)inner).arrangedSubviews) {
              if ([item isKindOfClass:[UIButton class]] && item.tag == idx) {
                [(UIButton *)item setTitle:val forState:UIControlStateNormal];
                return;
              }
            }
          }
        }
      }
    }
  }
}

- (UILabel *)createLabelFont:(CGFloat)size
                      weight:(UIFontWeight)weight
                       color:(UIColor *)color {
  UILabel *l = [UILabel new];
  l.font = [VMUIHelper scaledFontOfSize:MAX(12, size) weight:weight];
  l.adjustsFontForContentSizeCategory = YES;
  l.numberOfLines = 0;
  l.textColor = color;
  l.translatesAutoresizingMaskIntoConstraints = NO;
  return l;
}

- (UIButton *)createButton:(NSString *)title color:(UIColor *)color {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button setTitle:title forState:UIControlStateNormal];
  button.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:button primary:NO];
  return button;
}

#pragma mark - Actions

- (void)onEditTap {
  if ([self.delegate respondsToSelector:@selector(didClickSettings:)]) {
    [self.delegate didClickSettings:self];
  }
}

- (void)onScanTap {
  if ([self.delegate respondsToSelector:@selector(didClickScan:)]) {
    [self.delegate didClickScan:self];
  }
}

@end
