//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ViewController.h"
#import "UIImage+VisionDetection.h"
#import "UIUtilities.h"

@import MLKit;

NS_ASSUME_NONNULL_BEGIN

static NSArray *images;

static NSString *const detectionNoResultsMessage = @"No results returned.";
static NSString *const failedToDetectObjectsMessage = @"Failed to detect objects in image.";
static NSString *const sparseTextModelName = @"Sparse";
static NSString *const denseTextModelName = @"Dense";
static NSString *const localModelFileName = @"bird";
static NSString *const localModelFileType = @"tflite";

static float const labelConfidenceThreshold = 0.75;
static CGFloat const smallDotRadius = 5.0;
static CGFloat const largeDotRadius = 10.0;
static CGColorRef lineColor;
static CGColorRef fillColor;

static int const rowsCount = 13;
static int const componentsCount = 1;

/**
 * @enum DetectorPickerRow
 * Defines the ML Kit SDK vision detector types.
 */
typedef NS_ENUM(NSInteger, DetectorPickerRow) {
  /** On-Device vision face vision detector. */
  DetectorPickerRowDetectFaceOnDevice,
  /** On-Device vision text vision detector. */
  DetectorPickerRowDetectTextOnDevice,
  /** On-Device vision barcode vision detector. */
  DetectorPickerRowDetectBarcodeOnDevice,
  /** On-Device vision image label detector. */
  DetectorPickerRowDetectImageLabelsOnDevice,
  /** On-Device vision image custom label detector. */
  DetectorPickerRowDetectImageLabelsCustomOnDevice,
  /** On-Device vision object detector, prominent, only tracking. */
  DetectorPickerRowDetectObjectsProminentNoClassifier,
  /** On-Device vision object detector, prominent, with classification. */
  DetectorPickerRowDetectObjectsProminentWithClassifier,
  /** On-Device vision object detector, multiple, only tracking. */
  DetectorPickerRowDetectObjectsMultipleNoClassifier,
  /** On-Device vision object detector, multiple, with classification. */
  DetectorPickerRowDetectObjectsMultipleWithClassifier,
  /** On-Device vision object detector, custom model, prominent, only tracking. */
  DetectorPickerRowDetectObjectsCustomProminentNoClassifier,
  /** On-Device vision object detector, custom model, prominent, with classification. */
  DetectorPickerRowDetectObjectsCustomProminentWithClassifier,
  /** On-Device vision object detector, custom model, multiple, only tracking. */
  DetectorPickerRowDetectObjectsCustomMultipleNoClassifier,
  /** On-Device vision object detector, custom model, multiple, with classification. */
  DetectorPickerRowDetectObjectsCustomMultipleWithClassifier
};

@interface ViewController () <UINavigationControllerDelegate,
                              UIPickerViewDelegate,
                              UIPickerViewDataSource,
                              UIImagePickerControllerDelegate>

/** A string holding current results from detection. */
@property(nonatomic) NSMutableString *resultsText;

/** An overlay view that displays detection annotations. */
@property(nonatomic) UIView *annotationOverlayView;

/** An image picker for accessing the photo library or camera. */
@property(nonatomic) UIImagePickerController *imagePicker;
@property(weak, nonatomic) IBOutlet UIBarButtonItem *detectButton;

// Image counter.
@property(nonatomic) NSUInteger currentImage;

@property(weak, nonatomic) IBOutlet UIPickerView *detectorPicker;
@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property(weak, nonatomic) IBOutlet UIBarButtonItem *photoCameraButton;
@property(weak, nonatomic) IBOutlet UIBarButtonItem *videoCameraButton;

@end

@implementation ViewController

