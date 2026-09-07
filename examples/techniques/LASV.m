%% Large Amplitude Sinusoidal Voltammetry (LASV) - example of frequency sweeping
% Author: Zdenek Kohl, University of Defence, Czech Republic, zdenek.kohl@unob.cz
% Steps:
%	1. Charge to initial voltage via CPLIMIT technique
%	2. Run specified number of period of sinusoidal voltage signal with DC component: 

clear;
address = "192.109.209.128"; channel = 2;	% physical device address, channel number (numbering starts at 1)
CSVfileName = 'LASV.CSV';					% output data filename

% ------ Experiment parameters --------
VoltageDC = 1; VoltageAC = 0.5;				% DC/AC voltage component (Volts)
PhaseInit = 0;								% initial phase (Deg)
I_charge = 0.2;								% current for charging to initial voltage (Amps)
Fs = 0.001;									% starting frequency (Hz)
Periods = 2;								% number of sinusoidal signal periods
decades = -1;								% number of frequency decades; specify negative count for sweeping frequency down
FreqPerDec = 1;								% number of frequencies per decade
NofCycles = 1;								% number of LASV repetitions
dT = 0.01; dI = 0.1;						% sampling period (seconds), current change to be recorded (Amps)
ChargeDurMax = 10000;						% max. duration of initial charging (sec)
SafetyLimitsEnable = true;					% stop measurement if current or voltage is out of safety limits
VoltageLimitMin = 0; VoltageLimitMax = 2.5;		% voltage safety limits (Volts)
CurrentLimitMin = -1; CurrentLimitMax = 1;		% current safety limits (Amps)

% ------- Helper parameters ----------	
VoltageInit = VoltageDC + VoltageAC*sin(PhaseInit/180*pi);
DisplayInfo = true;							% display potentiostat related information
FwUpgrade = false; ForceFwReload = false;	% upgrade firmware if necessary; "force" means flash any time
ShowGauge = true;							% display progress bar during FW upgrade
ForceRun = true;							% force running measurement even the channel status is not "stopped"
AnimRefreshRate = 2;						% animation refresh rate (Hz); important for higher sampling rates
% ------------------------------------

InitialDataLength = 10000;					% initial vector size for measured data
I_Range_charge = BL.IRangeSet(I_charge);	% calculate optimal current measuring range
AnimRefreshPeriod = 1/AnimRefreshRate;

% Probe hardware parameters
ProbeConf = struct( ...
	'Connection', 0, ...			% 0 .. standard, 1 .. CE to ground, 2 .. WE to ground, 3 .. High voltage
	'Mode', 1);						% 0 .. grounded, 1 .. floating

% Initial charge via CPLIMIT technique
TechParamsCPLIMIT = struct( ...
	'technique', 'CPLIMIT', ...
	'E_Range', "5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', I_Range_charge, ...	% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous technique)
    'Bandwidth', 8, ...				% bandwidth number for loopback (1, 2, ... 9, BL.KEEP)
	'Record_every_dT', dT, ...		% sampling period (seconds, default = 1)
	'Record_every_dE', Inf, ...		% voltage increment that triggers new sample (Volts); Inf = ignore
    'Step_number', 1, ...			% number of steps - 1
    'N_Cycles', 0);					% number of times the technique is repeated - 1

StepParamsCPLIMIT = struct( ...
	'Current_step', 0, ...			% current (Amps)
	'vs_initial', false, ...		% current taken from previous step
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

% modification of parameters for charging to initial voltage (two steps - charge or discharge)
StepParamsCPLIMIT.Current_step = I_charge*[1, -1];
StepParamsCPLIMIT.Test1_Value = VoltageInit;
StepParamsCPLIMIT.Test1_Config = [bin2dec('00101'), bin2dec('00001')];		% step 1 ends if voltage > VoltageInit; step 2 ends if voltage < VoltageInit
StepParamsCPLIMIT.Exit_Cond = [0, 0];

% parameters for sinusoidal technique
TechParamsLASV = struct( ...
    'technique', 'LASV', ...
	'E_Range', "5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "1A", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous step)
    'Bandwidth', 8, ...				% bandwidth number for loopback (1, 2, ... 9, BL.KEEP)
	'Ei', VoltageInit, ...			% initial potential (Volts)
	'Ei_vs_initial', false, ...		% voltage is relative to the final voltage of the previous technique (default = false)
    'Step_number', 0, ...			% number of steps - 1
    'N_Cycles', NofCycles - 1);		% number of times the technique is repeated - 1

% Generic definition of step parameters for LASV
StepParamsLASV = struct( ...
	'Fs', 1, ...					% frequency (Hz, default = 1)
	'E1', 1, ...					% high peak potential (Volts)
	'E1_vs_initial', false, ...		% voltage is relative to the final voltage of the previous technique (default = false)
	'E2', 0, ...					% low peak potential (Volts)
	'E2_vs_initial', false, ...		% voltage is relative to the final voltage of the previous technique (default = false)
	'Period_number', Periods, ...	% number of signal periods per step (def = 0)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
	'Record_every_dI', Inf);		% current increment triggering sample (Amps); Inf = ignore

% More detail for some LASV steps
FsLog = log10(Fs); F = logspace(FsLog, FsLog + decades, abs(decades)*FreqPerDec + 1);
StepParamsLASV.Fs = F;
if mod(PhaseInit,360) < 180
	StepParamsLASV.E1 = VoltageDC + VoltageAC;
	StepParamsLASV.E2 = VoltageDC - VoltageAC;
else
	StepParamsLASV.E1 = VoltageDC - VoltageAC;
	StepParamsLASV.E2 = VoltageDC + VoltageAC;
end
TechParamsLASV.Step_number = length(F) - 1;

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

% Load LASV technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsLASV, StepParamsLASV,false,true);		% last technique

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
