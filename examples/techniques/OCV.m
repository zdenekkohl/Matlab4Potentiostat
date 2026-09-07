%% Open Circuit Voltage (OCV)
% Author: Zdenek Kohl, University of Defence, Czech Republic, zdenek.kohl@unob.cz
clear;
address = "192.109.209.128"; channel = 2;		% physical device address, channel number (numbering starts at 1)
CSVfileName = 'OCV.CSV';						% output data filename
TimeTotal = 10;									% total measuring time
TimeSampl = 0.1;								% sampling period (seconds)
DisplayInfo = true;								% display potentiostat related information
FwUpgrade = true; ForceFwReload = false;		% upgrade firmware if necessary; "force" means flash any time
ShowGauge = true;								% display progress bar during FW upgrade
ForceRun = true;								% force running measurement even the channel status is not "stopped"
InitialDataLength = ceil(TimeTotal/TimeSampl);	% initial vector size for measured data

% Probe hardware parameters (only for VMP-300 series)
ProbeConf = struct( ...
	'Connection', 0, ...				% 0 .. standard, 1 .. CE to ground, 2 .. WE to ground, 3 .. High voltage
	'Mode', 1);							% 0 .. grounded, 1 .. floating

% Parameters for OCV technique
TechParamsOCV = struct( ...
	'technique', 'OCV', ...
	'E_Range', "AUTO", ...				% ±voltage measuring range (2.5V, 5V, 10V, AUTO)
	'I_Range', "AUTO", ...				% ±current measuring range (100pA, 1nA, ..., 100mA, 1A, BOOSTER, AUTO, KEEP = from previous method)
	'Bandwidth', 8, ...					% bandwidth number for loopback (1, 2, ... 9, BL.KEEP)
	'Rest_time_T', TimeTotal, ...		% duration of measurement (seconds)
	'Record_every_dT', TimeSampl, ...	% sampling period (seconds, def = 1)
    'Record_every_dE', 0.01);			% voltage increment that triggers new sample (Volts); Inf = ignore
										% use "Inf" for exact sampling rate

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

% Load technique parameters to channel
BL.LoadTechnique(ID,channel,ChannelInfo.BoardType,TechParamsOCV,[],true,true);

% Start measurement
BL.StartChannel(ID,channel); fprintf("Starting measurement on channel %i\n", channel);

% Prepare data vectors and CSV file headers
DataLength = InitialDataLength;
t = NaN(DataLength, 1); Ewe = NaN(DataLength, 1); I = NaN(DataLength, 1);
writematrix(["t", "Ewe", "I"], CSVfileName, 'Delimiter','tab');				% create CSV file with headers

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
		t(indexTemp) = Data(1,:)' + DataInfo.StartTime; Ewe(indexTemp) = Data(2,:)'; I(indexTemp) = Data(3,:)';
		writematrix([t(indexTemp), Ewe(indexTemp), I(indexTemp)], CSVfileName, 'Delimiter', 'tab','WriteMode','append');		% append data to CSV file
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
t = t(1:indexEnd); Ewe = Ewe(1:indexEnd); I = I(1:indexEnd);
