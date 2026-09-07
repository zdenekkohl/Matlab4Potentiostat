%% Program for flashing EC-lab firmware on selected channel
clear;
address = "192.109.209.128"; channel = 2;	% physical device address, channel number (numbering starts at 1)
FlashFirmware = true;						% if "false" the script only displays information; running measurement is not affected

[ID, DevInfo] = BL.Connect(address);
ChannelInfo = BL.GetChannelInfo(ID, channel);

fprintf("Biologic library version: %s", BL.GetLibVersion)
fprintf("Device info:\n%s", DevInfo.txt)
fprintf("Channel %i info: %s\n", channel, ChannelInfo.txt)

if FlashFirmware
	Len = uint8(16);
	BoardType = BL.GetChannelBoardType(ID, channel);
	switch BoardType
		case "ESSENTIAL"
			BinFile = "interpr.bin"; XlxFile = "vmp_ii_0437_a6.xlx";
		case "PREMIUM"
			BinFile = "interpr4.bin"; XlxFile = "Vmp_iv_0395_aa.xlx";
		case "DIGICORE"
			BinFile = "interpr5.bin"; XlxFile = "";
	end
	ChannelMap = uint8(zeros(1, Len)); ChannelMap(channel) = 1;
	Results = int32(zeros(1, Len));
	[ret, FWUpgradeResult] = clib.BL_api.BL_LoadFirmware(ID, ChannelMap, Results, Len, true, true, BinFile, XlxFile);
	if ret ~= 0 && ret ~= -306
		disp(FWUpgradeResult)
		error('Function BL_LoadFirmware failed with error code %d,  %s', ret, BL.GetErrorMsg(ret));
	end
	pause(2);
	
	[ID, DevInfo] = BL.Connect(address);
	ChannelInfo = BL.GetChannelInfo(ID, channel);
	fprintf("Device info:\n%s", DevInfo.txt)
	fprintf("Channel %i info: %s\n", channel, ChannelInfo.txt)
end