/*
 * Copyright (c) 2015, Nordic Semiconductor
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DFUViewController.h"
#import "ScannerViewController.h"

#import "Constants.h"
#import "HelpViewController.h"
#import "FileTypeTableViewController.h"
#import "SSZipArchive.h"
#import "UnzipFirmware.h"
#import "Utility.h"
#import "JsonParser.h"


@interface DFUViewController () {
    
}

/*!
 * This property is set when the device has been selected on the Scanner View Controller.
 */
@property (strong, nonatomic) CBPeripheral *selectedPeripheral;
@property (nonatomic)DfuFirmwareTypes enumFirmwareType;

@property DFUOperations *dfuOperations;
@property NSURL *selectedFileURL;
@property NSURL *softdeviceURL;
@property NSURL *bootloaderURL;
@property NSURL *applicationURL;
@property NSURL *applicationMetaDataURL;
@property NSURL *bootloaderMetaDataURL;
@property NSURL *softdeviceMetaDataURL;
@property NSURL *systemMetaDataURL;
@property NSURL *softdevice_bootloaderURL;
@property NSUInteger selectedFileSize;
@property (nonatomic, retain)InitData *manifestData;
@property int dfuVersion;


@property (weak, nonatomic) IBOutlet UILabel *fileName;
@property (weak, nonatomic) IBOutlet UILabel *fileSize;


@property (weak, nonatomic) IBOutlet UILabel *uploadStatus;
@property (weak, nonatomic) IBOutlet UIProgressView *progress;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectFileButton;
@property (weak, nonatomic) IBOutlet UIView *uploadPane;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UILabel *fileType;
@property (weak, nonatomic) IBOutlet UIButton *selectFileTypeButton;

@property BOOL isTransferring;
@property BOOL isTransfered;
@property BOOL isTransferCancelled;
@property BOOL isConnected;
@property BOOL isErrorKnown;
@property BOOL isSelectedFileZipped;
@property BOOL isDfuVersionExist;
@property BOOL isManifestExist;

- (IBAction)uploadPressed;

@end

@implementation DFUViewController

@synthesize backgroundImage;
@synthesize deviceName;
@synthesize connectButton;
@synthesize selectedPeripheral;
@synthesize dfuOperations;
@synthesize fileName;
@synthesize fileSize;
@synthesize uploadStatus;
@synthesize progress;
@synthesize progressLabel;
@synthesize selectFileButton;
@synthesize uploadButton;
@synthesize uploadPane;
@synthesize selectedFileURL;
@synthesize fileType;
@synthesize enumFirmwareType;
@synthesize selectedFileType;
@synthesize selectFileTypeButton;


-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        PACKETS_NOTIFICATION_INTERVAL = [[[NSUserDefaults standardUserDefaults] valueForKey:@"dfu_number_of_packets"] intValue];
        NSLog(@"PACKETS_NOTIFICATION_INTERVAL %d",PACKETS_NOTIFICATION_INTERVAL);
        dfuOperations = [[DFUOperations alloc] initWithDelegate:self];
    }
    return self;
}

- (void)viewDidLoad
{
    if (is4InchesIPhone)
    {
        // 4 inches iPhone
        UIImage *image = [UIImage imageNamed:@"Background4.png"];
        [backgroundImage setImage:image];
    }
    else
    {
        // 3.5 inches iPhone
        UIImage *image = [UIImage imageNamed:@"Background35.png"];
        [backgroundImage setImage:image];
    }
    
    // Rotate the vertical label
    self.verticalLabel.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(-145.0f, 0.0f), (float)(-M_PI / 2));
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:YES];
    //if DFU peripheral is connected and user press Back button then disconnect it
    if ([self isMovingFromParentViewController] && self.isConnected) {
        NSLog(@"isMovingFromParentViewController");
        [dfuOperations cancelDFU];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)uploadPressed
{
    if (self.isTransferring) {
        [dfuOperations cancelDFU];
    }
    else {
        [self performDFU];
    }
}