- (NSString *)stringForDetectorPickerRow:(DetectorPickerRow)detectorPickerRow {
  switch (detectorPickerRow) {
    case DetectorPickerRowDetectFaceOnDevice:
      return @"Face On-Device";
    case DetectorPickerRowDetectTextOnDevice:
      return @"Text On-Device";
    case DetectorPickerRowDetectBarcodeOnDevice:
      return @"Barcode On-Device";
    case DetectorPickerRowDetectImageLabelsOnDevice:
      return @"Image Labeling On-Device";
    case DetectorPickerRowDetectImageLabelsCustomOnDevice:
      return @"Image Labeling Custom On-Device";
    case DetectorPickerRowDetectObjectsProminentNoClassifier:
      return @"ODT, single, no labeling";
    case DetectorPickerRowDetectObjectsProminentWithClassifier:
      return @"ODT, single, labeling";
    case DetectorPickerRowDetectObjectsMultipleNoClassifier:
      return @"ODT, multiple, no labeling";
    case DetectorPickerRowDetectObjectsMultipleWithClassifier:
      return @"ODT, multiple, labeling";
    case DetectorPickerRowDetectObjectsCustomProminentNoClassifier:
      return @"ODT, custom, single, no labeling";
    case DetectorPickerRowDetectObjectsCustomProminentWithClassifier:
      return @"ODT, custom, single, labeling";
    case DetectorPickerRowDetectObjectsCustomMultipleNoClassifier:
      return @"ODT, custom, multiple, no labeling";
    case DetectorPickerRowDetectObjectsCustomMultipleWithClassifier:
      return @"ODT, custom, multiple, labeling";
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];

  images = @[
    @"grace_hopper.jpg", @"barcode_128.png", @"qr_code.jpg", @"beach.jpg", @"image_has_text.jpg",
    @"liberty.jpg", @"bird.jpg"
  ];
  lineColor = UIColor.yellowColor.CGColor;
  fillColor = UIColor.clearColor.CGColor;

  self.imagePicker = [UIImagePickerController new];
  self.resultsText = [NSMutableString new];
  _currentImage = 0;
  _imageView.image = [UIImage imageNamed:images[_currentImage]];
  _annotationOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
  _annotationOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
  [_imageView addSubview:_annotationOverlayView];
  [NSLayoutConstraint activateConstraints:@[
    [_annotationOverlayView.topAnchor constraintEqualToAnchor:_imageView.topAnchor],
    [_annotationOverlayView.leadingAnchor constraintEqualToAnchor:_imageView.leadingAnchor],
    [_annotationOverlayView.trailingAnchor constraintEqualToAnchor:_imageView.trailingAnchor],
    [_annotationOverlayView.bottomAnchor constraintEqualToAnchor:_imageView.bottomAnchor]
  ]];
  _imagePicker.delegate = self;
  _imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

  _detectorPicker.delegate = self;
  _detectorPicker.dataSource = self;

  BOOL isCameraAvailable =
      [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront] ||
      [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
  if (isCameraAvailable) {
    // `CameraViewController` uses `AVCaptureDeviceDiscoverySession` which is only supported for
    // iOS 10 or newer.
    if (@available(iOS 10, *)) {
      [_videoCameraButton setEnabled:YES];
    }
  } else {
    [_photoCameraButton setEnabled:NO];
  }

  int defaultRow = (rowsCount / 2) - 1;
  [_detectorPicker selectRow:defaultRow inComponent:0 animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController.navigationBar setHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [self.navigationController.navigationBar setHidden:NO];
}

- (IBAction)detect:(id)sender {
  [self clearResults];
  NSInteger rowIndex = [_detectorPicker selectedRowInComponent:0];
  BOOL shouldEnableClassification =
      (rowIndex == DetectorPickerRowDetectObjectsProminentWithClassifier) ||
      (rowIndex == DetectorPickerRowDetectObjectsMultipleWithClassifier) ||
      (rowIndex == DetectorPickerRowDetectObjectsCustomProminentWithClassifier) ||
      (rowIndex == DetectorPickerRowDetectObjectsCustomMultipleWithClassifier);
  BOOL shouldEnableMultipleObjects =
      (rowIndex == DetectorPickerRowDetectObjectsMultipleNoClassifier) ||
      (rowIndex == DetectorPickerRowDetectObjectsMultipleWithClassifier) ||
      (rowIndex == DetectorPickerRowDetectObjectsCustomMultipleNoClassifier) ||
      (rowIndex == DetectorPickerRowDetectObjectsCustomMultipleWithClassifier);
  switch (rowIndex) {
    case DetectorPickerRowDetectFaceOnDevice:
      [self detectFacesInImage:_imageView.image];
      break;
    case DetectorPickerRowDetectTextOnDevice:
      [self detectTextOnDeviceInImage:_imageView.image];
      break;
    case DetectorPickerRowDetectBarcodeOnDevice:
      [self detectBarcodesInImage:_imageView.image];
      break;
    case DetectorPickerRowDetectImageLabelsOnDevice:
      [self detectLabelsInImage:_imageView.image useCustomModel:NO];
      break;
    case DetectorPickerRowDetectImageLabelsCustomOnDevice:
      [self detectLabelsInImage:_imageView.image useCustomModel:YES];
      break;
    case DetectorPickerRowDetectObjectsProminentNoClassifier:
    case DetectorPickerRowDetectObjectsProminentWithClassifier:
    case DetectorPickerRowDetectObjectsMultipleNoClassifier:
    case DetectorPickerRowDetectObjectsMultipleWithClassifier: {
      MLKObjectDetectorOptions *options = [MLKObjectDetectorOptions new];
      options.shouldEnableClassification = shouldEnableClassification;
      options.shouldEnableMultipleObjects = shouldEnableMultipleObjects;
      options.detectorMode = MLKObjectDetectorModeSingleImage;
      [self detectObjectsOnDeviceInImage:_imageView.image withOptions:options];
      break;
    }
    case DetectorPickerRowDetectObjectsCustomProminentNoClassifier:
    case DetectorPickerRowDetectObjectsCustomProminentWithClassifier:
    case DetectorPickerRowDetectObjectsCustomMultipleNoClassifier:
    case DetectorPickerRowDetectObjectsCustomMultipleWithClassifier: {
      NSString *localModelFilePath = [[NSBundle mainBundle] pathForResource:localModelFileName
                                                                     ofType:localModelFileType];
      if (localModelFilePath == nil) {
        NSLog(@"Failed to find custom local model file: %@.%@", localModelFileName,
              localModelFileType);
        return;
      }
      MLKLocalModel *localModel = [[MLKLocalModel alloc] initWithPath:localModelFilePath];
      MLKCustomObjectDetectorOptions *options =
          [[MLKCustomObjectDetectorOptions alloc] initWithLocalModel:localModel];
      options.shouldEnableClassification = shouldEnableClassification;
      options.shouldEnableMultipleObjects = shouldEnableMultipleObjects;
      options.detectorMode = MLKObjectDetectorModeSingleImage;
      [self detectObjectsOnDeviceInImage:_imageView.image withOptions:options];
      break;
    }
  }
}

- (IBAction)openPhotoLibrary:(id)sender {
  _imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  [self presentViewController:_imagePicker animated:YES completion:nil];
}

- (IBAction)openCamera:(id)sender {
  if (![UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront] &&
      ![UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]) {
    return;
  }
  _imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
  [self presentViewController:_imagePicker animated:YES completion:nil];
}

- (IBAction)changeImage:(id)sender {
  [self clearResults];
  self.currentImage = (_currentImage + 1) % images.count;
  _imageView.image = [UIImage imageNamed:images[_currentImage]];
}

/// Removes the detection annotations from the annotation overlay view.
- (void)removeDetectionAnnotations {
  for (UIView *annotationView in _annotationOverlayView.subviews) {
    [annotationView removeFromSuperview];
  }
}

/// Clears the results text view and removes any frames that are visible.
- (void)clearResults {
  [self removeDetectionAnnotations];
  self.resultsText = [NSMutableString new];
}

- (void)showResults {
  UIAlertController *resultsAlertController =
      [UIAlertController alertControllerWithTitle:@"Detection Results"
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  [resultsAlertController
      addAction:[UIAlertAction actionWithTitle:@"OK"
                                         style:UIAlertActionStyleDestructive
                                       handler:^(UIAlertAction *_Nonnull action) {
                                         [resultsAlertController dismissViewControllerAnimated:YES
                                                                                    completion:nil];
                                       }]];
  resultsAlertController.message = _resultsText;
  resultsAlertController.popoverPresentationController.barButtonItem = _detectButton;
  resultsAlertController.popoverPresentationController.sourceView = self.view;
  [self presentViewController:resultsAlertController animated:YES completion:nil];
  NSLog(@"%@", _resultsText);
}

/// Updates the image view with a scaled version of the given image.
- (void)updateImageViewWithImage:(UIImage *)image {
  CGFloat scaledImageWidth = 0.0;
  CGFloat scaledImageHeight = 0.0;
  switch (UIApplication.sharedApplication.statusBarOrientation) {
    case UIInterfaceOrientationPortrait:
    case UIInterfaceOrientationPortraitUpsideDown:
    case UIInterfaceOrientationUnknown:
      scaledImageWidth = _imageView.bounds.size.width;
      scaledImageHeight = image.size.height * scaledImageWidth / image.size.width;
      break;
    case UIInterfaceOrientationLandscapeLeft:
    case UIInterfaceOrientationLandscapeRight:
      scaledImageWidth = image.size.width * scaledImageHeight / image.size.height;
      scaledImageHeight = _imageView.bounds.size.height;
      break;
  }

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
    UIImage *scaledImage =
        [image scaledImageWithSize:CGSizeMake(scaledImageWidth, scaledImageHeight)];
    if (!scaledImage) {
      scaledImage = image;
    }
    if (!scaledImage) {
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      self->_imageView.image = scaledImage;
    });
  });
}

