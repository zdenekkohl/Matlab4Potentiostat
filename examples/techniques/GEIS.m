%% Galvano Electrochemical Impedance Spectroscopy (GEIS), adaptive AC current
% Author: Zdenek Kohl, University of Defence, Czech Republic, zdenek.kohl@unob.cz
% Adaptive current and current range; adoption after each half of frequency decade
% Steps:
%	1. Charge or discharge to bias voltage using constant current (CPLIMIT)
%		charging current is decreased to lower and lower value more times (suitable for supercapacitors)
%	2. Hold the bias voltage via constant voltage source until current falls below a defined level (CALIMIT)
%	3. Measure impedance using constant AC current - half of frequency decade (GEIS)
%	4. Based on maximum AC voltage, during temporary OCV, set new AC current and current measuring range for GEIS.
%		At the same time, number of wait periods (Wait_for_steady), and number of averages (Average_N_times) is proportionally decreased for low frequencies
%	5. Cycle: go to (1), ie. re-set bias, run GEIS with next half of frequency decade, new AC current and current range.

clear;
address = "192.109.209.128"; channel = 2;	% physical device address, channel number (numbering starts at 1)
fileNameCSV = 'GEIS.CSV';					% output data filename; script creates two files
											% "filename_CV.CSV" for current/voltage measurements, "filename_IS.CSV" for impedance measurements

% ------ Experiment parameters --------
V_bias = 1.5;						% bias voltage
I_charge = 0.1;						% current for charging to bias
Vac_mV_max = 10;					% max AC voltage (mV)
Iac_mA_max = 100;					% maximum AC current magnitude (mA)
Iac_mA = Iac_mA_max;				% starting value of AC current magnitude
f_begin = 1000;						% initial frequency (Hz)
f_decades = -7;						% number of frequency decades (negative count means sweeping down)
f_perDecade = 8;					% number of frequencies per decade (should be even number)
dT = 0.1;							% sampling period for current/voltage (C/V methods, i.e. initial charge)
ChargeDurMax = 10000;				% max. duration of initial charging
HoldBiasCurrentMax = I_charge/100;	% hold period finishes after the current falls below this value
DurationOCV = 10;					% duration of OCV technique (used temporarily to allow changing I_range)
WaitPeriods = 100;					% number of periods to wait before EIS technique starts measuring impedance ('Wait_for_steady')
AveragePeriods = 100;				% number of periods for averaging impedance ('Average_N_times')
									% Note: both 'Wait_for_steady' and 'Average_N_times' will be proportionally decreased for low frequencies

% ------- Helper parameters ----------	
DisplayInfo = false;						% display potentiostat related information
FwUpgrade = false; ForceFwReload = false;	% upgrade firmware if necessary; "force" means flash any time
ShowGauge = true;							% display progress bar during FW upgrade
ForceRun = true;							% force running measurement even the channel status is not "stopped"
AutoSave = false;							% automatically save environment for debugging purposes
LogarithmicTimeScale = false;				% set logarithmic time scale for plotting DC current/voltage component; useful for excessive number of frequency decades
AdaptiveACcurrent = true;					% AC current is modified for the next loop if the measured AC voltage is too low or too high
AdaptivePeriodsCount = true;				% number of wait periods and averages used by EIS is decreased for low frequencies
% ------------------------------------		

InitialDataLengthCV = 1000;					% initial vector size for measured data (CV methods)
InitialDataLengthEIS = 100;					% initial vector size for measured data (EIS)
I_Range_charge = BL.IRangeSet(I_charge);	% calculate optimal current measuring range for charging
Vac_max = Vac_mV_max/1000;					% AC current is decreased if AC voltage is above this value
Vac_min = Vac_max/10;						% AC current is increased if AC voltage is below this value

IacInit = Iac_mA/1000; Iac_max = Iac_mA_max/1000;
AdaptConst = sqrt(10);
FbeginLog = log10(f_begin);
if f_decades > 0
	f_progress = AdaptConst;
else
	f_progress = 1/AdaptConst;
end
f_per_cycle = ceil(f_perDecade/2) + 1; cycles = 2*abs(f_decades);
f_end = f_begin*f_progress;

