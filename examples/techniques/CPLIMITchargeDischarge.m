%% Chrono-Potentiometry Technique with Limits (CPLIMIT)
% Example of cyclic charge/discharge of battery or supercapacitor using constant current
% Author: Zdenek Kohl, University of Defence, Czech Republic, zdenek.kohl@unob.cz

clear;
address = "192.109.209.128"; channel = 2;	% physical device address, channel number (numbering starts at 1)
CSVfileName = 'CPLIMIT.CSV';				% output data filename

DisplayInfo = true;							% display potentiostat related information
FwUpgrade = false; ForceFwReload = false;	% upgrade firmware if necessary; "force" means flash any time
ShowGauge = true;							% display progress bar during FW upgrade
ForceRun = true;							% force running measurement even the channel status is not "stopped"

% ------ Experiment parameters --------
VoltageLow = 0.5; VoltageHigh = 1;			% minimum/maximum voltage (Volts)
I_charge = 0.5;								% charging/discharging current (Amps)
dT = 0.1; dE = 0.001;						% sampling period (seconds), voltage change to be recorded (Volts)
ChargeDurMax = 10000;						% max. duration of each charging/discharging cycle
OCVinitDuration = 10;						% duration of initial voltage measurement via OCV (sec)
OCVfinalDuration = 100;						% duration of final resting (sec)
N_cycles = 3;								% number of charge/discharge cycles
% ------------------------------------

InitialDataLength = 1000;					% initial vector size for measured data
I_Range_charge = BL.IRangeSet(I_charge);	% calculate optimal current measuring range

% Probe hardware parameters
ProbeConf = struct( ...
	'Connection', 0, ...			% 0 .. standard, 1 .. CE to ground, 2 .. WE to ground, 3 .. High voltage
	'Mode', 1);						% 0 .. grounded, 1 .. floating

% Parameters for initial OCV measurement; final OCV will use same parameters except the duration
TechParamsOCV = struct( ...
	'technique', 'OCV', ...
	'E_Range', "5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "AUTO", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous method)
	'Bandwidth', 8, ...				% BW number for loopback (1, 2, ... 9, BL.KEEP)
	'Rest_time_T', OCVinitDuration, ...		% duration of measurement (seconds)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
    'Record_every_dE', inf);		% voltage increment that triggers new sample (Volts); Inf = ignore

% Basic parameters for CPLIMIT method; these parameters are common to all measurement steps
TechParamsCPLIMIT = struct( ...
	'technique', 'CPLIMIT', ...
	'E_Range', "5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', I_Range_charge, ...	% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous method)
    'Bandwidth', 8, ...				% BW number for loopback (1, 2, ... 9, BL.KEEP)
	'Record_every_dT', dT, ...		% sampling period (seconds, default = 1)
	'Record_every_dE', dE, ...		% voltage increment that triggers new sample (Volts); Inf = ignore
    'Step_number', 0, ...			% number of steps - 1
    'N_Cycles', N_cycles - 1);		% number of times the technique is repeated - 1

% Generic definition of parameters of each step; should be vectors in case of more steps
StepParamsCPLIMIT = struct( ...
	'Current_step', 0, ...			% current (Amps)
	'vs_initial', false, ...		% if true, value is relative to the last one from previous technique
	'Duration_step', ChargeDurMax, ...		% maximum duration of the step (seconds)
	'Test1_Config', 0, ...			% 0bVV|S|L|A; VV = variable (00 = voltage, 01 = AUX1, 10 = AUX2, 11 = current); Sign (0 = "<", 1 = ">");
	...								% Logic (0 = OR, 1 = AND); Active (1 = active); example: Voltage > bias V: 0B00|001|x|1 = 5, other conditions inactive
	...								% voltage > bias: 0B00|001|x|1 = 5; voltage < bias: 0B00|000|x|1 = 1; 
	'Test1_Value', 0, ...			% condition (voltage) value
	'Test2_Config', 0, ...
	'Test2_Value', 0.0, ...
	'Test3_Config', 0, ...
	'Test3_Value', 0.0, ...
	'Exit_Cond', 0 ...				% exit condition; 0 = next step, 1 = next technique, 2 = stop measurement completely
	);

% modification of parameters for charge/discharge (two steps)
StepParamsCPLIMIT.Current_step = I_charge*[1, -1];
StepParamsCPLIMIT.Test1_Config = [bin2dec('00101'), bin2dec('00001')];		% step 1 ending if voltage > VoltageHigh; step 2 ending if voltage < VoltageLow
StepParamsCPLIMIT.Test1_Value = [VoltageHigh, VoltageLow];
StepParamsCPLIMIT.Exit_Cond = [0, 0];
TechParamsCPLIMIT.Step_number = length(StepParamsCPLIMIT.Current_step) - 1;