-(void)performDFU
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self disableOtherButtons];
        uploadStatus.hidden = NO;
        progress.hidden = NO;
        progressLabel.hidden = NO;
        uploadButton.enabled = NO;
    });
    if (self.isSelectedFileZipped) {
        switch (enumFirmwareType) {
            case SOFTDEVICE_AND_BOOTLOADER:
                if (self.isDfuVersionExist) {
                    if (self.isManifestExist) {
                        [dfuOperations performDFUOnFileWithMetaDataAndFileSizes:self.softdevice_bootloaderURL firmwareMetaDataURL:self.systemMetaDataURL softdeviceFileSize:self.manifestData.softdeviceSize bootloaderFileSize:self.manifestData.bootloaderSize firmwareType:SOFTDEVICE_AND_BOOTLOADER];
                    }
                    else {
                        [dfuOperations performDFUOnFilesWithMetaData:self.softdeviceURL bootloaderURL:self.bootloaderURL firmwaresMetaDataURL:self.systemMetaDataURL firmwareType:SOFTDEVICE_AND_BOOTLOADER];
                    }
                    
                }
                else {
                    [dfuOperations performDFUOnFiles:self.softdeviceURL bootloaderURL:self.bootloaderURL firmwareType:SOFTDEVICE_AND_BOOTLOADER];
                }
                
                break;
            case SOFTDEVICE:
                if (self.isDfuVersionExist) {
                    [dfuOperations performDFUOnFileWithMetaData:self.softdeviceURL firmwareMetaDataURL:self.softdeviceMetaDataURL firmwareType:SOFTDEVICE];
                }
                else {
                    [dfuOperations performDFUOnFile:self.softdeviceURL firmwareType:SOFTDEVICE];
                }
                break;
            case BOOTLOADER:
                if (self.isDfuVersionExist) {
                    [dfuOperations performDFUOnFileWithMetaData:self.bootloaderURL firmwareMetaDataURL:self.bootloaderMetaDataURL firmwareType:BOOTLOADER];
                }
                else {
                    [dfuOperations performDFUOnFile:self.bootloaderURL firmwareType:BOOTLOADER];
                }
                break;
            case APPLICATION:
                if (self.isDfuVersionExist) {
                    [dfuOperations performDFUOnFileWithMetaData:self.applicationURL firmwareMetaDataURL:self.applicationMetaDataURL firmwareType:APPLICATION];
                }
                else {
                [dfuOperations performDFUOnFile:self.applicationURL firmwareType:APPLICATION];
                }
                break;
                
            default:
                NSLog(@"Not valid File type");
                break;
        }
    }
    else {
        [dfuOperations performDFUOnFile:selectedFileURL firmwareType:enumFirmwareType];
    }
}

//Unzip and check if both bin and hex formats are present for same file then pick only bin format and drop hex format
-(void)unzipFiles:(NSURL *)zipFileURL
{
    self.softdeviceURL = self.bootloaderURL = self.applicationURL = nil;
    self.softdeviceMetaDataURL = self.bootloaderMetaDataURL = self.applicationMetaDataURL = self.systemMetaDataURL = nil;
    UnzipFirmware *unzipFiles = [[UnzipFirmware alloc]init];
    NSArray *firmwareFilesURL = [unzipFiles unzipFirmwareFiles:zipFileURL];
    if ([self getManifestFile:firmwareFilesURL]) {
        self.isManifestExist = YES;
        return;
    }
    [self getHexAndDatFile:firmwareFilesURL];
    [self getBinFiles:firmwareFilesURL];
}

