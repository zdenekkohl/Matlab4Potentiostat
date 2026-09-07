# MatlabPotentiostat - Library for Managing Biologic Potentiostat by Means of MATLAB<sup>®</sup>

This is a package for managing Biologic Potentiostat by means of MATLAB<sup>®</sup>. The library is based on the C library provided by the Biologic Company via the EClib64.dll file which is a part of the "EC-Lab® Development Package". This package was created from and tested with the "EC-Lab® Development Package" version 6.11.2 (Feb 18, 2025).



## Installation

1. Copy the folder BL_api to a selected folder an local PC; namely these file categories:

    **library files**

      * BL_apiInterface.dll (MATLAB<sup>®</sup> library itself)
      * BL.m (library extension; user friendly versions of the original library functions, some supporting/helper functions, and special constants/definitions used by this extension)

    **content of the "lib" folder of the "EC-Lab® Development Package"**

      * EClib64.dll
      * all .bin files and .xlx files (firmware files)
      * all .ecc files (technique definition files)

        
2. Add the folder "BL\_api" to the MATLAB<sup>®</sup> path; we recommend to add the path permanently (via the MATLAB<sup>®</sup> GUI menu)

Notes:

i. It is possible to copy only the techniques that would be used. The file name is the same as the abbreviation of the technique name (plus number). The names without a number are for the "VMP-3" series (ESSENTIAL), names ending with 4 are for "VMP-300" series (PREMIUM), and names ending with 5 are for the "VMP-300 P" series (DIGICOR). The family of the connected device can be seen after connecting the library using the library function "BL.connect" in the variable "DevInfo".

ii. The library contains only techniques that were tested by the author. For adding some other techniques, it is necessary to correct the BL.m library file, namely:

   * Add the technique to the "Technique" dictionary.
   * Add missing technique parameters to the "PARAM_TYPE" dictionary.
   * Possibly (depending on the technique data structure) correct the "GetData" function.

## Using the Library

All the functions provided by the original C library (EClib64.dll) can be called via the MATLAB<sup>®</sup> command



    >> clib.BL_api.function_name(parameters)



using the selected <em>function_name</em> syntax described in the "EC-Lab® Development Package User's Guide". See the script [ConnectDevice.m](examples/basic/ConnectDevice.m) for a demo how to connect the Potentiostat device.

## Re-compiling the Library

The library "BL_apiInterface.dll" can be created from the source code "**defineBL_api.m**" provided in the [libgen](libgen) folder using the MATLAB<sup>®</sup> command



    >> build(defineBL_api)



The source code "defineBL_api.m" should be existing in the current folder including the C library "EClib64.dll", both header files "BLFunctions.h" and "BLStructs.h" and the "BL_apiData.xml". The content of the XML file should be manually edited to reflect real directories on local PC. For successful run, a C compiler should be configured in MATLAB<sup>®</sup>. Either free MinGW64 compiler or Microsoft Visual C++ can be used. The compiler can be verified/changed via the command "mex -setup". Re-compilation may be necessary in case of using incompatible MATLAB<sup>®</sup> version, if the user wants to change some parameters or function definitions offered by the author, etc.

## Re-creating the Library Source File

The library re-creation is necessary in case the user wants to use a different version of the "EC-Lab® Development Package".



    >> clibgen.generateLibraryDefinition( ...
        'BLFunctions.h', ...
        'Libraries', 'EClib64.dll', ...
        'PackageName', 'BL_api', ...
        'OverwriteExistingDefinitionFiles', true ...
        );




For the source file creation, the Microsoft Visual C++ compiler should be used. Care should be taken since all the functions that originally use pointers as parameters should be manually corrected. This correction requires a kind of experience.

## Firmware Handling

The main problem of the Potentiostat device is that it requires specific firmware for EC-Lab<sup>®</sup> Windows software (so called "EC-Lab firmware") and different firmware for C based library which is utilized by scripting or C/Delphi programming (so called "interpreter firmware"). Additionally, both EC-Lab and interpreter firmware also depend on EC-Lab<sup>®</sup> version and C library version respectively.

The good message is that the firmware can be different on different channels. Script can connect to the library regardless running firmware, and is able to flash with correct firmware version only the channel that will be used for measuring. However, EC-Lab<sup>®</sup> fails to connect to the device where any channel is running incompatible firmware. The device should be power cycled (which is not possible remotely), then EC-Lab<sup>®</sup> flashes all channels.

To avoid power cycling the device, we provide the script [FlashEClabFW.m](utils/FlashEClabFW.m) that can flash selected channel with EC-Lab firmware without power cycling the device:

    FlashEClabFW.m