- (CGAffineTransform)transformMatrix {
  UIImage *image = _imageView.image;
  if (!image) {
    return CGAffineTransformMake(0, 0, 0, 0, 0, 0);
  }
  CGFloat imageViewWidth = _imageView.frame.size.width;
  CGFloat imageViewHeight = _imageView.frame.size.height;
  CGFloat imageWidth = image.size.width;
  CGFloat imageHeight = image.size.height;

  CGFloat imageViewAspectRatio = imageViewWidth / imageViewHeight;
  CGFloat imageAspectRatio = imageWidth / imageHeight;
  CGFloat scale = (imageViewAspectRatio > imageAspectRatio) ? imageViewHeight / imageHeight
                                                            : imageViewWidth / imageWidth;

  // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
  // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
  CGFloat scaledImageWidth = imageWidth * scale;
  CGFloat scaledImageHeight = imageHeight * scale;
  CGFloat xValue = (imageViewWidth - scaledImageWidth) / 2.0;
  CGFloat yValue = (imageViewHeight - scaledImageHeight) / 2.0;

  CGAffineTransform transform =
      CGAffineTransformTranslate(CGAffineTransformIdentity, xValue, yValue);
  return CGAffineTransformScale(transform, scale, scale);
}

- (CGPoint)pointFromVisionPoint:(MLKVisionPoint *)visionPoint {
  return CGPointMake(visionPoint.x, visionPoint.y);
}

