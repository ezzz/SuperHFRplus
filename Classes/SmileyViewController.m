//
//  SmileyViewController.m
//  SuperHFRplus
//
//  Created by ezzz on 09/06/2020.
//

#import "SmileyViewController.h"
#import "RehostCollectionCell.h"
#import "ThemeColors.h"
#import "ThemeManager.h"
#import "SmileyCache.h"
#import "AddMessageViewController.h"
#import "ASIHTTPRequest+Tools.h"
#import "HTMLParser.h"
#import "HFRAlertView.h"
#import "SimpleCellView.h"
#import "UILabel+Boldify.h"
#import "SmileyAlertView.h"
#import "PopupViewController.h"

#if !defined(MIN)
    #define MIN(A,B)    ((A) < (B) ? (A) : (B))
#endif

@implementation SmileySearch
@synthesize sSearchText, nSearchNumber, nSmileysResultNumber, dLastSearch;

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:sSearchText forKey:@"sSearchText"];
    [encoder encodeObject:nSearchNumber forKey:@"nSearchNumber"];
    [encoder encodeObject:nSmileysResultNumber forKey:@"nSmileysResultNumber"];
    [encoder encodeObject:dLastSearch forKey:@"dLastSearch"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    
    self = [super init];
    if (self) {
        sSearchText = [decoder decodeObjectForKey:@"sSearchText"];
        nSearchNumber = [decoder decodeObjectForKey:@"nSearchNumber"];
        nSmileysResultNumber = [decoder decodeObjectForKey:@"nSmileysResultNumber"];
        dLastSearch = [decoder decodeObjectForKey:@"dLastSearch"];
    }
    return self;
}


@end

@implementation SmileyViewController

@synthesize smileyCache, collectionViewSmileysDefault, collectionViewSmileysSearch, collectionViewSmileysFavorites, textFieldSmileys, btnSmileySearch, btnSmileyDefault, btnReduce, tableViewSearch;
@synthesize arrayTmpsmileySearch, arrSearch, arrTopSearchSorted, arrLastSearchSorted, arrTopSearchSortedFiltered, arrLastSearchSortedFiltered, request, requestSmile, bModeFullScreen, bActivateSmileySearchTable, labelNoResult;

#pragma mark -
#pragma mark View lifecycle

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        self.smileyCache = [SmileyCache shared];
        self.title = @"Smileys";
        
        self.bModeFullScreen = NO;
        self.bActivateSmileySearchTable = NO;

        self.arrSearch = [[NSMutableArray alloc] init];
        self.arrTopSearchSorted = [[NSMutableArray alloc] init];
        self.arrLastSearchSorted = [[NSMutableArray alloc] init];
        self.arrTopSearchSortedFiltered = [[NSMutableArray alloc] init];
        self.arrLastSearchSortedFiltered = [[NSMutableArray alloc] init];
        
        self.arrayTmpsmileySearch = [[NSMutableArray alloc] init];
        
        self.bFirstLoad = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

      // Configure Collection Smileys defaults
     [self.collectionViewSmileysDefault setHidden:NO];
     [self.collectionViewSmileysDefault registerClass:[SmileyCollectionCell class] forCellWithReuseIdentifier:@"SmileyCollectionCellId"];
     [self.collectionViewSmileysDefault  setDataSource:self];
     [self.collectionViewSmileysDefault  setDelegate:self];
     
    // Configure Collection Smileys search
    [self.collectionViewSmileysSearch setHidden:NO];
    [self.collectionViewSmileysSearch setAlpha:0];
    [self.collectionViewSmileysSearch registerClass:[SmileyCollectionCell class] forCellWithReuseIdentifier:@"SmileyCollectionCellId"];
    [self.collectionViewSmileysSearch  setDataSource:self];
    [self.collectionViewSmileysSearch  setDelegate:self];

    // Configure Collection Smileys favorite
    [self.collectionViewSmileysFavorites setHidden:NO];
    [self.collectionViewSmileysFavorites setAlpha:0];
    [self.collectionViewSmileysFavorites registerClass:[SmileyCollectionCell class] forCellWithReuseIdentifier:@"SmileyCollectionCellId"];
    [self.collectionViewSmileysFavorites  setDataSource:self];
    [self.collectionViewSmileysFavorites  setDelegate:self];

    // Dic of search smileys
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *directory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *searchFile = [[NSString alloc] initWithString:[directory stringByAppendingPathComponent:SEARCH_SMILEYS_FILE]];
    if ([fileManager fileExistsAtPath:searchFile]) {
        NSData *data = [[NSData alloc] initWithContentsOfFile:searchFile];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        self.arrSearch = [unarchiver decodeObject];
        [unarchiver finishDecoding];
    }
    else {
        [self.arrSearch removeAllObjects];
    }

    [self updateSearchArraySorted];

    UIImage* img = [self imageWithImage:[UIImage imageNamed:@"clear"] scaledToSize:CGSizeMake(15, 15)];
    UIImage *clearBtnImage = [ThemeColors tintImage:img withColor:[[ThemeColors textColor] colorWithAlphaComponent:0.7]];
    [self modifyClearButtonWithImage:clearBtnImage];
    [self.textFieldSmileys setBackgroundColor:[ThemeColors textFieldBackgroundColor]];
    labelNoResult.alpha = 0;
    labelNoResult.backgroundColor = [ThemeColors textFieldBackgroundColor];
    
    // TableView
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    v.backgroundColor = [ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]];
    [self.tableViewSearch setTableFooterView:v];
    [self.tableViewSearch registerNib:[UINib nibWithNibName:@"SimpleCellView" bundle:nil] forCellReuseIdentifier:@"SimpleCellId"];
    if (@available(iOS 15.0, *)) {
        self.tableViewSearch.sectionHeaderTopPadding = 0;
    }

    // Observe keyboard hide and show notifications to resize the text view appropriately.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // attach long press gesture to collectionView
    /*
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.delegate = self;
    lpgr.delaysTouchesBegan = YES;
    [self.collectionViewSmileysDefault addGestureRecognizer:lpgr];
    */
    UILongPressGestureRecognizer *lpgr2 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr2.delegate = self;
    lpgr2.delaysTouchesBegan = YES;
    [self.collectionViewSmileysSearch addGestureRecognizer:lpgr2];
    
    UILongPressGestureRecognizer *lpgr3 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr3.delegate = self;
    lpgr3.delaysTouchesBegan = YES;
    [self.collectionViewSmileysFavorites addGestureRecognizer:lpgr3];
    
    /*self.viewCancelActionSmiley.layer.cornerRadius = 15;
    self.viewCancelActionSmiley.layer.masksToBounds = true;*/
    /*self.viewCancelActionSmiley.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.viewCancelActionSmiley.layer.shadowRadius = 15;
    //self.viewCancelActionSmiley.layer.shadowOffset = 0;
    self.viewCancelActionSmiley.layer.shadowRadius = 10;
    self.viewCancelActionSmiley.layer.shadowOffset = CGSizeMake(0, 0);
    self.viewCancelActionSmiley.layer.shadowOpacity = 0.2;
    self.viewCancelActionSmiley.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.viewCancelActionSmiley.layer.shadowPath = [[UIBezierPath bezierPathWithRect:self.viewCancelActionSmiley.bounds] CGPath];*/
}

