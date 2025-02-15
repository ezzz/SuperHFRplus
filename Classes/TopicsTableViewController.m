//
//  TopicsTableViewController.m
//  HFRplus
//
//  Created by FLK on 06/07/10.
//

#import "HFRplusAppDelegate.h"

#import "ASIHTTPRequest+Tools.h"
#import "Constants.h"
#import "HTMLParser.h"

#import "ShakeView.h"

#import "TopicsTableViewController.h"
#import "MessagesTableViewController.h"
#import "HFRMPViewController.h"

#import "TopicCellView.h"
#import "Topic.h"

#import "SubCatTableViewController.h"

#import "UIScrollView+SVPullToRefresh.h"
#import "PullToRefreshErrorViewController.h"

#import "AideViewController.h"

#import "ThemeColors.h"
#import "ThemeManager.h"

@implementation TopicsTableViewController
@synthesize forumNewTopicUrl, forumName, loadingView, topicsTableView, arrayData, arrayNewData;
@synthesize messagesTableViewController, errorVC;

@synthesize swipeLeftRecognizer, swipeRightRecognizer;

@synthesize pressedIndexPath;
@synthesize imageForSelectedRow, imageForUnselectedRow;

@synthesize imageForRedFlag, imageForYellowFlag, imageForBlueFlag;

@synthesize forumBaseURL, forumFavorisURL, forumFlag1URL, forumFlag0URL;

@synthesize request;

@synthesize myPickerView, pickerViewArray, actionSheet, topicActionAlert, subCatSegmentedControl;


@synthesize tmpCell;
@synthesize status, statusMessage, maintenanceView, selectedFlagIndex;

@synthesize popover = _popover;

#pragma mark -
#pragma mark Data lifecycle

- (void)cancelFetchContent
{
    [self.request cancel];
    [self setRequest:nil];
}

- (void)fetchContent
{
    [self.topicsTableView setContentOffset:CGPointZero animated:YES];
    [self.topicsTableView triggerPullToRefresh];
}

- (void)fetchContentTrigger
{
    if(![self currentUrl]){
        [self cancelFetchContent];
         [self.topicsTableView.pullToRefreshView stopAnimating];
        return;
    }
	NSLog(@"fetchContent %@", [NSString stringWithFormat:@"%@%@", [k ForumURL], [self currentUrl]]);
	self.status = kIdle;
	[ASIHTTPRequest setDefaultTimeOutSeconds:kTimeoutMini];

	[self setRequest:[ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [k ForumURL], [self currentUrl]]]]];
	[request setShouldRedirect:NO];

	[request setDelegate:self];
	
	[request setDidStartSelector:@selector(fetchContentStarted:)];
	[request setDidFinishSelector:@selector(fetchContentComplete:)];
	[request setDidFailSelector:@selector(fetchContentFailed:)];

	[self.view removeGestureRecognizer:swipeLeftRecognizer];
	[self.view removeGestureRecognizer:swipeRightRecognizer];
	

	[request startAsynchronous];
}

- (void)fetchContentStarted:(ASIHTTPRequest *)theRequest
{
	//[self.maintenanceView setHidden:YES];
	//[self.topicsTableView setHidden:YES];
	//[self.loadingView setHidden:NO];
	
	//--
}

- (void)fetchContentComplete:(ASIHTTPRequest *)theRequest
{
    [self loadDataInTableView:[theRequest responseData]];
	
    [self.arrayData removeAllObjects];
    
    self.arrayData = [NSMutableArray arrayWithArray:self.arrayNewData];
    
    [self.arrayNewData removeAllObjects];
    
	[self.topicsTableView reloadData];
    
    [self.topicsTableView.pullToRefreshView stopAnimating];
    [self.topicsTableView.pullToRefreshView setLastUpdatedDate:[NSDate date]];
    
	[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setUserInteractionEnabled:YES];
    [self cancelFetchContent];
}

- (void)fetchContentFailed:(ASIHTTPRequest *)theRequest
{
    NSLog(@"fetchContentFailed");
    [self.maintenanceView setText:@"oops :o"];
    
    //[self.loadingView setHidden:YES];
    //[self.maintenanceView setHidden:NO];
    //[self.topicsTableView setHidden:YES];
	
    [self.topicsTableView.pullToRefreshView stopAnimating];
    
	[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setUserInteractionEnabled:YES];
	
    // Popup retry
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Ooops !" message:[theRequest.error localizedDescription]  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) { [self cancelFetchContent]; }];
    UIAlertAction* actionRetry = [UIAlertAction actionWithTitle:@"Réessayer" style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action) { [self fetchContent]; }];
    [alert addAction:actionCancel];
    [alert addAction:actionRetry];
    
    [self presentViewController:alert animated:YES completion:nil];
    [[ThemeManager sharedManager] applyThemeToAlertController:alert];
}