- (void)addContoursForFace:(MLKFace *)face transform:(CGAffineTransform)transform {
  // Face
  MLKFaceContour *faceContour = [face contourOfType:MLKFaceContourTypeFace];
  for (MLKVisionPoint *visionPoint in faceContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }

  // Eyebrows
  MLKFaceContour *leftEyebrowTopContour = [face contourOfType:MLKFaceContourTypeLeftEyebrowTop];
  for (MLKVisionPoint *visionPoint in leftEyebrowTopContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *leftEyebrowBottomContour =
      [face contourOfType:MLKFaceContourTypeLeftEyebrowBottom];
  for (MLKVisionPoint *visionPoint in leftEyebrowBottomContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *rightEyebrowTopContour = [face contourOfType:MLKFaceContourTypeRightEyebrowTop];
  for (MLKVisionPoint *visionPoint in rightEyebrowTopContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *rightEyebrowBottomContour =
      [face contourOfType:MLKFaceContourTypeRightEyebrowBottom];
  for (MLKVisionPoint *visionPoint in rightEyebrowBottomContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }

  // Eyes
  MLKFaceContour *leftEyeContour = [face contourOfType:MLKFaceContourTypeLeftEye];
  for (MLKVisionPoint *visionPoint in leftEyeContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *rightEyeContour = [face contourOfType:MLKFaceContourTypeRightEye];
  for (MLKVisionPoint *visionPoint in rightEyeContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }

  // Lips
  MLKFaceContour *upperLipTopContour = [face contourOfType:MLKFaceContourTypeUpperLipTop];
  for (MLKVisionPoint *visionPoint in upperLipTopContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *upperLipBottomContour = [face contourOfType:MLKFaceContourTypeUpperLipBottom];
  for (MLKVisionPoint *visionPoint in upperLipBottomContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *lowerLipTopContour = [face contourOfType:MLKFaceContourTypeLowerLipTop];
  for (MLKVisionPoint *visionPoint in lowerLipTopContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *lowerLipBottomContour = [face contourOfType:MLKFaceContourTypeLowerLipBottom];
  for (MLKVisionPoint *visionPoint in lowerLipBottomContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }

  // Nose
  MLKFaceContour *noseBridgeContour = [face contourOfType:MLKFaceContourTypeNoseBridge];
  for (MLKVisionPoint *visionPoint in noseBridgeContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
  MLKFaceContour *noseBottomContour = [face contourOfType:MLKFaceContourTypeNoseBottom];
  for (MLKVisionPoint *visionPoint in noseBottomContour.points) {
    CGPoint point = [self pointFromVisionPoint:visionPoint];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:self->_annotationOverlayView
                            color:UIColor.greenColor
                           radius:smallDotRadius];
  }
}

- (void)addLandmarksForFace:(MLKFace *)face transform:(CGAffineTransform)transform {
  // Mouth
  MLKFaceLandmark *bottomMouthLandmark = [face landmarkOfType:MLKFaceLandmarkTypeMouthBottom];
  if (bottomMouthLandmark) {
    CGPoint point = [self pointFromVisionPoint:bottomMouthLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.redColor
                           radius:largeDotRadius];
  }
  MLKFaceLandmark *leftMouthLandmark = [face landmarkOfType:MLKFaceLandmarkTypeMouthLeft];
  if (leftMouthLandmark) {
    CGPoint point = [self pointFromVisionPoint:leftMouthLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.redColor
                           radius:largeDotRadius];
  }
  MLKFaceLandmark *rightMouthLandmark = [face landmarkOfType:MLKFaceLandmarkTypeMouthLeft];
  if (rightMouthLandmark) {
    CGPoint point = [self pointFromVisionPoint:rightMouthLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.redColor
                           radius:largeDotRadius];
  }

  // Nose
  MLKFaceLandmark *noseBaseLandmark = [face landmarkOfType:MLKFaceLandmarkTypeNoseBase];
  if (noseBaseLandmark) {
    CGPoint point = [self pointFromVisionPoint:noseBaseLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.yellowColor
                           radius:largeDotRadius];
  }

  // Eyes
  MLKFaceLandmark *leftEyeLandmark = [face landmarkOfType:MLKFaceLandmarkTypeLeftEye];
  if (leftEyeLandmark) {
    CGPoint point = [self pointFromVisionPoint:leftEyeLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.cyanColor
                           radius:largeDotRadius];
  }
  MLKFaceLandmark *rightEyeLandmark = [face landmarkOfType:MLKFaceLandmarkTypeRightEye];
  if (rightEyeLandmark) {
    CGPoint point = [self pointFromVisionPoint:rightEyeLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.cyanColor
                           radius:largeDotRadius];
  }

  // Ears
  MLKFaceLandmark *leftEarLandmark = [face landmarkOfType:MLKFaceLandmarkTypeLeftEye];
  if (leftEarLandmark) {
    CGPoint point = [self pointFromVisionPoint:leftEarLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.purpleColor
                           radius:largeDotRadius];
  }
  MLKFaceLandmark *rightEarLandmark = [face landmarkOfType:MLKFaceLandmarkTypeRightEye];
  if (rightEarLandmark) {
    CGPoint point = [self pointFromVisionPoint:rightEarLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.purpleColor
                           radius:largeDotRadius];
  }

  // Cheeks
  MLKFaceLandmark *leftCheekLandmark = [face landmarkOfType:MLKFaceLandmarkTypeLeftEye];
  if (leftCheekLandmark) {
    CGPoint point = [self pointFromVisionPoint:leftCheekLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.orangeColor
                           radius:largeDotRadius];
  }
  MLKFaceLandmark *rightCheekLandmark = [face landmarkOfType:MLKFaceLandmarkTypeRightEye];
  if (rightCheekLandmark) {
    CGPoint point = [self pointFromVisionPoint:rightCheekLandmark.position];
    CGPoint transformedPoint = CGPointApplyAffineTransform(point, transform);
    [UIUtilities addCircleAtPoint:transformedPoint
                           toView:_annotationOverlayView
                            color:UIColor.orangeColor
                           radius:largeDotRadius];
  }
}

- (void)process:(MLKVisionImage *)visionImage
    withTextRecognizer:(MLKTextRecognizer *)textRecognizer {
  // [START recognize_text]
  [textRecognizer
      processImage:visionImage
        completion:^(MLKText *_Nullable text, NSError *_Nullable error) {
          if (text == nil) {
            // [START_EXCLUDE]
            self.resultsText = [NSMutableString
                stringWithFormat:@"Text recognizer failed with error: %@",
                                 error ? error.localizedDescription : detectionNoResultsMessage];
            [self showResults];
            // [END_EXCLUDE]
            return;
          }

          // [START_EXCLUDE]
          // Blocks.
          for (MLKTextBlock *block in text.blocks) {
            CGRect transformedRect =
                CGRectApplyAffineTransform(block.frame, [self transformMatrix]);
            [UIUtilities addRectangle:transformedRect
                               toView:self.annotationOverlayView
                                color:UIColor.purpleColor];

            // Lines.
            for (MLKTextLine *line in block.lines) {
              CGRect transformedRect =
                  CGRectApplyAffineTransform(line.frame, [self transformMatrix]);
              [UIUtilities addRectangle:transformedRect
                                 toView:self.annotationOverlayView
                                  color:UIColor.orangeColor];

              // Elements.
              for (MLKTextElement *element in line.elements) {
                CGRect transformedRect =
                    CGRectApplyAffineTransform(element.frame, [self transformMatrix]);
                [UIUtilities addRectangle:transformedRect
                                   toView:self.annotationOverlayView
                                    color:UIColor.greenColor];
                UILabel *label = [[UILabel alloc] initWithFrame:transformedRect];
                label.text = element.text;
                label.adjustsFontSizeToFitWidth = YES;
                [self.annotationOverlayView addSubview:label];
              }
            }
          }
          [self.resultsText appendFormat:@"%@\n", text.text];
          [self showResults];
          // [END_EXCLUDE]
        }];
  // [END recognize_text]
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
  return componentsCount;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView
    numberOfRowsInComponent:(NSInteger)component {
  return rowsCount;
}

#pragma mark - UIPickerViewDelegate

- (nullable NSString *)pickerView:(UIPickerView *)pickerView
                      titleForRow:(NSInteger)row
                     forComponent:(NSInteger)component {
  return [self stringForDetectorPickerRow:row];
}

- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
  [self clearResults];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
    didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info {
  [self clearResults];
  UIImage *pickedImage = info[UIImagePickerControllerOriginalImage];
  if (pickedImage) {
    [self updateImageViewWithImage:pickedImage];
  }
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Vision On-Device Detection

/// Detects faces on the specified image and draws a frame around the detected faces using
/// On-Device face API.
///
/// - Parameter image: The image.
- (void)detectFacesInImage:(UIImage *)image {
  if (!image) {
    return;
  }

  // Create a face detector with options.
  // [START config_face]
  MLKFaceDetectorOptions *options = [MLKFaceDetectorOptions new];
  options.landmarkMode = MLKFaceDetectorLandmarkModeAll;
  options.contourMode = MLKFaceDetectorContourModeAll;
  options.classificationMode = MLKFaceDetectorClassificationModeAll;
  options.performanceMode = MLKFaceDetectorPerformanceModeAccurate;
  // [END config_face]

  // [START init_face]
  MLKFaceDetector *faceDetector = [MLKFaceDetector faceDetectorWithOptions:options];
  // [END init_face]

  // Initialize a VisionImage object with the given UIImage.
  MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
  visionImage.orientation = image.imageOrientation;

  // [START detect_faces]
  [faceDetector
      processImage:visionImage
        completion:^(NSArray<MLKFace *> *_Nullable faces, NSError *_Nullable error) {
          if (!faces || faces.count == 0) {
            // [START_EXCLUDE]
            NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
            self.resultsText = [NSMutableString
                stringWithFormat:@"On-Device face detection failed with error: %@", errorString];
            [self showResults];
            // [END_EXCLUDE]
            return;
          }

          // Faces detected
          // [START_EXCLUDE]
          [self.resultsText setString:@""];
          for (MLKFace *face in faces) {
            CGAffineTransform transform = [self transformMatrix];
            CGRect transformedRect = CGRectApplyAffineTransform(face.frame, transform);
            [UIUtilities addRectangle:transformedRect
                               toView:self.annotationOverlayView
                                color:UIColor.greenColor];
            [self addLandmarksForFace:face transform:transform];
            [self addContoursForFace:face transform:transform];
            [self.resultsText appendFormat:@"Frame: %@\n", NSStringFromCGRect(face.frame)];
            NSString *headEulerAngleX =
                face.hasHeadEulerAngleX ? [NSString stringWithFormat:@"%.2f", face.headEulerAngleX]
                                        : @"NA";
            NSString *headEulerAngleY =
                face.hasHeadEulerAngleY ? [NSString stringWithFormat:@"%.2f", face.headEulerAngleY]
                                        : @"NA";
            NSString *headEulerAngleZ =
                face.hasHeadEulerAngleZ ? [NSString stringWithFormat:@"%.2f", face.headEulerAngleZ]
                                        : @"NA";
            NSString *leftEyeOpenProbability =
                face.hasLeftEyeOpenProbability
                    ? [NSString stringWithFormat:@"%.2f", face.leftEyeOpenProbability]
                    : @"NA";
            NSString *rightEyeOpenProbability =
                face.hasRightEyeOpenProbability
                    ? [NSString stringWithFormat:@"%.2f", face.rightEyeOpenProbability]
                    : @"NA";
            NSString *smilingProbability =
                face.hasSmilingProbability
                    ? [NSString stringWithFormat:@"%.2f", face.smilingProbability]
                    : @"NA";
            [self.resultsText appendFormat:@"Head Euler Angle X: %@\n", headEulerAngleX];
            [self.resultsText appendFormat:@"Head Euler Angle Y: %@\n", headEulerAngleY];
            [self.resultsText appendFormat:@"Head Euler Angle Z: %@\n", headEulerAngleZ];
            [self.resultsText
                appendFormat:@"Left Eye Open Probability: %@\n", leftEyeOpenProbability];
            [self.resultsText
                appendFormat:@"Right Eye Open Probability: %@\n", rightEyeOpenProbability];
            [self.resultsText appendFormat:@"Smiling Probability: %@\n", smilingProbability];
          }
          [self showResults];
          // [END_EXCLUDE]
        }];
  // [END detect_faces]
}

/// Detects barcodes on the specified image and draws a frame around the detected barcodes using
/// On-Device barcode API.
///
/// - Parameter image: The image.
- (void)detectBarcodesInImage:(UIImage *)image {
  if (!image) {
    return;
  }

  // Define the options for a barcode detector.
  // [START config_barcode]
  MLKBarcodeFormat format = MLKBarcodeFormatAll;
  MLKBarcodeScannerOptions *barcodeOptions =
      [[MLKBarcodeScannerOptions alloc] initWithFormats:format];
  // [END config_barcode]

  // Create a barcode detector.
  // [START init_barcode]
  MLKBarcodeScanner *barcodeScanner = [MLKBarcodeScanner barcodeScannerWithOptions:barcodeOptions];
  // [END init_barcode]

  // Initialize a VisionImage object with the given UIImage.
  MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
  visionImage.orientation = image.imageOrientation;

  // [START detect_barcodes]
  [barcodeScanner
      processImage:visionImage
        completion:^(NSArray<MLKBarcode *> *_Nullable barcodes, NSError *_Nullable error) {
          if (!barcodes || barcodes.count == 0) {
            // [START_EXCLUDE]
            NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
            self.resultsText = [NSMutableString
                stringWithFormat:@"On-Device barcode detection failed with error: %@", errorString];
            [self showResults];
            // [END_EXCLUDE]
            return;
          }

          // [START_EXCLUDE]
          [self.resultsText setString:@""];
          for (MLKBarcode *barcode in barcodes) {
            CGAffineTransform transform = [self transformMatrix];
            CGRect transformedRect = CGRectApplyAffineTransform(barcode.frame, transform);
            [UIUtilities addRectangle:transformedRect
                               toView:self.annotationOverlayView
                                color:UIColor.greenColor];
            [self.resultsText appendFormat:@"DisplayValue: %@, RawValue: %@, Frame: %@\n",
                                           barcode.displayValue, barcode.rawValue,
                                           NSStringFromCGRect(barcode.frame)];
          }
          [self showResults];
          // [END_EXCLUDE]
        }];
  // [END detect_barcodes]
}

/// Detects labels on the specified image using On-Device label API.
///
/// - Parameter image: The image.
/// - Parameter useCustomModel: Whether to use the custom image labeling model.
- (void)detectLabelsInImage:(UIImage *)image useCustomModel:(BOOL)useCustomModel {
  if (!image) {
    return;
  }

  // [START config_label]
  MLKCommonImageLabelerOptions *options;
  if (useCustomModel) {
    NSString *localModelPath = [[NSBundle mainBundle] pathForResource:localModelFileName
                                                               ofType:localModelFileType];
    MLKLocalModel *localModel = [[MLKLocalModel alloc] initWithPath:localModelPath];
    options = [[MLKCustomImageLabelerOptions alloc] initWithLocalModel:localModel];
  } else {
    options = [[MLKImageLabelerOptions alloc] init];
  }
  options.confidenceThreshold = @(labelConfidenceThreshold);
  // [END config_label]

  // [START init_label]
  MLKImageLabeler *onDeviceLabeler = [MLKImageLabeler imageLabelerWithOptions:options];
  // [END init_label]

  // Initialize a VisionImage object with the given UIImage.
  MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
  visionImage.orientation = image.imageOrientation;

  // [START detect_label]
  [onDeviceLabeler
      processImage:visionImage
        completion:^(NSArray<MLKImageLabel *> *_Nullable labels, NSError *_Nullable error) {
          if (!labels || labels.count == 0) {
            // [START_EXCLUDE]
            NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
            [self.resultsText
                appendFormat:@"On-Device label detection failed with error: %@", errorString];
            [self showResults];
            // [END_EXCLUDE]
            return;
          }

          // [START_EXCLUDE]
          [self.resultsText setString:@""];
          for (MLKImageLabel *label in labels) {
            [self.resultsText
                appendFormat:@"Label: %@, Confidence: %f\n", label.text, label.confidence];
          }
          [self showResults];
          // [END_EXCLUDE]
        }];
  // [END detect_label]
}

/// Detects text on the specified image and draws a frame around the recognized text using the
/// On-Device text recognizer.
///
/// - Parameter image: The image.
- (void)detectTextOnDeviceInImage:(UIImage *)image {
  if (!image) {
    return;
  }

  // [START init_text]
  MLKTextRecognizer *onDeviceTextRecognizer = [MLKTextRecognizer textRecognizer];
  // [END init_text]

  // Initialize a VisionImage object with the given UIImage.
  MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
  visionImage.orientation = image.imageOrientation;

  [self.resultsText appendString:@"Running On-Device Text Recognition...\n"];
  [self process:visionImage withTextRecognizer:onDeviceTextRecognizer];
}

/// Detects objects on the specified image and draws a frame around them.
///
/// - Parameter image: The image.
/// - Parameter options: The options for object detector.
- (void)detectObjectsOnDeviceInImage:(UIImage *)image
                         withOptions:(MLKCommonObjectDetectorOptions *)options {
  if (!image) {
    return;
  }

  // [START init_object_detector]
  // Create an objects detector with options.
  MLKObjectDetector *detector = [MLKObjectDetector objectDetectorWithOptions:options];
  // [END init_object_detector]

  // Initialize a VisionImage object with the given UIImage.
  MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
  visionImage.orientation = image.imageOrientation;

  // [START detect_object]
  [detector
      processImage:visionImage
        completion:^(NSArray<MLKObject *> *_Nullable objects, NSError *_Nullable error) {
          if (error != nil) {
            // [START_EXCLUDE]
            NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
            self.resultsText = [NSMutableString
                stringWithFormat:@"Object detection failed with error: %@", errorString];
            [self showResults];
            // [END_EXCLUDE]
          }
          if (!objects || objects.count == 0) {
            // [START_EXCLUDE]
            self.resultsText = [@"On-Device object detector returned no results." mutableCopy];
            [self showResults];
            // [END_EXCLUDE]
            return;
          }

          // [START_EXCLUDE]
          [self.resultsText setString:@""];
          for (MLKObject *object in objects) {
            CGAffineTransform transform = [self transformMatrix];
            CGRect transformedRect = CGRectApplyAffineTransform(object.frame, transform);
            [UIUtilities addRectangle:transformedRect
                               toView:self.annotationOverlayView
                                color:UIColor.greenColor];

            [self.resultsText appendFormat:@"Frame: %@\nObject ID: %@\nLabels:\n",
                                           NSStringFromCGRect(object.frame), object.trackingID];
            int i = 0;
            for (MLKObjectLabel *l in object.labels) {
              NSString *labelString =
                  [NSString stringWithFormat:@"Label %d: %@, %f, %lu\n", i++, l.text, l.confidence,
                                             (unsigned long)l.index];
              [self.resultsText appendString:labelString];
            }
          }
          [self showResults];
          // [END_EXCLUDE]
        }];
  // [END detect_object]
}
@end

NS_ASSUME_NONNULL_END