- (void)modifyClearButtonWithImage:(UIImage *)image {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:image forState:UIControlStateNormal];
    CGRect rect = [self.textFieldSmileys frame];
    float btnSize = 20;
    [button setFrame:CGRectMake(rect.size.width - btnSize - 5, 0, btnSize, btnSize)];

    [button addTarget:self action:@selector(clear:) forControlEvents:UIControlEventTouchUpInside];
    self.textFieldSmileys.rightView = button;
    self.textFieldSmileys.rightViewMode = UITextFieldViewModeWhileEditing;
}

- (IBAction)clear:(id)sender {
    [SmileyCache shared].bStopLoadingSmileysSearchToCache = YES;
    self.textFieldSmileys.text = @"";
    [self updateTableViewSearchFilters:@""];
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.view.backgroundColor = [UIColor clearColor];

    [self.btnSmileyDefault addTarget:self action:@selector(actionSmileysDefaults:) forControlEvents:UIControlEventTouchUpInside];
    [self.btnSmileySearch addTarget:self action:@selector(actionSmileysSearch:) forControlEvents:UIControlEventTouchUpInside];
    if (self.smileyCache.arrCurrentSmileyArray.count == 0) {
        [self.btnSmileySearch setEnabled:NO];
    }
    [self.btnSmileyFavorites addTarget:self action:@selector(actionSmileysFavorites:) forControlEvents:UIControlEventTouchUpInside];
    [self.btnCancelActionSmiley addTarget:self action:@selector(actionCancelSmileysFavorites:) forControlEvents:UIControlEventTouchUpInside];

    [self.btnReduce addTarget:self action:@selector(actionReduce:) forControlEvents:UIControlEventTouchUpInside];

    [self.tableViewSearch reloadData];
    [self.tableViewSearch setAlpha:0];

    self.textFieldSmileys.returnKeyType = UIReturnKeySearch;
    [self.textFieldSmileys addTarget:self action:@selector(actionSearch:) forControlEvents:UIControlEventPrimaryActionTriggered];
    
    [self.spinnerSmileySearch setHidesWhenStopped:YES];

    // Default view displayed at startup
    if (self.bFirstLoad) {
        [self changeDisplayMode:DisplayModeEnumSmileysDefault animate:NO];
        self.bFirstLoad = NO;
    }
    
    [self updateTheme];
}

- (void)updateTheme
{
    Theme theme = [[ThemeManager sharedManager] theme];
    [self.btnSmileyDefault setImage:[ThemeColors tintImage:[UIImage imageNamed:@"smiley"] withTheme:theme] forState:UIControlStateNormal];
    [self.btnSmileyDefault setImage:[ThemeColors tintImage:[UIImage imageNamed:@"smiley"] withTheme:theme] forState:UIControlStateHighlighted];
    [self.btnSmileySearch setImage:[ThemeColors tintImage:[UIImage imageNamed:@"redface"] withTheme:theme] forState:UIControlStateNormal];
    [self.btnSmileySearch setImage:[ThemeColors tintImage:[UIImage imageNamed:@"redface"] withTheme:theme] forState:UIControlStateHighlighted];
    [self.btnSmileyFavorites setImage:[ThemeColors tintImage:[UIImage imageNamed:@"favorites"] withTheme:theme] forState:UIControlStateNormal];
    [self.btnSmileyFavorites setImage:[ThemeColors tintImage:[UIImage imageNamed:@"favorites"] withTheme:theme] forState:UIControlStateHighlighted];
    [self.btnReduce setImage:[ThemeColors tintImage:[UIImage imageNamed:@"rectangle.expand"] withTheme:theme] forState:UIControlStateNormal];
    [self.btnReduce setImage:[ThemeColors tintImage:[UIImage imageNamed:@"rectangle.expand"] withTheme:theme] forState:UIControlStateHighlighted];
    self.collectionViewSmileysDefault.backgroundColor = [ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]];
    self.collectionViewSmileysSearch.backgroundColor = [ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]];
    self.collectionViewSmileysFavorites.backgroundColor = [ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]];
    self.tableViewSearch.backgroundColor = [ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]];
    [[ThemeManager sharedManager] applyThemeToTextField:self.textFieldSmileys];
    self.textFieldSmileys.keyboardAppearance = [ThemeColors keyboardAppearance:[[ThemeManager sharedManager] theme]];
    [self.textFieldSmileys setBackgroundColor:[ThemeColors navBackgroundColor]];
    self.view.backgroundColor = [UIColor clearColor];
    [self.collectionViewSmileysDefault reloadData];
    [self.collectionViewSmileysSearch reloadData];
    [self.collectionViewSmileysFavorites reloadData];
}

