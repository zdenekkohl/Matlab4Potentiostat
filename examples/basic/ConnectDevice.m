address = "192.109.209.129";
ID = int32(0); timeout = 5;
DevInfo = struct(clib.BL_api.TDeviceInfos_t);
[code, ID, DevInfo] = ...
	clib.BL_api.BL_Connect(address, ...
	timeout,ID,DevInfo);
if code == 0
	disp(DevInfo)
else
	fprintf("Device connect failed with error code %i\n", code)
end