#pragma mark -
#pragma mark View lifecycle

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        self.selectedFlagIndex = 0;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil flag:(int)flag {
    if ((self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        self.selectedFlagIndex = flag;
    }
    return self;
}

-(void)loadDataInTableView:(NSData *)contentData
{
    NSLog(@"TOPICS loadDataInTableView");
	[self.view removeGestureRecognizer:swipeLeftRecognizer];
	[self.view removeGestureRecognizer:swipeRightRecognizer];	
	
	HTMLParser * myParser = [[HTMLParser alloc] initWithData:contentData error:NULL];
	HTMLNode * bodyNode = [myParser body];

	//NSLog(@"rawContentsOfNode %@", rawContentsOfNode([bodyNode _node], [myParser _doc]));
	
	if (![bodyNode getAttributeNamed:@"id"]) {
        NSDictionary *notif;
        
		if ([[[bodyNode firstChild] tagName] isEqualToString:@"p"]) {
            
            notif = [NSDictionary dictionaryWithObjectsAndKeys:   [NSNumber numberWithInt:kMaintenance], @"status",
                     [[[bodyNode firstChild] contents] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"message", nil];
            
		}
        else {
            notif = [NSDictionary dictionaryWithObjectsAndKeys:   [NSNumber numberWithInt:kNoAuth], @"status",
                     [[[bodyNode findChildWithAttribute:@"class" matchingName:@"hop" allowPartial:NO] contents] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"message", nil];
            
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kStatusChangedNotification object:self userInfo:notif];
        
		return;
	}

	
	//MP
	BOOL needToUpdateMP = NO;
	HTMLNode *MPNode = [bodyNode findChildOfClass:@"none"]; //Get links for cat	
	NSArray *temporaryMPArray = [MPNode findChildTags:@"td"];
	
	if (temporaryMPArray.count == 3) {
		
		NSString *regExMP = @"[^.0-9]+([0-9]{1,})[^.0-9]+";			
		NSString *myMPNumber = [[[temporaryMPArray objectAtIndex:1] allContents] stringByReplacingOccurrencesOfRegex:regExMP
																										  withString:@"$1"];
		
		[[HFRplusAppDelegate sharedAppDelegate] updateMPBadgeWithString:myMPNumber];
	}
	else {
		if ([self isKindOfClass:[HFRMPViewController class]]) {
			needToUpdateMP = YES;
		}
	}
	//MP

	//On remplace le numéro de page dans le titre
	NSString *regexString  = @".*page=([^&]+).*";
    NSRange   matchedRange;// = NSMakeRange(NSNotFound, 0UL);
	NSRange   searchRange = NSMakeRange(0, self.currentUrl.length);
	NSError  *error2        = NULL;
	//int numPage;
	
	matchedRange = [self.currentUrl rangeOfRegex:regexString options:RKLNoOptions inRange:searchRange capture:1L error:&error2];
	
	if (matchedRange.location == NSNotFound) {
		NSRange rangeNumPage =  [[self currentUrl] rangeOfCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] options:NSBackwardsSearch];
		self.pageNumber = [[self.currentUrl substringWithRange:rangeNumPage] intValue];
	}
	else {
		self.pageNumber = [[self.currentUrl substringWithRange:matchedRange] intValue];
		
	}
	
	//[(UILabel *)[self navigationItem].titleView setText:[NSString stringWithFormat:@"%@ — %d", self.forumName, numPage]];
	//NSLog(@"forumUrl %@ — %d", [self forumName], numPage); 
	
	
	//New Topic URL
	HTMLNode * forumNewTopicNode = [bodyNode findChildWithAttribute:@"id" matchingName:@"md_btn_new_topic" allowPartial:NO];
	forumNewTopicUrl = [forumNewTopicNode getAttributeNamed:@"href"];

	if(forumNewTopicUrl.length > 0) self.navigationItem.rightBarButtonItem.enabled = YES;
	//-

	//Filtres
	HTMLNode *FiltresNode =		[bodyNode findChildWithAttribute:@"class" matchingName:@"cadreonglet" allowPartial:NO];
	
	if([FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet1" allowPartial:NO]) self.forumBaseURL = [[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet1" allowPartial:NO] getAttributeNamed:@"href"];
    
	if ([[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet2" allowPartial:NO] getAttributeNamed:@"href"]) {
		if(!self.forumFavorisURL)	self.forumFavorisURL = [[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet2" allowPartial:NO] getAttributeNamed:@"href"];
		[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setEnabled:YES forSegmentAtIndex:1];		
	}
	else {
		[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setEnabled:NO forSegmentAtIndex:1];
	}

	if ([[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet3" allowPartial:NO] getAttributeNamed:@"href"]) {
		if(!self.forumFlag1URL)		self.forumFlag1URL = [[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet3" allowPartial:NO] getAttributeNamed:@"href"];
		[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setEnabled:YES forSegmentAtIndex:2];		
	}
	else {
		[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setEnabled:NO forSegmentAtIndex:2];
	}	

	if ([[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet4" allowPartial:NO] getAttributeNamed:@"href"]) {
		if(!self.forumFlag0URL)		self.forumFlag0URL = [[FiltresNode findChildWithAttribute:@"id" matchingName:@"onglet4" allowPartial:NO] getAttributeNamed:@"href"];
		[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setEnabled:YES forSegmentAtIndex:3];
	}
	else {
		[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setEnabled:NO forSegmentAtIndex:3];
	}
	//NSLog(@"Filtres1Node %@", rawContentsOfNode([Filtres1Node _node], [myParser _doc]));
	//-- FIN Filtre

	HTMLNode * pagesTrNode = [bodyNode findChildWithAttribute:@"class" matchingName:@"fondForum1PagesHaut" allowPartial:YES];

	
	if(pagesTrNode)
	{	
		HTMLNode * pagesLinkNode = [pagesTrNode findChildWithAttribute:@"class" matchingName:@"left" allowPartial:NO];
		
		//NSLog(@"pagesLinkNode %@", rawContentsOfNode([pagesLinkNode _node], [myParser _doc]));

		if (pagesLinkNode) {
			//NSLog(@"pagesLinkNode %@", rawContentsOfNode([pagesLinkNode _node], [myParser _doc]));
			
			//NSArray *temporaryNumPagesArray = [[NSArray alloc] init];
			NSArray *temporaryNumPagesArray = [pagesLinkNode children];
			
			[self setFirstPageNumber:[[[temporaryNumPagesArray objectAtIndex:2] contents] intValue]];
			
			if ([self pageNumber] == [self firstPageNumber]) {
				NSString *newFirstPageUrl = [[NSString alloc] initWithString:[self currentUrl]];
				[self setFirstPageUrl:newFirstPageUrl];
			}
			else {
				NSString *newFirstPageUrl;
				
				if ([[[temporaryNumPagesArray objectAtIndex:2] tagName] isEqualToString:@"span"]) {
					newFirstPageUrl = [[NSString alloc] initWithString:[[[temporaryNumPagesArray objectAtIndex:2] className] decodeSpanUrlFromString2]];
				}
				else {
					newFirstPageUrl = [[NSString alloc] initWithString:[[temporaryNumPagesArray objectAtIndex:2] getAttributeNamed:@"href"]];
				}
				
				[self setFirstPageUrl:newFirstPageUrl];
			}
			
			[self setLastPageNumber:[[[temporaryNumPagesArray lastObject] contents] intValue]];
			
			if ([self pageNumber] == [self lastPageNumber]) {
				NSString *newLastPageUrl = [[NSString alloc] initWithString:[self currentUrl]];
				[self setLastPageUrl:newLastPageUrl];
			}
			else {
				NSString *newLastPageUrl;
				
				if ([[[temporaryNumPagesArray lastObject] tagName] isEqualToString:@"span"]) {
					newLastPageUrl = [[NSString alloc] initWithString:[[[temporaryNumPagesArray lastObject] className] decodeSpanUrlFromString2]];
				}
				else {
					newLastPageUrl = [[NSString alloc] initWithString:[[temporaryNumPagesArray lastObject] getAttributeNamed:@"href"]];
				}
				
				[self setLastPageUrl:newLastPageUrl];
			}
			
			/*
			 NSLog(@"premiere %d", [self firstPageNumber]);			
			 NSLog(@"premiere url %@", [self firstPageUrl]);
			 
			 NSLog(@"premiere %d", [self lastPageNumber]);			
			 NSLog(@"premiere url %@", [self lastPageUrl]);		
			 */
			
			//TableFooter
			UIToolbar *tmptoolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
            
            if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
                tmptoolbar.barStyle = -1;
                
                tmptoolbar.opaque = NO;
                tmptoolbar.translucent = YES;
                
                if (tmptoolbar.subviews.count > 1)
                {
                    [[tmptoolbar.subviews objectAtIndex:1] setHidden:YES];
                }
                
                if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")) {                    
                    [tmptoolbar setBackgroundImage:[ThemeColors imageFromColor:[ThemeColors toolbarPageBackgroundColor:[[ThemeManager sharedManager] theme]]]
                                forToolbarPosition:UIBarPositionAny
                                        barMetrics:UIBarMetricsDefault];
                    [tmptoolbar setShadowImage:[UIImage new]
                            forToolbarPosition:UIBarPositionAny];
                    
                }
                
                
            }
            
			[tmptoolbar sizeToFit];

			UIBarButtonItem *systemItemNext = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowforward"] 
																			   style:UIBarButtonItemStyleBordered 
																			  target:self 
																			  action:@selector(nextPage:)];

			
			//systemItemNext.imageInsets = UIEdgeInsetsMake(2.0, 0, -2.0, 0);
			
			UIBarButtonItem *systemItemPrevious = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowback"] 
																			   style:UIBarButtonItemStyleBordered 
																			  target:self 
																			  action:@selector(previousPage:)];	

			//systemItemPrevious.imageInsets = UIEdgeInsetsMake(2.0, 0, -2.0, 0);


			
			
			UIBarButtonItem *systemItem1 = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowbegin"] 
																				   style:UIBarButtonItemStyleBordered 
																				  target:self 
																				  action:@selector(firstPage:)];	
			
			//systemItem1.imageInsets = UIEdgeInsetsMake(2.0, 0, -2.0, 0);

			if ([self pageNumber] == [self firstPageNumber]) {
				[systemItem1 setEnabled:NO];
				[systemItemPrevious setEnabled:NO];
			}
			
			UIBarButtonItem *systemItem2 = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowend"] 
																			style:UIBarButtonItemStyleBordered 
																		   target:self 
																		   action:@selector(lastPage:)];	
			
			//systemItem2.imageInsets = UIEdgeInsetsMake(2.0, 0, -2.0, 0);

			if ([self pageNumber] == [self lastPageNumber]) {
				[systemItem2 setEnabled:NO];
				[systemItemNext setEnabled:NO];
			}		

			UIButton *labelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
			labelBtn.frame = CGRectMake(0, 0, 130, 44);
			[labelBtn addTarget:self action:@selector(choosePage) forControlEvents:UIControlEventTouchUpInside];
			[labelBtn setTitle:[NSString stringWithFormat:@"%d/%d", [self pageNumber], [self lastPageNumber]] forState:UIControlStateNormal];
			
            [[labelBtn titleLabel] setFont:[UIFont boldSystemFontOfSize:16.0]];

            if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                    [labelBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    [labelBtn setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                    [labelBtn titleLabel].shadowOffset = CGSizeMake(0.0, -1.0);
                }
                else {
                    [labelBtn setTitleColor:[UIColor colorWithRed:113/255.0 green:120/255.0 blue:128/255.0 alpha:1.0] forState:UIControlStateNormal];
                    [labelBtn setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    [labelBtn titleLabel].shadowColor = [UIColor whiteColor];
                    [labelBtn titleLabel].shadowOffset = CGSizeMake(0.0, 1.0);
                }
            }
            else
            {
                [labelBtn setTitleColor:[ThemeColors cellIconColor:[[ThemeManager sharedManager] theme]] forState:UIControlStateNormal];
            }
			UIBarButtonItem *systemItem3 = [[UIBarButtonItem alloc] initWithCustomView:labelBtn];
			
			//Use this to put space in between your toolbox buttons
			UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
																					  target:nil
																					  action:nil];
			UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
																					  target:nil
																					  action:nil];
			fixItem.width = SPACE_FOR_BARBUTTON;
			
			//Add buttons to the array
			NSArray *items = [NSArray arrayWithObjects: systemItem1, fixItem, systemItemPrevious, flexItem, systemItem3, flexItem, systemItemNext, fixItem, systemItem2, nil];
			
			//release buttons
			
			

			//add array of buttons to toolbar
			[tmptoolbar setItems:items animated:NO];
			
			if ([self firstPageNumber] != [self lastPageNumber]) {
                
                
                
                if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
                    if (![self.topicsTableView viewWithTag:666777]) {
                        CGRect frame = self.topicsTableView.bounds;
                        frame.origin.y = -frame.size.height;
                        UIView* grayView = [[UIView alloc] initWithFrame:frame];
                        grayView.tag = 666777;
                        grayView.backgroundColor = [ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]];
                        [self.topicsTableView insertSubview:grayView atIndex:0];
                    }

                    [self.topicsTableView setBackgroundColor:[ThemeColors addMessageBackgroundColor:[[ThemeManager sharedManager] theme]]];
                }
                
				self.topicsTableView.tableFooterView = tmptoolbar;
			}
			else {
				self.topicsTableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
			}

			//self.aToolbar = tmptoolbar;
			
		}
		else {
			//self.aToolbar = nil;
			//NSLog(@"pas de pages");
			
		}
		
		//Gestion des pages
		NSArray *temporaryPagesArray = [pagesTrNode findChildrenWithAttribute:@"class" matchingName:@"pagepresuiv" allowPartial:YES];
			
		if(temporaryPagesArray.count != 2)
		{
			//NSLog(@"pas 2");	
		}
		else {
			
			HTMLNode *nextUrlNode = [[temporaryPagesArray objectAtIndex:0] findChildWithAttribute:@"class" matchingName:@"md_cryptlink" allowPartial:YES];

			if (nextUrlNode) {
				
				self.nextPageUrl = [[nextUrlNode className] decodeSpanUrlFromString2];
				[self.view addGestureRecognizer:swipeLeftRecognizer];
				//NSLog(@"nextPageUrl = %@", self.nextPageUrl);

			}
			else {
				self.nextPageUrl = @"";
			}
			
			HTMLNode *previousUrlNode = [[temporaryPagesArray objectAtIndex:1] findChildWithAttribute:@"class" matchingName:@"md_cryptlink" allowPartial:YES];
			
			if (previousUrlNode) {
				
				self.previousPageUrl = [[previousUrlNode className] decodeSpanUrlFromString2];
				[self.view addGestureRecognizer:swipeRightRecognizer];
				//NSLog(@"previousPageUrl = %@", self.previousPageUrl);

			}
			else {
				self.previousPageUrl = @"";
			}

		}
		//-- Gestion des pages
			
		
	}

	
	NSArray *temporaryTopicsArray = [bodyNode findChildrenWithAttribute:@"class" matchingName:@"sujet ligne_booleen" allowPartial:YES]; //Get links for cat

	if (temporaryTopicsArray.count == 0) {
		//NSLog(@"Aucun nouveau message %d", self.arrayDataID.count);
        NSLog(@"kNoResults");
        
        NSDictionary *notif = [NSDictionary dictionaryWithObjectsAndKeys:   [NSNumber numberWithInt:kNoResults], @"status",
                               @"Aucun message", @"message", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kStatusChangedNotification object:self userInfo:notif];
		return;
	}
	
	
	//Date du jour
	NSDate *nowTopic = [[NSDate alloc] init];
	NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
	[dateFormat setDateFormat:@"dd-MM-yyyy"];
	NSString *theDate = [dateFormat stringFromDate:nowTopic];
	
	int countViewed = 0;
	

	for (HTMLNode * topicNode in temporaryTopicsArray) { //Loop through all the tags
        
		@autoreleasepool {

			Topic *aTopic = [[Topic alloc] init];
			
			//Title & URL
			HTMLNode * topicTitleNode = [topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase3" allowPartial:NO];

            NSString *aTopicAffix = [NSString string];
            NSString *aTopicSuffix = [NSString string];

			
			if ([[topicNode className] rangeOfString:@"ligne_sticky"].location != NSNotFound) {
				aTopicAffix = [aTopicAffix stringByAppendingString:@""];//➫ ➥▶✚
                aTopic.isSticky = YES;
			}
			if ([topicTitleNode findChildWithAttribute:@"alt" matchingName:@"closed" allowPartial:NO]) {
				aTopicAffix = [aTopicAffix stringByAppendingString:@""];
                aTopic.isClosed = YES;
			}
			
			if (aTopicAffix.length > 0) {
				aTopicAffix = [aTopicAffix stringByAppendingString:@" "];
			}

            aTopicAffix = @"";

			NSString *aTopicTitle = [[NSString alloc] initWithFormat:@"%@%@%@", aTopicAffix, [[topicTitleNode allContents] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], aTopicSuffix];
			[aTopic setATitle:aTopicTitle];

			NSString *aTopicURL = [[NSString alloc] initWithString:[[topicTitleNode findChildTag:@"a"] getAttributeNamed:@"href"]];
			[aTopic setAURL:aTopicURL];

			//Answer Count
			HTMLNode * numRepNode = [topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase7" allowPartial:NO];
			[aTopic setARepCount:[[numRepNode contents] intValue]];

            HTMLNode * pollImage = [topicNode findChildWithAttribute:@"src" matchingName:@"https://forum-images.hardware.fr/themes_static/images/defaut/sondage.gif" allowPartial:NO];
            if (pollImage != nil) {
                aTopic.isPoll = YES;
            }

			//Setup of Flag		
			HTMLNode * topicFlagNode = [topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase5" allowPartial:NO];
			HTMLNode * topicFlagLinkNode = [topicFlagNode findChildTag:@"a"];
			if (topicFlagLinkNode) {
				HTMLNode * topicFlagImgNode = [topicFlagLinkNode firstChild];

				NSString *aURLOfFlag = [[NSString alloc] initWithString:[topicFlagLinkNode getAttributeNamed:@"href"]];
				[aTopic setAURLOfFlag:aURLOfFlag];
				
				NSString *imgFlagSrc = [[NSString alloc] initWithString:[topicFlagImgNode getAttributeNamed:@"src"]];
				
				if (!([imgFlagSrc rangeOfString:@"flag0.gif"].location == NSNotFound)) {
					[aTopic setATypeOfFlag:@"red"];
				}
				else if (!([imgFlagSrc rangeOfString:@"flag1.gif"].location == NSNotFound)) {
					[aTopic setATypeOfFlag:@"blue"];
				}
				else if (!([imgFlagSrc rangeOfString:@"favoris.gif"].location == NSNotFound)) {
					[aTopic setATypeOfFlag:@"yellow"];
				}
			
			}
			else {
				[aTopic setAURLOfFlag:@""];
				[aTopic setATypeOfFlag:@""];
			}

			//Viewed?
			[aTopic setIsViewed:YES];
			HTMLNode * viewedNode = [topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase1" allowPartial:YES];
			HTMLNode * viewedFlagNode = [viewedNode findChildTag:@"img"];
			if (viewedFlagNode) {
				NSString *viewedFlagAlt = [viewedFlagNode getAttributeNamed:@"alt"];
			
				if ([viewedFlagAlt isEqualToString:@"On"]) {
					[aTopic setIsViewed:NO];
					countViewed++;
				}

			}


			//aAuthorOrInter
			HTMLNode * interNode = [topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase6" allowPartial:YES];	
                
			if ([[interNode findChildTag:@"a"] contents]) {
				NSString *aAuthorOrInter = [[NSString alloc] initWithFormat:@"%@", [[interNode findChildTag:@"a"] contents]];
            [aTopic setAAuthorOrInter:aAuthorOrInter];
			}
			else if ([[interNode findChildTag:@"span"] contents]) {
				NSString *aAuthorOrInter = [[NSString alloc] initWithFormat:@"%@", [[interNode findChildTag:@"span"] contents]];
				[aTopic setAAuthorOrInter:aAuthorOrInter];
			}
			else {
				[aTopic setAAuthorOrInter:@""];
			}



			//Author & Url of Last Post & Date
			HTMLNode * lastRepNode = [topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase9" allowPartial:YES];		
			HTMLNode * linkLastRepNode = [lastRepNode firstChild];
        
        if ([[linkLastRepNode findChildTag:@"b"] contents]) {
            NSString *aAuthorOfLastPost = [[NSString alloc] initWithFormat:@"%@", [[linkLastRepNode findChildTag:@"b"] contents]];
            [aTopic setAAuthorOfLastPost:aAuthorOfLastPost];
        }
			else {
				[aTopic setAAuthorOfLastPost:@""];
			}
			
			NSString *aURLOfLastPost = [[NSString alloc] initWithString:[linkLastRepNode getAttributeNamed:@"href"]];
			[aTopic setAURLOfLastPost:aURLOfLastPost];
			

			NSString *maDate = [linkLastRepNode contents];
            NSDateFormatter * df = [[NSDateFormatter alloc] init];
            [df setTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Paris"]];
            [df setDateFormat:@"dd-MM-yyyy à HH:mm"];
            aTopic.dDateOfLastPost = [df dateFromString:maDate];
                NSTimeInterval secondsBetween = [nowTopic timeIntervalSinceDate:aTopic.dDateOfLastPost];
                int numberMinutes = secondsBetween / 60;
                int numberHours = secondsBetween / 3600;
                if (secondsBetween < 0)
                {
                    [aTopic setADateOfLastPost:[maDate substringFromIndex:13]];
                }
                else if (numberMinutes == 0)
                {
                    [aTopic setADateOfLastPost:@"il y a 1 min"];
                }
                else if (numberMinutes >= 1 && numberMinutes < 60)
                {
                    [aTopic setADateOfLastPost:[NSString stringWithFormat:@"il y a %d min",numberMinutes]];
                }
                else if (secondsBetween >= 3600 && secondsBetween < 24*3600)
                {
                    [aTopic setADateOfLastPost:[NSString stringWithFormat:@"il y a %d h",numberHours]];
                }
                else
                {
				[aTopic setADateOfLastPost:[NSString stringWithFormat:@"%@/%@/%@", [maDate substringWithRange:NSMakeRange(0, 2)]
									  , [maDate substringWithRange:NSMakeRange(3, 2)]
									  , [maDate substringWithRange:NSMakeRange(8, 2)]]];
			}

			//URL of Last Page & maxPage
			HTMLNode * topicLastPageNode = [[topicNode findChildWithAttribute:@"class" matchingName:@"sujetCase4" allowPartial:NO] findChildTag:@"a"];
			if (topicLastPageNode) {
				NSString *aURLOfLastPage = [[NSString alloc] initWithString:[topicLastPageNode getAttributeNamed:@"href"]];
				[aTopic setAURLOfLastPage:aURLOfLastPage];
            [aTopic setMaxTopicPage:[[topicLastPageNode contents] intValue]];

			}
			else {
				[aTopic setAURLOfLastPage:[aTopic aURL]];
            [aTopic setMaxTopicPage:1];
            
			}
        
			[self.arrayNewData addObject:aTopic];

		}
		
	}
	
	if (needToUpdateMP) {
		//NSLog(@"J'update avec countViewed");
		[[HFRplusAppDelegate sharedAppDelegate] updateMPBadgeWithString:[NSString stringWithFormat:@"%d", countViewed]];
	}
	
	
	//NSDate *now = [NSDate date]; // Create a current date
	
	//NSLog(@"TOPICS Time elapsed initWithContentsOfURL : %f", [then0 timeIntervalSinceDate:then]);
	//NSLog(@"TOPICS Time elapsed initWithData          : %f", [then1 timeIntervalSinceDate:then0]);
	//NSLog(@"TOPICS Time elapsed myParser              : %f", [then2 timeIntervalSinceDate:then1]);
	//NSLog(@"TOPICS Time elapsed arraydata             : %f", [now timeIntervalSinceDate:then2]);
	//NSLog(@"TOPICS Time elapsed Total                 : %f", [now timeIntervalSinceDate:then]);
    if (self.status != kNoResults) {
        NSDictionary *notif = [NSDictionary dictionaryWithObjectsAndKeys:   [NSNumber numberWithInt:kComplete], @"status", nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kStatusChangedNotification object:self userInfo:notif];
    }
}

-(void)reset
{
	//NSLog(@"TOPIC RESET");
	//[self viewDidUnload];
	[self.arrayData removeAllObjects];
	
	[self.topicsTableView reloadData];
	
	//[self.topicsTableView setHidden:YES];
	//[self.maintenanceView setHidden:YES];
	//[self.loadingView setHidden:YES];
}

-(NSString *)newTopicTitle
{
	return @"Nouv. Sujet";	
}

-(void)newTopic
{
	//[[HFRplusAppDelegate sharedAppDelegate] openURL:[NSString stringWithFormat:@"http://forum.hardware.fr%@", forumNewTopicUrl]];

	NewMessageViewController *editMessageViewController = [[NewMessageViewController alloc]
															initWithNibName:@"AddMessageViewController" bundle:nil];
	editMessageViewController.delegate = self;
	[editMessageViewController setUrlQuote:[NSString stringWithFormat:@"%@%@", [k ForumURL], forumNewTopicUrl]];
	editMessageViewController.title = [self newTopicTitle];
	// Create the navigation controller and present it modally.
	HFRNavigationController *navigationController = [[HFRNavigationController alloc]
													initWithRootViewController:editMessageViewController];

    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
	[self presentModalViewController:navigationController animated:YES];
	
	// The navigation controller is now owned by the current view controller
	// and the root view controller is owned by the navigation controller,
	// so both objects should be released to prevent over-retention.

}

-(void)loadSubCat
{
    [_popover dismissPopoverAnimated:YES];
    
    [self dismissModalViewControllerAnimated:YES];

    
	//NSLog(@"curName %@", self.forumName);
	
	//NSLog(@"newName %@", [[pickerViewArray objectAtIndex:[myPickerView selectedRowInComponent:0]] aTitle]);

	if (![self.forumName isEqualToString:[[pickerViewArray objectAtIndex:[myPickerView selectedRowInComponent:0]] aTitle]]) {
		//NSLog(@"On switch");
        
		self.currentUrl = [[pickerViewArray objectAtIndex:[myPickerView selectedRowInComponent:0]] aURL];
		self.forumName = [[pickerViewArray objectAtIndex:[myPickerView selectedRowInComponent:0]] aTitle];
		self.forumBaseURL = self.currentUrl;

		self.forumFavorisURL = nil;
		self.forumFlag1URL = nil;
		self.forumFlag0URL = nil;	
			
		self.title = forumName;
		
		if ([(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] selectedSegmentIndex] == 0) {
			[self segmentFilterAction];
		}
		else {
			[(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setSelectedSegmentIndex:0];
            [self segmentFilterAction];
		}
	}
	else {
		
	}
	
	[self dismissActionSheet];

}

-(void)OrientationChanged
{
    if (topicActionAlert) {
        [topicActionAlert dismissViewControllerAnimated:YES completion:nil];
    }
    
}

-(void)StatusChanged:(NSNotification *)notification {
    
    if ([[notification object] class] != [self class]) {
        //NSLog(@"KO");
        return;
    }
    
    NSDictionary *notif = [notification userInfo];
    
    self.status = [[notif valueForKey:@"status"] intValue];
    
    //NSLog(@"StatusChanged %d = %u", self.childViewControllers.count, self.status);
    
    //on vire l'eventuel header actuel
    if (self.childViewControllers.count > 0) {
        [[self.childViewControllers objectAtIndex:0] removeFromParentViewController];
        self.topicsTableView.tableHeaderView = nil;
    }
    
    if (self.status == kComplete || self.status == kIdle) {
        //NSLog(@"COMPLETE %d", self.childViewControllers.count);
        
    }
    else {
        self.errorVC = [[PullToRefreshErrorViewController alloc] initWithNibName:nil bundle:nil andDico:notif];
        [self addChildViewController:self.errorVC];
        
        self.topicsTableView.tableHeaderView = self.errorVC.view;
        [self.errorVC sizeToFit];
        [self.errorVC applyTheme];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = forumName;
    self.navigationController.navigationBar.translucent = NO;

    NSLog(@"self nav %@", self.navigationController);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(OrientationChanged)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(StatusChanged:)
                                                 name:kStatusChangedNotification
                                               object:nil];
    

    


	//Gesture
	UIGestureRecognizer *recognizer;
	
	//De Gauche à droite
	recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeToRight:)];
	self.swipeRightRecognizer = (UISwipeGestureRecognizer *)recognizer;
	
	[self.view addGestureRecognizer:swipeRightRecognizer];
	
	self.swipeRightRecognizer = (UISwipeGestureRecognizer *)recognizer;
	
	//De Droite à gauche
	recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeToLeft:)];
	self.swipeLeftRecognizer = (UISwipeGestureRecognizer *)recognizer;
	swipeLeftRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
	
	[self.view addGestureRecognizer:swipeLeftRecognizer];
	
	self.swipeLeftRecognizer = (UISwipeGestureRecognizer *)recognizer;
	//-- Gesture

	//Filtres
	// "Segmented" control to the right
	//Title View
	self.navigationItem.titleView = [[UIView alloc] init];//WithFrame:CGRectMake(0, 0, 120, self.navigationController.navigationBar.frame.size.height - 14)];
	
    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@"Retour"
                                     style: UIBarButtonItemStyleBordered
                                    target:nil
                                    action:nil];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
        self.navigationItem.backBarButtonItem.title = @" ";
    }
    
    
	//Filter Control
    UISegmentedControl *segmentedControl;
    
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        
         segmentedControl = [[UISegmentedControl alloc] initWithItems:
                                                [NSArray arrayWithObjects:
                                                 @"Tous",
                                                 @"Favoris",
                                                 @"Suivis",
                                                 @"Lus",
                                                 nil]];
        
        [segmentedControl setWidth:38.0f forSegmentAtIndex:0];
        [segmentedControl setWidth:44.0f forSegmentAtIndex:1];
        [segmentedControl setWidth:38.0f forSegmentAtIndex:2];
        [segmentedControl setWidth:32.0f forSegmentAtIndex:3];
        
        
        
        UIFont *font = [UIFont systemFontOfSize:10.0f];
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:font
                                                               forKey:UITextAttributeFont];
        [segmentedControl setTitleTextAttributes:attributes
                                        forState:UIControlStateNormal];
        
    }
    else
    {
        segmentedControl = [[UISegmentedControl alloc] initWithItems:
                                                [NSArray arrayWithObjects:
                                                 [UIImage imageNamed:@"global.gif"],
                                                 [UIImage imageNamed:@"multiplefavoris.gif"],
                                                 [UIImage imageNamed:@"multipleflag1.gif"],
                                                 [UIImage imageNamed:@"multipleflag0.gif"],												 
                                                 nil]];
    }
    
    
    [segmentedControl setUserInteractionEnabled:NO];

	[segmentedControl addTarget:self action:@selector(segmentFilterAction) forControlEvents:UIControlEventValueChanged];
	segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;

	//NSLog(@"sg	%@", segmentedControl);
	[self.navigationItem.titleView insertSubview:segmentedControl atIndex:1];

    
	//SubCats Control
    if (self.pickerViewArray.count) {
        
        UISegmentedControl *segmentedControl2;
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            segmentedControl2 = [[UISegmentedControl alloc] initWithItems:
                                  [NSArray arrayWithObjects:
                                   [UIImage imageNamed:@"all_categories"],
                                   nil]];
        }
        else
        {
            segmentedControl2 = [[UISegmentedControl alloc] initWithItems:
                                                     [NSArray arrayWithObjects:
                                                      [UIImage imageNamed:@"icon_list_bullets"],
                                                      nil]];
        }

        [segmentedControl2 addTarget:self action:@selector(segmentCatAction:) forControlEvents:UIControlEventValueChanged];
        segmentedControl2.segmentedControlStyle = UISegmentedControlStyleBar;
        segmentedControl2.momentary = YES;

        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && SYSTEM_VERSION_LESS_THAN(@"7.0")) {
            segmentedControl2.tintColor = [UIColor colorWithRed:156/255.f green:161/255.f blue:167/255.f alpha:1.00];
        }

         
        segmentedControl2.frame = CGRectMake(segmentedControl.frame.size.width + 15, 0, segmentedControl2.frame.size.width, segmentedControl2.frame.size.height);
        segmentedControl.frame = CGRectMake(5, 0, segmentedControl.frame.size.width, segmentedControl.frame.size.height);


        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            CGRect oldSegFrame = segmentedControl2.frame;
            oldSegFrame.size.width -= 10;
            segmentedControl2.frame = oldSegFrame;
        }
        
        [self.navigationItem.titleView insertSubview:segmentedControl2 atIndex:1];
        self.navigationItem.titleView.frame = CGRectMake(0, 0, segmentedControl.frame.size.width + 20 + segmentedControl2.frame.size.width, segmentedControl.frame.size.height);

        segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        segmentedControl2.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        self.navigationItem.titleView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        
        self.subCatSegmentedControl = segmentedControl2;
        
            
    }
    else
    {
        segmentedControl.frame = CGRectMake(5, 0, segmentedControl.frame.size.width, segmentedControl.frame.size.height);
        self.navigationItem.titleView.frame = CGRectMake(0, 0, segmentedControl.frame.size.width, segmentedControl.frame.size.height);
        segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        self.navigationItem.titleView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);

    }

	

	
	UIBarButtonItem *segmentBarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(newTopic)];
    segmentBarItem.enabled = NO;
	
	self.navigationItem.rightBarButtonItem = segmentBarItem;

	[(ShakeView*)self.view setShakeDelegate:self];

	self.arrayData = [[NSMutableArray alloc] init];
	self.arrayNewData = [[NSMutableArray alloc] init];
	self.statusMessage = [[NSString alloc] init];
	
	self.forumNewTopicUrl = [[NSString alloc] init];
	
	self.imageForUnselectedRow = [UIImage imageNamed:@"selectedrow"];
	self.imageForSelectedRow = [UIImage imageNamed:@"unselectedrow"];
	
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.imageForRedFlag = [UIImage imageNamed:@"Flat-RedFlag-25"];
        self.imageForYellowFlag = [UIImage imageNamed:@"Flat-YellowFlag-25"];
        self.imageForBlueFlag = [UIImage imageNamed:@"Flat-CyanFlag-25"];
    }
    else
    {
        self.imageForRedFlag = [UIImage imageNamed:@"flagred"];
        self.imageForYellowFlag = [UIImage imageNamed:@"flagyellow"];
        self.imageForBlueFlag = [UIImage imageNamed:@"flagblue2"];
    }

	
	
	//self.forumBaseURL = self.currentUrl;
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.backgroundColor = [UIColor clearColor];
    [self.topicsTableView setTableFooterView:v];

	//self.topicsTableView.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.frame.size.height);
    if (@available(iOS 15.0, *)) {
        self.topicsTableView.sectionHeaderTopPadding = 0;
    }
	//NSLog(@"%f", self.searchDisplayController.searchBar.frame.size.height);
	
    
    if (self.pickerViewArray.count) {
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:nil cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
            [actionSheet setBackgroundColor:[UIColor whiteColor]];
        }
        else {
            [actionSheet setActionSheetStyle:UIActionSheetStyleDefault];
        }
        
        myPickerView = [[UIPickerView alloc] initWithFrame:CGRectZero];
        //myPickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        
        myPickerView.showsSelectionIndicator = YES;
        myPickerView.dataSource = self;
        myPickerView.delegate = self;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
            [myPickerView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.03]];
        }
        

        [actionSheet addSubview:myPickerView];
        
        UISegmentedControl *closeButton = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObject:@"Retour"]];
        closeButton.momentary = YES; 
        closeButton.frame = CGRectMake(10, 7.0f, 55.0f, 30.0f);
        closeButton.segmentedControlStyle = UISegmentedControlStyleBar;
        closeButton.tintColor = [UIColor blackColor];
        [closeButton addTarget:self action:@selector(dismissActionSheet) forControlEvents:UIControlEventValueChanged];
        [actionSheet addSubview:closeButton];
        
        UISegmentedControl *confirmButton = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObject:@"Valider"]];
        confirmButton.momentary = YES; 
        confirmButton.tag = 546; 
        confirmButton.frame = CGRectMake(255, 7.0f, 55.0f, 30.0f);
        confirmButton.segmentedControlStyle = UISegmentedControlStyleBar;
        confirmButton.tintColor = [UIColor colorWithRed:60/255.f green:136/255.f blue:230/255.f alpha:1.00];
        [confirmButton addTarget:self action:@selector(loadSubCat) forControlEvents:UIControlEventValueChanged];
        [actionSheet addSubview:confirmButton];
        
    }

	
    [(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setSelectedSegmentIndex:self.selectedFlagIndex];

    // Fix iOS 5 : setSelectedSegmentIndex not working.
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0")) {
        [self goFlag];
    }
    
}