-(BOOL)getManifestFile:(NSArray *)firmwareFilesURL
{
    for (NSURL *firmwareManifestURL in firmwareFilesURL) {
        if ([[[firmwareManifestURL path] lastPathComponent] isEqualToString:@"manifest.json"]) {
            //TODO now parse the manifest.json file and then search the required files and assigned to appropriate properties (i.e self.softdeviceURL, self.bootloaderURL, self.applicationURL, self.applicationMetaDataURL, ...)
            NSData *data = [NSData dataWithContentsOfURL:firmwareManifestURL];
            self.manifestData = [[[JsonParser alloc]init] parseJson:data];
            [self getBinAndDatFilesAsMentionedInManfest:firmwareFilesURL jsonPacketData:self.manifestData];
            return YES;
        }
    }
    return NO;
}

-(void)getBinAndDatFilesAsMentionedInManfest:(NSArray *)firmwareFilesURL jsonPacketData:(InitData *)data
{
    for (NSURL *firmwareURL in firmwareFilesURL) {
        if ([[[firmwareURL path] lastPathComponent] isEqualToString:data.firmwareBinFileName]) {
            if (data.firmwareType == SOFTDEVICE) {
                self.softdeviceURL = firmwareURL;
            }
            else if (data.firmwareType == BOOTLOADER) {
                self.bootloaderURL = firmwareURL;
            }
            else if (data.firmwareType == APPLICATION)
            {
                self.applicationURL = firmwareURL;
            }
            else if (data.firmwareType == SOFTDEVICE_AND_BOOTLOADER)
            {
                self.softdevice_bootloaderURL = firmwareURL;
            }
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:data.firmwareDatFileName]) {
            if (data.firmwareType == SOFTDEVICE) {
                self.softdeviceMetaDataURL = firmwareURL;
            }
            else if (data.firmwareType == BOOTLOADER) {
                self.bootloaderMetaDataURL = firmwareURL;
            }
            else if (data.firmwareType == APPLICATION)
            {
                self.applicationMetaDataURL = firmwareURL;
            }
            else if (data.firmwareType == SOFTDEVICE_AND_BOOTLOADER)
            {
                self.systemMetaDataURL = firmwareURL;
            }
        }
    }
}

-(void)getHexAndDatFile:(NSArray *)firmwareFilesURL
{
    for (NSURL *firmwareURL in firmwareFilesURL) {
        if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"softdevice.hex"]) {
            self.softdeviceURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"bootloader.hex"]) {
            self.bootloaderURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"application.hex"]) {
            self.applicationURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"application.dat"]) {
            self.applicationMetaDataURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"bootloader.dat"]) {
            self.bootloaderMetaDataURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"softdevice.dat"]) {
            self.softdeviceMetaDataURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"system.dat"]) {
            self.systemMetaDataURL = firmwareURL;
        }
    }
}

-(void)getBinFiles:(NSArray *)firmwareFilesURL
{
    for (NSURL *firmwareBinURL in firmwareFilesURL) {
        if ([[[firmwareBinURL path] lastPathComponent] isEqualToString:@"softdevice.bin"]) {
            self.softdeviceURL = firmwareBinURL;
        }
        else if ([[[firmwareBinURL path] lastPathComponent] isEqualToString:@"bootloader.bin"]) {
            self.bootloaderURL = firmwareBinURL;
        }
        else if ([[[firmwareBinURL path] lastPathComponent] isEqualToString:@"application.bin"]) {
            self.applicationURL = firmwareBinURL;
        }
    }
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // The 'scan' or 'select' seque will be performed only if DFU process has not been started or was completed.
    //return !self.isTransferring;
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"scan"])
    {
        // Set this contoller as scanner delegate
        ScannerViewController *controller = (ScannerViewController *)segue.destinationViewController;
        // controller.filterUUID = dfuServiceUUID; - the DFU service should not be advertised. We have to scan for any device hoping it supports DFU.
        controller.delegate = self;
    }
    else if ([segue.identifier isEqualToString:@"FileSegue"])
    {
        NSLog(@"performing Select File segue");
        UITabBarController *barController = segue.destinationViewController;
        NSLog(@"BarController %@",barController);
        UINavigationController *navController = [barController.viewControllers firstObject];
        NSLog(@"NavigationController %@",navController);
        AppFilesTableViewController *appFilesVC = (AppFilesTableViewController *)navController.topViewController;
        NSLog(@"AppFilesTableVC %@",appFilesVC);        
        appFilesVC.fileDelegate = self;
    }
    else if ([[segue identifier] isEqualToString:@"help"]) {
        HelpViewController *helpVC = [segue destinationViewController];
        helpVC.helpText = [Utility getDFUHelpText];
        helpVC.isDFUViewController = YES;
    }
    else if ([segue.identifier isEqualToString:@"FileTypeSegue"]) {
        NSLog(@"performing FileTypeSegue");
        FileTypeTableViewController *fileTypeVC = [segue destinationViewController];
        fileTypeVC.chosenFirmwareType = selectedFileType;
    }
}