[ID, DevInfo] = BL.Connect(address); [status, err] = BL.TestConnection(ID);
if FwUpgrade
	FWUpgradeResult = BL.LoadFirmware(ID, channel, ShowGauge, ForceFwReload);
end
ChannelInfo = BL.GetChannelInfo(ID, channel);
if DisplayInfo
	fprintf("Biologic library version: %s", BL.GetLibVersion);
	fprintf("Device info:\n%s\n Status: %s\nChannel %i info:\n%s\n", DevInfo.txt, status, channel, ChannelInfo.txt);
end

if ChannelInfo.raw.State ~= 0 & ~ForceRun			% finish program if channel is not stopped (previous measurement still running)
	error("Channel is not stopped, exiting ...")
end

% Set probe configuration
BL.SetHardConf(ID, channel, ProbeConf);

% Load initial OCV technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsOCV,[],true,false);		% first technique

% Load CPLIMIT technique parameters to channel (charge/discharge using constant current)
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCPLIMIT, StepParamsCPLIMIT,false,false);

TechParamsOCV.Rest_time_T = OCVfinalDuration;			% set duration of resting
% Load final OCV technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsOCV,[],false,true);		% last technique

% Start measurement
BL.StartChannel(ID,channel); fprintf("Starting measurement on channel %i\n", channel);

% Prepare data vectors and CSV file headers
DataLength = InitialDataLength;
t = NaN(DataLength, 1); Ewe = NaN(DataLength, 1); I = NaN(DataLength, 1); cycle = NaN(DataLength, 1);
writematrix(["t", "Ewe", "I", "Cycle"], CSVfileName, 'Delimiter','tab');				% create CSV file with headers

% Start animation
figure(); set(gcf, 'Position', [100,100,1200,400]); MarkerSize = 4;

yyaxis left; l = plot(t, Ewe, 'r.', 'MarkerSize',MarkerSize); ylabel('$v(t)$ (V)','Interpreter','latex');
ax = gca; ax.YColor = 'r'; ax.TickDir = "out"; box off;
l.XDataSource = 't'; l.YDataSource = 'Ewe';

yyaxis right; r = plot(t, I, 'b.', 'MarkerSize',MarkerSize);  ylabel('$i(t)$ (A)','Interpreter','latex');
ax = gca; ax.YColor = 'b';
xlabel('$t$ (s)','Interpreter','latex');
r.XDataSource = 't'; r.YDataSource = 'I';

% Start retrieving data from channel
indexStart = 1; tic;
delay = 0.1; delayMax = 4; pause(delay);
while true
	% Read data from channel
	[Data, DataInfo, CurrentValues] = BL.GetData(ID, channel, ChannelInfo.BoardTypeCode);
	NbRows = DataInfo.NbRows;
	if NbRows > 0						% if retrieved data is not empty
		indexEnd = indexStart + NbRows - 1;
		if indexEnd > DataLength		% increase size of data vectors if necessary
			FillRange = DataLength + 1:2*DataLength;
			t(FillRange, 1) = NaN; Ewe(FillRange, 1) = NaN; I(FillRange, 1) = NaN;
			DataLength = 2*DataLength;
		end
		indexTemp = indexStart:indexEnd;
		t(indexTemp) = Data(1,:)' + DataInfo.StartTime; Ewe(indexTemp) = Data(2,:)'; I(indexTemp) = Data(3,:)'; cycle(indexTemp) = Data(4,:)';
		writematrix([t(indexTemp), Ewe(indexTemp), I(indexTemp), cycle(indexTemp)], CSVfileName, 'Delimiter', 'tab','WriteMode','append');		% append data to CSV file
		indexStart = indexEnd + 1;
		refreshdata; drawnow;			% refresh animation
	end
	if (CurrentValues.State == 0 && CurrentValues.MemFilled == 0)
		disp("Finished.")
		break
	end
	if CurrentValues.State ~= 0
		pause(delay)
		% correct delay time based on size of retrieved data:
		if DataInfo.NbRows >= 100
			delay = delay/4;
		elseif DataInfo.NbRows <= 20
			delay = min(delay*2, delayMax);
		end
	end
end
toc
t = t(1:indexEnd); Ewe = Ewe(1:indexEnd); I = I(1:indexEnd); cycle = cycle(1:indexEnd);
