#import "ReactNativeShareExtension.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];

    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;

    UIView *rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }

    self.view = rootView;
}


RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
}



RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSString* content, NSString* image, NSString* val, NSString* contentType, NSException* err) {
        if(err) {
//            NSLog(@"error1%@", err);
            reject(@"error", err.description, nil);
        } else {
            resolve(@{
                      @"content": content,
                      @"image": image,
                      @"type": contentType,
                      @"value": val
                      });
        }
    }];
}

- (BOOL)isBlankString:(NSString *)str {
    if (str == nil || str == NULL) {
        return YES;
    }
    if ([str isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if (str.length == 0) {
        return YES;
    }
    if ([[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
        return YES;
    }
    return NO;
}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSString *contentText, NSString* previewImage, NSString *value, NSString* contentType, NSException *exception))callback {
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSAttributedString *content = item.attributedContentText;
        __block NSString *contentStr = content.string;

        NSArray *attachments = item.attachments;
        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;

        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                *stop = YES;
            }
        }];

        if(urlProvider) {
            //???????url
            [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *url = (NSURL *)item;
                if ([self isBlankString:contentStr]) {
                    contentStr = [url absoluteString];
                }
                //??????
                [urlProvider loadPreviewImageWithOptions:nil completionHandler:^(id<NSSecureCoding>  _Nullable item, NSError * _Null_unspecified error) {
                    if (item) {
                        UIImage *image = (UIImage *)item;
                        NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
                        NSString *base64String = [imageData base64EncodedStringWithOptions:kNilOptions];
                        if(callback) {
                            if ([self isBlankString:base64String]) {
                                callback(contentStr, @"image", [url absoluteString], @"text/plain", nil);
                            } else {
                                callback(contentStr, base64String, [url absoluteString], @"text/plain", nil);
                            }
                        }
                    } else {
//                        callback(@"???????image?item?", @"image", [url absoluteString], @"text/plain", nil);
                        callback(contentStr, @"image", [url absoluteString], @"text/plain", nil);
                    }

                }];
            }];
        }
        else if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *url = (NSURL *)item;
                if ([self isBlankString:contentStr]) {
                    contentStr = [url absoluteString];
                }
                if(callback) {
                    callback(contentStr, @"", [url absoluteString], [[[url absoluteString] pathExtension] lowercaseString], nil);
                }
            }];
        } else if (textProvider) {
            NSLog(@"textProvider");
            [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSString *text = (NSString *)item;
                if ([self isBlankString:contentStr]) {
                    contentStr = text;
                }
                if(callback) {
                    callback(contentStr, @"", text, @"text/plain", nil);
                }
            }];
        } else {
            NSLog(@"noProvider");
            if(callback) {
                callback(@"", @"", @"", @"", [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]);
            }
        }
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(@"content", @"image", @"value", @"type", exception);
        }
    }
}

@end
