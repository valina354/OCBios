local handle, code, result, reason = component.proxy(component.list("internet")()).request('https://www.dropbox.com/s/g0g33x1z4p48otc/bios.lua?dl=1'), ''
if handle then
	while true do
		result, reason = handle.read(math.huge)
		if result then
			code = code..result
		else
			if reason then
				error(reason,0)
			end
			break
		end
	end
	result, reason = load(code)
	if result then
		result, reason = xpcall(result, debug.traceback)
		if not result then
			error(reason,0)
		end
	end
	error(reason,0)
else
	error('Invalid address',0)
end