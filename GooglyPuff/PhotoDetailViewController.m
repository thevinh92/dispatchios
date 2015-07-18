//
//  PhotoDisplayViewController.m
//  GCDTutorial
//
//  Created by A Magical Unicorn on A Sunday Night.
//  Copyright (c) 2014 Derek Selander. All rights reserved.
//

@import CoreImage;
@import QuartzCore;
#import "PhotoDetailViewController.h"
#import "PhotoManager.h"

const CGFloat kRetinaToEyeScaleFactor = 0.5f;
const CGFloat kFaceBoundsToEyeScaleFactor = 4.0f;

@interface PhotoDetailViewController () <UIScrollViewDelegate>
@property (weak, nonatomic) IBOutlet UIScrollView *photoScrollView;
@property (weak, nonatomic) IBOutlet UIImageView *photoImageView;
@property (nonatomic, strong) UIImage *image;
@end

@implementation PhotoDetailViewController

//*****************************************************************************/
#pragma mark - LifeCycle
//*****************************************************************************/

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSAssert(_image, @"Image not set; required to use view controller");
    self.photoImageView.image = _image;
    
    //Resize if neccessary to ensure it's not pixelated
    if (_image.size.height <= self.photoImageView.bounds.size.height &&
        _image.size.width <= self.photoImageView.bounds.size.width) {
        [self.photoImageView setContentMode:UIViewContentModeCenter];
    }
    
//    UIImage *overlayImage = [self faceOverlayImageFromImage:_image];
//    [self fadeInNewImage:overlayImage];
    
    /*
     1.You first move the work off of the main thread and onto a global queue. Because this is a dispatch_async(), the block is submitted asynchronously meaning that execution of the calling thread continues. This lets viewDidLoad finish earlier on the main thread and makes the loading feel more snappy. Meanwhile, the face detection processing is started and will finish at some later time.
     2.At this point, the face detection processing is complete and you’ve generated a new image. Since you want to use this new image to update your UIImageView, you add a new block of work to the main queue. Remember – you must always access UI Kit classes on the main thread!
     3.Finally, you update the UI with fadeInNewImage: which performs a fade-in transition of the new googly eyes image.
     */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{ //1
        UIImage* overlayImage = [self faceOverlayImageFromImage:_image];
        dispatch_async(dispatch_get_main_queue(), ^{ //2
            [self fadeInNewImage:overlayImage]; //3
        });
    });

}

//*****************************************************************************/
#pragma mark - Public Methods
//*****************************************************************************/

- (void)setupWithImage:(UIImage *)image
{
    self.image = image;
}

//*****************************************************************************/
#pragma mark - Private Methods
//*****************************************************************************/

- (UIImage *)faceOverlayImageFromImage:(UIImage *)image
{
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil
                                              options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    // Get features from the image
    CIImage* newImage = [CIImage imageWithCGImage:image.CGImage];
    
    NSArray *features = [detector featuresInImage:newImage];
    
    UIGraphicsBeginImageContext(image.size);
    CGRect imageRect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    
    //Draws this in the upper left coordinate system
    [image drawInRect:imageRect blendMode:kCGBlendModeNormal alpha:1.0f];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (CIFaceFeature *faceFeature in features) {
        CGRect faceRect = [faceFeature bounds];
        CGContextSaveGState(context);
        
        // CI and CG work in different coordinate systems, we should translate to
        // the correct one so we don't get mixed up when calculating the face position.
        CGContextTranslateCTM(context, 0.0, imageRect.size.height);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        
        if ([faceFeature hasLeftEyePosition]) {
            CGPoint leftEyePosition = [faceFeature leftEyePosition];
            CGFloat eyeWidth = faceRect.size.width / kFaceBoundsToEyeScaleFactor;
            CGFloat eyeHeight = faceRect.size.height / kFaceBoundsToEyeScaleFactor;
            CGRect eyeRect = CGRectMake(leftEyePosition.x - eyeWidth/2.0f,
                                        leftEyePosition.y - eyeHeight/2.0f,
                                        eyeWidth,
                                        eyeHeight);
            [self drawEyeBallForFrame:eyeRect];
        }
        
        if ([faceFeature hasRightEyePosition]) {
            CGPoint leftEyePosition = [faceFeature rightEyePosition];
            CGFloat eyeWidth = faceRect.size.width / kFaceBoundsToEyeScaleFactor;
            CGFloat eyeHeight = faceRect.size.height / kFaceBoundsToEyeScaleFactor;
            CGRect eyeRect = CGRectMake(leftEyePosition.x - eyeWidth / 2.0f,
                                        leftEyePosition.y - eyeHeight / 2.0f,
                                        eyeWidth,
                                        eyeHeight);
            [self drawEyeBallForFrame:eyeRect];
        }
    
        CGContextRestoreGState(context);
    }
    
    UIImage *overlayImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return overlayImage;
}

- (CGFloat)faceRotationInRadiansWithLeftEyePoint:(CGPoint)startPoint rightEyePoint:(CGPoint)endPoint;
{
    CGFloat deltaX = endPoint.x - startPoint.x;
    CGFloat deltaY = endPoint.y - startPoint.y;
    CGFloat angleInRadians = atan2f(deltaY, deltaX);
    
    return angleInRadians;
}

- (void)drawEyeBallForFrame:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(context, rect);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillPath(context);
    
    CGFloat x, y, eyeSizeWidth, eyeSizeHeight;
    eyeSizeWidth = rect.size.width * kRetinaToEyeScaleFactor;
    eyeSizeHeight = rect.size.height * kRetinaToEyeScaleFactor;
    
    x = arc4random_uniform((rect.size.width - eyeSizeWidth));
    y = arc4random_uniform((rect.size.height - eyeSizeHeight));
    x += rect.origin.x;
    y += rect.origin.y;
    
    CGFloat eyeSize = MIN(eyeSizeWidth, eyeSizeHeight);
    CGRect eyeBallRect = CGRectMake(x, y, eyeSize, eyeSize);
    CGContextAddEllipseInRect(context, eyeBallRect);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillPath(context);
}

- (void)fadeInNewImage:(UIImage *)newImage
{
    UIImageView *tmpImageView = [[UIImageView alloc] initWithImage:newImage];
    tmpImageView.contentMode = self.photoImageView.contentMode;
    tmpImageView.frame = self.photoImageView.bounds;
    tmpImageView.alpha = 0.0f;
    [self.photoImageView addSubview:tmpImageView];
    
    [UIView animateWithDuration:0.75f animations:^{
        tmpImageView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        self.photoImageView.image = newImage;
        [tmpImageView removeFromSuperview];
    }];
}

//*****************************************************************************/
#pragma mark - UIScrollViewDelegate
//*****************************************************************************/

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.photoImageView;
}
@end

