%% Constant Amplitude Sinusoidal Micro Galvano Polarization Technique (CASG) - example of frequency sweeping
% Author: Zdenek Kohl, University of Defence, Czech Republic, zdenek.kohl@unob.cz
% Steps:
%	1. Charge to bias voltage via CPLIMIT technique
%	2. Hold DC voltage via CALIMIT technique until current falls below 1 % of charging current value
%	3. Run specified number of periods of sinusoidal current signal with DC current component, more frequencies
%	   (keep sampling rate and number of signal periods inversely proportional to frequency)
% Note: Maximum number of frequencies (number of steps fro CASG) is 20

clear;
address = "192.109.209.128"; channel = 2;	% physical device address, channel number (numbering starts at 1)
CSVfileName = 'CASG.CSV';					% output data filename

% ------ Experiment parameters --------
VoltageBias = 1.5;			% DC voltage component (Volts)
CurrentAC = 0.5;			% AC current amplitude (Amps)
PhaseInit = 0;				% initial signal phase (Deg)
I_charge = 0.2;				% current for charging to initial voltage (Amps)
Fs = 0.1;					% starting frequency (Hz)
Periods = 10;				% starting number of sinusoidal signal periods
PeriodsMin = 2;				% minimum periods of sinusoidal signal (should be <= Periods)
decades = -1;				% number of frequency decades; specify negative count for sweeping frequency down
FreqPerDec = 4;				% number of frequencies per decade
SamplesPerPeriod = 1024;	% number of samples per signal period
dT = 0.01;					% sampling period (seconds) for initial charge
ChargeDurMax = 1000;		% max. duration of initial discharging and initial DC keeping
I_keep = I_charge/100;		% max. holding current during CALIMIT technique

SafetyLimitsEnable = true;						% stop measurement if current or voltage out of safety limits
VoltageLimitMin = 0.01; VoltageLimitMax = 2.9;	% voltage safety limits (Volts), should not be > then E_range
CurrentLimitMin = -0.9; CurrentLimitMax = 0.9;	% current safety limits (Amsp), should not be > then I_range

% ------- Helper parameters ----------	
DisplayInfo = true;							% display potentiostat related information
FwUpgrade = false; ForceFwReload = false;	% upgrade firmware if necessary; "force" means flash any time
ShowGauge = true;							% display progress bar during FW upgrade
ForceRun = true;							% force running measurement even the channel status is not "stopped"
AnimRefreshRate = 2;						% animation refresh rate (Hz); important for higher sampling rates
% ------------------------------------

if PeriodsMin > Periods
	PeriodsMin = Periods;
end
AnimRefreshPeriod = 1/AnimRefreshRate;
InitialDataLength = 10000;					% initial vector size for measured data

% Probe hardware parameters
ProbeConf = struct( ...
	'Connection', 0, ...			% 0 .. standard, 1 .. CE to ground, 2 .. WE to ground, 3 .. High voltage
	'Mode', 1);						% 0 .. grounded, 1 .. floating

% Initial charge via CPLIMIT technique
I_Range_charge = BL.IRangeSet(I_charge);	% calculate optimal current measuring range for charging
TechParamsCPLIMIT = struct( ...
	'technique', 'CPLIMIT', ...
	'E_Range', "AUTO", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', I_Range_charge, ...	% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous technique)
    'Bandwidth', 8, ...				% bandwidth number for loopback (1, 2, ... 9, BL.KEEP)
	'Record_every_dT', dT, ...		% sampling period (seconds, default = 1)
	'Record_every_dE', Inf, ...		% voltage increment that triggers new sample (Volts); Inf = ignore
    'Step_number', 1, ...			% number of steps - 1
    'N_Cycles', 0);					% number of times the technique is repeated again

