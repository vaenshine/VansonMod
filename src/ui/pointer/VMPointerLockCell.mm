#import "../../utils/helpers/VMUIHelper.h"
#import "VMPointerLockCell.h"
#import "../../../include/VMLocalization.h"
#import <objc/runtime.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])
#define kCardCornerRadius 16.0

@interface VMPointerLockCell ()
@property(nonatomic, strong) UIView *cardContainer;
@property(nonatomic, strong) UIColor *cardBorderColor;
@property(nonatomic, strong) UIView *statusIndicator;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *authorLabel;
@property(nonatomic, strong) UILabel *chainPathLabel;
@property(nonatomic, strong) UILabel *valueDisplayLabel; 
@property(nonatomic, strong) UILabel *metaInfoLabel;
@property(nonatomic, strong) UIButton *btnEdit;
@property(nonatomic, strong) UIButton *btnToggle;
@property(nonatomic, strong) UIButton *
    btnApply; 
              
@property(nonatomic, strong) UIView *separatorLine;
@property(nonatomic, strong) UISlider *valueSlider;
@property(nonatomic, strong) UIStackView *centerStackView;
@property(nonatomic, assign) BOOL isLockedState;

@property(nonatomic, strong) UISwitch *valueSwitch;
@property(nonatomic, strong) UILabel *resultTitleLabel;

- (UIButton *)createButton:(NSString *)title
                     color:(UIColor *)color
                    filled:(BOOL)filled;
- (void)updateButton:(UIButton *)btn
               title:(NSString *)title
               color:(UIColor *)color
              filled:(BOOL)filled;
- (void)commitSliderValue;
@end