- (void) changeDisplayMode:(DisplayModeEnum)newMode animate:(BOOL)bAnimate
{
    NSLog(@"SMILEY changeDisplayMode");
    if (bAnimate) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.2];
    }
    
    if (newMode == self.displayMode) {
        return;
    }
    DisplayModeEnum oldMode = self.displayMode;
    
    switch (newMode) {
        case DisplayModeEnumSmileysDefault:
            [self.collectionViewSmileysDefault setAlpha:1];
            [self.collectionViewSmileysSearch setAlpha:0];
            [self.collectionViewSmileysFavorites setAlpha:0];
            [self.tableViewSearch setAlpha:0];
            [self.textFieldSmileys resignFirstResponder];
            [self.collectionViewSmileysDefault reloadData];
            break;
        case DisplayModeEnumSmileysSearch:
            [self.collectionViewSmileysDefault setAlpha:0];
            [self.collectionViewSmileysSearch setAlpha:1];
            [self.collectionViewSmileysFavorites setAlpha:0];
            [self.tableViewSearch setAlpha:0];
            [self.textFieldSmileys resignFirstResponder];
            [self.collectionViewSmileysSearch reloadData];
            break;
        case DisplayModeEnumSmileysFavorites:
            [self.collectionViewSmileysDefault setAlpha:0];
            [self.collectionViewSmileysSearch setAlpha:0];
            [self.collectionViewSmileysFavorites setAlpha:1];
            [self.tableViewSearch setAlpha:0];
            [self.textFieldSmileys resignFirstResponder];
            [self.collectionViewSmileysSearch reloadData];
            break;
        case DisplayModeEnumTableSearch:
            [self.collectionViewSmileysDefault setAlpha:0];
            [self.collectionViewSmileysSearch setAlpha:0];
            [self.collectionViewSmileysFavorites setAlpha:0];
            [self.tableViewSearch reloadData];
            [self.tableViewSearch setAlpha:1];
            if (self.bModeFullScreen) {
                [self.textFieldSmileys becomeFirstResponder];
            }
            break;

        default:
            break;
    }
    
    if (bAnimate) {
        [UIView commitAnimations];
    }
    self.displayMode = newMode;
    if (oldMode == DisplayModeEnumTableSearch && (newMode == DisplayModeEnumSmileysSearch || newMode == DisplayModeEnumSmileysDefault || newMode == DisplayModeEnumSmileysFavorites)) {
        [self.addMessageVC updateExpandCompressSmiley];
    }
}

#pragma mark - Collection management

static CGFloat fCellSizeDefault = 1*0.85; // 0.65 pour 3 lignes
static CGFloat fCellSizeSearch = 1*0.85;
static CGFloat fCellImageSize = 1;