[filePath,fileName,fileExt] = fileparts(fileNameCSV);
filePathName = fullfile(filePath, fileName);
FileNameMAT = filePathName + "_AutoSave.mat";	% .mat file for autosave
FileNameCV = filePathName + "_CV.csv";			% CSV file for current/voltage data (initial charge)
FileNameEIS = filePathName + "_EIS.csv";		% CSV file for impedance spectroscopy	

% Probe hardware parameters
ProbeConf = struct( ...
	'Connection', 0, ...			% 0 .. standard, 1 .. CE to ground, 2 .. WE to ground, 3 .. High voltage
	'Mode', 1);						% 0 .. grounded, 1 .. floating

% Parameters for initial charge via CP technique with limits
TechParamsCPLIMIT = struct( ...
	'technique', 'CPLIMIT', ...
	'E_Range', "AUTO", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', I_Range_charge, ...	% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous step)
    'Bandwidth', 8, ...				% bandwidth number for loopback (1, 2, ... 9, BL.KEEP)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
	'Record_every_dE', Inf, ...		% voltage increment that triggers new sample (Volts); Inf = ignore
    'Step_number', 0, ...			% number of steps - 1
    'N_Cycles', 0);					% number of times the technique is repeated - 1

StepParamsCPLIMIT = struct( ...
	'Current_step', 0, ...			% current (A)
	'vs_initial', false, ...		% if true, value is relative to the last one from previous technique
	'Duration_step', ChargeDurMax, ...		% duration of the step (s)
	'Test1_Config', 0, ...			% 0bVV|S|L|A; VV = variable (00 = voltage, 01 = AUX1, 10 = AUX2, 11 = current); Sign (0 = "<", 1 = ">");
	...								% Logic (0 = OR, 1 = AND); Active (1 = active)
	...								% voltage > bias: 0B00|001|x|1 = 5; voltage < bias: 0B00|000|x|1 = 1; 
	'Test1_Value', V_bias, ...		% condition (voltage) value
	'Test2_Config', 0, ...
	'Test2_Value', 0.0, ...
	'Test3_Config', 0, ...
	'Test3_Value', 0.0, ...
	'Exit_Cond', 0 ...				% exit condition; 0 = next step, 1 = next technique, 2 = stop
	);
StepParamsCPLIMIT.Current_step = I_charge*[1, -1, 1/5, -1/5, 1/25, -1/25, 1/100, -1/100];
StepNumber = length(StepParamsCPLIMIT.Current_step)/2;
StepParamsCPLIMIT.Test1_Config = repmat([5, 1], 1, StepNumber);
StepParamsCPLIMIT.Exit_Cond = [zeros(1,StepNumber - 1),1];
TechParamsCPLIMIT.Step_number = 2*StepNumber - 1;

% Parameters for technique "CALIMIT" (keeping bias voltage)
TechParamsCALIMIT = struct( ...
	'technique', 'CALIMIT', ...
	'E_Range', "AUTO", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "AUTO", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous step)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
	'Record_every_dI', Inf, ...		% current increment triggering sample (Amps); Inf = ignore
    'Step_number', 1, ...			% number of steps - 1
    'N_Cycles', 0);					% number of times the technique is repeated - 1

TechParamsCALIMIT.I_Range = BL.IRangeSet(HoldBiasCurrentMax*2);

StepParamsCALIMIT = struct( ...
	'Voltage_step', V_bias, ...		% voltage (V)
	'vs_initial', false, ...		% if true, value is relative to the last one from previous technique
	'Duration_step', ChargeDurMax, ...		% step duration (s); step ends with duration or with test condition - what comes first
	'Test1_Config', 99, ...			% binary: 0bVV|S|L|A; VV = variable (00 = voltage, 01 = AUX1, 10 = AUX2, 11 = current); Sign (0 = "<", 1 = ">"); Logic (0 = OR, 1 = AND); Active (1 = active);
	...								% Test1: Current > -I_keep, Logic = AND with Test2: 0B11|001|1|1 = 99
	'Test1_Value', HoldBiasCurrentMax, ...		% condition value (current limit)
	'Test2_Config', 101, ...		% Test2: Current < I_keep: 0B11|000|x|1 = 101
	'Test2_Value', -HoldBiasCurrentMax, ...
	'Test3_Config', 0, ...
	'Test3_Value', 0.0, ...
	'Exit_Cond', 1 ...				% exit condition; 0 = next step, 1 = next technique, 2 = stop
	);

