classdef BL
    properties (Constant, Access = public)
		MAX_PARAMS = 500; KEEP = -1; MAX_UPDATE_PARAMS = 10;
		DEVICE_ = ["VMP", "VMP2", "MPG", "BISTAT", "MCS_200", "VMP3", "VSP", "HCP803", "EPP400", "EPP4000", ...
            "BISTAT2", "FCT150S", "VMP300", "SP50", "SP150", "FCT50S", "SP300", "CLB500", "HCP1005", ...
            "CLB2000", "VSP300", "SP200", "MPG2", "SP100", "MOSLED", "KINEXXX", "BCS815", "SP240", ...
            "MPG205", "MPG210", "MPG220", "MPG240", "BP300", "VMP3E", "VSP3E", "SP50E", "SP150E"];
        VMP300_FAMILY_ = ["SP100","SP200","SP300","VSP300","VMP300","SP240","BP300"];
        BOARD_TYPE_ = dictionary(0, 'UNKNOWN', 1, 'ESSENTIAL', 2, 'PREMIUM', 3, 'DIGICORE');
		FirmwareCode = dictionary( ...
			0, "No FW loaded", ...
			1, "FW for EC-Lab", ...
			4, "Unknown FW", ...
			5, "FW for scripting", ...
			8, "Invalid FW", ...
			10, "FW for calibration");
		State = dictionary( ...
			0, "Channel is stopped.", ...
			1, "Channel is running", ...
			2, "Channel is paused");
		E_RANGE = dictionary( ...
            '2.5V', 0, ...	% ±2.5V
            '5V', 1, ...	% ±5V
            '10V', 2, ...	% ±10V
            'AUTO', 3);		% auto
		I_RANGE = dictionary( ...
			'KEEP', -1, ...	% Keep previous
			'100pA', 0, ...	% 100 pA
			'1nA', 1, ...
			'10nA', 2, ...
			'100nA', 3, ...
			'1uA', 4, ...
			'10uA', 5, ...
			'100uA', 6, ...
			'1mA', 7, ...
			'10mA', 8, ...
			'100mA', 9, ...	% 100 mA
			'1A', 10, ...	% 1 A
			'BOOSTER', 11, ...
			'AUTO', 12)
		PARAM_TYPE = dictionary( ...
			'E_Range', 'int', ...				% ALL
			'I_Range', 'int', ...				% ALL
			'Bandwidth', 'int', ...				% ALL
			'Record_every_dT', 'single', ...	% OCV, LASV
			'Record_every_dE', 'single', ...	% OCV, CASG
            'Record_every_dI', 'single', ...    % LASV
			'Rest_time_T', 'single', ...		% OCV
			'Duration_step', 'single', ...		% PEIS, CPLIMIT
			'Begin_measuring_E', 'single', ...	% ISCAN
			'End_measuring_E', 'single', ...	% ISCAN
			'Ei', 'single', ...					% LASV
			'E1', 'single', ...					% LASV
			'E2', 'single', ...					% LASV
			'Voltage_step', 'single', ...		% CPLIMIT
			'Initial_Voltage_step', 'single',...% PEIS
			'Initial_Current_step', 'single',...% GEIS
			'Final_Voltage_step', 'single',...	% 
			'Current_step', 'single', ...		% ISCAN, CPLIMIT
			'Amplitude_Voltage', 'single', ...	% PEIS
			'Amplitude_Current', 'single', ...	% GEIS
			'vs_initial', 'bool', ...			% CPLIMIT, CALIMIT
			'Ei_vs_initial', 'bool', ...		% LASV
			'E1_vs_initial', 'bool', ...		% LASV
			'E2_vs_initial', 'bool', ...		% LASV
			'Ii', 'single', ...					% CASG
			'I1', 'single', ...					% CASG
			'I2', 'single', ...					% CASG
			'vs_initial', 'bool', ...			% ISCAN, CPLIMIT, CALIMIT, PEIS
			'Ii_vs_initial', 'bool', ...		% CASG
			'I1_vs_initial', 'bool', ...		% CASG
			'I2_vs_initial', 'bool', ...		% CASG
			'Test1_Config', 'int', ...			% CPLIMIT, CALIMIT
			'Test1_Value', 'single', ...		% CPLIMIT, CALIMIT
			'Test2_Config', 'int', ...			% CPLIMIT, CALIMIT
			'Test2_Value', 'single', ...		% CPLIMIT, CALIMIT
			'Test3_Config', 'int', ...			% CPLIMIT, CALIMIT
			'Test3_Value', 'single', ...		% CPLIMIT, CALIMIT
			'Exit_Cond', 'int', ...				% CPLIMIT, CALIMIT
			'Final_frequency', 'single', ...	% PEIS
			'Initial_frequency', 'single', ...	% PEIS
			'Frequency_number', 'int', ...		% PEIS
			'sweep', 'bool', ...				% PEIS
			'Average_N_times', 'int', ...		% PEIS
			'Wait_for_steady', 'single', ...	% PEIS
			'Correction', 'bool', ...			% PEIS
			'Scan_Rate', 'single', ...			% ISCAN
			'Fs', 'single', ...					% LASV
			'Period_number', 'int', ...			% LASV
			'Step_number', 'int', ...			% LASV
			'Scan_number', 'int', ...			% ISCAN
			'N_Cycles', 'int', ...				% LASV
			'loop_N_times', 'int', ...			% all
			'protocol_number', 'int' ...		% all
			)
		Technique = dictionary( ...
			0, 'NONE', ...
			100, 'OCV', ...
			104, 'PEIS', ...
			107, 'GEIS', ...
			125, 'ISCAN', ...
			150, 'LOOP', ...
			155, 'CPLIMIT', ...
			157, 'CALIMIT', ...
			159, 'LASV', ...
			169, 'CASG' ...
			)
		Electrode_conn = dictionary( ...
			0, 'Standard', ...
			1, 'CE to ground', ...
			2, 'WE to ground', ...
			3, 'High Voltage' ...
			)
		Channel_mode = dictionary( ...
			0, 'Grounded', ...
			1, 'Floating')
		
	end
	properties (Constant, Access = private)
		MAX_SLOTS_COUNT = 16;
	end

    methods (Static)
		function Version = GetLibVersion()
			version = char(zeros(1,32)); size = uint32(32);
			[ret, version, size] = clib.BL_api.BL_GetLibVersion(version, size);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
			Version = version(1:size);
		end
		function SN = GetVolumeSerialNumber()
			SN = clib.BL_api.BL_GetVolumeSerialNumber();
		end
		function ErrMsg = GetErrorMsg(code)
			message = char(zeros(1,255)); size = uint32(255);
			[ret, message, size] = clib.BL_api.BL_GetErrorMsg(code, message, size);
			if ret ~= 0
				error('Function %s failed with error code %d', dbstack().name, ret);
			end
			ErrMsg = message(1:size);
		end
		function [ID, DevInfo] = Connect(address, timeout)
			if nargin < 3
				timeout = 10;
			end
			ID = int32(0); devInfo = struct(clib.BL_api.TDeviceInfos_t);
			[ret, ID, DevInfoRaw] = clib.BL_api.BL_Connect(address,timeout,ID,devInfo);
			if ret ~= 0
				FunctionName = dbstack().name;
				error('Function %s failed with error code %d, "%s"', FunctionName, ret, BL.GetErrorMsg(ret));
			end
			if DevInfoRaw.HTdisplayOn
				HTD = 'on';
			else
				HTD = 'off';
			end
			if any((BL.DEVICE_(DevInfoRaw.DeviceCode + 1)) == BL.VMP300_FAMILY_)
				Family = 'VMP300';
			else
				Family = 'VMP3';
			end
			DevInfo.txt = sprintf(" %s (%s family) %iMB, CPU=%i, %i channels, %i slots\n Firmware: v%02.2f %i/%i/%i\n %i connections, HTdisplay %s", ...
				BL.DEVICE_(DevInfoRaw.DeviceCode + 1), Family, DevInfoRaw.RAMSize, DevInfoRaw.CPU, DevInfoRaw.NumberOfChannels, DevInfoRaw.NumberOfChannels, ...
				DevInfoRaw.FirmwareVersion/100, DevInfoRaw.FirmwareDate_yyyy, DevInfoRaw.FirmwareDate_mm, DevInfoRaw.FirmwareDate_dd, DevInfoRaw.NbOfConnectedPC, HTD);
			DevInfo.DevModel = BL.DEVICE_(DevInfoRaw.DeviceCode + 1);
			DevInfo.Family = Family;
			DevInfo.Raw = DevInfoRaw;
			%ChannelInfo = BL.GetChannelInfo(ID, channel);
		end
		function Disconnect(ID)
			[ret] = clib.BL_api.BL_Disconnect(ID);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function [status, err] = TestConnection(ID)
			[ret] = clib.BL_api.BL_TestConnection(ID);
			if ret == 0
				status = "OK"; err = "";
			else
    			status = "Not OK"; err = BL.GetErrorMsg(ret);
			end
		end
		function [DeviceSpeed, ChannelSpeed] = TestCommSpeed(ID, channel)
			DeviceSpeed = int32(0); ChannelSpeed = int32(0);
			[ret, DeviceSpeed, ChannelSpeed] = clib.BL_api.BL_TestCommSpeed(ID, channel - 1, DeviceSpeed, ChannelSpeed);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function USBdevInfo = GetUSBdeviceinfo(USBindex)
			company = char(zeros(1,255)); companySize = uint32(0); device = char(zeros(1,255)); deviceSize = uint32(0); SN = char(zeros(1,255)); SNsize = uint32(0);
			[ret, company, device, SN] = clib.BL_api.BL_GetUSBdeviceinfos(USBindex, company, companySize, device, deviceSize, SN, SNsize);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
			USBdevInfo = struct( ...
				"Company", company, ...
				"Device", device, ...
				"SN", SN);
		end
		function FWUpgradeResult = LoadFirmware(ID, channel, ShowGauge, ForceReload)
			Len = uint8(BL.MAX_SLOTS_COUNT);
			BoardType = BL.GetChannelBoardType(ID, channel);
			switch BoardType
				case "ESSENTIAL"
					BinFile = "kernel.bin";
					XlxFile = "vmp_ii_0437_a6.xlx";
				case "PREMIUM"
					BinFile = "kernel4.bin";
					XlxFile = "Vmp_iv_0395_aa.xlx";
				case "DIGICORE"
					BinFile = "kernel5.bin";
					XlxFile = "";
			end
			ChannelMap = uint8(zeros(1, Len)); ChannelMap(channel) = 1;
			Results = int32(zeros(1, Len));
			[ret, FWUpgradeResult] = clib.BL_api.BL_LoadFirmware(ID, ChannelMap, Results, Len, ShowGauge, ForceReload, BinFile, XlxFile);
			if ret ~= 0
				disp(FWUpgradeResult)
				error('Function BL_LoadFirmware failed with error code %d,  "%s"', ret, BL.GetErrorMsg(ret));
			end
		end
		function Plugged = IsChannelPlugged(ID, channel)
			Plugged = clib.BL_api.BL_IsChannelPlugged(ID, channel - 1);
		end
		function ChannelsPlugged = GetChannelsPlugged(ID)
			channels = uint8(zeros(1, BL.MAX_SLOTS_COUNT)); size = uint8(BL.MAX_SLOTS_COUNT);
			[ret, ChannelsPlugged] = clib.BL_api.BL_GetChannelsPlugged(ID, channels, size);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function BoardType = GetChannelBoardType(ID, channel)
			BoardTypeCode = uint32(0);
			[ret, BoardTypeCode] = clib.BL_api.BL_GetChannelBoardType(ID, channel - 1, BoardTypeCode);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
			BoardType = BL.BOARD_TYPE_(BoardTypeCode);
		end
		function ChannelInfo = GetChannelInfo(ID, channel)
			ChannelInfoRaw = struct(clib.BL_api.TChannelInfos_t);
			[ret, ChannelInfoRaw] = clib.BL_api.BL_GetChannelInfos(ID, channel - 1, ChannelInfoRaw);
			if ret ~= 0
    			disp(BL.GetErrorMsg(ret))
				warning('Function BL_GetChannelInfos failed with error code %d, "%s"', ret, BL.GetErrorMsg(ret));
			else
				ChannelInfoTxt = sprintf(" Firmware version (%2.2f), %s\n State: %s", ChannelInfoRaw.FirmwareVersion/100, BL.FirmwareCode(ChannelInfoRaw.FirmwareCode), BL.State(ChannelInfoRaw.State));
				BoardTypeCode = uint32(0);
				[ret, BoardTypeCode] = clib.BL_api.BL_GetChannelBoardType(ID, channel - 1, BoardTypeCode);
				ChannelInfo = struct('txt', ChannelInfoTxt, 'raw', ChannelInfoRaw, 'BoardType', BL.BOARD_TYPE_(BoardTypeCode), 'BoardTypeCode', BoardTypeCode);
				if ret ~= 0
					error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
				end
			end
		end
		function Msg = GetMessage(ID, channel)
			message = char(zeros(1,255)); size = uint32(255);
			[ret, message, size] = clib.BL_api.BL_GetMessage(ID, channel - 1, message, size);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
			Msg = message(1:size);
		end
		function HardConf = GetHardConf(ID, channel)
			HardConf = struct(clib.BL_api.THardwareConf_t);
			[ret, HardConf] = clib.BL_api.BL_GetHardConf(ID, channel - 1, HardConf);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function SetHardConf(ID, channel, ProbeConf)
			if BL.GetChannelBoardType(ID, channel) == "ESSENTIAL"
				warning("BL.SetHardConf: Setting probe parameters not supported on VMP3 family")
			else
				ProbeConfReq = struct(clib.BL_api.THardwareConf_t); ProbeConfReq.Conn = ProbeConf.Connection; ProbeConfReq.Ground = ProbeConf.Mode;
				ret = clib.BL_api.BL_SetHardConf(ID, channel - 1, ProbeConfReq);
				if ret ~= 0
					error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
				end
			end
		end
		function LoadTechnique(ID, channel,BoardType, TechParams, StepParams, FirstTechnique, LastTechnique)
			if isempty(StepParams)
				StepParams = struct();
			end
			[ParamsCount, EccParamsList] = BL.MakeEccParameters(TechParams, StepParams);
			EccParams = struct('len', int32(ParamsCount), 'pParams', EccParamsList);
			TechFile = lower(TechParams.technique);
			switch BoardType
				case "ESSENTIAL"
					TechFile = [TechFile, '.ecc'];
				case "PREMIUM"
					TechFile = [TechFile, '4.ecc'];
				case "DIGICORE"
					TechFile = [TechFile, '5.ecc'];
			end
			ret = clib.BL_api.BL_LoadTechnique(ID,channel - 1, TechFile, EccParams, FirstTechnique, LastTechnique, false);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function StartChannel(ID,channel)
			ret = clib.BL_api.BL_StartChannel(ID, channel - 1);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function StopChannel(ID,channel)
			ret = clib.BL_api.BL_StopChannel(ID, channel - 1);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function UpdateParameters(ID, channel, TechIndx, BoardType, Params, Step)
			ParamNames = fieldnames(Params); ParamsCount = length(ParamNames) - 1;
			if ParamsCount > BL.MAX_UPDATE_PARAMS
        		error(['Too many parameters to update, max number is ', num2str(BL.MAX_UPDATE_PARAMS)]);
			end
			EccParamsList(1:BL.MAX_PARAMS) = struct(clib.BL_api.TEccParam_t);
			for ii = 1:ParamsCount
				ParamName = ParamNames{ii + 1};
				EccParam = BL.DefineEccParameter(ParamName, Params.(ParamName), Step);
				EccParamsList(ii) = EccParam;
			end
			EccParams = struct('len', int32(ParamsCount), 'pParams', EccParamsList);
			TechFile = lower(Params.technique);
			switch BoardType
				case "ESSENTIAL"
					TechFile = [TechFile, '.ecc'];
				case "PREMIUM"
					TechFile = [TechFile, '4.ecc'];
				case "DIGICORE"
					TechFile = [TechFile, '5.ecc'];
			end
			ret = clib.BL_api.BL_UpdateParameters(ID,channel - 1, TechIndx, EccParams, TechFile);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function CurrentValues = GetCurrentValues(ID, channel)
			CurrentValues = struct(clib.BL_api.TCurrentValues_t);
			[ret, CurrentValues] = clib.BL_api.BL_GetCurrentValues(ID, channel - 1, CurrentValues);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
		function [Data, DataInfo, CurrentValues] = GetData(ID, channel, BoardTypeCode)
			DataBuffer = struct(clib.BL_api.TDataBuffer_t); DataInfo = struct(clib.BL_api.TDataInfos_t); CurrentValues = struct(clib.BL_api.TCurrentValues_t);
			[ret, rData, DataInfo, CurrentValues] = clib.BL_api.BL_GetData(ID, channel - 1, DataBuffer, DataInfo, CurrentValues);
			if ret ~= 0
				error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
			timebase = CurrentValues.TimeBase; NbRows = DataInfo.NbRows; NbCols = DataInfo.NbCols;
			Technique = BL.Technique(DataInfo.TechniqueID);
			switch Technique
				case "OCV"
					t = zeros(1, NbRows); Ewe = zeros(1, NbRows); I = zeros(1, NbRows); cycle = zeros(1, NbRows);
					index = 1; t_temp = double(0); Ewe_temp = single(0);
					for ix = 1:NbCols:NbRows*NbCols
						[~, t(index)] = clib.BL_api.BL_ConvertTimeChannelNumericIntoSeconds(rData.data(ix:ix + 1), t_temp, timebase, BoardTypeCode);
						[~, Ewe(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 2), Ewe_temp, BoardTypeCode);
						index = index + 1;
					end
					Data = [t; Ewe; I; cycle];
				% CP like methods
				case {"LASV", "CASG", "CPLIMIT", "CALIMIT"}
					t = zeros(1, NbRows); Ewe = zeros(1, NbRows); I = zeros(1, NbRows); cycle = zeros(1, NbRows);
					index = 1; t_temp = double(0); Ewe_temp = single(0); I_temp = single(0);
					for ix = 1:NbCols:NbRows*NbCols
						[~, t(index)] = clib.BL_api.BL_ConvertTimeChannelNumericIntoSeconds(rData.data(ix:ix + 1), t_temp, timebase, BoardTypeCode);
	    				[~, Ewe(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 2), Ewe_temp, BoardTypeCode);
						[~, I(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 3), I_temp, BoardTypeCode);
						cycle(index) = rData.data(ix + 4);
						index = index + 1;
					end
					Data = [t; Ewe; I; cycle];
				case{"ISCAN"}
					t = zeros(1, NbRows); Ewe = zeros(1, NbRows); I = zeros(1, NbRows); cycle = zeros(1, NbRows);
					index = 1; t_temp = double(0); Ewe_temp = single(0); I_temp = single(0);
					for ix = 1:NbCols:NbRows*NbCols
						[~, t(index)] = clib.BL_api.BL_ConvertTimeChannelNumericIntoSeconds(rData.data(ix:ix + 1), t_temp, timebase, BoardTypeCode);
	    				[~, I(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 2), Ewe_temp, BoardTypeCode);
						[~, Ewe(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 3), I_temp, BoardTypeCode);
						cycle(index) = rData.data(ix + 4);
						index = index + 1;
					end
					Data = [t; Ewe; I; cycle];
				case {"PEIS", "GEIS"}
					ProcessIndex = DataInfo.ProcessIndex;
					if ProcessIndex == 0
						t = zeros(1, NbRows); Ewe = zeros(1, NbRows); I = zeros(1, NbRows);
						index = 1;
						temp_double = double(0); temp_single = single(0);
						for ix = 1:NbCols:NbRows*NbCols
							[~, t(index)] = clib.BL_api.BL_ConvertTimeChannelNumericIntoSeconds(rData.data(ix:ix + 1), temp_double, timebase, BoardTypeCode);
	    					[~, Ewe(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 2), temp_single, BoardTypeCode);
							[~, I(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 3), temp_single, BoardTypeCode);
							index = index + 1;
						end
						Data = [t; Ewe; I];
					elseif ProcessIndex == 1
						%fprintf("ProcessIndex %i\n", ProcessIndex);
						f = zeros(1, NbRows); EweAbs = f; IAbs = f; Phase = f; Ewe = f; I = f; t = f;
						index = 1; temp_single = single(0);
						for ix = 1:NbCols:NbRows*NbCols
	    					[~, f(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix), temp_single, BoardTypeCode);
							[~, EweAbs(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 1), temp_single, BoardTypeCode);
							[~, IAbs(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 2), temp_single, BoardTypeCode);
							[~, Phase(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 3), temp_single, BoardTypeCode);
							[~, Ewe(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 4), temp_single, BoardTypeCode);
							[~, I(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 5), temp_single, BoardTypeCode);
							[~, t(index)] = clib.BL_api.BL_ConvertChannelNumericIntoSingle(rData.data(ix + 13), temp_single, BoardTypeCode);
							index = index + 1;
						end
						Data = [f; EweAbs; IAbs; Phase; Ewe; I; t];
					end
				otherwise
					fprintf("!Error!, method ID %i not expected.\n", DataInfo.TechniqueID);
					disp(DataInfo)
					disp(CurrentValues)
					Data = zeros(4, 0);
			end
		end
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		% Helper functions not defined by DLL *
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		function Messages = GetMessages(ID, channel)
			Messages = strings(100, 1); messagesCount = 0;
			while 1
				Msg = BL.GetMessage(ID, channel);
				if isempty(Msg)
					break
				end
				messagesCount = messagesCount + 1;
				Messages(messagesCount, 1) = Msg;
			end
			Messages = Messages(1:messagesCount, 1);
		end
		function PrintMessages(ID, channel)
			while 1
				Msg = BL.GetMessage(ID, channel);
				if isempty(Msg)
					break
				end
				disp(Msg)
			end
		end
		function PrintHardConf(ID, channel)
			HardConf = BL.GetHardConf(ID, channel);
			fprintf(' Probe connection: %s\n', BL.Electrode_conn(HardConf.Conn));
			fprintf(' Probe mode:       %s\n', BL.Channel_mode(HardConf.Ground));
		end
		function param = DefineEccParameter(label, value, index)
			switch BL.PARAM_TYPE(label)
				case 'technique'
				case 'single'
                    param = BL.DefineSglParameter(label, value, index);
                case 'int'
                    switch label
                        case "E_Range"
                            param = BL.DefineIntParameter(label, BL.E_RANGE(value), index);
                        case "I_Range"
                            param = BL.DefineIntParameter(label, BL.I_RANGE(value), index);
                        case "bandwidth"
                            param = BL.DefineIntParameter(label, BL.BANDWIDTH(value), index);
                        otherwise
                            param = BL.DefineIntParameter(label, value, index);
                    end
				case 'bool'
					param = BL.DefineBoolParameter(label, value, index);
                otherwise
                    error('Unknown parameter %s', label)
			end
        end
		function [ParamIndex, EccParamsList] = MakeEccParameters(TechParams, StepParams)
			ParamIndex = 0;
			EccParamsList(1:BL.MAX_PARAMS) = struct(clib.BL_api.TEccParam_t);
			TechParamNames = fieldnames(TechParams); TechParamsCount = length(TechParamNames);
			StepParamNames = fieldnames(StepParams); StepParamsCount = length(StepParamNames);
			ParamLength = zeros(1,StepParamsCount);
            for ii = 1:StepParamsCount
				ParamLength(ii) = length(StepParams.(StepParamNames{ii}));
            end
			N_Steps = max(ParamLength);
			% correct number of steps
			if (isfield(TechParams, 'Step_number')) && (N_Steps <= TechParams.Step_number)
				TechParams.Step_number = N_Steps - 1;
			end
			for ii = 1:TechParamsCount
				ParamName = TechParamNames{ii};
				if ParamName == "technique"
					continue
				end
				ParamIndex = ParamIndex + 1;
				if ParamIndex > BL.MAX_PARAMS
            		error("Too many parameters or steps, increase the max number of parameters in the 'BL_api' library definition and regenerate the library.")
				end
				EccParam = BL.DefineEccParameter(ParamName, TechParams.(ParamName), 0);
				EccParamsList(ParamIndex) = EccParam;
			end
			% extend step parameters to all steps (based on last defined value)
			if N_Steps > 1
				for ii = 1:StepParamsCount
					ParamName = StepParamNames{ii}; ParamLength_temp = ParamLength(ii);
					%%{
					if (ParamName == "Scan_Rate" && StepParams.(ParamName)(1) ~= 0)
						StepParams.(ParamName) = [0, StepParams.(ParamName)]; ParamLength_temp = ParamLength_temp + 1;
					end
					%%}
					if ParamLength(ii) < N_Steps
                        StepParams.(ParamName)(ParamLength_temp + 1:N_Steps) = StepParams.(ParamName)(ParamLength_temp);
					end
				end
			end
			%%}
			for StepNumber = 1:N_Steps
				for ii = 1:StepParamsCount
					ParamName = StepParamNames{ii};
                    ParamIndex = ParamIndex + 1;
                    if ParamIndex > BL.MAX_PARAMS
                        error("Too many parameters or steps, increase the max number of parameters in the 'BL_api' library definition and regenerate the library.")
                    end
                    EccParam = BL.DefineEccParameter(ParamName, StepParams.(ParamName)(StepNumber), StepNumber - 1);
					EccParamsList(ParamIndex) = EccParam;
				end
			end
        end
		function IRangeNew = IRangeSet(I)
			IRangeKeys = BL.I_RANGE.keys; IRangeValues = BL.I_RANGE.values;
			IRangeIdx = find(IRangeValues(2:12) >= log10(I) + 10, 1);
			if ~isempty(IRangeIdx)
				IRangeNew = IRangeKeys(IRangeIdx + 1); 
			elseif I <= 100e-12
        		IRangeNew = "100pA";
			else 
        		IRangeNew = "1A";
			end
		end
	end
	methods (Static, Hidden)
        function param = DefineBoolParameter(label, value, index)
            EccParam = struct(clib.BL_api.TEccParam_t);
            [ret, param] = clib.BL_api.BL_DefineBoolParameter(label, value, index, EccParam);
         	if ret ~= 0
	    		error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
            end
        end
        function param = DefineIntParameter(label, value, index)
			EccParam = struct(clib.BL_api.TEccParam_t);
			[ret, param] = clib.BL_api.BL_DefineIntParameter(label, int32(value), index, EccParam);
			if ret ~= 0
	    		error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
		end
        function param = DefineSglParameter(label, value, index)
            EccParam = struct(clib.BL_api.TEccParam_t);
			[ret, param] = clib.BL_api.BL_DefineSglParameter(label, single(value), index, EccParam);
			if ret ~= 0
	    		error('Function %s failed with error code %d, "%s"', dbstack().name, ret, BL.GetErrorMsg(ret));
			end
        end
	end
		
end