- (void)goFlag {
    [(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] setUserInteractionEnabled:NO];

	switch (self.selectedFlagIndex) {
		case 0:
			self.currentUrl = self.forumBaseURL;
			break;
		case 1:
			self.currentUrl = self.forumFavorisURL;   
			break;			
		case 2:
			self.currentUrl = self.forumFlag1URL;
			break;
		case 3:
			self.currentUrl = self.forumFlag0URL;  
			break;			
		default:
			self.currentUrl = self.forumBaseURL;  
			break;
	}
    
    
    // setup pull-to-refresh
    
    __weak TopicsTableViewController *self_ = self;

    [self.topicsTableView addPullToRefreshWithActionHandler:^{
        //NSLog(@"=== BEGIN");
        [self_ fetchContentTrigger];
        //NSLog(@"=== END");
    }];
    
    [self fetchContent];

}

- (void)segmentFilterAction
{
	switch ([(UISegmentedControl *)[self.navigationItem.titleView.subviews objectAtIndex:0] selectedSegmentIndex]) {
		case 0:
            self.selectedFlagIndex = 0;
			break;
		case 1:
            self.selectedFlagIndex = 1;            
			break;			
		case 2:
            self.selectedFlagIndex = 2;            
			break;
		case 3:
            self.selectedFlagIndex = 3;            
			break;			
		default:
            self.selectedFlagIndex = 0;            
			break;
	}
    
	[self goFlag];


}