The script can just display selected channel info without interrupting running measurement. If flashing is chosen (FlashFirmware = true), only selected channel is affected/flashed, other channels are untouched.

**Mixed environment**

It is possible to manage different channels via different tools. For this scenario, we recommend the following steps:

1. Make sure all channels are running EC-lab firmware. Connect the device from EC-lab<sup>®</sup> software.
1. Connect with a script, flash the channel(s) that will be used by the script  using the option "FwUpgrade = true" in the script. This would not affect measurements on other channels. Flashing is necessary just once.

Note - Forcing flash: Even the option "FwUpgrade = true" is selected, flash will be performed only if necessary. Flashing can be forced selecting "ForceFwReload = true". This feature can be used, for example, to remotely restart a channel.

## Library Extension

Since the original C syntax of the implemented functions may be somewhat cumbersome and restrictive, we have developed an extension library implemented in the file "[**BL.m**](src/BL_api/BL.m)". This library brings simplified syntax of the original functions, and keeps their names similar by skipping the prefix "BL_". For example, instead of calling the "Connect" function using the command "**clib.BL_api.BL_Connect**(<em>parameters</em>)", we use the command "**BL.Connect**(<em>parameters</em>)" with less stringent requirements for function parameters. Additionally, the extended implementation deals with errors returned by the original C based function. See the script [ConnectDevice2.m](examples/basic/ConnectDevice2.m) for a demo how to connect the Potentiostat device using the library extensions, and compare with the previous one. There is no need to prepare requested C type structures, no need to check if the connection succeeded or not.

### Standard Functions Implemented by BL.m
These functions are simplified/friendly versions of original functions implemented via the EClib64.dll library. See more in "EC-Lab® Development Package User's Guide" for the original syntax of the functions and their parameters description. The function headers follow:

    Version = GetLibVersion()
    SN = GetVolumeSerialNumber()
    ErrMsg = GetErrorMsg(code)
    [ID, DevInfo] = Connect(address, timeout)
    Disconnect(ID)
    [status, err] = TestConnection(ID)
    [DeviceSpeed, ChannelSpeed] = TestCommSpeed(ID, channel)
    USBdevInfo = GetUSBdeviceinfo(USBindex)
    FWUpgradeResult = LoadFirmware(ID, channel, ShowGauge, ForceReload)
    Plugged = IsChannelPlugged(ID, channel)
    ChannelsPlugged = GetChannelsPlugged(ID)
    BoardType = GetChannelBoardType(ID, channel)
    ChannelInfo = GetChannelInfo(ID, channel)
    Msg = GetMessage(ID, channel)
    HardConf = GetHardConf(ID, channel)
    SetHardConf(ID, channel, ProbeConf)
    LoadTechnique(ID, channel,BoardType, TechParams, StepParams, FirstTechnique, LastTechnique)
    StartChannel(ID,channel)
    StopChannel(ID,channel)
    UpdateParameters(ID, channel, TechIndx, BoardType, Params, Step)
    CurrentValues = GetCurrentValues(ID, channel)
    [Data, DataInfo, CurrentValues] = GetData(ID, channel, BoardTypeCode)
    
### Additional (Helper) Functions
These functions define some additional functionalities to simplify standard programming of the Potentiostat equipment. Most of them can be understood from provided examples (see later).

    Messages = GetMessages(ID, channel)
    PrintMessages(ID, channel)
    PrintHardConf(ID, channel)
    param = DefineEccParameter(label, value, index)
    [ParamIndex, EccParamsList] = MakeEccParameters(TechParams, StepParams)
    IRangeNew = IRangeSet(I)
    

## Simple Device Connect Example

These two scripts mentioned above, stored in the [examples/basic](examples/basic) folder, can be used as a simple introduction for verifying the device connectivity. Measuremens running on the device are not affected.

    ConnectDevice.m
    ConnectDevice2.m


## Defining Technique Parameters

Each technique (except OCV) can have more steps where each step has its unique parameters. There are two sets of parameters for each technique:

* Technique parameters - these parameters are common for all steps
* Step parameters - these parameters can be defined as array (vectors in MATLAB<sup>®</sup>); each member of the vector defines the parameter for the relevant step. If the technique is defined as multi-step, all step parameters should have the same size. The library allows to define a step parameter as a scalar value in case its value is the same for all steps. The library will extend the array automatically.

The description of all the parameters can be found in the "EC-Lab<sup>®</sup> Development Package User's Guide". Generic script templates for selected techniques are in the files "[**TechniquesGeneric.m**](docs/TechniquesGeneric.m)" and "**TechniquesGenericX.mlx**" in the [docs](docs) folder. The form of MATLAB<sup>®</sup> sript was chosen for the templates.

## Selected Techniques Examples