-(void) setFirmwareType:(NSString *)firmwareType
{
    if ([firmwareType isEqualToString:FIRMWARE_TYPE_SOFTDEVICE]) {
        enumFirmwareType = SOFTDEVICE;
    }
    else if ([firmwareType isEqualToString:FIRMWARE_TYPE_BOOTLOADER]) {
        enumFirmwareType = BOOTLOADER;
    }
    else if ([firmwareType isEqualToString:FIRMWARE_TYPE_BOTH_SOFTDEVICE_BOOTLOADER]) {
        enumFirmwareType = SOFTDEVICE_AND_BOOTLOADER;
    }
    else if ([firmwareType isEqualToString:FIRMWARE_TYPE_APPLICATION]) {
        enumFirmwareType = APPLICATION;
    }
}

- (void) clearUI
{
    selectedPeripheral = nil;
    deviceName.text = @"DEFAULT DFU";
    uploadStatus.text = @"waiting ...";
    uploadStatus.hidden = YES;
    progress.progress = 0.0f;
    progress.hidden = YES;
    progressLabel.hidden = YES;
    progressLabel.text = @"";
    [uploadButton setTitle:@"Upload" forState:UIControlStateNormal];
    uploadButton.enabled = NO;
    [self enableOtherButtons];
}

-(void)enableUploadButton
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (selectedFileType && self.selectedFileSize > 0) {
            if ([self isValidFileSelected]) {
                NSLog(@" valid file selected");
            }
            else {
                NSLog(@"Valid file not available in zip file");                
                [Utility showAlert:[self getFileValidationMessage]];
                return;
            }
        }
        if (self.isDfuVersionExist) {
            if (selectedPeripheral && selectedFileType && self.selectedFileSize > 0 && self.isConnected && self.dfuVersion > 1) {
                //TODO check if initPacket file (*.dat) exist inside selected zip file
                if ([self isInitPacketFileExist]) {
                    uploadButton.enabled = YES;
                }
                else {
                    //TODO show message "init packet file (.dat) missing. on screen"
                    //TODO create method for showing right message like getFileValidationMessage
                    [Utility showAlert:[self getInitPacketFileValidationMessage]];
                }
                
            }
            else {
                NSLog(@"cant enable Upload button");
            }
        }
        else {
            if (selectedPeripheral && selectedFileType && self.selectedFileSize > 0 && self.isConnected) {
                uploadButton.enabled = YES;
            }
            else {
                NSLog(@"cant enable Upload button");
            }
        }

    });
}

-(BOOL)isInitPacketFileExist
{
    //Zip file is required with firmware and .dat files
    if (self.isSelectedFileZipped) {
        switch (enumFirmwareType) {
            case SOFTDEVICE_AND_BOOTLOADER:
                if (self.systemMetaDataURL) {
                    NSLog(@"Found system.dat in selected zip file");
                    return YES;
                }
                break;
            case SOFTDEVICE:
                if (self.softdeviceMetaDataURL) {
                    NSLog(@"Found softdevice.dat file in selected zip file");
                    return YES;
                }
                break;
            case BOOTLOADER:
                if (self.bootloaderMetaDataURL) {
                    NSLog(@"Found Bootloader.dat file in selected zip file");
                    return YES;
                }
                break;
            case APPLICATION:
                if (self.applicationMetaDataURL) {
                    NSLog(@"Found Application.dat file in selected zip file");
                    return YES;
                }
                break;
                
            default:
                NSLog(@"Not valid File type");
                return NO;
                break;
        }
        //Corresponding file .dat to selected firmware is not present in zip file
        return NO;
    }
    else {//Zip file is not selected
        return NO;
    }
}