- (IBAction)segmentCatAction:(id)sender
{
	[self showPicker:sender];
    return;
    
	// The segmented control was clicked, handle it here 
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
	//NSLog(@"Segment clicked: %d", segmentedControl.selectedSegmentIndex);
	
	switch (segmentedControl.selectedSegmentIndex) {
		case 0:
			//NSLog(@"segmentCatAction");
			
			break;		
		default:
			break;
	}
	
	
}


- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	[self.view becomeFirstResponder];
    Theme theme = [[ThemeManager sharedManager] theme];
    self.view.backgroundColor = self.topicsTableView.backgroundColor = self.maintenanceView.backgroundColor = self.loadingView.backgroundColor = self.topicsTableView.pullToRefreshView.backgroundColor = [ThemeColors greyBackgroundColor:theme];
    self.topicsTableView.separatorColor = [ThemeColors cellBorderColor:theme];
    self.topicsTableView.pullToRefreshView.arrowColor = [ThemeColors cellTextColor:theme];
    self.topicsTableView.pullToRefreshView.textColor = [ThemeColors cellTextColor:theme];
    self.topicsTableView.pullToRefreshView.activityIndicatorViewStyle = [ThemeColors activityIndicatorViewStyle];
    if (self.errorVC) {
        [self.errorVC applyTheme];
    }


    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadSubCat) name:@"SubCatSelected" object:nil];
    
	if (self.messagesTableViewController) {
		//NSLog(@"viewWillAppear Topics Table View Dealloc MTV");

		self.messagesTableViewController = nil;
	}
    
    if (self.pressedIndexPath) 
    {
		self.pressedIndexPath = nil;
    }
    
    [self.topicsTableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
	[self.view resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SubCatSelected" object:nil];
	
	//Topic *aTopic = [arrayData objectAtIndex:indexPath.row];
	
	//NSLog(@"TT viewDidDisappear %@ - %@", self.topicsTableView.indexPathForSelectedRow, self.pressedIndexPath);


	
	/*[[(TopicCellView *)[topicsTableView cellForRowAtIndexPath:topicsTableView.indexPathForSelectedRow] titleLabel]setFont:[UIFont systemFontOfSize:13]];
	[topicsTableView deselectRowAtIndexPath:topicsTableView.indexPathForSelectedRow animated:NO];*/

}


#pragma mark -
#pragma mark AddMessage Delegate
- (void)addMessageViewControllerDidFinish:(AddMessageViewController *)controller {
    //NSLog(@"addMessageViewControllerDidFinish %@", self.editFlagTopic);
	
	//[self setEditFlagTopic:nil];
	[self dismissModalViewControllerAnimated:YES];
}

- (void)addMessageViewControllerDidFinishOK:(AddMessageViewController *)controller {
	//NSLog(@"addMessageViewControllerDidFinishOK");
	
	[self dismissModalViewControllerAnimated:YES];
	[self shakeHappened:nil];
	[self.navigationController popToViewController:self animated:NO];
	
	
}

#pragma mark -
#pragma mark Gestures
-(void) shakeHappened:(ShakeView*)view
{
	//NSLog(@"shakeHappened");
	if (![request inProgress]) {
		[self fetchContent];
	}
}

- (void)handleSwipeToLeft:(UISwipeGestureRecognizer *)recognizer {
	[self nextPage:recognizer];
}

- (void)handleSwipeToRight:(UISwipeGestureRecognizer *)recognizer {
	[self previousPage:recognizer];
}

#pragma mark -
#pragma mark Table view data source
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[self forumName] stringByAppendingString:[NSString stringWithFormat:@" p.%d", [self pageNumber]]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSInteger iSizeTextTopics = [[NSUserDefaults standardUserDefaults] integerForKey:@"size_text_topics"];
    
    if (arrayData.count)
        return HEIGHT_FOR_HEADER_IN_SECTION*iSizeTextTopics/100;
    else
        return 0;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    
    //On récupère la section (forum)
    CGFloat curWidth = self.view.frame.size.width;
    NSInteger iSizeTextTopics = [[NSUserDefaults standardUserDefaults] integerForKey:@"size_text_topics"];

    //UIView globale
	UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0,0,curWidth,HEIGHT_FOR_HEADER_IN_SECTION*iSizeTextTopics/100)];
    customView.backgroundColor = [ThemeColors headSectionBackgroundColor];
    customView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    UIView* borderView = [[UIView alloc] initWithFrame:CGRectMake(0,0,curWidth,1/[[UIScreen mainScreen] scale])];
    borderView.backgroundColor = [UIColor colorWithRed:158/255.0f green:158/255.0f blue:114/162.0f alpha:0.7];
        
    UIView* borderView2 = [[UIView alloc] initWithFrame:CGRectMake(0,HEIGHT_FOR_HEADER_IN_SECTION*iSizeTextTopics/100-1/[[UIScreen mainScreen] scale],curWidth,1/[[UIScreen mainScreen] scale])];
    borderView2.backgroundColor = [UIColor colorWithRed:158/255.0f green:158/255.0f blue:114/162.0f alpha:0.7];

    //UIButton clickable pour accéder à la catégorie
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, curWidth, HEIGHT_FOR_HEADER_IN_SECTION*iSizeTextTopics/100)];
    [button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];

    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    
    [button setTitleColor:[ThemeColors headSectionTextColor] forState:UIControlStateNormal];
    [button setTitle:[title uppercaseString] forState:UIControlStateNormal];
    [button.titleLabel setFont:[UIFont systemFontOfSize:14.0*iSizeTextTopics/100]];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    [button.titleLabel setNumberOfLines:1];


    [button setTitleEdgeInsets:UIEdgeInsetsMake(2, 10, 0, 0)];

    button.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *guide = customView.safeAreaLayoutGuide;
    //Trailing
    NSLayoutConstraint *trailing =[NSLayoutConstraint
                                   constraintWithItem:button
                                   attribute:NSLayoutAttributeTrailing
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:guide
                                   attribute:NSLayoutAttributeTrailing
                                   multiplier:1.0f
                                   constant:0.f];

    //Leading

    NSLayoutConstraint *leading = [NSLayoutConstraint
                                   constraintWithItem:button
                                   attribute:NSLayoutAttributeLeading
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:guide
                                   attribute:NSLayoutAttributeLeading
                                   multiplier:1.0f
                                   constant:0.f];

    //Bottom
    NSLayoutConstraint *bottom =[NSLayoutConstraint
                                 constraintWithItem:button
                                 attribute:NSLayoutAttributeBottom
                                 relatedBy:NSLayoutRelationEqual
                                 toItem:customView
                                 attribute:NSLayoutAttributeBottom
                                 multiplier:1.0f
                                 constant:0.f];

    NSLayoutConstraint *top =[NSLayoutConstraint
                              constraintWithItem:button
                              attribute:NSLayoutAttributeTop
                              relatedBy:NSLayoutRelationEqual
                              toItem:customView
                              attribute:NSLayoutAttributeTop
                              multiplier:1.0f
                              constant:0.f];

    [customView addSubview:button];

    //[button.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor];
    //[button.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor];
    [customView addConstraint:trailing];
    [customView addConstraint:leading];
    [customView addConstraint:bottom];
    [customView addConstraint:top];
	
	return customView;
 }


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return arrayData.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger iSizeTextTopics = [[NSUserDefaults standardUserDefaults] integerForKey:@"size_text_topics"];
    return 62.0*iSizeTextTopics/100;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	static NSString *CellIdentifier = @"ApplicationCell";
    
    TopicCellView *cell = (TopicCellView *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	
    if (cell == nil)
    {

        [[NSBundle mainBundle] loadNibNamed:@"TopicCellView" owner:self options:nil];
        cell = tmpCell;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;	

		UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] 
															 initWithTarget:self action:@selector(handleLongPress:)];
		[cell addGestureRecognizer:longPressRecognizer];
		
        self.tmpCell = nil;
		
	}
		 

	Topic *aTopic = [arrayData objectAtIndex:indexPath.row];
    cell.topicViewed = [aTopic isViewed];

    NSInteger iSizeTextTopics = [[NSUserDefaults standardUserDefaults] integerForKey:@"size_text_topics"];

    UIFont *font1 = [UIFont boldSystemFontOfSize:13.0f*iSizeTextTopics/100];
    if ([aTopic isViewed]) {
        font1 = [UIFont systemFontOfSize:13.0f*iSizeTextTopics/100];
    }
    NSDictionary *arialDict = [NSDictionary dictionaryWithObject: font1 forKey:NSFontAttributeName];
    NSMutableAttributedString *aAttrString1 = [[NSMutableAttributedString alloc] initWithString:[aTopic aTitle] attributes: arialDict];
    
    UIFont *font2 = [UIFont fontWithName:@"fontello" size:15.0f*iSizeTextTopics/100];

    NSMutableAttributedString *finalString = [[NSMutableAttributedString alloc]initWithString:@""];
    
    if (aTopic.isSticky) {
        UIColor *fontsC = [UIColor colorWithHex:@"#e74c3c" alpha:1.0];
        NSDictionary *arialDict2S = [NSDictionary dictionaryWithObjectsAndKeys:font2, NSFontAttributeName, fontsC, NSForegroundColorAttributeName, nil];
        NSMutableAttributedString *aAttrString2S = [[NSMutableAttributedString alloc] initWithString:@" " attributes: arialDict2S];
        
        [finalString appendAttributedString:aAttrString2S];
    }
    
    if (aTopic.isClosed) {
//            UIColor *fontcC = [UIColor orangeColor];
        UIColor *fontcC = [UIColor colorWithHex:@"#4A4A4A" alpha:1.0];


        NSDictionary *arialDict2c = [NSDictionary dictionaryWithObjectsAndKeys:font2, NSFontAttributeName, fontcC, NSForegroundColorAttributeName, nil];
        NSMutableAttributedString *aAttrString2C = [[NSMutableAttributedString alloc] initWithString:@" " attributes: arialDict2c];
        
        [finalString appendAttributedString:aAttrString2C];
        //NSLog(@"finalString1 %@", finalString);
    }

    [finalString appendAttributedString:aAttrString1];

    cell.titleLabel.attributedText = finalString;
    cell.titleLabel.numberOfLines = 2;
    
    NSString* sPoll = @"";
    if (aTopic.isPoll) {
        sPoll = @" \U00002263";
    }
    
	if (aTopic.aRepCount == 0) {
	 [cell.msgLabel setText:[NSString stringWithFormat:@"↺%@ %d", sPoll, (aTopic.aRepCount + 1)]];
	}
	else {
	 [cell.msgLabel setText:[NSString stringWithFormat:@"↺%@ %d", sPoll, (aTopic.aRepCount + 1)]];
	}
    [cell.msgLabel setFont:[UIFont systemFontOfSize:13.0*iSizeTextTopics/100]];

    // Time label 
	[cell.timeLabel setText:[NSString stringWithFormat:@"%@ - %@", [aTopic aAuthorOfLastPost], [aTopic aDateOfLastPost]]];
    [cell.timeLabel setFont:[UIFont systemFontOfSize:11.0*iSizeTextTopics/100]];



	//Flag
	if ([aTopic aTypeOfFlag].length > 0) {
		
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		
		CGRect frame = CGRectMake(0.0, 0.0, 45, 50);
		button.frame = frame;	// match the button's size with the image size

		if([[aTopic aTypeOfFlag] isEqualToString:@"red"]) {
			[button setBackgroundImage:imageForRedFlag forState:UIControlStateNormal];
			[button setBackgroundImage:imageForRedFlag forState:UIControlStateHighlighted];
		}
		else if ([[aTopic aTypeOfFlag] isEqualToString:@"blue"]) {
			[button setBackgroundImage:imageForBlueFlag forState:UIControlStateNormal];
			[button setBackgroundImage:imageForBlueFlag forState:UIControlStateHighlighted];
		}
		else if ([[aTopic aTypeOfFlag] isEqualToString:@"yellow"]) {
			[button setBackgroundImage:imageForYellowFlag forState:UIControlStateNormal];
			[button setBackgroundImage:imageForYellowFlag forState:UIControlStateHighlighted];
		}
        
		// set the button's target to this table view controller so we can interpret touch events and map that to a NSIndexSet
		[button addTarget:self action:@selector(accessoryButtonTapped:withEvent:) forControlEvents:UIControlEventTouchUpInside];

        //[button setBackgroundColor:[UIColor greenColor]];
		
        cell.accessoryView = button;
	}
	else {
		
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	
		//CGRect frame = CGRectMake(0.0, 0.0, imageForSelectedRow.size.width, imageForSelectedRow.size.height);
		CGRect frame = CGRectMake(0.0, 0.0, 45, 50);
		button.frame = frame;	// match the button's size with the image size
		
		[button setBackgroundImage:imageForSelectedRow forState:UIControlStateNormal];
		[button setBackgroundImage:imageForUnselectedRow forState:UIControlStateHighlighted];
		[button setUserInteractionEnabled:NO];
        //[button setBackgroundColor:[UIColor blueColor]];

		cell.accessoryView = button;
		
	}
	//Flag
    return cell;
	
}