The examples are provided as .m files ([examples/techniques](examples/techniques) folder). Due to limited device availability, most of the techniques were tested with SP-300, some of them also with SP-150. Functionality on other device models may require corrections (especially regarding voltage/current supply and measuring range, probe configuration etc.).

### Open Circuit Voltage (OCV)

This is a passive method (no voltage or current source applied to the measured element) suitable for testing device functionality or as a resting technique at the end of measurement or between two measurement phases.

Note that OCV technique is a single step one, there are no step parameters for this technique.

Example script ([OCV.m](/examples/techniques/OCV.m)):

    OCV.m


### Chrono-Potentiometry Technique with Limits (CPLIMIT)

Chrono-Potentiometry technique allows to apply constant current source to the terminal port. Each step can have different current, and different duration. Maximum of 20 steps is possible. The technique with limits allows to finish each step prematurely if a defined condition is met. Crossing a defined voltage level as a condition is typical for this technique. Two examples given.

[CPLIMIT example #1](examples/techniques/CPLIMIT.m): Charging a capacitor or a battery to a defined level (bias voltage) using constant current.

    CPLIMIT.m

[CPLIMIT example #2](examples/techniques/CPLIMITchargeDischarge.m): Cyclic charging and discharging of a capacitor or battery with a constant current.

    CPLIMITchargeDischarge.m
    

### Large Amplitude Sinusoidal Voltammetry (LASV)

LASV technique applies sinusoidal voltage with a defined bias, AC signal frequency and amplitude. Each step defines unique AC amplitude, frequency and number of periods. We supply one example ([LASV.m](examples/techniques/LASV.m)):

    LASV.m

In the example, we first establish the bias voltage via CPLIMIT technique, then we generate sinusoidal voltage signal with defined magnitude, phase and with frequency sweeping.

Notes:
1. This technique is not suitable for capacitive devices or batteries. This is due to the voltage is generated by a DA converter, and consequently, the voltage is a staircase signal. Since the current flowing through capacitor is proportional to derivative of voltage, the current is affected by peaks at each voltage value change. See the figure [LASV.png](examples/techniques/figs/LASV.png) in the [examples/techniques/figs](examples/techniques/figs) folder. The figure demonstrates sinusoidal voltage source of frequency 10 mHz applied to a supercapacitor of 100 farads and resulting current.
1. Maximum number of steps (maximum number of frequencies) is 20.

### Constant Amplitude Sinusoidal Micro Galvano Polarization Technique (CASG)

CASG is similar to LASV with the exception it uses sinusoidal current source. We supply the example script [CASG.m](examples/techniques/CASG.m):

    CASG.m

This script runs CASG technique starting with a defined frequency, applying frequency sweeping over specified number of frequency decades. The sampling rate is recalculated for each frequency to keep constant number of samples per signal period, and the number of signal periods is adjusted to keep approximately constant duration of the signal for each frequency. See the figure [CASG.png](examples/techniques/figs/CASG.png) in the [examples/techniques/figs](examples/techniques/figs) folder, which demonstrates CASG method with frequency sweeping applied to the supercapacitor with capacity of 100 farads. It can be seen (comparing with the figure [LASV.png](examples/techniques/figs/LASV.png)), that both voltage and current are smooth curves. Figure [CASGdetail.png](examples/techniques/figs/CASGdetail.png) shows the initial part for the same case where all three phases (charging via CPLIMIT, holding via CALIMIT and sinusoidal output via CASG) can be identified.

### Galvano Electrochemical Impedance Spectroscopy Technique (GEIS)

This method performs impedance measurement using AC current source. The measurement is performed over specified range of frequencies using determined AC current magnitude, number of wait periods and number of measurements to be averaged. We provide an example script [GEIS.m](examples/techniques/GEIS.m):

    GEIS.m

This script carries out a measurement from starting frequency over specified number of frequency decades, specified density of frequencies, measuring AC current magnitude, etc. The measurement is adaptive:

* The number of wait periods, and the number of measurement averages is proportionally decreased with decreasing the frequency,
* The measuring AC current is automatically corrected (increased or decreased) if the AC voltage is out of specified limits.

Figure [GEIS.png](examples/techniques/figs/GEIS.png) demonstrates adaptive impedance measurement of supercapacitor with nominal capacity of 100 farads over frequencies from 1 kHz to 0.01 mHz. The upper plot shows time progress of DC voltage end current. These entities are measured during charge to bias voltage and at the end of each impedance measurement for a single frequency. The middle plot demonstrates the time progress of AC voltage end current. It can be seen that the measuring AC current is decreased if AC voltage crosses upper limit. The modification is performed at the end of each half frequency decade. Finally, the lower plot shows the measured impedance for each frequency.