%% Chrono-Potentiometry technique with limits (CPLIMIT)
% Author: Zdenek Kohl, University of Defence, Czech Republic, zdenek.kohl@unob.cz
% Steps:
%	Charge or discharge to bias voltage using constant current (CPLIMIT technique)
%	Stop charging, measure voltage on open circuit (OCV)

clear;
address = "192.109.209.128"; channel = 2;	% physical device address, channel number (numbering starts at 1)
CSVfileName = 'CPLIMIT.CSV';				% output data filename

DisplayInfo = true;							% display potentiostat related information
FwUpgrade = false; ForceFwReload = false;	% upgrade firmware if necessary; "force" means flash any time
ShowGauge = true;							% display progress bar during FW upgrade
ForceRun = true;							% force running measurement even the channel status is not "stopped"

% ------ Measuring parameters --------
V_bias = 1.5; I_charge = 0.1;				% bias voltage (Volts), current for charging to bias (Amps)
dT = 0.02; dE = 0.01;						% sampling period, voltage change to be recorded
ChargeDurMax = 1000;						% max. duration of initial charging
DurationOCV = 200;							% OCV phase duration (seconds)
% ------------------------------------

InitialDataLength = 1000;					% initial vector size for measured data
I_Range_charge = BL.IRangeSet(I_charge);	% calculate optimum current measurement range during charge phase

% Probe hardware parameters (only for VMP-300 series)
ProbeConf = struct( ...
	'Connection', 0, ...				% 0 .. standard, 1 .. CE to ground, 2 .. WE to ground, 3 .. High voltage
	'Mode', 1);							% 0 .. grounded, 1 .. floating

% Parameters for initial charge via CP technique with limits
TechParamsCPLIMIT = struct( ...
	'technique', 'CPLIMIT', ...
	'E_Range', "2.5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', I_Range_charge, ...	% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous step)
    'Bandwidth', 8, ...				% BW number for loopback (1, 2, ... 9, BL.KEEP)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
	'Record_every_dE', dE, ...
    'Step_number', 0, ...			% number of steps - 1
    'N_Cycles', 0);					% number of times the technique is repeated - 1

StepParamsCPLIMIT = struct( ...
	'Current_step', 0, ...			% current (A)
	'vs_initial', false, ...		% if true, value is relative to the last one from previous technique
	'Duration_step', ChargeDurMax, ...		% duration of the step (s)
	'Test1_Config', 0, ...			% 0BVV|S|L|A; VV = variable (00 = voltage, 01 = AUX1, 10 = AUX2, 11 = current); Sign (0 = "<", 1 = ">");
	...								% Logic (0 = OR, 1 = AND); Active (1 = active);
	'Test1_Value', 0.0, ...			% condition (voltage) value
	'Test2_Config', 0, ...
	'Test2_Value', 0.0, ...
	'Test3_Config', 0, ...
	'Test3_Value', 0.0, ...
	'Exit_Cond', 0 ...				% exit condition; 0 = next step, 1 = next technique, 2 = stop
	);

StepParamsCPLIMIT.Current_step = [I_charge, -I_charge];
StepParamsCPLIMIT.Test1_Value = [V_bias, V_bias];
StepParamsCPLIMIT.Test1_Config = [bin2dec('00101'), bin2dec('00001')];		% voltage > bias: 0B00|001|x|1 = 5; voltage < bias: 0B00|000|x|1 = 1;
StepParamsCPLIMIT.Exit_Cond = [0,1];
TechParamsCPLIMIT.Step_number = length(StepParamsCPLIMIT.Current_step) - 1;

% Parameters for OCV
TechParamsOCV = struct( ...
	'technique', 'OCV', ...
	'E_Range', "2.5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "KEEP", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous step)
	'Bandwidth', 8, ...				% bandwidth number for loopback (1, 2, ... 9, BL.KEEP)
	'Rest_time_T', DurationOCV, ...	% duration of measuring (seconds)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
    'Record_every_dE', dE);			% voltage increment triggering sample (Volts); Inf = ignore

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
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCPLIMIT,StepParamsCPLIMIT,true,false);		% first technique

% Load OCV technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsOCV,[],false,true);							% last technique

% Start measurement
BL.StartChannel(ID,channel);

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