- (void) accessoryButtonTapped: (UIControl *) button withEvent: (UIEvent *) event
{
	
    NSIndexPath * indexPath = [self.topicsTableView indexPathForRowAtPoint: [[[event touchesForView: button] anyObject] locationInView: self.topicsTableView]];
    if ( indexPath == nil )
        return;
	else {
		[self setPressedIndexPath:indexPath];
		//self.pressedIndexPath = [indexPath autorelease];
	}

	
	
	//NSLog(@"url %@", [[arrayData objectAtIndex:self.pressedIndexPath.row] aURLOfFlag]);

	//if (self.messagesTableViewController == nil) {
	MessagesTableViewController *aView = [[MessagesTableViewController alloc] initWithNibName:@"MessagesTableViewController" bundle:nil andUrl:[[arrayData objectAtIndex:indexPath.row]  aURLOfFlag] displaySeparator:YES];
	self.messagesTableViewController = aView;
	//}
	
	//setup the URL

	self.messagesTableViewController.topicName = [[arrayData objectAtIndex:indexPath.row] aTitle];	
	self.messagesTableViewController.isViewed = [[arrayData objectAtIndex:pressedIndexPath.row] isViewed];	

	[self pushTopic];
    //[self.navigationController pushViewController:messagesTableViewController animated:YES];


}

