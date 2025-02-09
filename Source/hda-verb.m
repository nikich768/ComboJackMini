/*
 * Accessing HD-audio verbs via hwdep interface
 * Version 0.3
 *
 * Copyright (c) 2008 Takashi Iwai <tiwai@suse.de>
 *
 * Licensed under GPL v2 or later.
 */

//
// Based on alc-verb from AppleALC
//
// Conceptually derived from ALCPlugFix:
// https://github.com/goodwin/ALCPlugFix
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>
#include <sys/stat.h>
#include <semaphore.h>
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <inttypes.h>

// For driver
#define kALCUserClientProvider "ALCUserClientProvider"

#define GET_CFSTR_FROM_DICT(_dict, _key) (__bridge CFStringRef)[_dict objectForKey:_key]

//
// Global Variables
//
io_service_t AppleAlcUserClientIOService;
io_connect_t DataConnection;
uint32_t connectiontype = 0;
uint8_t previousState = 0;
bool run = true;
bool awake = false;
bool isSleeping = false;
bool restorePreviousState = false;
io_connect_t  root_port;
io_object_t   notifierObject;
struct stat consoleinfo;

long codecID = 0;

//dialog text
NSDictionary *dlgText;

//
// Open connection to IOService
//

uint32_t OpenServiceConnection(void)
{
    CFMutableDictionaryRef appleAlcDict = IOServiceMatching(kALCUserClientProvider);
    
    AppleAlcUserClientIOService = IOServiceGetMatchingService(kIOMasterPortDefault, appleAlcDict);
    
    // Hopefully the kernel extension loaded properly so it can be found.
    if (!AppleAlcUserClientIOService)
    {
        fprintf(stderr, "Looks like AppleALC.kext is not loaded. Ensure it is loaded and alcverbs function is enabled; verbs cannot be sent otherwise.\n");
        return -1;
    }
    
    // Connect to the IOService object
    // Note: kern_return_t is just an int
    kern_return_t kernel_return_status = IOServiceOpen(AppleAlcUserClientIOService, mach_task_self(), connectiontype, &DataConnection);
    
    if (kernel_return_status != kIOReturnSuccess)
    {
        fprintf(stderr, "Failed to open AppleALC IOService: %08x.\n", kernel_return_status);
        return -1;
    }
    
    return kernel_return_status; // 0 if successful
}

int indexOf(int *array, int array_size, int number) {
    for (int i = 0; i < array_size; ++i) {
        if (array[i] == number) {
            return i;
        }
    }
    return -1;
}

int indexOf_L(long *array, int array_size, long number) {
    for (int i = 0; i < array_size; ++i) {
        if (array[i] == number) {
            return i;
        }
    }
    return -1;
}

//
// Send verb command
//

static uint32_t AlcVerbCommand(uint16_t nid, uint16_t verb,uint16_t param)
{
    // Call the function ultimately responsible for sending commands in the kernel extension. That function will return the response we also want.
    // https://lists.apple.com/archives/darwin-drivers/2008/Mar/msg00007.html
    
    uint32_t inputCount = 3; // Number of input arguments
    uint32_t outputCount = 1; // Number of elements in output
    uint64_t input[inputCount]; // Array of input scalars
    uint64_t output; // Array of output scalars
    
    input[0] = nid;
    
    if (verb & 0xff){
        input[1] = verb;
    } else {
        input[1] = verb >> 8;
    }
    
    input[2] = param;
    
    kern_return_t kernel_return_status = IOConnectCallScalarMethod(DataConnection, connectiontype, input, inputCount, &output, &outputCount);
    
    if (kernel_return_status != kIOReturnSuccess)
    {
        fprintf(stderr, "Error sending command.\n");
        return -1;
    }
    
    // Return command response
    return (uint32_t)output;
}

static uint32_t GetJackStatus(void)
{
    return AlcVerbCommand(0x21, 0xf09, 0x00);
}

//
// Close connection to IOService
//

void CloseServiceConnection(void)
{
    // Done with the AppleALC IOService object, so we don't need to hold on to it anymore
    IOObjectRelease(AppleAlcUserClientIOService);
    IODeregisterForSystemPower(&notifierObject);
}

//
// Two-headed patcher
//
static void AFGpatcher()
{
    if (AlcVerbCommand(0x01, 0xf05, 0xf) != 0x00000000)
    {
        printf("Patched power state of AFG node.\n");
        AlcVerbCommand(0x01, 0x705, 0x00);
    }
}
static void HeadsetPatcher()
{
    if (AlcVerbCommand(0x19, 0xf07, 0x9) != 0x00000024)
    {
        printf("Patched pin widget of headset node.\n");
        AlcVerbCommand(0x19, 0x707, 0x24);
    }
}