-(BOOL)isValidFileSelected
{
    NSLog(@"isValidFileSelected");
    if (self.isSelectedFileZipped) {
        switch (enumFirmwareType) {
            case SOFTDEVICE_AND_BOOTLOADER:
                if (self.isManifestExist) {
                    if (self.softdevice_bootloaderURL) {
                        NSLog(@"Found Softdevice_Bootloader file in selected zip file");
                        return YES;
                    }
                }
                else {
                    if (self.softdeviceURL && self.bootloaderURL) {
                        NSLog(@"Found Softdevice and Bootloader files in selected zip file");
                        return YES;
                    }
                }
                
                break;
            case SOFTDEVICE:
                if (self.softdeviceURL) {
                    NSLog(@"Found Softdevice file in selected zip file");
                    return YES;
                }
                break;
            case BOOTLOADER:
                if (self.bootloaderURL) {
                    NSLog(@"Found Bootloader file in selected zip file");
                    return YES;
                }
                break;
            case APPLICATION:
                if (self.applicationURL) {
                    NSLog(@"Found Application file in selected zip file");
                    return YES;
                }
                break;
                
            default:
                NSLog(@"Not valid File type");
                return NO;
                break;
        }
        //Corresponding file to selected file type is not present in zip file
        return NO;
    }
    else if(enumFirmwareType == SOFTDEVICE_AND_BOOTLOADER){
        NSLog(@"Please select zip file with softdevice and bootloader inside");
        return NO;
    }
    else {
        //Selcted file is not zip and file type is not Softdevice + Bootloader
        //then it is upto user to assign correct file to corresponding file type
        return YES;
    }    
}

-(NSString *)getUploadStatusMessage
{
    switch (enumFirmwareType) {
        case SOFTDEVICE:
            return @"uploading softdevice ...";
            break;
        case BOOTLOADER:
            return @"uploading bootloader ...";
            break;
        case APPLICATION:
            return @"uploading application ...";
            break;
        case SOFTDEVICE_AND_BOOTLOADER:
            if (self.isManifestExist) {
                return @"uploading softdevice+bootloader ...";
            }
            return @"uploading softdevice ...";
            break;
            
        default:
            return @"uploading ...";
            break;
    }
}

-(NSString *)getInitPacketFileValidationMessage
{
    NSString *message;
    switch (enumFirmwareType) {
        case SOFTDEVICE:
            message = [NSString stringWithFormat:@"softdevice.dat is missing. It must be placed inside zip file with softdevice"];
            return message;
        case BOOTLOADER:
            message = [NSString stringWithFormat:@"bootloader.dat is missing. It must be placed inside zip file with bootloader"];
            return message;
        case APPLICATION:
            message = [NSString stringWithFormat:@"application.dat is missing. It must be placed inside zip file with application"];
            return message;
            
        case SOFTDEVICE_AND_BOOTLOADER:
            return @"system.dat is missing. It must be placed inside zip file with softdevice and bootloader";
            break;
            
        default:
            return @"Not valid File type";
            break;
    }

}