-(void)handleLongPress:(UILongPressGestureRecognizer*)longPressRecognizer {
	if (longPressRecognizer.state == UIGestureRecognizerStateBegan) {
		CGPoint longPressLocation = [longPressRecognizer locationInView:self.topicsTableView];
		self.pressedIndexPath = [[self.topicsTableView indexPathForRowAtPoint:longPressLocation] copy];
				
        if (self.topicActionAlert != nil) {
            self.topicActionAlert = nil;
        }
        
        NSMutableArray *arrayActionsMessages = [NSMutableArray array];
        [arrayActionsMessages addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"la dernière page", @"lastPageAction", nil] forKeys:[NSArray arrayWithObjects:@"title", @"code", nil]]];
        [arrayActionsMessages addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"la dernière réponse", @"lastPostAction", nil] forKeys:[NSArray arrayWithObjects:@"title", @"code", nil]]];
        [arrayActionsMessages addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"la page numéro...", @"chooseTopicPage", nil] forKeys:[NSArray arrayWithObjects:@"title", @"code", nil]]];
        [arrayActionsMessages addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Copier le lien", @"copyLinkAction", nil] forKeys:[NSArray arrayWithObjects:@"title", @"code", nil]]];
        
        topicActionAlert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

        for( NSDictionary *dico in arrayActionsMessages) {
            [topicActionAlert addAction:[UIAlertAction actionWithTitle:[dico valueForKey:@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                if ([self respondsToSelector:NSSelectorFromString([dico valueForKey:@"code"])])
                {
                    //[self performSelector:];
                    [self performSelectorOnMainThread:NSSelectorFromString([dico valueForKey:@"code"]) withObject:nil waitUntilDone:NO];
                }
                else {
                    NSLog(@"CRASH not respondsToSelector %@", [dico valueForKey:@"code"]);
                    
                    [self performSelectorOnMainThread:NSSelectorFromString([dico valueForKey:@"code"]) withObject:nil waitUntilDone:NO];
                }
            }]];
        }
				
        CGPoint longPressLocation2 = [longPressRecognizer locationInView:[[[HFRplusAppDelegate sharedAppDelegate] splitViewController] view]];
        CGRect origFrame = CGRectMake( longPressLocation2.x, longPressLocation2.y, 1, 1);

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
            // Can't use UIAlertActionStyleCancel in dark theme : https://stackoverflow.com/a/44606994/1853603
            UIAlertActionStyle cancelButtonStyle = [[ThemeManager sharedManager] cancelAlertStyle];
            [topicActionAlert addAction:[UIAlertAction actionWithTitle:@"Annuler" style:cancelButtonStyle handler:^(UIAlertAction *action) {
                [self dismissViewControllerAnimated:YES completion:nil];
            }]];
        }
        else   {
            // Required for UIUserInterfaceIdiomPad
            topicActionAlert.popoverPresentationController.sourceView = [[[HFRplusAppDelegate sharedAppDelegate] splitViewController] view];
            topicActionAlert.popoverPresentationController.sourceRect = origFrame;
            topicActionAlert.popoverPresentationController.backgroundColor = [ThemeColors alertBackgroundColor:[[ThemeManager sharedManager] theme]];
        }
        [self presentViewController:topicActionAlert animated:YES completion:nil];
        [[ThemeManager sharedManager] applyThemeToAlertController:topicActionAlert];
    }

}