- (float) getDisplayHeight {
    //return 150 * 0.85;
    return fCellSizeSearch * 2 * 50 + 35;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SmileyCollectionCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"SmileyCollectionCellId" forIndexPath:indexPath];
    BOOL bPlaceholder = NO;
    UIImage* image = nil;//[UIImage imageNamed:@"19-gear"];
    if (collectionView == self.collectionViewSmileysDefault) {
        image = [self.smileyCache getImageDefaultSmileyForIndex:(int)indexPath.row];
    }
    else {
        
        BOOL bFavorite = NO;
        BOOL bFavoriteFromApp = NO;

        int index = (int)indexPath.row;
        if (collectionView == self.collectionViewSmileysFavorites) {
            NSLog(@"Loading favorite cell %d", (int)indexPath.row);
            bFavorite = YES;
            if (index >= self.smileyCache.arrFavoritesSmileysForum.count) {
                bFavoriteFromApp = YES;
                index = index - (int)self.smileyCache.arrFavoritesSmileysForum.count;
            }
        }
        
        image = [self.smileyCache getImageForIndex:index forCollection:collectionView andIndexPath:indexPath favoriteSmiley:bFavorite favoriteFromApp:bFavoriteFromApp];
    }

    CGFloat ch = cell.bounds.size.height;
    CGFloat cw = cell.bounds.size.width;
    CGFloat w = image.scale*image.size.width*fCellImageSize;
    CGFloat h = image.scale*image.size.height*fCellImageSize;
    if (bPlaceholder) {
        w = h = 20;
    }
    if (cell.smileyImage == nil) {
        cell.smileyImage = [[UIImageView alloc] initWithFrame:CGRectMake(cw/2-w/2, ch/2-h/2, w, h)];
        [cell addSubview:cell.smileyImage];
    }
    else {
        cell.smileyImage.frame = CGRectMake(cw/2-w/2, ch/2-h/2, w, h);
    }

    //NSLog(@"row %d - %@", (int)indexPath.row, NSStringFromCGRect(CGRectMake(cw/2-w/2, ch/2-h/2, w, h)));

    [cell.smileyImage setImage:image];

    cell.smileyImage.clipsToBounds = NO;
    cell.smileyImage.layer.masksToBounds = true;
    cell.layer.borderColor = [ThemeColors cellBorderColor].CGColor;
    cell.layer.backgroundColor = [ThemeColors greyBackgroundColorLighter].CGColor;
    cell.layer.borderWidth = 1.0f;
    cell.layer.cornerRadius = 3;
    cell.layer.masksToBounds = true;
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        if (collectionView == self.collectionViewSmileysDefault) {
            NSString* sCode = self.smileyCache.dicCommonSmileys[indexPath.row][@"code"];
            [self didSelectSmile:sCode];
        }
        else if (collectionView == self.collectionViewSmileysSearch) {
            NSString* sCode = [self.smileyCache getSmileyCodeForIndex:(int)indexPath.row favoriteSmiley:NO favoriteFromApp:NO];
            [self didSelectSmile:sCode];
        }
        else if (collectionView == self.collectionViewSmileysFavorites) {
            int index = 0;
            BOOL bFavoriteSmileyFromApp = YES;
            if (indexPath.row < self.smileyCache.arrFavoritesSmileysForum.count) {
                index = (int)indexPath.row;
                bFavoriteSmileyFromApp = NO;
            }
            else { // Favorite from app
                index = (int)indexPath.row - (int)self.smileyCache.arrFavoritesSmileysForum.count;
            }
            NSString* sCode = [self.smileyCache getSmileyCodeForIndex:index favoriteSmiley:YES favoriteFromApp:bFavoriteSmileyFromApp];
            [self didSelectSmile:sCode];
        }
    } @catch (NSException *e) {
        NSLog(@"Error in smiley selection: %@", e);
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (collectionView == self.collectionViewSmileysDefault) {
        return self.smileyCache.dicCommonSmileys.count;
    }
    else if (collectionView == self.collectionViewSmileysSearch) {
        return self.smileyCache.arrCurrentSmileyArray.count;
    }
    else if (collectionView == self.collectionViewSmileysFavorites) {
        return (self.smileyCache.arrFavoritesSmileysForum.count + smileyCache.arrFavoritesSmileysApp.count);
    }
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView
{
    return 1;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (collectionView == self.collectionViewSmileysDefault) {
        return CGSizeMake(70*fCellSizeDefault, 50*fCellSizeDefault);
    }
    else {
        return CGSizeMake(70*fCellSizeSearch, 50*fCellSizeSearch);
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(0,0,0,0);  // top, left, bottom, right
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 1.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 2.0;
}

#pragma mark - Table view management

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 32.0f;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.arrSearch.count == 0) {
        return 1;
    }
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.arrSearch.count == 0) {
        return 1;
    }
    if (section == 0) {
        return MIN(5, self.arrLastSearchSorted.count); // Maximum 3 Last search
    } else {
        return MIN(15, self.arrTopSearchSortedFiltered.count);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.arrSearch.count == 0) {
        return @"Recherches précédentes";
    }
    if (section == 0) {
        return @"Recherches précédentes";
    } else {
        return @"Recherches les plus fréquentes";
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.tableViewSearch) {
        //NSLog(@"table rect: %@", NSStringFromCGRect(self.tableViewSearch.frame));
        SimpleCellView *cell = [tableView dequeueReusableCellWithIdentifier:@"SimpleCellId"];
        if (self.arrSearch.count == 0) {
            cell.labelText.text = @"rien du tout :(";
            UIFontDescriptor * fontD = [cell.labelText.font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
            cell.labelText.font = [UIFont fontWithDescriptor:fontD size:0];
            cell.imageIcon.image = nil;
            cell.labelBadge.backgroundColor = [UIColor clearColor];
            cell.labelBadge.textColor = [UIColor clearColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        else {
            SmileySearch* s = nil;
            if (indexPath.section == 0) { // Last search
                s = [self.arrLastSearchSorted objectAtIndex:indexPath.row];
                cell.imageIcon.image = [UIImage imageNamed:@"revert"];
            }
            else {
                s = [self.arrTopSearchSortedFiltered objectAtIndex:indexPath.row];
                cell.imageIcon.image = [UIImage imageNamed:@"06-magnify.png"];
            }
            
            int iResults = 0;
            //NSLog(@"reload: %@ / %@", s.sSearchText, self.textFieldSmileys.text);
            if (s) {
                cell.labelText.text = s.sSearchText;
                if (indexPath.section == 1) {
                    [cell.labelText boldSubstring: self.textFieldSmileys.text];
                }
                else {
                    [cell.labelText boldSubstring: @""];
                }
                iResults = [s.nSearchNumber intValue];
            }
            else {
                cell.labelText.text = @"Y a rien";

            }
            
            // Format badge
            if (iResults > 0) {
                cell.labelBadge.text = [NSString stringWithFormat:@"%d", iResults];
                cell.labelBadge.backgroundColor = [ThemeColors tintColorWithAlpha:0.1];
                cell.labelBadge.textColor = [ThemeColors tintColorWithAlpha:0.5];// [UIColor whiteColor];
                cell.labelBadge.clipsToBounds = YES;
                cell.labelBadge.layer.cornerRadius = cell.labelBadge.frame.size.height / 2;
            } else {
                cell.labelBadge.backgroundColor = [UIColor clearColor];
                cell.labelBadge.textColor = [UIColor clearColor];
                cell.labelBadge.text = @"";
            }
        }
        
        [[ThemeManager sharedManager] applyThemeToCell:cell];
        
        return cell;
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;

    header.textLabel.font = [UIFont boldSystemFontOfSize:13];
    /*CGRect headerFrame = header.frame;
    header.textLabel.frame = headerFrame;*/
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.arrSearch.count > 0 && tableView == self.tableViewSearch) {
        SmileySearch* s = nil;
        if (indexPath.section == 0) { // Last search
            s = [self.arrLastSearchSorted objectAtIndex:indexPath.row];
        }
        else {
            s = [self.arrTopSearchSortedFiltered objectAtIndex:indexPath.row];
        }
        if (s) {
            self.textFieldSmileys.text = s.sSearchText;
            [self fetchSmileys];
            //[self textFieldShouldReturn:self.textFieldSmileys];
            [self.tableViewSearch deselectRowAtIndexPath:self.tableViewSearch.indexPathForSelectedRow animated:NO];
        }
    }
    else {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
}
/*
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    //TODO: implement search deletion
}
*/

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        @try {
            // En mode toolbar (non fullscreen), l'alertview provoque des clignotements avec l'affichage/masquage du clavier
            if (self.bModeFullScreen)
            {
                NSIndexPath *indexPath = nil;
                BOOL bAddSmiley = YES;
                BOOL bShowAction = YES;
                BOOL bFavoriteSmiley = NO;
                BOOL bFavoriteSmileyFromApp = YES;
                NSString* sSmileyCode = nil;
                int index = -1;
                if (self.displayMode == DisplayModeEnumSmileysSearch) {
                    CGPoint p = [gestureRecognizer locationInView:self.collectionViewSmileysSearch];
                    indexPath = [self.collectionViewSmileysSearch indexPathForItemAtPoint:p];
                    index = (int)indexPath.row;
                    sSmileyCode = [self.smileyCache getSmileyCodeForIndex:index favoriteSmiley:NO favoriteFromApp:NO];
                    if ([self.smileyCache isFavoriteSmileyFromApp:sSmileyCode]) {
                        bAddSmiley = NO;
                    }
                }
                else { // DisplayModeEnumSmileysFavorites
                    bFavoriteSmiley = YES;
                    CGPoint p = [gestureRecognizer locationInView:self.collectionViewSmileysFavorites];
                    indexPath = [self.collectionViewSmileysFavorites indexPathForItemAtPoint:p];
                    
                    // Do not know show action add/remove on favorites from forum
                    if (indexPath.row < self.smileyCache.arrFavoritesSmileysForum.count) {
                        index = (int)indexPath.row;
                        bFavoriteSmileyFromApp = NO;
                        bShowAction = NO;
                    }
                    else { // Favorite from app
                        index = (int)indexPath.row - (int)self.smileyCache.arrFavoritesSmileysForum.count;
                    }
                    sSmileyCode = [self.smileyCache getSmileyCodeForIndex:index favoriteSmiley:YES favoriteFromApp:bFavoriteSmileyFromApp];
                }

                if ([self.smileyCache isFavoriteSmileyFromApp:sSmileyCode]) {
                    bAddSmiley = NO;
                }

                NSString* sSmileyImgUrlRaw = [[self.smileyCache getSmileyImgUrlForIndex:index favoriteSmiley:bFavoriteSmiley favoriteFromApp:bFavoriteSmileyFromApp] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString* sSmileyImgUrlOK = [sSmileyImgUrlRaw stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
                NSLog(@"sSmileyCode :%@", sSmileyCode);
                NSLog(@"sSmileyImgUrlRaw :%@", sSmileyImgUrlRaw);
                NSLog(@"sSmileyImgUrlOK :%@", sSmileyImgUrlOK);
                self.sCancelSmileyFavoriteCode = sSmileyCode;
                //self.sCancelSmileyFavoriteUrl = sSmileyImgUrlOK;
                //elf.sCancelSmileyFavoriteUrl = sSmileyImgUrlOK;
                
                [[SmileyAlertView shared] displaySmileyActionCancel:sSmileyCode withUrl:sSmileyImgUrlRaw addSmiley:bAddSmiley showAction:bShowAction handlerDone:^{[self AddFavoriteSmileyOK:bAddSmiley];} handlerFailed:^{[self AddFavoriteSmileyFailed:NO];} handlerSelectCode:^(NSString* s){[self actionSelectCode:s];} baseController:self];

            }
        } @catch (NSException *e) {
            NSLog(@"Error in smiley selection: %@", e);
        }
    }
}

- (void)AddFavoriteSmileyOK:(BOOL)bSmileyAdded
{
    if (bSmileyAdded) {
        [self showPopupWithLabel:@"Smiley ajouté" buttonName:@"Annuler" action:^{[self AddFavoriteSmileyOK:bSmileyAdded];}];
    } else {
        [self showPopupWithLabel:@"Smiley retiré" buttonName:@"Annuler" action:^{[self AddFavoriteSmileyOK:bSmileyAdded];}];
    }
    [self.collectionViewSmileysFavorites reloadData];

}

- (void)AddFavoriteSmileyFailed:(BOOL)bSmileyAdded {
    [self.labelCancelActionSmiley setText:@"Erreur"];
    [self.collectionViewSmileysFavorites reloadData];
    [UIView transitionWithView:self.viewCancelActionSmiley duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^(void) {
        [self.viewCancelActionSmiley setHidden:NO];
    } completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIView transitionWithView:self.viewCancelActionSmiley duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^(void) {
            [self.viewCancelActionSmiley setHidden:YES];
        } completion:nil];
    });
}


- (void)showPopupWithLabel:(NSString*)sLabel buttonName:(NSString*)sButtonText action:(dispatch_block_t)blockHandlerAction
{
    // Prepare next view
    self.popup = [[PopupViewController alloc] init];
    [self.popup.view setHidden:YES];
    [self.view addSubview:self.popup.view];

    // Resize popup
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat fPopupHeight = 80/2;

    self.popup.view.frame = CGRectMake((w - w*0.7)/2, h - fPopupHeight - 50, w*0.7, fPopupHeight); //XYwh
    NSLog(@"POPUP: %@ / screen %@", NSStringFromCGRect(self.popup.view.frame), NSStringFromCGRect([UIScreen mainScreen].bounds));
    CALayer *layer = self.popup.view.layer;
    layer.cornerRadius = 15.0f;
    layer.masksToBounds = NO;

    layer.shadowOffset = CGSizeMake(0, 3);
    layer.shadowColor = [[UIColor blackColor] CGColor];
    layer.shadowRadius = 4.0f;
    layer.shadowOpacity = 0.35f;
    layer.shadowPath = [[UIBezierPath bezierPathWithRoundedRect:layer.bounds cornerRadius:layer.cornerRadius] CGPath];
    
    self.popup.view.backgroundColor = nil;
    self.popup.view.layer.backgroundColor = [ThemeColors popupBackgroundColor].CGColor;
    [self.popup configurePopupWithLabel:sLabel buttonName:sButtonText action:blockHandlerAction];
    [UIView transitionWithView:self.popup.view duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^(void) {
        [self.popup.view setHidden:NO];
    } completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIView transitionWithView:self.popup.view duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^(void) {
            [self closePopup];
        } completion:^(BOOL finished){}];
    });
}