@implementation VMPointerLockCell

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
  _cardContainer.layer.shadowColor = [UIColor blackColor].CGColor;
  _cardContainer.layer.shadowOpacity = 0;
  _cardContainer.layer.shadowOffset = CGSizeMake(0, 3);
  _cardContainer.layer.shadowRadius = 6;
  _cardContainer.layer.borderWidth = 1.0;
  self.cardBorderColor = UIColor.clearColor;
  _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_cardContainer];

  _titleLabel = [[UILabel alloc] init];
  _titleLabel.font = [VMUIHelper scaledFontOfSize:17 weight:UIFontWeightSemibold];
  _titleLabel.adjustsFontForContentSizeCategory = YES;
  _titleLabel.numberOfLines = 0;
  _titleLabel.textColor = [UIColor labelColor];
  _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_titleLabel];

  _authorLabel = [[UILabel alloc] init];
  _authorLabel.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
  _authorLabel.adjustsFontForContentSizeCategory = YES;
  _authorLabel.numberOfLines = 0;
  _authorLabel.textColor = [UIColor secondaryLabelColor];
  _authorLabel.textAlignment = NSTextAlignmentNatural;
  _authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_authorLabel];

  _statusIndicator = [[UIView alloc] init];
  _statusIndicator.backgroundColor = [UIColor systemGray4Color];
  _statusIndicator.layer.cornerRadius = 4;
  _statusIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_statusIndicator];

  _chainPathLabel = [[UILabel alloc] init];
  _chainPathLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]];
  _chainPathLabel.textColor = [UIColor secondaryLabelColor];
  _chainPathLabel.numberOfLines = 0;
  _chainPathLabel.adjustsFontForContentSizeCategory = YES;
  _chainPathLabel.lineBreakMode = NSLineBreakByCharWrapping;
  _chainPathLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_chainPathLabel];

  _separatorLine = [[UIView alloc] init];
  _separatorLine.backgroundColor = [UIColor separatorColor];
  _separatorLine.alpha = 0.5;
  _separatorLine.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_separatorLine];

  _centerStackView = [[UIStackView alloc] init];
  _centerStackView.axis = UILayoutConstraintAxisVertical;
  _centerStackView.spacing = 8;
  _centerStackView.alignment = UIStackViewAlignmentFill;
  _centerStackView.distribution = UIStackViewDistributionFill;
  _centerStackView.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:_centerStackView];

  _valueDisplayLabel = [[UILabel alloc] init];
  _valueDisplayLabel.font = [UIFont systemFontOfSize:18
                                              weight:UIFontWeightBold];
  _valueDisplayLabel.textColor = [UIColor labelColor];
  _valueDisplayLabel.textAlignment = NSTextAlignmentCenter;
  [_centerStackView addArrangedSubview:_valueDisplayLabel];

  _valueSlider = [[UISlider alloc] init];
  _valueSlider.hidden = YES;
  _valueSlider.userInteractionEnabled = YES;
  [_valueSlider.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [_valueSlider addTarget:self
                   action:@selector(onSliderChanged:)
         forControlEvents:UIControlEventValueChanged];
  [_valueSlider addTarget:self
                   action:@selector(onSliderTouchUp:)
         forControlEvents:UIControlEventTouchUpInside |
                          UIControlEventTouchUpOutside];
  [_centerStackView addArrangedSubview:_valueSlider];

  _resultTitleLabel = [[UILabel alloc] init];
  _resultTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  _resultTitleLabel.textColor = [UIColor secondaryLabelColor];
  _resultTitleLabel.textAlignment = NSTextAlignmentCenter;
  _resultTitleLabel.hidden = YES;
  [_centerStackView addArrangedSubview:_resultTitleLabel];
  
  _valueSwitch = [[UISwitch alloc] init];
  _valueSwitch.hidden = YES;
  [_valueSwitch addTarget:self
                   action:@selector(onSwitchChanged:)
         forControlEvents:UIControlEventValueChanged];
  
  UIView *switchContainer = [[UIView alloc] init];
  switchContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [switchContainer addSubview:_valueSwitch];
  _valueSwitch.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [_valueSwitch.centerXAnchor constraintEqualToAnchor:switchContainer.centerXAnchor],
    [_valueSwitch.topAnchor constraintEqualToAnchor:switchContainer.topAnchor],
    [_valueSwitch.bottomAnchor constraintEqualToAnchor:switchContainer.bottomAnchor]
  ]];
  [_centerStackView addArrangedSubview:switchContainer];

  _metaInfoLabel = [[UILabel alloc] init];
  _metaInfoLabel.font =
      [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
  _metaInfoLabel.textColor = [UIColor secondaryLabelColor];
  _metaInfoLabel.textAlignment = NSTextAlignmentCenter;
  [_centerStackView addArrangedSubview:_metaInfoLabel];

  UIStackView *btnStack = [[UIStackView alloc] init];
  btnStack.axis = UILayoutConstraintAxisHorizontal;
  btnStack.spacing = 10;
  btnStack.distribution = UIStackViewDistributionFillEqually;
  btnStack.translatesAutoresizingMaskIntoConstraints = NO;
  [_cardContainer addSubview:btnStack];

  _btnEdit = [self createButton:TR(@"Common_Edit")
                          color:[UIColor systemGrayColor]
                         filled:NO];
  [_btnEdit addTarget:self
                action:@selector(onEditTap)
      forControlEvents:UIControlEventTouchUpInside];

  _btnToggle = [self createButton:TR(@"Btn_Lock")
                            color:[UIColor systemGrayColor]
                           filled:NO];
  [_btnToggle addTarget:self
                 action:@selector(onToggleTap)
       forControlEvents:UIControlEventTouchUpInside];

  _btnApply = [self createButton:TR(@"Btn_Apply")
                           color:[VMUIHelper accentColor]
                          filled:YES];
  [_btnApply addTarget:self
                action:@selector(onApplyTap)
      forControlEvents:UIControlEventTouchUpInside];

  [btnStack addArrangedSubview:_btnEdit];
  [btnStack addArrangedSubview:_btnToggle];
  [btnStack addArrangedSubview:_btnApply]; 

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

    [_chainPathLabel.topAnchor constraintEqualToAnchor:_authorLabel.bottomAnchor
                                              constant:4],
    [_chainPathLabel.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_chainPathLabel.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],

    [_separatorLine.topAnchor
        constraintEqualToAnchor:_chainPathLabel.bottomAnchor
                       constant:8],
    [_separatorLine.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_separatorLine.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],
    [_separatorLine.heightAnchor constraintEqualToConstant:0.5],

    [_centerStackView.topAnchor
        constraintEqualToAnchor:_separatorLine.bottomAnchor
                       constant:8],
    [_centerStackView.leadingAnchor
        constraintEqualToAnchor:_cardContainer.leadingAnchor
                       constant:p],
    [_centerStackView.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],

    [btnStack.topAnchor constraintEqualToAnchor:_centerStackView.bottomAnchor
                                       constant:16],
    [btnStack.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor
                                           constant:p],
    [btnStack.trailingAnchor
        constraintEqualToAnchor:_cardContainer.trailingAnchor
                       constant:-p],
    [btnStack.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor
                                          constant:-p],
    [btnStack.heightAnchor constraintGreaterThanOrEqualToConstant:44],
  ]];
}