-(NSString *)getFileValidationMessage
{
    NSString *message;
    switch (enumFirmwareType) {
        case SOFTDEVICE:
            message = [NSString stringWithFormat:@"softdevice.hex not exist inside selected file %@",[self.selectedFileURL lastPathComponent]];
            return message;
        case BOOTLOADER:
            message = [NSString stringWithFormat:@"bootloader.hex not exist inside selected file %@",[self.selectedFileURL lastPathComponent]];
            return message;
        case APPLICATION:
            message = [NSString stringWithFormat:@"application.hex not exist inside selected file %@",[self.selectedFileURL lastPathComponent]];
            return message;
            
        case SOFTDEVICE_AND_BOOTLOADER:
            return @"For selected File Type, zip file is required having inside softdevice.hex and bootloader.hex";
            break;
            
        default:
            return @"Not valid File type";
            break;
    }
}

-(void)disableOtherButtons
{
    selectFileButton.enabled = NO;
    selectFileTypeButton.enabled = NO;
    connectButton.enabled = NO;
}

-(void)enableOtherButtons
{
    selectFileButton.enabled = YES;
    selectFileTypeButton.enabled = YES;
    connectButton.enabled = YES;
}

-(void)appDidEnterBackground:(NSNotification *)_notification
{
    NSLog(@"appDidEnterBackground");
    if (self.isConnected && self.isTransferring) {
        [Utility showBackgroundNotification:[self getUploadStatusMessage]];
    }
}

-(void)appDidEnterForeground:(NSNotification *)_notification
{
    NSLog(@"appDidEnterForeground");
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

#pragma mark FileType Selector Delegate

- (IBAction)unwindFileTypeSelector:(UIStoryboardSegue*)sender
{
    FileTypeTableViewController *fileTypeVC = [sender sourceViewController];
    selectedFileType = fileTypeVC.chosenFirmwareType;
    NSLog(@"unwindFileTypeSelector, selected Filetype: %@",selectedFileType);
    fileType.text = selectedFileType;
    [self setFirmwareType:selectedFileType];
    [self enableUploadButton];
}

#pragma mark Device Selection Delegate
-(void)centralManager:(CBCentralManager *)manager didPeripheralSelected:(CBPeripheral *)peripheral
{
    selectedPeripheral = peripheral;
    [dfuOperations setCentralManager:manager];
    deviceName.text = peripheral.name;
    [dfuOperations connectDevice:peripheral];
}

#pragma mark File Selection Delegate

-(void)onFileSelected:(NSURL *)url
{
    NSLog(@"onFileSelected");
    selectedFileURL = url;
    if (selectedFileURL) {
        NSLog(@"selectedFile URL %@",selectedFileURL);
        NSString *selectedFileName = [[url path]lastPathComponent];
        NSData *fileData = [NSData dataWithContentsOfURL:url];
        self.selectedFileSize = fileData.length;
        NSLog(@"fileSelected %@",selectedFileName);
        
        //get last three characters for file extension
        NSString *extension = [selectedFileName substringFromIndex: [selectedFileName length] - 3];
        NSLog(@"selected file extension is %@",extension);
        if ([extension isEqualToString:@"zip"]) {
            NSLog(@"this is zip file");
            self.isSelectedFileZipped = YES;
            self.isManifestExist = NO;
            [self unzipFiles:selectedFileURL];
        }
        else {
            self.isSelectedFileZipped = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            fileName.text = selectedFileName;
            fileSize.text = [NSString stringWithFormat:@"%d bytes", self.selectedFileSize];
            [self enableUploadButton];
        });
    }
    else {
        [Utility showAlert:@"Selected file not exist!"];
    }
}


#pragma mark DFUOperations delegate methods

-(void)onDeviceConnected:(CBPeripheral *)peripheral
{
    NSLog(@"onDeviceConnected %@",peripheral.name);
    self.isConnected = YES;
    self.isDfuVersionExist = NO;
    [self enableUploadButton];
    //Following if condition display user permission alert for background notification
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];

}

-(void)onDeviceConnectedWithVersion:(CBPeripheral *)peripheral
{
    NSLog(@"onDeviceConnectedWithVersion %@",peripheral.name);
    self.isConnected = YES;
    self.isDfuVersionExist = YES;
    [self enableUploadButton];
    //Following if condition display user permission alert for background notification
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];

}