-(void)lastPageAction{
    MessagesTableViewController *aView = [[MessagesTableViewController alloc] initWithNibName:@"MessagesTableViewController" bundle:nil andUrl:[[arrayData objectAtIndex:pressedIndexPath.row] aURLOfLastPage]];
    self.messagesTableViewController = aView;
    
    self.messagesTableViewController.topicName = [[arrayData objectAtIndex:pressedIndexPath.row] aTitle];
    self.messagesTableViewController.isViewed = [[arrayData objectAtIndex:pressedIndexPath.row] isViewed];
    
    [self pushTopic];
    //[self.navigationController pushViewController:messagesTableViewController animated:YES];
    //NSLog(@"url pressed last page: %@", [[arrayData objectAtIndex:pressedIndexPath.row] aURLOfLastPage]);
}

-(void)lastPostAction{
    
    MessagesTableViewController *aView = [[MessagesTableViewController alloc] initWithNibName:@"MessagesTableViewController" bundle:nil andUrl:[[arrayData objectAtIndex:pressedIndexPath.row] aURLOfLastPost]];
    self.messagesTableViewController = aView;
    
    self.messagesTableViewController.topicName = [[arrayData objectAtIndex:pressedIndexPath.row] aTitle];
    self.messagesTableViewController.isViewed = [[arrayData objectAtIndex:pressedIndexPath.row] isViewed];
    
    [self pushTopic];
    //NSLog(@"url pressed last post: %@", [[arrayData objectAtIndex:pressedIndexPath.row] aURLOfLastPost]);
}

-(void)copyLinkAction {
    NSLog(@"copier lien page 1");
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = [NSString stringWithFormat:@"%@%@", [k RealForumURL], [[arrayData objectAtIndex:pressedIndexPath.row] aURL]];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleAlert];
    NSMutableAttributedString * message = [[NSMutableAttributedString alloc] initWithString:@"Lien copié dans le presse-papiers"];
    [message addAttribute:NSForegroundColorAttributeName value:[ThemeColors textColor:[[ThemeManager sharedManager] theme]] range:(NSRange){0, [message.string length]}];
    [alert setValue:message forKey:@"attributedMessage"];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
    [[ThemeManager sharedManager] applyThemeToAlertController:alert];
    
}


-(void)test {
    AideViewController *avc = [[AideViewController alloc] initWithNibName:@"AideViewController" bundle:nil];
    [avc awakeFromNib];
    
    //[rightMessageController removeFromParentViewController];
    
    NSLog(@"avc %@", avc);
    
    [self.navigationController pushViewController:avc animated:YES];
}

- (void)pushTopic {


    if (([self respondsToSelector:@selector(traitCollection)] && [HFRplusAppDelegate sharedAppDelegate].window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) ||
        [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ||
        [[HFRplusAppDelegate sharedAppDelegate].detailNavigationController.topViewController isMemberOfClass:[BrowserViewController class]]) {
        
        
        
        [self.navigationController pushViewController:messagesTableViewController animated:YES];
    }
    else {
        [[[[[HFRplusAppDelegate sharedAppDelegate] splitViewController] viewControllers] objectAtIndex:1] popToRootViewControllerAnimated:NO];

        [[[HFRplusAppDelegate sharedAppDelegate] detailNavigationController] setViewControllers:[NSMutableArray arrayWithObjects:messagesTableViewController, nil] animated:YES];
        
        if ([messagesTableViewController.splitViewController respondsToSelector:@selector(displayModeButtonItem)]) {
            NSLog(@"PUSH ADD BTN");
            [[HFRplusAppDelegate sharedAppDelegate] detailNavigationController].viewControllers[0].navigationItem.leftBarButtonItem = messagesTableViewController.splitViewController.displayModeButtonItem;
            [[HFRplusAppDelegate sharedAppDelegate] detailNavigationController].viewControllers[0].navigationItem.leftItemsSupplementBackButton = YES;
        }
    }
    
    [self setTopicViewed];
    
    // Close left panel on ipad in portrait mode
    [[HFRplusAppDelegate sharedAppDelegate] hidePrimaryPanelOnIpad];
}

-(void)setTopicViewed {

	if (self.pressedIndexPath && self.arrayData.count > 0 && [self.pressedIndexPath row] <= self.arrayData.count) {
		[[self.arrayData objectAtIndex:[self.pressedIndexPath row]] setIsViewed:YES];
        
        NSArray* rowsToReload = [NSArray arrayWithObjects:self.pressedIndexPath, nil];
        [self.topicsTableView reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationNone];
	}
	else if (self.topicsTableView.indexPathForSelectedRow && self.arrayData.count > 0 && [self.topicsTableView.indexPathForSelectedRow row] <= self.arrayData.count) {
		[[self.arrayData objectAtIndex:[self.topicsTableView.indexPathForSelectedRow row]] setIsViewed:YES];
        
        NSArray* rowsToReload = [NSArray arrayWithObjects:self.topicsTableView.indexPathForSelectedRow, nil];
        [self.topicsTableView reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationNone];
	}
}

#pragma mark -
#pragma mark chooseTopicPage

-(void)chooseTopicPage {
    //NSLog(@"chooseTopicPage Topics");
    
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: nil
                                                                              message: nil
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    NSMutableAttributedString * message = [[NSMutableAttributedString alloc] initWithString:@"Aller à la page"];
    [message addAttribute:NSForegroundColorAttributeName value:[ThemeColors textColor:[[ThemeManager sharedManager] theme]] range:(NSRange){0, [message.string length]}];
    [alertController setValue:message forKey:@"attributedTitle"];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [NSString stringWithFormat:@"(numéro entre 1 et %d)", [[arrayData objectAtIndex:pressedIndexPath.row] maxTopicPage]];
        [[ThemeManager sharedManager] applyThemeToTextField:textField];
        textField.textAlignment = NSTextAlignmentCenter;
        textField.delegate = self;
        [textField addTarget:self action:@selector(textFieldTopicDidChange:) forControlEvents:UIControlEventEditingChanged];
        textField.keyboardAppearance = [ThemeColors keyboardAppearance:[[ThemeManager sharedManager] theme]];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray * textfields = alertController.textFields;
        UITextField * pagefield = textfields[0];
        int pageNumber = [[pagefield text] intValue];
        [self gotoPageNumber:pageNumber];
        
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Annuler"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          [alertController dismissViewControllerAnimated:YES completion:nil];
                                                      }]];
    
    [[ThemeManager sharedManager] applyThemeToAlertController:alertController];
    [self presentViewController:alertController animated:YES completion:^{
        if([[ThemeManager sharedManager] theme] == ThemeDark){
            for (UIView* textfield in alertController.textFields) {
                UIView *container = textfield.superview;
                UIView *effectView = container.superview.subviews[0];
                
                if (effectView && [effectView class] == [UIVisualEffectView class]){
                    container.backgroundColor = [UIColor clearColor];
                    [effectView removeFromSuperview];
                }
            }
        }
    }];
    
    
    
    
}