StepParamsCPLIMIT = struct( ...
	'Current_step', 0, ...			% current (Amps)
	'vs_initial', false, ...		% if true, value is relative to the last one from previous technique
	'Duration_step', ChargeDurMax, ...		% maximum duration of the step (seconds)
	'Test1_Config', 0, ...			% 0bVV|S|L|A; VV = variable (00 = voltage, 01 = AUX1, 10 = AUX2, 11 = current); Sign (0 = "<", 1 = ">");
	...								% Logic (0 = OR, 1 = AND); Active (1 = active);
	...								% voltage > bias: 0B00|001|x|1 = 5; voltage < bias: 0B00|000|x|1 = 1; 
	'Test1_Value', 0, ...			% condition (voltage) value
	'Test2_Config', 0, ...
	'Test2_Value', 0.0, ...
	'Test3_Config', 0, ...
	'Test3_Value', 0.0, ...
	'Exit_Cond', 0 ...				% exit condition; 0 = next step, 1 = next technique, 2 = stop measurement completely
	);

% modification of parameters for charging to initial voltage (two steps - charge or discharge)
StepParamsCPLIMIT.Current_step = I_charge*[1, -1];
StepParamsCPLIMIT.Test1_Value = VoltageBias;
StepParamsCPLIMIT.Test1_Config = [bin2dec('00101'), bin2dec('00001')];		% step 1 ends if voltage > VoltageInit; step 2 ends if voltage < VoltageInit
StepParamsCPLIMIT.Exit_Cond = [0, 0];

% Keep DC voltage until current falls below some delta (needed for supercapacitors with alpha < 1)
TechParamsCALIMIT = struct( ...
	'technique', 'CALIMIT', ...
	'E_Range', "AUTO", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "AUTO", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous method)
	'Bandwidth', 8, ...				% BW number for loopback (1, 2, ... 9, BL.KEEP)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
	'Record_every_dI', Inf, ...		% current increment triggering sample (Amps); Inf = ignore
    'Step_number', 0, ...			% number of steps - 1
    'N_Cycles', 0);					% number of times the technique is repeated - 1

% Step parameters for CASG
StepParamsCALIMIT = struct( ...
	'Voltage_step', VoltageBias, ...	% voltage (V)
	'vs_initial', false, ...		% if true, value is relative to the last one from previous technique
	'Duration_step', ChargeDurMax, ...		% max step duration (s); step ends with duration or with test condition - what comes first
	'Test1_Config', 99, ...			% binary: 0bVV|S|L|A; VV = variable (00 = voltage, 01 = AUX1, 10 = AUX2, 11 = current); Sign (0 = "<", 1 = ">"); Logic (0 = OR, 1 = AND); Active (1 = active);
	...								% Test1: Current > -I_keep, Logic = AND with Test2: 0B11|001|1|1 = 99
	'Test1_Value', I_keep, ...		% condition value (current limit)
	'Test2_Config', 101, ...		% Test2: Current < I_keep: 0B11|000|x|1 = 101
	'Test2_Value', -I_keep, ...
	'Test3_Config', 0, ...
	'Test3_Value', 0.0, ...
	'Exit_Cond', 0 ...				% exit condition; 0 = next step, 1 = next technique, 2 = stop
	);

% parameters for sinusoidal technique
TechParamsCASG = struct( ...
    'technique', 'CASG', ...
	'E_Range', "AUTO", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "100mA", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, KEEP = from previous step); AUTO not allowed
    'Bandwidth', 8, ...				% BW number for loopback (1, 2, ... 9, BL.KEEP)
	'Ii', 0, ...					% initial current (Amp)
	'Ii_vs_initial', false, ...		% (default = false)
    'Step_number', 0, ...			% number of steps - 1; max = 19
    'N_Cycles', 0);					% number of times the technique is repeated - 1