-(void)onDeviceDisconnected:(CBPeripheral *)peripheral
{
    NSLog(@"device disconnected %@",peripheral.name);
    self.isTransferring = NO;
    self.isConnected = NO;
    
    // Scanner uses other queue to send events. We must edit UI in the main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.dfuVersion != 1) {
            [self clearUI];
        
        
            if (!self.isTransfered && !self.isTransferCancelled && !self.isErrorKnown) {
                if ([Utility isApplicationStateInactiveORBackground]) {
                    [Utility showBackgroundNotification:[NSString stringWithFormat:@"%@ peripheral is disconnected.",peripheral.name]];
                }
                else {
                    [Utility showAlert:@"The connection has been lost"];
                }
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
            }
            self.isTransferCancelled = NO;
            self.isTransfered = NO;
            self.isErrorKnown = NO;
        }
        else {
            double delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [dfuOperations connectDevice:peripheral];
            });
            
        }
    });
}

-(void)onReadDFUVersion:(int)version
{
    NSLog(@"onReadDFUVersion %d",version);
    self.dfuVersion = version;
    NSLog(@"DFU Version: %d",self.dfuVersion);
    if (self.dfuVersion == 1) {
        [dfuOperations setAppToBootloaderMode];
    }
    [self enableUploadButton];
}

-(void)onDFUStarted
{
    NSLog(@"onDFUStarted");
    self.isTransferring = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        uploadButton.enabled = YES;
        [uploadButton setTitle:@"Cancel" forState:UIControlStateNormal];
        NSString *uploadStatusMessage = [self getUploadStatusMessage];
        if ([Utility isApplicationStateInactiveORBackground]) {
            [Utility showBackgroundNotification:uploadStatusMessage];
        }
        else {
            uploadStatus.text = uploadStatusMessage;
        }
        
    });
}

-(void)onDFUCancelled
{
    NSLog(@"onDFUCancelled");
    self.isTransferring = NO;
    self.isTransferCancelled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self enableOtherButtons];
    });
}

-(void)onSoftDeviceUploadStarted
{
    NSLog(@"onSoftDeviceUploadStarted");
}

-(void)onSoftDeviceUploadCompleted
{
    NSLog(@"onSoftDeviceUploadCompleted");
}

-(void)onBootloaderUploadStarted
{
    NSLog(@"onBootloaderUploadStarted");
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([Utility isApplicationStateInactiveORBackground]) {
            [Utility showBackgroundNotification:@"uploading bootloader ..."];
        }
        else {
            uploadStatus.text = @"uploading bootloader ...";
        }
        
    });
    
}

-(void)onBootloaderUploadCompleted
{
    NSLog(@"onBootloaderUploadCompleted");
}

-(void)onTransferPercentage:(int)percentage
{
    NSLog(@"onTransferPercentage %d",percentage);
    // Scanner uses other queue to send events. We must edit UI in the main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        progressLabel.text = [NSString stringWithFormat:@"%d %%", percentage];
        [progress setProgress:((float)percentage/100.0) animated:YES];
    });    
}

-(void)onSuccessfulFileTranferred
{
    NSLog(@"OnSuccessfulFileTransferred");
    // Scanner uses other queue to send events. We must edit UI in the main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isTransferring = NO;
        self.isTransfered = YES;
        NSString* message = [NSString stringWithFormat:@"%u bytes transfered in %u seconds", dfuOperations.binFileSize, dfuOperations.uploadTimeInSeconds];
        if ([Utility isApplicationStateInactiveORBackground]) {
            [Utility showBackgroundNotification:message];
        }
        else {
            [Utility showAlert:message];
        }
        
    });
}

-(void)onError:(NSString *)errorMessage
{
    NSLog(@"OnError %@",errorMessage);
    self.isErrorKnown = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [Utility showAlert:errorMessage];
        [self clearUI];
    });
}

@end