% Parameters for GEIS technique
TechParamsGEIS = struct( ...
    'technique', 'GEIS', ...
	'E_Range', "2.5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
    'I_Range', "AUTO", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, KEEP = from previous step);
	'Bandwidth', 8);				% BW number for loopback (1, 2, ... 9, BL.KEEP)

StepParamsGEIS = struct( ...
	'vs_initial', false, ...			% bias current from previous step
	'Initial_Current_step', 0, ...		% bias current (A)
	'Duration_step', 5, ...				% duration of initial phase that sets bias current (s)
	'Record_every_dT', dT, ...			% sampling period (seconds, def = 1) during initial phase
	'Record_every_dE', Inf, ...			% voltage increment triggering sample (V); Inf = ignore
	'Initial_frequency', f_begin, ...	% (Hz)
	'Final_frequency', f_end, ...		% (Hz)
	'sweep', false, ...					% true = linear, false = logarithmic
	'Amplitude_Current', IacInit, ...	% sinusoidal current amplitude (A)
	'Frequency_number', f_per_cycle, ...	% number of frequencies per cycle
	'Average_N_times', AveragePeriods, ...	% how many repeat times for averaging
	'Correction', false, ...			% drift correction
	'Wait_for_steady', WaitPeriods);	% single precision, number of periods to wait before each frequency measurement

TechParamsGEIS.I_Range = BL.IRangeSet(IacInit*2);		% IRange must be at least maximum current twice

% Parameters for OCV
TechParamsOCV = struct( ...
	'technique', 'OCV', ...
	'E_Range', "5V", ...			% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "KEEP", ...			% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous step); AUTO not allowed for current step methods
	'Bandwidth', 8, ...				% BW number for loopback (1, 2, ... 9, BL.KEEP)
	'Rest_time_T', DurationOCV, ...	% duration of measuring (seconds)
	'Record_every_dT', dT, ...		% sampling period (seconds, def = 1)
    'Record_every_dE', Inf);		% voltage increment triggering sample (Volts); Inf = ignore

% Parameters for LOOP
TechParamsLOOP = struct( ...
	'technique', 'LOOP', ...
	'loop_N_times', cycles - 1, ...	% number of loops - 1; number of loops = number of half decades = 2*decades
    'protocol_number', 0);			% index of technique to go

[ID, DevInfo] = BL.Connect(address); [status, err] = BL.TestConnection(ID);
if FwUpgrade
	FWUpgradeResult = BL.LoadFirmware(ID, channel, ShowGauge, ForceFwReload);
end
ChannelInfo = BL.GetChannelInfo(ID, channel);
if DisplayInfo
	fprintf("Biologic library version: %s", BL.GetLibVersion);
	fprintf("Device info:\n%s\n Status: %s\nChannel %i info:\n%s\n", DevInfo.txt, status, channel, ChannelInfo.txt);
end

Techniques = table('Size', [5, 3], 'VariableTypes', ["string", "double", "double"],'VariableNames',["TechName", "TechIdx", "Steps"]);

% Load CPLIMIT technique for initial charge to bias (DC) voltage
TechIdx = 1;
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCPLIMIT,StepParamsCPLIMIT,true,false);		% first technique
Techniques.TechName(TechIdx) = TechParamsCPLIMIT.technique; Techniques.TechIdx(TechIdx) = TechIdx - 1; Techniques.Steps(TechIdx) = TechParamsCPLIMIT.Step_number + 1;

% Load CALIMIT technique for holding bias voltage (important for supercapacitors with alpha < 1)
TechIdx = TechIdx + 1;
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsCALIMIT,StepParamsCALIMIT,false,false);
Techniques.TechName(TechIdx) = TechParamsCALIMIT.technique; Techniques.TechIdx(TechIdx) = TechIdx - 1; Techniques.Steps(TechIdx) = TechParamsCALIMIT.Step_number + 1;