- (void)closePopup {
    if (self.popup) {
        [self.popup.view setHidden:YES];
        [self.popup.view removeFromSuperview];
        self.popup = nil;
    }
}


- (void)actionSelectCode:(NSString*)sSelectedSmileyCode
{
    self.textFieldSmileys.text = sSelectedSmileyCode;
    [self fetchSmileys];
    [self changeDisplayMode:DisplayModeEnumTableSearch animate:NO];
}

#pragma mark - Responding to keyboard events

- (void)keyboardWillShow:(NSNotification *)notification {
}

- (void)keyboardWillHide:(NSNotification *)notification {
}

- (void)resizeViewWithKeyboard:(NSNotification *)notification {
    NSLog(@"SMILEY resizeViewWithKeyboard");

    NSDictionary *userInfo = [notification userInfo];
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    CGRect keyboardRect = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect convertedKeyboardRect = [self.view convertRect:keyboardRect fromView:self.view.window];
    CGRect safeAreaFrame = CGRectInset(self.view.safeAreaLayoutGuide.layoutFrame, 0, -self.additionalSafeAreaInsets.bottom);
    CGRect intersection = CGRectIntersection(safeAreaFrame, convertedKeyboardRect);
    
    //NSLog(@"### Keyboard  rect %@", NSStringFromCGRect(keyboardRect));
    //NSLog(@"### SafeFrame rect %@", NSStringFromCGRect(safeAreaFrame));
    NSLog(@"### SMILEY intersection rect %@", NSStringFromCGRect(intersection));

    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];

    // Animate the resize of the text view's frame in sync with the keyboard's appearance.
    [UIView beginAnimations:nil context:NULL];
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, intersection.size.height, 0);
    [self.view layoutIfNeeded];
    [UIView commitAnimations];
}