//
// Respect OS signals
//

void sigHandler(int signo)
{
    fprintf(stderr, "\nsigHandler: Received signal %d.\n", signo); // Technically this print is not async-safe, but so far haven't run into any issues
    switch (signo)
    {
        // Need to be sure object gets released correctly on any kind of quit
        // notification, otherwise the program's left still running!
        case SIGINT: // CTRL + c or Break key
        case SIGTERM: // Shutdown/Restart
        case SIGHUP: // "Hang up" (legacy)
        case SIGKILL: // Kill
        case SIGTSTP: // Close terminal from x button
            run = false;
            break; // SIGTERM, SIGINT mean we must quit, so do it gracefully
        default:
            break;
    }
}

//Codec fixup, invoked when boot/wake
void alcInit(void)
{
    fprintf(stderr, "Init codec.\n");
    AlcVerbCommand(0x21, 0x708, 0x83);
}

// Sleep/Wake event callback function, calls the fixup function
void SleepWakeCallBack( void * refCon, io_service_t service, natural_t messageType, void * messageArgument )
{
    switch ( messageType )
    {
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange( root_port, (long)messageArgument );
            break;
        case kIOMessageSystemWillSleep:
            isSleeping = true;
            IOAllowPowerChange( root_port, (long)messageArgument );
            break;
        case kIOMessageSystemWillPowerOn:
            break;
        case kIOMessageSystemHasPoweredOn:
            restorePreviousState = true;
            if (isSleeping)
            {
                while(run)
                {
                    if (GetJackStatus() != -1){
                        break;
                    }
                    usleep(10000);
                }
                printf( "Re-init codec...\n" );
                alcInit();
                if ((GetJackStatus() & 0x80000000) == 0x80000000) {
                    usleep(10000);
                }
                
                awake = true;
                isSleeping = false;
            }
            break;
        default:
            break;
    }
}

// start cfrunloop that listen to wakeup event
void watcher(void)
{
    IONotificationPortRef  notifyPortRef;
    void*                  refCon = NULL;
    root_port = IORegisterForSystemPower( refCon, &notifyPortRef, SleepWakeCallBack, &notifierObject );
    if ( root_port == 0 )
    {
        printf("IORegisterForSystemPower failed.\n");
        exit(1);
    }
    else
    {
        CFRunLoopAddSource( CFRunLoopGetCurrent(),
            IONotificationPortGetRunLoopSource(notifyPortRef), kCFRunLoopCommonModes );
            printf("Starting wakeup watcher.\n");
            CFRunLoopRun();
    }
}

//Get onboard audio device info
void getAudioID(void)
{
    (void)(codecID = 0);
    
    codecID   = AlcVerbCommand(0x00, 0x0f00, 0x00);
    
    fprintf(stderr, "CodecID: 0x%lx.\n", codecID);
}

//
// Main
//

int main(void)
{
    if (sem_open("ComboJackMini_Watcher", O_CREAT, 600, 1) == SEM_FAILED)
    {
        fprintf(stderr, "Another instance is already running!\n");
        return 1;
    }
    // Set up error handler
    signal(SIGHUP, sigHandler);
    signal(SIGTERM, sigHandler);
    signal(SIGINT, sigHandler);
    signal(SIGKILL, sigHandler);
    signal(SIGTSTP, sigHandler);
    
    // Local variables
    kern_return_t ServiceConnectionStatus;
    //int nid, verb, param;
    //struct hda_verb_ioctl val;

    // Establish user-kernel connection
    ServiceConnectionStatus = OpenServiceConnection();
    if (ServiceConnectionStatus != kIOReturnSuccess)
    {
        while ((ServiceConnectionStatus != kIOReturnSuccess) && run)
        {
            fprintf(stderr, "Error establshing IOService connection. Retrying in 1 second...\n");
            sleep (1);
            ServiceConnectionStatus = OpenServiceConnection();
        }
    }

    // Get audio device info
    getAudioID();

    //alc256 init
    alcInit();
    //start a new thread that waits for wakeup event
    pthread_t watcher_id;
    if (pthread_create(&watcher_id,NULL,(void*)watcher,NULL))
    {
        fprintf(stderr, "create pthread error!\n");
        return 1;
    }
    
    usleep(100000);
    printf("Starting node patcher.\n");
    while(run) // Poll patcher
    {
        {
            AFGpatcher();
            HeadsetPatcher();
        }
        usleep(3000); // Sleep delay (microseconds)
    }

    sem_unlink("ComboJackMini_Watcher");
    // Clean up and exit safely
    CloseServiceConnection();
    
    fprintf(stderr, "Exiting safely!\n");
    
    return 0;
}