StepParamsCASG = struct( ...
	'Fs', 1, ...					% frequency (Hz, def = 1)
	'I1', 0.1, ...					% high peak current (Amp)
	'I1_vs_initial', false, ...		% if true, value is relative to the last one from previous technique (default = false)
	'I2', -0.1, ...					% low peak current (Amp)
	'I2_vs_initial', false, ...		% if true, value is relative to the last one from previous technique (default = false)
	'Period_number', 1, ...			% number of signal periods per step (integer, default = 0)
	'Record_every_dT', 0.1, ...		% sampling period (seconds, default = 1)
	'Record_every_dE', Inf);		% voltage increment triggering sample (Volts); Inf = ignore

% Defining steps for CASG
TechParamsCASG.I_Range = BL.IRangeSet(CurrentAC + VoltageBias);		% set optimal current measuring range
FsLog = log10(Fs); F = logspace(FsLog, FsLog + decades, abs(decades)*FreqPerDec + 1);
StepParamsCASG.Fs = F;
TechParamsCASG.Ii = CurrentAC*sin(PhaseInit/180*pi);				% initial current depends on initial signal phase
StepParamsCASG.I1 = CurrentAC;
StepParamsCASG.I2 = -CurrentAC;
StepParamsCASG.Period_number = max(Periods.*F/Fs, PeriodsMin);		% recalculate number of periods to keep constant signal duration for each frequency
%StepParamsCASG.Record_every_dT = dT*Fs./F;							% recalculate sampling rate
StepParamsCASG.Record_every_dT = 1./(SamplesPerPeriod*F);			% recalculate sampling rate to keep constant number of samples per period
TechParamsCASG.Step_number = length(F) - 1;							% number of steps = number of frequencies (should be <= 20)

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

% Set probe configuration (VMP-300 series only)
BL.SetHardConf(ID, channel, ProbeConf);

% Load CPLIMIT technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCPLIMIT, StepParamsCPLIMIT,true,false);		% first technique

% Load CALIMIT technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCALIMIT, StepParamsCALIMIT,false,false);

% Load CASG technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCASG, StepParamsCASG,false,true);		% last technique

% Start measurement
BL.StartChannel(ID,channel); fprintf("Starting measurement on channel %i\n", channel);

% Prepare data vectors and CSV file headers
DataLength = InitialDataLength;
t = NaN(DataLength, 1); Ewe = NaN(DataLength, 1); I = NaN(DataLength, 1); Tech = strings(DataLength, 1); cycle = NaN(DataLength, 1);
writematrix(["t", "Ewe", "I", "Tech", "Cycle"], CSVfileName, 'Delimiter','tab');				% create CSV file with headers

% Start animation
figure(); set(gcf, 'Position', [100,100,1200,400]); MarkerSize = 4;

yyaxis left; l = plot(t, Ewe, 'r.', 'MarkerSize',MarkerSize); ylabel('$v(t)$ (V)','Interpreter','latex');
ax = gca; ax.YColor = 'r'; ax.TickDir = "out"; box off;
l.XDataSource = 't'; l.YDataSource = 'Ewe'; grid on;

yyaxis right; r = plot(t, I, 'b.', 'MarkerSize',MarkerSize);  ylabel('$i(t)$ (A)','Interpreter','latex');
ax = gca; ax.YColor = 'b';
xlabel('$t$ (s)','Interpreter','latex');
r.XDataSource = 't'; r.YDataSource = 'I';