- (void)configureWithChain:(VMPointerChain *)chain
                   address:(NSString *)addr
                       val:(NSString *)val
                      type:(NSString *)typeStr {
  self.currentChain = chain;

  _titleLabel.text = (chain.note && chain.note.length > 0)
                         ? chain.note
                         : TR(@"Lock_Default_Note_Ptr");
  _authorLabel.text =
      [NSString stringWithFormat:@"@%@", chain.author ?: TR(@"Lab_Me_Default")];

  _chainPathLabel.text = [chain displayString];
  _metaInfoLabel.text = [NSString stringWithFormat:@"%@ • %@", addr, typeStr];

  _valueDisplayLabel.text = val;
  _valueDisplayLabel.numberOfLines = 0;
  _metaInfoLabel.numberOfLines = 0;
  _valueSlider.accessibilityLabel = _titleLabel.text;
  _valueSwitch.accessibilityLabel = _titleLabel.text;
  _valueSlider.accessibilityValue = val;
  _valueSwitch.accessibilityValue = val;

  BOOL isSlider = [chain.type isEqualToString:@"slider"] ||
                  chain.uiMode == VMPointerUIModeSlider;
  BOOL isSwitch = chain.uiMode == VMPointerUIModeSwitch;
  
  _valueSlider.hidden = YES;
  _valueSwitch.hidden = YES;
  _resultTitleLabel.hidden = YES;
  _valueSwitch.superview.hidden = YES;
  
  if (isSwitch) {
    
    _valueSwitch.hidden = NO;
    _valueSwitch.superview.hidden = NO;
    
    BOOL isOn = [val isEqualToString:chain.switchOnValue];
    [_valueSwitch setOn:isOn animated:NO];
    
  } else if (isSlider) {
    _valueSlider.hidden = NO;
    _valueSlider.minimumValue = chain.uiMin;
    _valueSlider.maximumValue = chain.uiMax;

    if (!_valueSlider.isTracking) {
      _valueSlider.value = [val floatValue];
    }
  }

  _btnEdit.enabled = YES;
  _btnEdit.alpha = 1.0;

  if (chain.isImported) {
    
    _titleLabel.text = chain.note ?: TR(@"Lock_Default_Note_Ptr");

    _cardContainer.layer.borderWidth = 1.0;
    self.cardBorderColor = UIColor.systemGray4Color;
  } else {
    
    _cardContainer.layer.borderWidth = 0;
  }

  [self updateLockStateVisuals:chain.lockEnabled animated:NO];
}

