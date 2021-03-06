//
//  MainViewController.m
//  F2 Demo
//
//  Created by Nathan Johnson on 1/28/14.
//  Copyright (c) 2014 Markit. All rights reserved.
//

#import "MainViewController.h"
#import "F2AppView.h"

#define kNameKey @"Name"
#define kSymbolKey @"Symbol"
#define kExhangeKey @"Exchange"

//these must be lower case, and no special characters
#define kEventAppSymbolChange @"appsymbolchange"

@implementation MainViewController{
    NSString*                   _currentSymbol;
    
    F2AppView*                  _f2ChartView;
    F2AppView*                  _f2WatchlistView;
    F2AppView*                  _f2QuoteView;
    F2AppView*                  _f2CustomView;

    UIView*                     _customEditView;
    UITextView*                 _configurationTextView;

    UISearchBar*                _searchBar;
    UISearchDisplayController*  _searchDisplayController;
    NSURLSessionDataTask*       _searchTask;
    NSMutableArray*             _symbolArray;
}

#pragma mark UIViewController Methods
- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor colorWithRed:0.145 green:0.545 blue:0.816 alpha:1] /*#258bd0*/];
    
    _symbolArray = [NSMutableArray new];
    
    float margin = 8;
    float padding = 4;
    UIButton* f2Logo = [UIButton buttonWithType:UIButtonTypeCustom];
    [f2Logo addTarget:self action:@selector(f2ButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [f2Logo setImage:[UIImage imageNamed:@"Icon-40"] forState:UIControlStateNormal];
    [f2Logo setFrame:CGRectMake(margin, 20+margin, 30, 30)];
    [self.view addSubview:f2Logo];
    
    CGFloat buttonWidth = CGRectGetHeight(f2Logo.frame);
    UIButton* refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [refreshButton.titleLabel setFont:[UIFont fontWithName:@"CourierNewPSMT" size:buttonWidth]];
    [refreshButton setTitle:@"🔄" forState:UIControlStateNormal];
    [refreshButton setFrame:CGRectMake(CGRectGetMaxX(self.view.bounds)-buttonWidth-margin, 0, buttonWidth, CGRectGetHeight(f2Logo.frame))];
    [refreshButton sizeToFit];
    [refreshButton setCenter:CGPointMake(refreshButton.center.x, f2Logo.center.y + 2)];
    [refreshButton addTarget:self action:@selector(resfresh) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:refreshButton];
    
    UIView* searchBarContainer = [UIView new];
    CGFloat searchX = CGRectGetMaxX(f2Logo.frame)+padding;
    [searchBarContainer setFrame:CGRectMake(searchX, 20+2, CGRectGetMinX(refreshButton.frame)-padding-searchX, CGRectGetHeight(f2Logo.frame)+10)];
    [searchBarContainer setBackgroundColor:[UIColor colorWithRed:0.145 green:0.545 blue:0.816 alpha:1] /*#258bd0*/];
    [searchBarContainer setClipsToBounds:YES];
    [self.view addSubview:searchBarContainer];
    
    _searchBar = [UISearchBar new];
    if([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
    {
        _searchBar.barTintColor = [UIColor blackColor];
        _searchBar.backgroundImage = [UIImage imageNamed:@"clear-background"];
        [_searchBar setBarTintColor:[UIColor whiteColor]];
        [_searchBar setTintColor:[UIColor whiteColor]];
    }
    else
    {
        [_searchBar setTintColor:[UIColor colorWithRed:0.145 green:0.545 blue:0.816 alpha:1] /*#258bd0*/];
    }
    [_searchBar setDelegate:self];
    [_searchBar setPlaceholder:@"Search for Company"];
    [_searchBar setSearchBarStyle:UISearchBarStyleProminent];
    [_searchBar setFrame:searchBarContainer.bounds];
    [searchBarContainer addSubview:_searchBar];
    
    _searchDisplayController = [[UISearchDisplayController alloc]initWithSearchBar:_searchBar contentsController:self];
    [_searchDisplayController setDelegate:self];
    [_searchDisplayController setSearchResultsDataSource:self];
    [_searchDisplayController setSearchResultsDelegate:self];

    CGFloat viewHeight = self.view.bounds.size.height;
    CGFloat contentStart = CGRectGetMaxY(searchBarContainer.frame) + margin;
    CGFloat fullHeight = viewHeight - contentStart - padding;
    CGFloat halfHeight = (fullHeight - padding) / 2.;
    halfHeight = floorf(halfHeight);
    
    //Create the Watchlist F2 View
    _f2WatchlistView = [[F2AppView alloc]initWithFrame:CGRectMake(padding, contentStart, 310, halfHeight)];
    [_f2WatchlistView setDelegate:self];
    [_f2WatchlistView setScrollable:YES];
    [_f2WatchlistView setScale:0.9f];
    [_f2WatchlistView setAppJSONConfig:@"[{\"appId\": \"com_f2_examples_javascript_watchlist\",\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\"name\": \"Watchlist\"}]"];
    [_f2WatchlistView registerEvent:@"F2.Constants.Events.APP_SYMBOL_CHANGE" key:kEventAppSymbolChange dataValueGetter:@"data.symbol"];
    [_f2WatchlistView loadApp];
    [self.view addSubview:_f2WatchlistView];
    
    //Create the Quote F2 View
    _f2QuoteView = [[F2AppView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_f2WatchlistView.frame)+padding, contentStart, 350, halfHeight)];
    [_f2QuoteView setDelegate:self];
    [_f2QuoteView setScrollable:NO];
    [_f2QuoteView setScale:0.9f];
    [_f2QuoteView setAppJSONConfig:@"[{\"appId\": \"com_openf2_examples_javascript_quote\",\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\"name\": \"Quote\", \"context\":{\"symbol\":\"MSFT\"}}]"];
    [_f2QuoteView loadApp];
    [self.view addSubview:_f2QuoteView];
    
    //Create the Chart F2 View
    _f2ChartView = [[F2AppView alloc]initWithFrame:CGRectMake(padding, CGRectGetMaxY(_f2QuoteView.frame)+padding, CGRectGetMaxX(_f2QuoteView.frame)-padding, halfHeight)];
    [_f2ChartView setDelegate:self];
    [_f2ChartView setScrollable:NO];
    [_f2ChartView setScale:0.8f];
    [_f2ChartView setAdditionalCss:@"h2 {font-size:23px}"];
    [_f2ChartView setAppJSONConfig:@"[{\"appId\": \"com_openf2_examples_csharp_chart\",\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\"name\": \"One Year Price Movement\"}]"];
    [_f2ChartView loadApp];
    [self.view addSubview:_f2ChartView];
    
    //Create Flip Containter
    CGFloat flipX = CGRectGetMaxX(_f2QuoteView.frame)+padding;
    UIView* flipContainer = [[UIView alloc]initWithFrame:CGRectMake(flipX, contentStart, self.view.bounds.size.width-flipX-padding, fullHeight)];
    [self.view addSubview:flipContainer];
    
    //Create the Custom F2 View
    _f2CustomView = [[F2AppView alloc]initWithFrame:flipContainer.bounds];
    [_f2CustomView setDelegate:self];
    [_f2CustomView setScrollable:YES];
    [_f2CustomView setScale:0.9f];
    [_f2CustomView setAppJSONConfig:@"[{\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]"];
    [_f2CustomView loadApp];
    [flipContainer addSubview:_f2CustomView];
    
    CGRect _editViewFrame = flipContainer.bounds;
    _editViewFrame.size.height = 336;
    _customEditView = [[UIView alloc]initWithFrame:_editViewFrame];
    [_customEditView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.5]];
    

    _configurationTextView = [[UITextView alloc]initWithFrame:CGRectMake(padding, padding, CGRectGetWidth(flipContainer.frame)-(padding*2), 224)];
    [_configurationTextView setText:@"[{\n\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]"];
    [_configurationTextView setFont:[UIFont fontWithName:@"CourierNewPSMT" size:15]];
    [_customEditView addSubview:_configurationTextView];
    
    UIButton* customViewMarketNewsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customViewMarketNewsButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
    [customViewMarketNewsButton setTitle:@"Market News" forState:UIControlStateNormal];
    [customViewMarketNewsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [customViewMarketNewsButton.layer setBorderColor:[UIColor whiteColor].CGColor];
    [customViewMarketNewsButton.layer setBorderWidth:1];
    [customViewMarketNewsButton setFrame:CGRectMake(padding, CGRectGetMaxY(_configurationTextView.frame)+padding, (CGRectGetWidth(_customEditView.frame)/2)-(padding*1.5), 40)];
    [customViewMarketNewsButton addTarget:self action:@selector(marketNewsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_customEditView addSubview:customViewMarketNewsButton];
    
    UIButton* customViewStockNewsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customViewStockNewsButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
    [customViewStockNewsButton setTitle:@"Stock News" forState:UIControlStateNormal];
    [customViewStockNewsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [customViewStockNewsButton.layer setBorderColor:[UIColor whiteColor].CGColor];
    [customViewStockNewsButton.layer setBorderWidth:1];
    [customViewStockNewsButton setFrame:CGRectMake(CGRectGetMaxX(customViewMarketNewsButton.frame)+padding, CGRectGetMaxY(_configurationTextView.frame)+padding, (CGRectGetWidth(_customEditView.frame)/2)-(padding*1.5), 40)];

    [customViewStockNewsButton addTarget:self action:@selector(stockNewsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_customEditView addSubview:customViewStockNewsButton];
    
    UIButton* customViewDoneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customViewDoneButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
    [customViewDoneButton setTitle:@"Done" forState:UIControlStateNormal];
    [customViewDoneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [customViewDoneButton setBackgroundColor:[UIColor colorWithRed:29.0f/255 green:104.0f/255 blue:153.0f/255 alpha:1]];
    [customViewDoneButton setFrame:CGRectMake(CGRectGetWidth(_customEditView.frame)/4, CGRectGetMaxY(customViewStockNewsButton.frame)+padding, CGRectGetWidth(_customEditView.frame)/2, 40)];
    [customViewDoneButton addTarget:self action:@selector(donePressed) forControlEvents:UIControlEventTouchUpInside];
    [_customEditView addSubview:customViewDoneButton];
    
     UIButton* customViewInfoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [customViewInfoButton setFrame:CGRectMake(CGRectGetWidth(flipContainer.frame)-32, CGRectGetHeight(flipContainer.frame)-32, 32, 32)];
    [customViewInfoButton addTarget:self action:@selector(infoPressed) forControlEvents:UIControlEventTouchUpInside];
    [_f2CustomView addSubview:customViewInfoButton];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

#pragma mark "Private" Methods
- (void)searchFor:(NSString*)searchText {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSString* searchURL = [NSString stringWithFormat:@"http://dev.markitondemand.com/Api/v2/Lookup/json?input=%@",searchText];
    NSURL* URL = [NSURL URLWithString:searchURL];
    NSURLRequest* request = [NSURLRequest requestWithURL:URL];
    NSURLSession* session = [NSURLSession sharedSession];
    _searchTask = [session dataTaskWithRequest:request
                             completionHandler:^(NSData* data, NSURLResponse* response, NSError* sessionError) {
                                 if (!sessionError) {
                                     NSError* JSONerror = nil;
                                     NSArray* responses = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONerror];
                                     if (JSONerror){
                                         NSLog(@"JSONObjectWithData error: %@", JSONerror);
                                     }else{
                                         dispatch_sync(dispatch_get_main_queue(), ^{
                                             _symbolArray = [NSMutableArray arrayWithArray:responses];
                                             [_searchDisplayController.searchResultsTableView reloadData];
                                         });
                                     }
                                 }
                                 dispatch_sync(dispatch_get_main_queue(), ^{
                                     //getting main thread just to be safe
                                     [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                 });
                                 
                             }];
    [_searchTask resume];
}

- (void)goForSymbol:(NSString*)symbol {
    if (![_currentSymbol isEqualToString:symbol]) {
        _currentSymbol = symbol;
        [_f2ChartView sendJavaScript:[NSString stringWithFormat:@"F2.Events.emit(F2.Constants.Events.CONTAINER_SYMBOL_CHANGE, { 'symbol': '%@' });",symbol]];
        [_f2QuoteView sendJavaScript:[NSString stringWithFormat:@"F2.Events.emit(F2.Constants.Events.CONTAINER_SYMBOL_CHANGE, { 'symbol': '%@' });",symbol]];
        [_f2CustomView sendJavaScript:[NSString stringWithFormat:@"F2.Events.emit(F2.Constants.Events.CONTAINER_SYMBOL_CHANGE, { 'symbol': '%@' });",symbol]];
    }
}

-(void)infoPressed{
    [_configurationTextView becomeFirstResponder];
    [UIView transitionFromView:_f2CustomView toView:_customEditView duration:1 options:UIViewAnimationOptionTransitionFlipFromRight completion:^(BOOL finished) {
       
    }];
}
-(void)donePressed{
    NSString * newConfig = _configurationTextView.text;
    if ([_configurationTextView isFirstResponder]) {
        [_configurationTextView resignFirstResponder];
    }
    NSError* error = [_f2CustomView setAppJSONConfig:newConfig];
    if (error) {
        [[[UIAlertView alloc]initWithTitle:@"Error" message:error.localizedDescription delegate:NULL cancelButtonTitle:@"OK" otherButtonTitles:NULL]show];
    }else{
        [_f2CustomView loadApp];
        [UIView transitionFromView:_customEditView toView:_f2CustomView duration:1 options:UIViewAnimationOptionTransitionFlipFromLeft completion:^(BOOL finished) {
        }];
    }
}

-(void)marketNewsButtonPressed{
    [_configurationTextView setText:@"[{\n\"appId\": \"com_openf2_examples_csharp_marketnews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Market News\"\n}]"];
}

-(void)stockNewsButtonPressed{
    [_configurationTextView setText:@"[{\n\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]"];
}

-(void)resfresh{
    NSString * customConfig = @"[{\n\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]";
    [_configurationTextView setText:customConfig];
    [_f2CustomView setAppJSONConfig:customConfig];
    _currentSymbol = @"MSFT";//this seems to be the default
    [_f2CustomView loadApp];
    [_f2ChartView loadApp];
    [_f2QuoteView loadApp];
    [_f2WatchlistView loadApp];
}

- (void)f2ButtonPressed {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"http://www.openf2.org"]];
}

#pragma mark UISearchBarDelegate Methods
- (void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)searchText{
    [_searchTask cancel];
    if (searchText.length>0) {
        [self searchFor:searchText];
    }else{
        [_symbolArray removeAllObjects];
        [_searchDisplayController.searchResultsTableView reloadData];
    }
}

#pragma mark UITableViewDataSource Methods
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section{
    return _symbolArray.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"searchResultCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"searchResultCell"];
        [cell.textLabel setTextColor:[UIColor blackColor]];
        [cell.detailTextLabel setTextColor:self.view.backgroundColor];
    }
    NSDictionary* symbol = [_symbolArray objectAtIndex:indexPath.row];
    [cell.textLabel setText:symbol[kSymbolKey]];
    [cell.detailTextLabel setText:[NSString stringWithFormat:@"%@ - %@",symbol[kNameKey],symbol[kExhangeKey]]];
    return cell;
}

#pragma mark UITableViewDelegate Methods
-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath{
    NSDictionary* symbol = [_symbolArray objectAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [_searchDisplayController setActive:NO animated:YES];
    [_searchBar setText:[NSString stringWithFormat:@"%@ %@",symbol[kSymbolKey],symbol[kNameKey]]];
    [self goForSymbol:symbol[kSymbolKey]];
}

#pragma mark F2AppViewDelegate methods
-(void)F2View:(F2AppView*)appView messageRecieved:(NSString*)message withKey:(NSString*)key{
    if ([key isEqualToString:kEventAppSymbolChange]){
        [self goForSymbol:message];
        [_searchBar setText:message];
    }
}

-(void)F2View:(F2AppView *)appView appFinishedLoading:(NSError *)error{
    if (error) {
        [[[UIAlertView alloc]initWithTitle:@"An error occured." message:[NSString stringWithFormat:@"%@",error.localizedDescription]  delegate:NULL cancelButtonTitle:@"Close" otherButtonTitles:NULL]show];
    }
}

@end