% Start retrieving data from channel
indexStart = 1; tic; delay = 0.1; delayMax = 4; pause(delay); refreshtime = 0;
while true
	% Read data from channel
	[Data, DataInfo, CurrentValues] = BL.GetData(ID, channel, ChannelInfo.BoardTypeCode);
	NbRows = DataInfo.NbRows;
	if NbRows > 0						% if retrieved data is not empty
		indexEnd = indexStart + NbRows - 1;
		if indexEnd > DataLength		% increase size of data vectors if necessary
			FillRange = DataLength + 1:2*DataLength;
			t(FillRange, 1) = NaN; Ewe(FillRange, 1) = NaN; I(FillRange, 1) = NaN;
			Tech(FillRange, 1) = string; cycle(FillRange, 1) = NaN;
			DataLength = 2*DataLength;
		end
		indexTemp = indexStart:indexEnd;
		t(indexTemp) = Data(1,:)' + DataInfo.StartTime; Ewe(indexTemp) = Data(2,:)'; I(indexTemp) = Data(3,:)';
		Tech(indexTemp) = BL.Technique(DataInfo.TechniqueID); cycle(indexTemp) = Data(4,:)';
		writematrix([t(indexTemp), Ewe(indexTemp), I(indexTemp), Tech(indexTemp), cycle(indexTemp)], CSVfileName, 'Delimiter', 'tab','WriteMode','append');		% append data to CSV file
		indexStart = indexEnd + 1;
		if Data(1, end) - refreshtime > AnimRefreshPeriod
			refreshdata; drawnow;			% refresh animation if refresh period crossed
			refreshtime = Data(1, end);
		end

		if SafetyLimitsEnable			% check safety limits, stop measuring if limits crossed
			if (max(Data(2,:)) >= VoltageLimitMax) || (min(Data(2,:)) <= VoltageLimitMin) || (abs(max(Data(3,:))) >= CurrentLimitMax)
				BL.StopChannel(ID,channel);
				error("Safety limits exceeded, stopping channel ...");
			end
		end
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
t = t(1:indexEnd); Ewe = Ewe(1:indexEnd); I = I(1:indexEnd); Tech = Tech(1:indexEnd); cycle = cycle(1:indexEnd);

return
% Start retrieving data from channel
index_m = 1; tic; delay = 1; pause(delay);
while true
	% Read data from channel
	[Data, DataInfo, CurrentValues] = BL.GetData(ID, channel, ChannelInfo.BoardTypeCode);
	NbRows = DataInfo.NbRows; technique = BL.Technique(DataInfo.TechniqueID);
	if NbRows > 0
		index_end = index_m + NbRows - 1;
		if index_end > DataLength		% increase size of data vectors if necessary
			FillRange = DataLength + 1:2*DataLength;
			t(FillRange, 1) = NaN; Ewe(FillRange, 1) = NaN; I(FillRange, 1) = NaN; cycle(FillRange, 1) = NaN; Tech(FillRange, 1) = "";
			DataLength = 2*DataLength;
		end
		index_temp = index_m:index_end;
		t(index_temp) = Data(1,:)' + DataInfo.StartTime; Ewe(index_temp) = Data(2,:)'; I(index_temp) = Data(3,:)'; cycle(index_temp) = Data(4,:)';
		Tech(index_temp) = technique;
		writematrix([t(index_temp), Ewe(index_temp), I(index_temp), cycle(index_temp), Tech(index_temp)], CSVfileName, 'Delimiter', 'tab','WriteMode','append');		% append data to CSV file
		index_m = index_end + 1;
		refreshdata; drawnow;			% refresh plot

		if SafetyLimitsEnable & ~isempty(Data)
			if (max(Data(2,:)) >= VoltageLimitMax) || (min(Data(2,:)) <= VoltageLimitMin) || (abs(max(Data(3,:))) >= CurrentLimitMax) %|| (CurrentValues.Eoverflow && technique == "CASG") || CurrentValues.Ioverflow 
				BL.StopChannel(ID,channel);
				save("CASG_limits.mat");
				error("Safety limits exceeded, stopping channel ...");
			end
		end
		if (CurrentValues.State == 0 && CurrentValues.MemFilled == 0)
			break
		end
		if CurrentValues.State ~= 0
			pause(delay)
			% correct delay time based on size of retrieved data:
			if NbRows >= 100
				delay = delay/4;
			elseif NbRows <= 20
				delay = delay*2;
			end
		end
	end
end
disp("Finished.")
toc
DataLength = index_m; t = t(1:DataLength); Ewe = Ewe(1:DataLength); I = I(1:DataLength); Tech = Tech(1:DataLength);