% Load GEIS technique for measuring impedance
TechIdx = TechIdx + 1;
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsGEIS,StepParamsGEIS,false,false);
Techniques.TechName(TechIdx) = TechParamsGEIS.technique; Techniques.TechIdx(TechIdx) = TechIdx - 1; Techniques.Steps(TechIdx) = 1;

% Load OCV technique; the technique is temporary to allow modifying current measuring range (I_range)
TechIdx = TechIdx + 1;
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsOCV,[],false,false);
Techniques.TechName(TechIdx) = TechParamsOCV.technique; Techniques.TechIdx(TechIdx) = TechIdx - 1; Techniques.Steps(TechIdx) = 1;

% LOOP for repeating next half decade of frequencies
TechIdx = TechIdx + 1;
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsLOOP,[],false,true);	% last technique
Techniques.TechName(TechIdx) = TechParamsLOOP.technique; Techniques.TechIdx(TechIdx) = TechIdx - 1; Techniques.Steps(TechIdx) = 1;

if DisplayInfo
	display(Techniques)
end

% Start measurement
BL.StartChannel(ID,channel); fprintf("Starting measurement on channel %i\n", channel);

% Init data for Current/Voltage phases
DataLengthCV = InitialDataLengthCV; TimeIndex = 1;
t = NaN(DataLengthCV, 1); Ewe = t; I = t; Tech = strings(DataLengthCV, 1);
writematrix(["t", "Ewe", "I", "Tech"], FileNameCV, 'Delimiter','tab');				% create CSV file with headers (voltage/current)


%  Init data for EIS phase
DataLengthEIS = InitialDataLengthEIS; EisIndex = 1;
f = NaN(DataLengthEIS, 1);
EweAbs = f; IAbs = f; PhaseDeg = f; ZAbs = EweAbs./IAbs; EweDC = f; I_DC = f; EisTime = f;
writematrix(["f", "E_AC_mV", "I_AC_mA", "PhaseDeg", "ZAbs", "EweDC", "I_DC", "EisTime"], FileNameEIS, 'Delimiter', 'tab');		% create CSV file with headers (EIS)

% Start animation
% Init plot, C/V phase - DC voltage/current
MarkerSize = 4;
fig = figure('Position',[100,100,1200,800]); clf(fig);
subplot(3,1,1,'Parent',fig);
yyaxis left; ax1L = gca;
if LogarithmicTimeScale
	InitL = semilogx(ax1L,t, Ewe, 'r.', 'MarkerSize',MarkerSize);
else
	InitL = plot(ax1L, t, Ewe, 'r.', 'MarkerSize',MarkerSize);
end
ylabel('$v(t)$ (V)','Interpreter','latex');
ax1L.YColor = 'r'; ax1L.TickDir = "out"; box off; %ylim([-5, 5]);
InitL.XDataSource = 't'; InitL.YDataSource = 'Ewe';

yyaxis right;
ax1R = gca;
if LogarithmicTimeScale
	InitR = semilogx(ax1R, t, I, 'b.', 'MarkerSize',MarkerSize);
else
	InitR = plot(ax1R, t, I, 'b.', 'MarkerSize',MarkerSize);
end
ylabel('$i(t)$ (A)','Interpreter','latex');
ax1R.YColor = 'b'; %ylim([-0.1, 0.1]);
xlabel('$t$ (s)','Interpreter','latex'); title('DC Voltage/current');
InitR.XDataSource = 't'; InitR.YDataSource = 'I';

% Init plot, EIS phase - AC voltage/current
subplot(3,1,2,'Parent',fig);
MarkerSize = 10;
yyaxis left; ax2L = gca;
Vac_L = loglog(ax2L, EweAbs, 'r.', 'MarkerSize',MarkerSize); ylabel('$|V_{AC}(f)|$ (mV)','Interpreter','latex');
ax2L.YColor = 'r'; ax2L.TickDir = "out"; box off;
Vac_L.XDataSource = 'f'; Vac_L.YDataSource = 'EweAbs';

yyaxis right; ax2R = gca;
Vac_R = loglog(ax2R, f, IAbs, 'b.', 'MarkerSize',MarkerSize); ylabel('$|I_{AC}(f)|$ (mA)','Interpreter','latex');
ax2R.YColor = 'b';
xlabel('$f$ (Hz)','Interpreter','latex'); title('AC voltage/current');
Vac_R.XDataSource = 'f'; Vac_R.YDataSource = 'IAbs';