- (void)updateLockStateVisuals:(BOOL)isLocked animated:(BOOL)animated {
  self.isLockedState = isLocked;
  
  void (^updates)(void) = ^{
    if (isLocked) {
      self.cardBorderColor = VMUIHelper.accentColor;
      self.cardContainer.backgroundColor = [VMUIHelper cardColor];
      self.statusIndicator.backgroundColor = [VMUIHelper accentColor];
      self.valueDisplayLabel.textColor = [VMUIHelper accentColor];

      [self updateButton:self.btnToggle
                   title:TR(@"Btn_Unlock")
                   color:[VMUIHelper accentColor]
                  filled:YES];
    } else {
      self.cardBorderColor = self.currentChain.isImported ? UIColor.systemGray4Color : UIColor.clearColor;
      self.cardContainer.backgroundColor =
          [UIColor secondarySystemGroupedBackgroundColor];
      self.statusIndicator.backgroundColor = [UIColor systemGray4Color];
      self.valueDisplayLabel.textColor = [UIColor labelColor];

      [self updateButton:self.btnToggle
                   title:TR(@"Btn_Lock")
                   color:[UIColor systemGrayColor]
                  filled:NO];
    }
  };

  if (animated) {
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:updates
                     completion:nil];
  } else {
    updates();
  }
}

- (void)onSliderChanged:(UISlider *)slider {
  
  NSString *val = [NSString stringWithFormat:@"%.2f", slider.value];
  _valueDisplayLabel.text = val;
  self.currentChain.lockValue = val;

  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(commitSliderValue)
                                             object:nil];
  [self performSelector:@selector(commitSliderValue)
             withObject:nil
             afterDelay:1.0];
}

- (void)onSliderTouchUp:(UISlider *)slider {
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(commitSliderValue)
                                             object:nil];

  NSString *val = [NSString stringWithFormat:@"%.2f", slider.value];
  self.currentChain.lockValue = val;
  _valueDisplayLabel.text = val;

  if ([self.delegate respondsToSelector:@selector(didChangeSliderValue:
                                                                 value:)]) {
    [self.delegate didChangeSliderValue:self value:val];
  }
}

- (void)commitSliderValue {
  NSString *val = self.currentChain.lockValue;
  if ([self.delegate respondsToSelector:@selector(didChangeSliderValue:
                                                                 value:)]) {
    [self.delegate didChangeSliderValue:self value:val];
  }
}

- (void)prepareForReuse {
  [super prepareForReuse];
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(commitSliderValue)
                                             object:nil];
}

- (void)onEditTap {
  if ([self.delegate respondsToSelector:@selector(didClickSettings:)])
    [self.delegate didClickSettings:self];
}

- (void)onToggleTap {
  
  BOOL newState = !self.isLockedState;
  [self updateLockStateVisuals:newState animated:YES];

  if ([self.delegate respondsToSelector:@selector(didChangeLockState:isOn:)]) {
    [self.delegate didChangeLockState:self isOn:newState];
  }
}

- (void)onApplyTap {
  
  if ([self.delegate respondsToSelector:@selector(didClickSet:)]) {
    [self.delegate didClickSet:self];
  }
}

- (void)onSwitchChanged:(UISwitch *)sender {
  BOOL isOn = sender.isOn;
  
  if (isOn) {
    self.currentChain.lockValue = self.currentChain.switchOnValue;
  } else {
    self.currentChain.lockValue = self.currentChain.switchOffValue;
  }
  
  _valueDisplayLabel.text = self.currentChain.lockValue;
  
  if ([self.delegate respondsToSelector:@selector(didChangeSwitchState:isOn:)]) {
    [self.delegate didChangeSwitchState:self isOn:isOn];
  }
}

- (void)configureForSignature:(VMPointerChain *)chain {
}

#pragma mark - Helper UI Methods

- (UIButton *)createButton:(NSString *)title color:(UIColor *)color filled:(BOOL)filled {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.tintColor = filled ? [VMUIHelper accentColor] : [UIColor secondaryLabelColor];
  [button setTitle:title forState:UIControlStateNormal];
  [VMUIHelper styleButton:button primary:filled];
  return button;
}

- (void)updateButton:(UIButton *)button title:(NSString *)title color:(UIColor *)color filled:(BOOL)filled {
  button.tintColor = color;
  [button setTitle:title forState:UIControlStateNormal];
  button.accessibilityLabel = title;
  [VMUIHelper styleButton:button primary:filled];
}

@end