-(void)textFieldTopicDidChange:(id)sender {
	//NSLog(@"textFieldDidChange %d %@", [[(UITextField *)sender text] intValue], sender);	
	
	
	if ([[(UITextField *)sender text] length] > 0) {
		int val; 
		if ([[NSScanner scannerWithString:[(UITextField *)sender text]] scanInt:&val]) {
			//NSLog(@"int %d %@ %@", val, [(UITextField *)sender text], [NSString stringWithFormat:@"%d", val]);
			
			if (![[(UITextField *)sender text] isEqualToString:[NSString stringWithFormat:@"%d", val]]) {
				//NSLog(@"pas int");
				[sender setText:[NSString stringWithFormat:@"%d", val]];
			}
			else if ([[(UITextField *)sender text] intValue] < 1) {
				//NSLog(@"ERROR WAS %d", [[(UITextField *)sender text] intValue]);
				[sender setText:[NSString stringWithFormat:@"%d", 1]];
				//NSLog(@"ERROR NOW %d", [[(UITextField *)sender text] intValue]);
				
			}
			else if ([[(UITextField *)sender text] intValue] > [[arrayData objectAtIndex:pressedIndexPath.row] maxTopicPage]) {
				//NSLog(@"ERROR WAS %d", [[(UITextField *)sender text] intValue]);
				[sender setText:[NSString stringWithFormat:@"%d", [[arrayData objectAtIndex:pressedIndexPath.row] maxTopicPage]]];
				//NSLog(@"ERROR NOW %d", [[(UITextField *)sender text] intValue]);
				
			}	
			else {
				//NSLog(@"OK");
			}
		}
		else {
			[sender setText:@""];
		}
		
		
	}
}


-(void)gotoPageNumber:(int)number{
        //NSLog(@"goto topic page %d", [[pageNumberField text] intValue]);
        NSString * newUrl = [[NSString alloc] initWithString:[[arrayData objectAtIndex:pressedIndexPath.row] aURL]];
       
        //NSLog(@"newUrl %@", newUrl);

        newUrl = [newUrl stringByReplacingOccurrencesOfString:@"_1.htm" withString:[NSString stringWithFormat:@"_%d.htm", number]];
        newUrl = [newUrl stringByReplacingOccurrencesOfString:@"page=1&" withString:[NSString stringWithFormat:@"page=%d&",number]];
        
        //NSLog(@"newUrl %@", newUrl);

        newUrl = [newUrl stringByRemovingAnchor];
        
        //if (self.messagesTableViewController == nil) {
		MessagesTableViewController *aView = [[MessagesTableViewController alloc] initWithNibName:@"MessagesTableViewController" bundle:nil andUrl:newUrl];
		self.messagesTableViewController = aView;
        //}
        
        
        
        //NSLog(@"%@", self.navigationController.navigationBar);
        

        //setup the URL
        self.messagesTableViewController.topicName = [[arrayData objectAtIndex:pressedIndexPath.row] aTitle];	
        self.messagesTableViewController.isViewed = [[arrayData objectAtIndex:pressedIndexPath.row] isViewed];	
        
        [self pushTopic];
        //[self.navigationController pushViewController:messagesTableViewController animated:YES];
    
}



#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.

    //NSLog(@"did Select row Topics table views: %d", indexPath.row);

	//if (self.messagesTableViewController == nil) {
		MessagesTableViewController *aView = [[MessagesTableViewController alloc] initWithNibName:@"MessagesTableViewController" bundle:nil andUrl:[[arrayData objectAtIndex:indexPath.row] aURL]];
		self.messagesTableViewController = aView;
	//}
	
	//NSLog(@"%@", self.navigationController.navigationBar);
    //NSLog(@"b4 %@", self.navigationController);

	//setup the URL
    
    
    [self.messagesTableViewController setTopicName:[[arrayData objectAtIndex:indexPath.row] aTitle]];
	self.messagesTableViewController.isViewed = [[arrayData objectAtIndex:indexPath.row] isViewed];	
    
    //NSLog(@"pushTopic");
    [self pushTopic];
	//[self.navigationController pushViewController:messagesTableViewController animated:YES];
}

#pragma mark -
#pragma mark UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	if (pickerView == myPickerView)	// don't show selection for the custom picker
	{
		// report the selection to the UI label
		//label.text = [NSString stringWithFormat:@"%@ - %d",
		//			  [pickerViewArray objectAtIndex:[pickerView selectedRowInComponent:0]],
		//			  [pickerView selectedRowInComponent:1]];
		
		//NSLog(@"%@", [pickerViewArray objectAtIndex:[pickerView selectedRowInComponent:0]]);
	}
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	NSString *returnStr = @"";
	
	if (row == 0) {
		//NSString *returnStr = @"";

	}
	else {
		returnStr = @"- ";
	}

	
	// note: custom picker doesn't care about titles, it uses custom views
	if (pickerView == myPickerView)
	{
		if (component == 0)
		{
			returnStr = [returnStr stringByAppendingString:[[pickerViewArray objectAtIndex:row] aTitle]];
		}
	}
	
	return returnStr;
}
/*
 - (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
 {
 CGFloat componentWidth = 0.0;
 
 if (component == 0)
 componentWidth = 240.0;	// first column size is wider to hold names
 else
 componentWidth = 40.0;	// second column is narrower to show numbers
 
 return componentWidth;
 }
 */
- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
	return 40.0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return [pickerViewArray count];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    //NSLog(@"NOC");
	return 1;
}


// return the picker frame based on its size, positioned at the bottom of the page
- (CGRect)pickerFrameWithSize:(CGSize)size
{
	//CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
	CGRect pickerRect = CGRectMake(	0.0,
								   40,
								    self.view.frame.size.width,
								   size.height);
	
	
	return pickerRect;
}

-(void)dismissActionSheet {
	[actionSheet dismissWithClickedButtonIndex:0 animated:YES];
}

-(UIViewController *)presentationController:(UIPresentationController *)controller viewControllerForAdaptivePresentationStyle:(UIModalPresentationStyle)style   {
    
    UINavigationController *uvc = [[UINavigationController alloc] initWithRootViewController:controller.presentedViewController];
    return uvc;
    
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

-(void)showPicker:(id)sender {

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8")) {
        //NSLog(@"TT %@", [[pickerViewArray objectAtIndex:[myPickerView selectedRowInComponent:0]] aTitle]);
        
        SubCatTableViewController *subCatTableViewController = [[SubCatTableViewController alloc] initWithStyle:UITableViewStylePlain];
        subCatTableViewController.suPicker = myPickerView;
        subCatTableViewController.arrayData = pickerViewArray;
        subCatTableViewController.notification = @"SubCatSelected";
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8")) {
            subCatTableViewController.modalPresentationStyle = UIModalPresentationPopover;
            UIPopoverPresentationController *pc = [subCatTableViewController popoverPresentationController];
            pc.permittedArrowDirections = UIPopoverArrowDirectionAny;
            pc.delegate = self;
            pc.sourceView = self.subCatSegmentedControl;
            pc.sourceRect = CGRectMake(0, 0, 45, 35);

            [self presentViewController:subCatTableViewController animated:YES completion:nil];
        }
        else {
            self.popover = nil;
            self.popover = [[UIPopoverController alloc] initWithContentViewController:subCatTableViewController];
            CGRect origFrame = [(UISegmentedControl *)sender frame];
            [_popover presentPopoverFromRect:origFrame inView:self.navigationItem.titleView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }

    }
    else {
        CGSize pickerSize = [myPickerView sizeThatFits:CGSizeZero];
        myPickerView.frame = [self pickerFrameWithSize:pickerSize];
        
        [actionSheet showInView:[[[HFRplusAppDelegate sharedAppDelegate] rootController] view]];
        
        CGRect curFrame = [[actionSheet viewWithTag:546] frame];
        curFrame.origin.x =  self.view.frame.size.width - curFrame.size.width - 10;
        [[actionSheet viewWithTag:546] setFrame:curFrame];
        
        
        [UIView beginAnimations:nil context:nil];
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
            [actionSheet setFrame:CGRectMake(0, self.view.frame.size.height - myPickerView.frame.size.height + 34,
                                             self.view.frame.size.width, myPickerView.frame.size.height + 34)];
        }
        else
        {
            [actionSheet setFrame:CGRectMake(0, [[[HFRplusAppDelegate sharedAppDelegate] rootController] tabBar].frame.size.height + self.view.frame.size.height + self.navigationController.navigationBar.frame.size.height + 20 - myPickerView.frame.size.height - 44,
                                             self.view.frame.size.width, myPickerView.frame.size.height + 44)];
        }
        
        [actionSheet setBounds:CGRectMake(0, 0,
                                          self.view.frame.size.width, myPickerView.frame.size.height + 44)];
        
        [UIView commitAnimations];
        
    }


}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
	//NSLog(@"mem warning TTV");
}

@end