- (void)showTableViewInFullScreen
{
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    NSLog(@"SMILEY textFieldDidBeginEditing1");
    self.bActivateSmileySearchTable = YES;
    NSLog(@"SMILEY textFieldDidBeginEditing2");
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.2];

    [self changeDisplayMode:DisplayModeEnumTableSearch animate:NO];
    NSLog(@"SMILEY textFieldDidBeginEditing3");
    [self.addMessageVC updateExpandCompressSmiley];
    NSLog(@"SMILEY textFieldDidBeginEditing4");
    [UIView commitAnimations];
    /*
    if (self.bModeFullScreen) {
        NSLog(@"SMILEY bModeFullScreen -> NO");
        self.bModeFullScreen = NO;
        [self updateExpandButton];
    }*/
}



- (void)textFieldDidEndEditing:(UITextField *)textField
{
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (self.textFieldSmileys.text.length < 3) {
        return NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
 {
    NSLog(@"textFieldShouldClear %@", textField.text);
     return YES;
 }

- (void)actionSearch:(id)sender
{
    [self fetchSmileys];
}

-(IBAction)textFieldSmileChange:(id)sender
{
    [SmileyCache shared].bStopLoadingSmileysSearchToCache = YES;
    [self updateTableViewSearchFilters:[(UITextField *)sender text]];

}

- (void)updateTableViewSearchFilters:(NSString*)sText
{
    if (sText.length > 0) {
        sText = [sText stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        sText = [sText stringByReplacingOccurrencesOfString:@"\\" withString:@""];
        @try {
            self.arrTopSearchSortedFiltered = [self.arrTopSearchSorted filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SmileySearch* s, NSDictionary *bindings) {
                return [s.sSearchText containsString:sText];  // Return YES for each object you want in filteredArray.
            }]];
            self.arrLastSearchSortedFiltered = [self.arrLastSearchSorted filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SmileySearch* s, NSDictionary *bindings) {
                return [s.sSearchText containsString:sText];  // Return YES for each object you want in filteredArray.
            }]];

            [self.tableViewSearch reloadData];
        }
        @catch (NSException* exception) {
            NSLog(@"exception %@", exception);
        }
    }
    else {
        self.arrTopSearchSortedFiltered = self.arrTopSearchSorted;
        self.arrLastSearchSortedFiltered = self.arrLastSearchSorted;
        [self.tableViewSearch reloadData];
        if (self.smileyCache.bSearchSmileysActivated && self.displayMode == DisplayModeEnumSmileysSearch && self.bActivateSmileySearchTable == NO) {
            [self changeDisplayMode:DisplayModeEnumTableSearch animate:NO];
        }
    }
}

#pragma mark - Data lifecycle

