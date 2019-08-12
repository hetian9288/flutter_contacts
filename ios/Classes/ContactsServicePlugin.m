#import "ContactsServicePlugin.h"
#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AssetsLibrary/AssetsLibrary.h>


@implementation ContactsServicePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    ContactsServicePlugin* instance = [[ContactsServicePlugin alloc] init];
    
    FlutterMethodChannel* channel =
    [FlutterMethodChannel methodChannelWithName:@"github.com/clovisnicolas/flutter_contacts"
                                binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result
{
    if ([call.method isEqualToString:@"getContacts"]) {
        NSMutableArray *ret = [self getContacts:call.arguments[@"query"] withThumbnails:[[call.arguments valueForKey:@"withThumbnails"] boolValue] photoHighResolution:[[call.arguments valueForKey:@"photoHighResolution"] boolValue] phoneQuery: false];
        result(ret);
    } else if ([call.method isEqualToString:@"getContactsForPhone"]) {
        NSMutableArray *ret = [self getContacts:[call.arguments valueForKey:@"phone"] withThumbnails:[call.arguments[@"withThumbnails"] boolValue] photoHighResolution:[call.arguments[@"photoHighResolution"] boolValue] phoneQuery: true];
        result(ret);
    } else if ([call.method isEqualToString:@"addContact"]) {
        CNMutableContact * contact = [self dictionaryToContact:call.arguments];
        NSString *ret = [self addContact:contact];
        result(ret);
    } else if ([call.method isEqualToString:@"deleteContact"]) {
        result([self deleteContact:call.arguments]);
    } else if ([call.method isEqualToString:@"updateContact"]) {
        result(@([self updateContact:call.arguments]));
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (NSString *) addContact:(CNMutableContact *) contact
{
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    if(!contactStore)
        return @"";
    
    @try {
        CNSaveRequest *request = [[CNSaveRequest alloc] init];
        [request addContact:contact toContainerWithIdentifier:nil];
        
        [contactStore executeSaveRequest:request error:nil];
    }
    @catch (NSException *exception) {
        return @"";
    }
    return @"";
}

- (NSString *)deleteContact:(NSDictionary *)contactData
{
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    if(!contactStore)
        return @"";
    NSString* recordID = [contactData valueForKey:@"identifier"];
    
    NSArray *keys = @[CNContactIdentifierKey];
    
    @try {
        
        CNMutableContact *contact = [[contactStore unifiedContactWithIdentifier:recordID keysToFetch:keys error:nil] mutableCopy];
        NSError *error;
        CNSaveRequest *saveRequest = [[CNSaveRequest alloc] init];
        [saveRequest deleteContact:contact];
        [contactStore executeSaveRequest:saveRequest error:&error];
        
        return @"";
    }
    @catch (NSException *exception) {
        return NULL;
    }
}

- (BOOL) updateContact:(NSDictionary *)contactData
{
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    if(!contactStore)
        return false;
    NSError* contactError;
    NSString* recordID = [contactData valueForKey:@"recordID"];
    NSArray * keysToFetch =@[
                             CNContactEmailAddressesKey,
                             CNContactPhoneNumbersKey,
                             CNContactFamilyNameKey,
                             CNContactGivenNameKey,
                             CNContactMiddleNameKey,
                             CNContactPostalAddressesKey,
                             CNContactOrganizationNameKey,
                             CNContactJobTitleKey,
                             CNContactImageDataAvailableKey,
                             CNContactThumbnailImageDataKey,
                             CNContactImageDataKey,
                             CNContactUrlAddressesKey,
                             CNContactBirthdayKey
                             ];
    
    @try {
        CNMutableContact* record = [[contactStore unifiedContactWithIdentifier:recordID keysToFetch:keysToFetch error:&contactError] mutableCopy];
        [self updateRecord:record withData:contactData];
        CNSaveRequest *request = [[CNSaveRequest alloc] init];
        [request updateContact:record];
        
        [contactStore executeSaveRequest:request error:nil];
        
        return true;
    }
    @catch (NSException *exception) {
        return false;
    }
}

- (NSMutableArray *) getContacts:(NSString *)query withThumbnails:(BOOL)withThumbnails photoHighResolution:(BOOL) photoHighResolution phoneQuery:(BOOL)phoneQuery
{
    CNContactStore *contactStore = [[CNContactStore alloc] init];
    NSMutableArray<NSMutableDictionary *> *contacts = [[NSMutableArray alloc] init];
    if (!contactStore){
        return contacts;
    }
    NSError *contactError = NULL;
    NSMutableArray *keys = [[NSMutableArray alloc] initWithArray:@[
                                                                   CNContactEmailAddressesKey,
                                                                   CNContactPhoneNumbersKey,
                                                                   CNContactFamilyNameKey,
                                                                   CNContactGivenNameKey,
                                                                   CNContactMiddleNameKey,
                                                                   CNContactPostalAddressesKey,
                                                                   CNContactOrganizationNameKey,
                                                                   CNContactJobTitleKey,
                                                                   CNContactUrlAddressesKey,
                                                                   CNContactBirthdayKey
                                                                   ]];
    if (withThumbnails) {
        if (photoHighResolution) {
            [keys addObject:CNContactImageDataAvailableKey];
        }else{
            [keys addObject:CNContactThumbnailImageDataKey];
        }
    }
    
    if (phoneQuery && query != NULL) {
        if (@available(iOS 11.0, *)) {
            CNPhoneNumber *cnPhoneNumber = [[CNPhoneNumber alloc] initWithStringValue:query];
            NSArray *arrayOfContacts = [contactStore unifiedContactsMatchingPredicate:[CNContact            predicateForContactsMatchingPhoneNumber:cnPhoneNumber]
                                                                          keysToFetch:keys
                                                                                error:&contactError];
            [arrayOfContacts enumerateObjectsUsingBlock:^(CNContact * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [contacts addObject:[self contactToDictionary:obj withThumbnails:withThumbnails]];
            }];
        } else {
            CNContactFetchRequest * request = [[CNContactFetchRequest alloc]initWithKeysToFetch:keys];
            [contactStore enumerateContactsWithFetchRequest:request error:&contactError usingBlock:^(CNContact * __nonnull contact, BOOL * __nonnull stop){
                for (CNLabeledValue<CNPhoneNumber*> *phoneItem in contact.phoneNumbers) {
                    if ([phoneItem.value.stringValue containsString:query]) {
                        [contacts addObject:[self contactToDictionary:contact withThumbnails:withThumbnails]];
                    }
                }
            }];
        }
    } else if (query != NULL && [NSNull isEqual:query]) {
        NSArray *arrayOfContacts = [contactStore unifiedContactsMatchingPredicate:[CNContact predicateForContactsMatchingName:query]
                                                               keysToFetch:keys
                                                                     error:&contactError];
        [arrayOfContacts enumerateObjectsUsingBlock:^(CNContact * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [contacts addObject:[self contactToDictionary:obj withThumbnails:withThumbnails]];
        }];
    } else {
        CNContactFetchRequest * request = [[CNContactFetchRequest alloc]initWithKeysToFetch:keys];
        [contactStore enumerateContactsWithFetchRequest:request error:&contactError usingBlock:^(CNContact * __nonnull contact, BOOL * __nonnull stop){
            NSMutableDictionary *ret = [self contactToDictionary:contact withThumbnails:withThumbnails];
            [contacts addObject:ret];
        }];
    }
    if (contactError != NULL) {
        NSLog(@"获取通讯录失败：%@, %@", contactError, contactError.localizedDescription);
    }
    
    return contacts;
}

- (void) updateRecord: (CNMutableContact *)contact withData:(NSDictionary *)contactData
{
    NSString *givenName = [contactData valueForKey:@"givenName"];
    NSString *familyName = [contactData valueForKey:@"familyName"];
    NSString *middleName = [contactData valueForKey:@"middleName"];
    NSString *company = [contactData valueForKey:@"company"];
    NSString *jobTitle = [contactData valueForKey:@"jobTitle"];
    
    
    contact.givenName = givenName;
    contact.familyName = familyName;
    contact.middleName = middleName;
    contact.organizationName = company;
    contact.jobTitle = jobTitle;
    
    NSMutableArray *phoneNumbers = [[NSMutableArray alloc]init];
    
    for (id phoneData in [contactData valueForKey:@"phones"]) {
        NSString *label = [phoneData valueForKey:@"label"];
        NSString *number = [phoneData valueForKey:@"value"];
        
        CNLabeledValue *phone;
        if ([label isEqual: @"main"]){
            phone = [[CNLabeledValue alloc] initWithLabel:CNLabelPhoneNumberMain value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        else if ([label isEqual: @"mobile"]){
            phone = [[CNLabeledValue alloc] initWithLabel:CNLabelPhoneNumberMobile value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        else if ([label isEqual: @"iPhone"]){
            phone = [[CNLabeledValue alloc] initWithLabel:CNLabelPhoneNumberiPhone value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        else{
            phone = [[CNLabeledValue alloc] initWithLabel:label value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        
        [phoneNumbers addObject:phone];
    }
    contact.phoneNumbers = phoneNumbers;
    
    NSMutableArray *emails = [[NSMutableArray alloc]init];
    
    for (id emailData in [contactData valueForKey:@"emails"]) {
        NSString *label = [emailData valueForKey:@"label"];
        NSString *email = [emailData valueForKey:@"value"];
        
        if(label && email) {
            [emails addObject:[[CNLabeledValue alloc] initWithLabel:label value:email]];
        }
    }
    
    contact.emailAddresses = emails;
    
    NSMutableArray *postalAddresses = [[NSMutableArray alloc]init];
    
    for (id addressData in [contactData valueForKey:@"postalAddresses"]) {
        NSString *label = [addressData valueForKey:@"label"];
        NSString *street = [addressData valueForKey:@"street"];
        NSString *postalCode = [addressData valueForKey:@"postcode"];
        NSString *city = [addressData valueForKey:@"city"];
        NSString *country = [addressData valueForKey:@"country"];
        NSString *state = [addressData valueForKey:@"state"];
        
        if(label && street) {
            CNMutablePostalAddress *postalAddr = [[CNMutablePostalAddress alloc] init];
            postalAddr.street = street;
            postalAddr.postalCode = postalCode;
            postalAddr.city = city;
            postalAddr.country = country;
            postalAddr.state = state;
            [postalAddresses addObject:[[CNLabeledValue alloc] initWithLabel:label value: postalAddr]];
        }
    }
    
    contact.postalAddresses = postalAddresses;
    
    FlutterStandardTypedData *avatarData = [contactData valueForKey:@"avatar"];
    if (avatarData != NULL) {
        contact.imageData = avatarData.data;
    }
}

- (CNMutableContact *) dictionaryToContact:(NSDictionary*)contactData
{
    CNMutableContact * contact = [[CNMutableContact alloc] init];
    NSString *givenName = [contactData valueForKey:@"givenName"];
    NSString *familyName = [contactData valueForKey:@"familyName"];
    NSString *middleName = [contactData valueForKey:@"middleName"];
    NSString *company = [contactData valueForKey:@"company"];
    NSString *jobTitle = [contactData valueForKey:@"jobTitle"];
    
    
    contact.givenName = givenName;
    contact.familyName = familyName;
    contact.middleName = middleName;
    contact.organizationName = company;
    contact.jobTitle = jobTitle;
    
    NSMutableArray *phoneNumbers = [[NSMutableArray alloc]init];
    
    for (id phoneData in [contactData valueForKey:@"phones"]) {
        NSString *label = [phoneData valueForKey:@"label"];
        NSString *number = [phoneData valueForKey:@"value"];
        
        CNLabeledValue *phone;
        if ([label isEqual: @"main"]){
            phone = [[CNLabeledValue alloc] initWithLabel:CNLabelPhoneNumberMain value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        else if ([label isEqual: @"mobile"]){
            phone = [[CNLabeledValue alloc] initWithLabel:CNLabelPhoneNumberMobile value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        else if ([label isEqual: @"iPhone"]){
            phone = [[CNLabeledValue alloc] initWithLabel:CNLabelPhoneNumberiPhone value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        else{
            phone = [[CNLabeledValue alloc] initWithLabel:label value:[[CNPhoneNumber alloc] initWithStringValue:number]];
        }
        
        [phoneNumbers addObject:phone];
    }
    contact.phoneNumbers = phoneNumbers;
    
    NSMutableArray *emails = [[NSMutableArray alloc]init];
    
    for (id emailData in [contactData valueForKey:@"emails"]) {
        NSString *label = [emailData valueForKey:@"label"];
        NSString *email = [emailData valueForKey:@"value"];
        
        if(label && email) {
            [emails addObject:[[CNLabeledValue alloc] initWithLabel:label value:email]];
        }
    }
    
    contact.emailAddresses = emails;
    
    NSMutableArray *postalAddresses = [[NSMutableArray alloc]init];
    
    for (id addressData in [contactData valueForKey:@"postalAddresses"]) {
        NSString *label = [addressData valueForKey:@"label"];
        NSString *street = [addressData valueForKey:@"street"];
        NSString *postalCode = [addressData valueForKey:@"postcode"];
        NSString *city = [addressData valueForKey:@"city"];
        NSString *country = [addressData valueForKey:@"country"];
        NSString *state = [addressData valueForKey:@"state"];
        
        if(label && street) {
            CNMutablePostalAddress *postalAddr = [[CNMutablePostalAddress alloc] init];
            postalAddr.street = street;
            postalAddr.postalCode = postalCode;
            postalAddr.city = city;
            postalAddr.country = country;
            postalAddr.state = state;
            [postalAddresses addObject:[[CNLabeledValue alloc] initWithLabel:label value: postalAddr]];
        }
    }
    
    contact.postalAddresses = postalAddresses;
    
    FlutterStandardTypedData *avatarData = [contactData valueForKey:@"avatar"];
    if (avatarData != NULL) {
        contact.imageData = avatarData.data;
    }
    return contact;
}

-(NSMutableDictionary *) contactToDictionary:(CNContact *) person
                      withThumbnails:(BOOL)withThumbnails
{
    NSMutableDictionary* output = [[NSMutableDictionary alloc] init];
    NSLog(@"%@", person.familyName);
    NSString *recordID = person.identifier;
    NSString *givenName = person.givenName;
    NSString *familyName = person.familyName;
    NSString *middleName = person.middleName;
    NSString *company = person.organizationName;
    NSString *jobTitle = person.jobTitle;
//    NSString *namePrefix = person.namePrefix;
//    NSString *nameSuffix = person.nameSuffix;

    NSLog(@"%@", recordID);
    [output setObject:recordID forKey: @"identifier"];

    [output setObject: givenName forKey:@"givenName"];
    [output setObject: familyName forKey:@"familyName"];
    [output setObject: middleName forKey:@"middleName"];
    [output setObject: company forKey:@"company"];
    [output setObject: jobTitle forKey:@"jobTitle"];
//    [output setObject: namePrefix forKey:@"prefix"];
//    [output setObject: nameSuffix forKey:@"suffix"];
//
    //handle phone numbers
    NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];

    for (CNLabeledValue<CNPhoneNumber*>* labeledValue in person.phoneNumbers) {
        NSMutableDictionary* phone = [NSMutableDictionary dictionary];
        NSString * label = [CNLabeledValue localizedStringForLabel:[labeledValue label]];
        NSString* value = [[labeledValue value] stringValue];

        if(value) {
            if(!label) {
                label = [CNLabeledValue localizedStringForLabel:@"other"];
            }
            [phone setObject: value forKey:@"value"];
            [phone setObject: label forKey:@"label"];
            [phoneNumbers addObject:phone];
        }
    }

    [output setObject: phoneNumbers forKey:@"phones"];
    //end phone numbers


    //handle emails
    NSMutableArray *emailAddreses = [[NSMutableArray alloc] init];

    for (CNLabeledValue<NSString*>* labeledValue in person.emailAddresses) {
        NSMutableDictionary* email = [NSMutableDictionary dictionary];
        NSString* label = [CNLabeledValue localizedStringForLabel:[labeledValue label]];
        NSString* value = [labeledValue value];

        if(value) {
            if(!label) {
                label = [CNLabeledValue localizedStringForLabel:@"other"];
            }
            [email setObject: value forKey:@"value"];
            [email setObject: label forKey:@"label"];
            [emailAddreses addObject:email];
        } else {
            NSLog(@"%@",@"ignoring blank email");
        }
    }

    [output setObject: emailAddreses forKey:@"emails"];
    //end emails

    //handle postal addresses
    NSMutableArray *postalAddresses = [[NSMutableArray alloc] init];

    for (CNLabeledValue<CNPostalAddress*>* labeledValue in person.postalAddresses) {
        CNPostalAddress* postalAddress = labeledValue.value;
        NSMutableDictionary* address = [NSMutableDictionary dictionary];

        NSString* street = postalAddress.street;
        if(street){
            [address setObject:street forKey:@"street"];
        }
        NSString* city = postalAddress.city;
        if(city){
            [address setObject:city forKey:@"city"];
        }
        NSString* state = postalAddress.state;
        if(state){
            [address setObject:state forKey:@"state"];
        }
        NSString* region = postalAddress.state;
        if(region){
            [address setObject:region forKey:@"region"];
        }
        NSString* postCode = postalAddress.postalCode;
        if(postCode){
            [address setObject:postCode forKey:@"postcode"];
        }
        NSString* country = postalAddress.country;
        if(country){
            [address setObject:country forKey:@"country"];
        }

        NSString* label = [CNLabeledValue localizedStringForLabel:labeledValue.label];
        if(label) {
            [address setObject:label forKey:@"label"];

            [postalAddresses addObject:address];
        }
    }

    [output setObject:postalAddresses forKey:@"postalAddresses"];
    //end postal addresses
    
    if (withThumbnails) {
        
    }
    
    return output;
}

- (NSString *)thumbnailFilePath:(NSString *)recordID
{
    NSString *filename = [recordID stringByReplacingOccurrencesOfString:@":ABPerson" withString:@""];
    NSString* filepath = [NSString stringWithFormat:@"%@/rncontacts_%@.png", [self getPathForDirectory:NSCachesDirectory], filename];
    return filepath;
}

-(NSString *) getFilePathForThumbnailImage:(CNContact*) contact recordID:(NSString*) recordID
{
    if (contact.imageDataAvailable){
        NSString *filepath = [self thumbnailFilePath:recordID];
        NSData *contactImageData = contact.thumbnailImageData;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            NSData *existingImageData = [NSData dataWithContentsOfFile: filepath];
            
            if([contactImageData isEqual: existingImageData]) {
                return filepath;
            }
        }
        
        BOOL success = [[NSFileManager defaultManager] createFileAtPath:filepath contents:contactImageData attributes:nil];
        
        if (!success) {
            NSLog(@"%@",@"Unable to copy image");
            return @"";
        }
        
        return filepath;
    }
    
    return @"";
}

- (NSString *)getPathForDirectory:(int)directory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    return [paths firstObject];
}

@end
