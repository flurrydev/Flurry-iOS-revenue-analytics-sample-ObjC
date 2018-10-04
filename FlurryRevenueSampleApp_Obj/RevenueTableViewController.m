//
//  RevenueTableViewController.m
//  FlurryRevenueSampleApp_Obj
//
//  Created by Yilun Xu on 10/3/18.
//  Copyright © 2018 Flurry. All rights reserved.
//

#import "RevenueTableViewController.h"
#import "Flurry.h"
#import <StoreKit/StoreKit.h>

@interface RevenueTableViewController () <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic, strong) NSMutableArray<SKProduct *> *verifiedProducts;
@property (nonatomic, strong) NSSet<NSString *> *products;

@end

@implementation RevenueTableViewController

@synthesize autoLogSwitch;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // fetch products id from plist file
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"products"
                                         withExtension:@"plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfURL:url];
    self.products = [NSSet setWithArray:productIdentifiers];
    
    //init request
    if (![SKPaymentQueue canMakePayments]) {
        return;
    }
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:self.products];
    request.delegate = self;
    [request start];
    
    // add self as an observer, be notified if one or more transactions are being updated
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    // record toggle position
    NSUserDefaults *defaults =[NSUserDefaults standardUserDefaults];
    if(![[[defaults dictionaryRepresentation] allKeys] containsObject:@"iapReporting"]){
        NSLog(@"not found");
        [defaults setBool:YES forKey:@"iapReporting"];
        autoLogSwitch.on = YES;
    } else {
        autoLogSwitch.on = [defaults boolForKey:@"iapReporting"];
    }
}

// purchase the product
-(void)purchase:(SKProduct *)product {
    if ([SKPaymentQueue canMakePayments]) {
        // add this payment to the payment queue
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

#pragma mark - StoreKit delegate + observer

// Accepts the reponse from app store that contains the request products information
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    self.verifiedProducts = [NSMutableArray array];
    // invalid products
    for (NSString *identifier in response.invalidProductIdentifiers) {
        NSLog(@"invalid identifier:  %@", identifier);
    }
    // valid products
    for (SKProduct *product in response.products) {
        [self.verifiedProducts addObject:product];
    }
    [self.tableView reloadData];
}

- (NSString *)stringForTransactionRecordStatus:(FlurryTransactionRecordStatus)status {
    switch (status) {
        case FlurryTransactionRecorded:
            return @"Recorded";
        case FlurryTransactionRecordFailed:
            return @"Failed to Record";
        case FlurryTransactionRecordExceeded:
            return @"Record Exceeded";
        case FlurryTransactionRecodingDisabled:
            return @"Recording Disabled";
    }
}

// Tell the observer when one or more transactions are being updated
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                if (!autoLogSwitch.isOn) {
                    [Flurry logPaymentTransaction:transaction statusCallback:^(FlurryTransactionRecordStatus status) {
                        [self displayAlertWithTitle:@"Success" message:[self stringForTransactionRecordStatus:status]];
                    }];
                } else {
                    [self displayAlertWithTitle:@"Success" message:@"Payment went througth successfully"];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"%@", transaction.error.debugDescription);
                if (!autoLogSwitch.isOn) {
                    [Flurry logPaymentTransaction:transaction statusCallback:^(FlurryTransactionRecordStatus status) {
                        [self displayAlertWithTitle:@"Failed" message:[self stringForTransactionRecordStatus:status]];
                    }];
                } else {
                    [self displayAlertWithTitle:@"Failed" message:@"Payment did not go througth"];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateDeferred:
                break;
            case SKPaymentTransactionStateRestored:
                break;
            case SKPaymentTransactionStatePurchasing:
                break;
        }
    }
    
}

#pragma mark - alert

-(void)displayAlertWithTitle:(NSString *)title message:(NSString *)message {

    // set alert controller
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    
    // present the alert
    [self presentViewController:controller animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [controller dismissViewControllerAnimated:YES completion:nil];
            });
    }];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.verifiedProducts.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    return @"Products";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    SKProduct *product = self.verifiedProducts[indexPath.row];
    
    cell.textLabel.text = product.localizedTitle;
    if ([product.priceLocale respondsToSelector:@selector(countryCode)]) {
        if (@available(iOS 10.0, *)) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@%@", product.priceLocale.countryCode, product.priceLocale.currencySymbol, product.price];
        } else {
            // Fallback on earlier versions
            NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
            [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
            [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
            [numberFormatter setLocale:product.priceLocale];
            NSString *formattedString = [numberFormatter stringFromNumber:product.price];
            cell.detailTextLabel.text = formattedString;
            
        }
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Price :  %@", product.price];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"product id is : %@", self.verifiedProducts[indexPath.row].productIdentifier);
    if ([SKPaymentQueue canMakePayments]) {
        [self purchase:self.verifiedProducts[indexPath.row]];
    } else {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error" message:@"Purchases are disabled in your device" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [controller addAction:okAction];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

#pragma mark - update toggle

- (IBAction)updateAutoLogSwitch:(UISwitch *)sender {
    [Flurry setIAPReportingEnabled:sender.isOn];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSLog(@"change value");
    
    [defaults setBool:sender.isOn forKey:@"iapReporting"];
    [defaults synchronize];
}
@end