- (void)fetchSmileys
{
    // Stop loading smileys of previous request
    [SmileyCache shared].bStopLoadingSmileysSearchToCache = YES;

    NSString *sTextSmileys = [NSString stringWithFormat:@"+%@", [[self.textFieldSmileys.text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@" +"]];
    NSMutableArray* smileyList = [[SmileyCache shared] getSmileyListForText:sTextSmileys];
    if (smileyList) {
        self.arrayTmpsmileySearch = smileyList;
        [self performSelectorInBackground:@selector(loadSmileys) withObject:nil];
    }
    else {
        [ASIHTTPRequest setDefaultTimeOutSeconds:kTimeoutMini];
        NSString * encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                         NULL,
                                                                                                         (CFStringRef)sTextSmileys,
                                                                                                         NULL,
                                                                                                         (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                                         kCFStringEncodingUTF8 ));
        
        [self setRequestSmile:[ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/message-smi-mp-aj.php?config=hfr.inc&findsmilies=%@", [k ForumURL], encodedString]]]];
        [requestSmile setDelegate:self];
        [requestSmile setDidStartSelector:@selector(fetchSmileContentStarted:)];
        [requestSmile setDidFinishSelector:@selector(fetchSmileContentComplete:)];
        [requestSmile setDidFailSelector:@selector(fetchSmileContentFailed:)];
        [requestSmile startAsynchronous];
    }
}

- (void)fetchSmileContentStarted:(ASIHTTPRequest *)theRequest
{
    NSLog(@"fetchSmileContentStarted %@", theRequest);
}

- (void)fetchSmileContentComplete:(ASIHTTPRequest *)theRequest
{
    NSLog(@"fetchSmileContentComplete %@", theRequest);
    //Traitement des smileys (to Array)
    [self.arrayTmpsmileySearch removeAllObjects]; //RaZ

    /*
    [self.segmentControlerPage setTitle:@"Smilies" forSegmentAtIndex:1];*/
    
    //NSDate *thenT = [NSDate date]; // Create a current date
    
    HTMLParser * myParser = [[HTMLParser alloc] initWithString:[theRequest safeResponseString] error:NULL];
    HTMLNode * smileNode = [myParser doc]; //Find the body tag
    NSArray * tmpImageArray =  [smileNode findChildTags:@"img"];
    for (HTMLNode * imgNode in tmpImageArray) { //Loop through all the tags
        [self.arrayTmpsmileySearch addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[imgNode getAttributeNamed:@"src"], [imgNode getAttributeNamed:@"alt"], nil] forKeys:[NSArray arrayWithObjects:@"source", @"code", nil]]];
    }

    if (self.arrayTmpsmileySearch.count == 0) {
        /*UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:@"Aucun résultat !"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                              }];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        [[ThemeManager sharedManager] applyThemeToAlertController:alert];
        self.bActivateSmileySearchTable = YES;*/
        
        labelNoResult.alpha = 0;
        labelNoResult.backgroundColor = [ThemeColors textFieldBackgroundColor];
        labelNoResult.textColor = [ThemeColors textColor];

        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDuration:0.5];
        labelNoResult.alpha = 1;
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
        [UIView commitAnimations];

    }
    else {
        // Save search when smiley is selected (this confirms the search is OK)
        if (self.textFieldSmileys.text.length >= 3) {
            //NSLog(@"SS saving %@", self.textFieldSmileys.text);
            NSArray *arrFound = [self.arrSearch filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SmileySearch* s, NSDictionary *bindings) {
                return [s.sSearchText isEqualToString:self.textFieldSmileys.text];  // Return YES for each object you want in filteredArray.
            }]];
            if (arrFound.count > 0) {

                SmileySearch* ss = (SmileySearch*)arrFound[0];
                ss.nSearchNumber = [NSNumber numberWithInt:[ss.nSearchNumber intValue] + 1];
                ss.dLastSearch = [NSDate date];
                //NSLog(@"SS %@ found, n:%d", self.textFieldSmileys.text, [ss.nSearchNumber intValue]);
            }
            else {
                SmileySearch* ss = [[SmileySearch alloc] init];
                ss.nSearchNumber = [NSNumber numberWithInt:[ss.nSearchNumber intValue] + 1];
                ss.dLastSearch = [NSDate date];
                ss.sSearchText = self.textFieldSmileys.text;
                if (self.arrSearch == nil) {
                    self.arrSearch = [[NSMutableArray alloc] init];
                }
                [self.arrSearch addObject:ss];
                //NSLog(@"SS %@ is new, n:%d", self.textFieldSmileys.text, [ss.nSearchNumber intValue]);
            }
            
            [self updateSearchArraySorted];
            
            NSString *directory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            NSString *file = [[NSString alloc] initWithString:[directory stringByAppendingPathComponent:SEARCH_SMILEYS_FILE]];
            NSMutableData *data = [[NSMutableData alloc] init];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];// error:&error];
            [archiver encodeObject:self.arrSearch];
            [archiver finishEncoding];
            [data writeToFile:file atomically:YES];
        }
        
        [self performSelectorOnMainThread:@selector(displaySmileys) withObject:nil waitUntilDone:YES];
        [self performSelectorInBackground:@selector(loadSmileys) withObject:nil];
    }
}

-(void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished  context:(void *)context
{
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:1.1];
    labelNoResult.alpha = 0;
    [UIView commitAnimations];
}
    
    
- (void) displaySmileys {
    [self.btnSmileySearch setEnabled:YES];
    [self.collectionViewSmileysSearch reloadData];
    self.bActivateSmileySearchTable = NO;
    [self changeDisplayMode:DisplayModeEnumSmileysSearch animate:NO];
    if (self.bModeFullScreen == NO) {
        [self.addMessageVC.textViewPostContent becomeFirstResponder];
    }
}