% Init plot, EIS phase - impedance
subplot(3,1,3,'Parent',fig);
MarkerSize = 10;
yyaxis left; ax3L = gca; 
Z_L = loglog(ax3L, f, ZAbs, 'r.', 'MarkerSize',MarkerSize); ylabel('$|Z(f)|$ (Ohm)','Interpreter','latex');
ax3L.YColor = 'r'; ax3L.TickDir = "out"; box off;
Z_L.XDataSource = 'f'; Z_L.YDataSource = 'ZAbs';

yyaxis right; ax3R = gca;
Z_R = semilogx(ax3R, f, PhaseDeg, 'b.', 'MarkerSize',MarkerSize); ylabel('${\varphi}(f)$ (Deg)','Interpreter','latex');
ax3R.YColor = 'b';
xlabel('$f$ (Hz)','Interpreter','latex'); title('Impedance');
Z_R.XDataSource = 'f'; Z_R.YDataSource = 'PhaseDeg';
delay = 1; pause(delay); tic; t0 = toc;
TechniqueLast = "CPLIMIT";
Iac = IacInit;
while true
	[Data, DataInfo, CurrentValues] = BL.GetData(ID, channel, ChannelInfo.BoardTypeCode);
	NbRows = DataInfo.NbRows; Technique = BL.Technique(DataInfo.TechniqueID);
	if NbRows > 0
		if Technique ~= TechniqueLast
			TechniqueLast = Technique;
			if Technique == "OCV"
				f_begin = f_end; f_end = f_begin*f_progress;
				if AdaptiveACcurrent
					if EweAbsMax >= Vac_max
						Iac = Iac/AdaptConst;
					elseif (EweAbsMax < Vac_min) && (IAbsMax*1.2 > Iac) %&& (IacTemp*10 <= Iac_max)
						Iac = min(Iac*AdaptConst, Iac_max);
					end
				end
				TechIdx = Techniques{find(Techniques.TechName == "GEIS",1), 2};
				ParamsChange = struct( ...
					'technique', 'GEIS', ...
					'I_Range', BL.IRangeSet(Iac*2));
				BL.UpdateParameters(ID,channel,TechIdx,ChannelInfo.BoardType,ParamsChange,0);
				ParamsChange = struct( ...
					'technique', 'GEIS', ...
					'Initial_frequency', f_begin, ...
					'Final_frequency', f_end, ...
					'Amplitude_Current', Iac);
				if AdaptivePeriodsCount
					if f_begin <= 1e3
						ParamsChange.Wait_for_steady = max(WaitPeriods/10, 10);
						ParamsChange.Average_N_times = max(AveragePeriods/10, 10);
					elseif f_begin <= 10
						ParamsChange.Wait_for_steady = max(WaitPeriods/100, 1);
						ParamsChange.Average_N_times = max(AveragePeriods/100, 1);
					elseif f_begin <= 1
						ParamsChange.Wait_for_steady = 1;
						ParamsChange.Average_N_times = 1;
					end
				end
				BL.UpdateParameters(ID,channel,TechIdx,ChannelInfo.BoardType,ParamsChange,0);
			end
		end
		if any(Technique == ["CPLIMIT", "CALIMIT", "OCV"]) || ((Technique == "GEIS") && (DataInfo.ProcessIndex == 0))
			TimeIndexEnd = TimeIndex + NbRows - 1;
			if TimeIndexEnd + 1 > DataLengthCV		% increase size of data vectors if necessary
				FillRange = DataLengthCV + 1:2*DataLengthCV;
				t(FillRange, 1) = NaN; Ewe(FillRange, 1) = NaN; I(FillRange, 1) = NaN; Tech(FillRange, 1) = "";
				DataLengthCV = 2*DataLengthCV;
			end
			TimeIndexTemp = TimeIndex:TimeIndexEnd;
			t(TimeIndexTemp) = Data(1,:)' + DataInfo.StartTime; Ewe(TimeIndexTemp) = Data(2,:)'; I(TimeIndexTemp) = Data(3,:)';
			Tech(TimeIndexTemp) = BL.Technique(DataInfo.TechniqueID);
			writematrix([t(TimeIndexTemp), Ewe(TimeIndexTemp), I(TimeIndexTemp), Tech(TimeIndexTemp)], FileNameCV, 'Delimiter', 'tab','WriteMode','append');	% append C/V data to CSV file
			TimeIndex = TimeIndexEnd + 1;
		elseif DataInfo.ProcessIndex == 1
			EisIndexEnd = EisIndex + NbRows - 1;
			if EisIndexEnd + 1 > DataLengthEIS
				FillRange = DataLengthEIS + 1:2*DataLengthEIS;
				f(FillRange, 1) = NaN; EweAbs(FillRange, 1) = NaN; IAbs(FillRange, 1) = NaN; EweDC(FillRange, 1) = NaN; I_DC(FillRange, 1) = NaN;
                DataLengthEIS = 2*DataLengthEIS;
			end
			EisIndexTemp = EisIndex:EisIndexEnd;
			f(EisIndexTemp) = Data(1,:)'; EweAbs(EisIndexTemp) = Data(2,:)'*1000;
			EweAbsMax = max(Data(2,:)); IAbsMax = max(Data(3,:));
			IAbs(EisIndexTemp) = Data(3,:)'*1000; PhaseDeg(EisIndexTemp) = Data(4,:)'/pi*180; ZAbs(EisIndexTemp) = Data(2,:)'./Data(3,:)';
			EweDC(EisIndexTemp) = Data(5,:)'; I_DC(EisIndexTemp) = Data(6,:)'; EisTime(EisIndexTemp) = Data(7,:)';
			writematrix([f(EisIndexTemp), EweAbs(EisIndexTemp), IAbs(EisIndexTemp), PhaseDeg(EisIndexTemp), ZAbs(EisIndexTemp), EweDC(EisIndexTemp), ...
				I_DC(EisIndexTemp), EisTime(EisIndexTemp)], FileNameEIS, 'Delimiter', 'tab','WriteMode','append');		% append EIS data to CSV file
			EisIndex = EisIndexEnd + 1;
	
			TimeIndexEnd = TimeIndex + NbRows - 1;
			if TimeIndexEnd + 1 > DataLengthCV
				FillRange = DataLengthCV + 1:2*DataLengthCV;
				t(FillRange, 1) = NaN; Ewe(FillRange, 1) = NaN; I(FillRange, 1) = NaN; Tech(FillRange, 1) = "";
			end
			TimeIndexTemp = TimeIndex:TimeIndexEnd; Tech(TimeIndexTemp) = BL.Technique(DataInfo.TechniqueID) + "f";
			t(TimeIndexTemp) = Data(7,:)'; Ewe(TimeIndexTemp) = Data(5,:)'; I(TimeIndexTemp) = Data(6,:)';
			writematrix([t(TimeIndexTemp), Ewe(TimeIndexTemp), I(TimeIndexTemp), Tech(TimeIndexTemp)], FileNameCV, 'Delimiter', 'tab','WriteMode','append');
			TimeIndex = TimeIndexEnd + 1;
		end
		refreshdata(fig); drawnow;
	end
	if (CurrentValues.State == 0 && CurrentValues.MemFilled == 0)
		disp("Finished.")
		break
	end
	if CurrentValues.State ~= 0
		pause(delay)
		if NbRows >= 100
			delay = delay/4;
		elseif (NbRows <= 20) & (delay < 2)
			delay = delay*2;
		end
	end
	if (toc - t0 > 1800) && AutoSave
		save(FileNameMAT);
		t0 = toc;
	end

end
toc

TimeIndex = TimeIndex - 1; EisIndex = EisIndex - 1;
t = t(1:TimeIndex); Ewe = Ewe(1:TimeIndex); I = I(1:TimeIndex); t_hrs = t/(60*60);
f = f(1:EisIndex); EweAbs = EweAbs(1:EisIndex); IAbs = IAbs(1:EisIndex); PhaseDeg = PhaseDeg(1:EisIndex); ZAbs = ZAbs(1:EisIndex); EweDC = EweDC(1:EisIndex);
I_DC = I_DC(1:EisIndex); EisTime = EisTime(1:EisIndex);