- (void) loadSmileys {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.addMessageVC updateExpandCompressSmiley];
    });
    [[SmileyCache shared] handleSearchSmileyArray:self.arrayTmpsmileySearch forCollection:self.collectionViewSmileysSearch
                                    spinner:self.spinnerSmileySearch];
}

- (void)fetchSmileContentFailed:(ASIHTTPRequest *)theRequest
{
    [self.spinnerSmileySearch stopAnimating];
    [self cancelFetchContent];
}

- (void)cancelFetchContent
{
    [self.request cancel];
    [self setRequest:nil];
}

#pragma mark - Action events

- (void) didSelectSmile:(NSString *)smile
{
    NSLog(@"didSelectSmile");
    [SmileyCache shared].bStopLoadingSmileysCustomToCache = YES;

    // ajout des espaces avant/aprés le smiley.
    smile = [NSString stringWithFormat:@" %@ ", smile];

    // Update main textField
    [[NSNotificationCenter defaultCenter] postNotificationName:@"smileyReceived" object:smile];
}



- (void)actionReduce:(id)sender {
    [self closePopup];
    [self.addMessageVC actionExpandCompressSmiley];
}

- (void)updateExpandButton {
    NSString* sImageName = @"rectangle.expand";
    if (self.bModeFullScreen) {
        sImageName = @"rectangle.compress";
    }
    Theme theme = [[ThemeManager sharedManager] theme];
    [self.btnReduce setImage:[ThemeColors tintImage:[UIImage imageNamed:sImageName] withTheme:theme] forState:UIControlStateNormal];
    [self.btnReduce setImage:[ThemeColors tintImage:[UIImage imageNamed:sImageName] withTheme:theme] forState:UIControlStateHighlighted];
}

- (void) updateSearchArraySorted
{
    NSSortDescriptor *sortDescriptorNumber = [[NSSortDescriptor alloc] initWithKey: @"nSearchNumber" ascending:NO selector:@selector(compare:)];
    NSSortDescriptor *sortDescriptorDate = [[NSSortDescriptor alloc] initWithKey: @"dLastSearch" ascending:NO selector:@selector(compare:)];
    self.arrTopSearchSorted = (NSMutableArray *)[self.arrSearch sortedArrayUsingDescriptors: [NSArray arrayWithObject:sortDescriptorNumber]];
    self.arrLastSearchSorted = (NSMutableArray *)[self.arrSearch sortedArrayUsingDescriptors: [NSArray arrayWithObject:sortDescriptorDate]];
    self.arrTopSearchSortedFiltered = self.arrTopSearchSorted;
    self.arrLastSearchSortedFiltered = self.arrLastSearchSorted;
}

- (void)actionSmileysDefaults:(id)sender {
    if (self.displayMode == DisplayModeEnumSmileysDefault) {
        return;
    }
    
    if (self.bModeFullScreen) {
        [self changeDisplayMode:DisplayModeEnumSmileysDefault animate:NO];
        //[self.addMessageVC updateExpandCompressSmiley];
        [self resignFirstResponder];
    }
    else {
        BOOL bSetFirstResponder = NO;
        if (self.displayMode != DisplayModeEnumSmileysDefault) {
            bSetFirstResponder = YES;
        }
        [self changeDisplayMode:DisplayModeEnumSmileysDefault animate:NO];
        [self.addMessageVC updateExpandCompressSmiley];
        if (bSetFirstResponder) {
            [self.addMessageVC.textViewPostContent becomeFirstResponder];
        }
    }
}


- (void)actionSmileysSearch:(id)sender {
    if (self.displayMode == DisplayModeEnumSmileysSearch) {
        return;
    }
    
    if (self.bModeFullScreen) {
        [self changeDisplayMode:DisplayModeEnumSmileysSearch animate:NO];
        //[self.addMessageVC updateExpandCompressSmiley];
        [self resignFirstResponder];
    }
    else {
        BOOL bSetFirstResponder = NO;
        if (self.displayMode != DisplayModeEnumSmileysSearch) {
            bSetFirstResponder = YES;
        }
        [self changeDisplayMode:DisplayModeEnumSmileysSearch animate:NO];
        [self.addMessageVC updateExpandCompressSmiley];
        if (bSetFirstResponder) {
            [self.addMessageVC.textViewPostContent becomeFirstResponder];
        }
    }
}

- (void)actionSmileysFavorites:(id)sender {
    if (self.displayMode == DisplayModeEnumSmileysFavorites) {
        return;
    }
    
    if (self.bModeFullScreen) {
        [self changeDisplayMode:DisplayModeEnumSmileysFavorites animate:NO];
        //[self.addMessageVC updateExpandCompressSmiley];
        [self resignFirstResponder];
    }
    else {
        BOOL bSetFirstResponder = NO;
        if (self.displayMode != DisplayModeEnumSmileysFavorites) {
            bSetFirstResponder = YES;
        }
        [self changeDisplayMode:DisplayModeEnumSmileysFavorites animate:NO];
        [self.addMessageVC updateExpandCompressSmiley];
        if (bSetFirstResponder) {
            [self.addMessageVC.textViewPostContent becomeFirstResponder];
        }
    }
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    // Stop loading smileys of previous request
    [SmileyCache shared].bStopLoadingSmileysCustomToCache = YES;
    NSLog(@"----------- STOP REQUIRED -----------");
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Stop loading smileys of previous request
    [SmileyCache shared].bStopLoadingSmileysCustomToCache = YES;
    NSLog(@"----------- STOP REQUIRED -----------");
}
@end
