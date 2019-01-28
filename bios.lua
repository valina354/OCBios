local cl = component.list
local cp = component.proxy
local invoke = component.invoke

local unicode = unicode or utf8 --lua 5.3 compatibility )0))

local gpu,InternetInt,internet
local BiosStage

local users
local filesystems

local CurrentMenu = {}
local BootMenuStage = {1}--1 - current str, 2 - max strs, 3 - label, 4 - address, 5 - ready?
local ServiceMenuStage
local BootPageFirstStart,SystemInformationPageFirstStart = true, true

local BiosVersion = '0.05b'
------------------------------------------
computer.getBootAddress = function()
	local controllerMemory = invoke(cl("eeprom")(), "getData")
	return string.sub(controllerMemory,1,36) --первый адрес в контроллере (1-36 символ)
end

computer.setBootAddress = function(address)
	if string.len(address) == 36 then
		local controllerMemory = invoke(cl("eeprom")(), "getData")
		local newData = address..string.sub(controllerMemory,37,string.len(controllerMemory)) --перезапись первых 36 символов
		return invoke(cl('eeprom')(), "setData", newData)
	end
end

local function getPriorityBootAddress()
	local controllerMemory = invoke(cl("eeprom")(), "getData")
	return string.sub(controllerMemory,37,73) --второй адрес в контроллере (36-73 символ)
end

local function setPriorityBootAddress(address)
	if string.len(address) == 36 then
		local controllerMemory = invoke(cl("eeprom")(), "getData")
		local newData = string.sub(controllerMemory,1,36)..address..string.sub(controllerMemory,74,string.len(controllerMemory)) --перезапись 37-74 символов
		return invoke(cl('eeprom')(), "setData", newData)
	end
end

local function setBackground(a)
	gpu.setBackground(a)
end

local function setForeground(a)
	gpu.setForeground(a)
end

local function fill(...)
	gpu.fill(...)
end

local function set(...)
	gpu.set(...)
end

local function setResolution(...)
	gpu.setResolution(...)
end

local function fillBackground()
	local w,h = gpu.getResolution()
	gpu.fill(1,1,w,h,' ')
end

local function SetTextInTheMiddle(y,space,text,correct)
	if correct then
		set(space/2-unicode.len(text)/2+correct,y,text)
	else
		set(space/2-unicode.len(text)/2,y,text)
	end
end
------------------------------------------
local function BootWithAddress(address)
	computer.setBootAddress(address)
	local handle, err
	if ServiceMenuStage[2][6] == 'MineOS' then
		handle, err = invoke(address, "open", "/OS.lua")
	else
		handle, err = invoke(address, "open", "/init.lua")
	end
	if not handle then
		error(err)
	end
	local bootCode = ""
	repeat
		local chunk = invoke(address, "read", handle, math.huge)
		bootCode = bootCode..(chunk or "")
	until not chunk
	load(bootCode)()
end

local function BootWithoutAddress()
	local PriorityBootAddress = getPriorityBootAddress()
	if PriorityBootAddress and component.proxy(PriorityBootAddress) and invoke(PriorityBootAddress,'exists','/init.lua') and not invoke(PriorityBootAddress, "isDirectory", "init.lua") then
		computer.setBootAddress(PriorityBootAddress)
		local handle, err = invoke(PriorityBootAddress, "open", "/init.lua")
		if not handle then
			error(err)
		end
		local bootCode = ""
		repeat
			local chunk = invoke(PriorityBootAddress, "read", handle, math.huge)
			bootCode = bootCode..(chunk or "")
		until not chunk
		load(bootCode)()
	else
		for address in pairs(cl('filesystem')) do
			if cp(address).getLabel() ~= 'tmpfs' then
				if invoke(address,'exists','/init.lua') and not invoke(address, "isDirectory", "init.lua") then 
					computer.setBootAddress(address)
					local handle, err = invoke(address, "open", "/init.lua")
					if handle then
						local bootCode = ""
						repeat
							local chunk = invoke(address, "read", handle, math.huge)
							bootCode = bootCode..(chunk or "")
						until not chunk
						load(bootCode)()
					end
				end
			end
		end
	end
	error('No bootable device!')
end
------------------------------------------
local function ChangeDescription(description)
	-- body
end

local function getOS(address)
	if invoke(address,'exists','/OS.lua') and not invoke(address, "isDirectory", "/OS.lua") then --MineOS
		return 'MineOS'
	elseif invoke(address,'exists','/init.lua') and not invoke(address, "isDirectory", "/init.lua") then --OpenOS
		local isOpenOS, path
		if invoke(address,'exists','/lib/tools/boot.lua') then
			isOpenOS = true
			path = '/lib/tools/boot.lua'
		elseif invoke(address,'exists','/lib/core/boot.lua') then
			isOpenOS = true
			path = '/lib/core/boot.lua'
		end
		local handle = invoke(address, "open", path)
		if not handle then
			return tostring('unknown')
		end
		local bootCode = ""
		repeat
			local chunk = invoke(address, "read", handle, math.huge)
			bootCode = bootCode..(chunk or "")
		until not chunk
		local _,strEnd = string.find(bootCode,'_G._OSVERSION = "')
		return string.sub(bootCode,strEnd+1,string.find(bootCode,'"',strEnd+1)-1)
	end
	return tostring('unknown') --если ничё ни подошло
end

local function SystemInformationPageUpdate()
	local totalMemory, freeMemory = computer.totalMemory(), computer.freeMemory()
	fill(6,7,41,3,' ')
	set(6,7,'Total memory: '..totalMemory)
	set(6,8,'Used memory: '..totalMemory-freeMemory)
	set(6,9,'Free memory: '..freeMemory)

	fill(6,13,41,4,' ')
	local uptime = computer.uptime()
	if uptime > 60 then
		uptime = tostring(math.modf(uptime/60*10)/10)..'m'
	else
		uptime = uptime..'s'
	end
	set(6,13,'Computer uptime: '..uptime)
	set(6,14,'Computer max energy: '..computer.maxEnergy())
	set(6,15,'Computer energy: '..math.modf(computer.energy()))
	set(6,16,'Boot priority address: '..unicode.sub(getPriorityBootAddress(),1,18))
end
------------------------------------------

local function ClearLastPage()
	local lastBackground,lastForeground = gpu.getBackground(), gpu.getForeground()

	fill(50,4,24,20,' ') --боковая панель
	fill(2,4,47,20,' ') --сама страница

	fill(1,4,1,20,'║')
	fill(49,4,1,20,'║')
	set(1,5,'╟───────────────────────────────────────────────╢')

	setBackground(0x0000af)
	--fill(1,2,74,1,' ')
	setForeground(0xcdcdcf)
	set(3,2,'  System information  ')
	set(25,2,'  Boot or repair  ')
	set(43,2,'  Bios settings  ')

	setBackground(lastBackground)
	setForeground(lastForeground)
end

local function got()
	setResolution(74,25)
	setBackground(0xcdcdcf)
	setForeground(0x0000af)
	fill(1,1,74,25,' ')
	set(1,3,'╔')
	fill(2,3,72,1,'═')
	set(74,3,'╗')
	fill(1,4,1,20,'║')
	fill(74,4,1,20,'║')
	fill(2,24,72,1,'═')
	set(1,24,'╚')
	set(74,24,'╝')
	set(49,3,'╦')
	fill(49,4,1,20,'║')
	set(49,24,'╩')
	set(1,5,'╟───────────────────────────────────────────────╢')
	setBackground(0x40e0d0)
	fill(1,1,74,1,' ')
	set(23,1,'Advanced BIOS setup utility')
	setBackground(0x0000af)
	fill(1,2,74,1,' ')
	setForeground(0xcdcdcf)
	set(3,2,'  System information  ')
	set(25,2,'  Boot or repair  ')
	set(43,2,'  Bios settings  ')
	fill(1,25,74,1,' ')
	setForeground(0xcdcdcf)
	SetTextInTheMiddle(25,74,'v'..BiosVersion..' Made by titan123023, ATK inc.')
end

local function GetSystemInformationPage()
	CurrentMenu = 'SystemInformation'

	setBackground(0xcdcdcf)
	setForeground(0x0000af)
	ClearLastPage()
	set(3,2,'  System information  ')
	SetTextInTheMiddle(4,49,'Information about your system')

	set(50,21,'←→    Select Screen')
	set(50,22,'F9    Save and Exit')

	local totalMemory, freeMemory = computer.totalMemory(), computer.freeMemory()
	set(4,6,'Memory information:')
	set(6,7,'Total memory: '..totalMemory)
	set(6,8,'Used memory: '..totalMemory-freeMemory)
	set(6,9,'Free memory: '..freeMemory)

	set(4,11,'Computer information:')
	--[[local users = {computer.users()}
	if not users then
		set(6,12,'Computer users: nil')
	else
		set(6,12,'Computer users: ')
		for i=1, #users do
			set(23,12+i,'['..i..']  '..unicode.sub('users[i]',1,20))
		end
	end]]
	set(6,12,'Computer address: '..unicode.sub(computer.address(),1,8))
	set(6,13,'Computer uptime: '..computer.uptime())
	set(6,14,'Computer max energy: '..computer.maxEnergy())
	set(6,15,'Computer energy: '..math.modf(computer.energy()))
	set(6,16,'Boot priority address: '..unicode.sub(getPriorityBootAddress(),1,18))
	set(6,17,'Last boot disc address: '..unicode.sub(computer.getBootAddress(),1,18))
end

local function CheckDriveReadyToStart()
	if filesystems[BootMenuStage[1]][5] and filesystems[BootMenuStage[1]][6] ~= 'unknown' then
		return 'YES!'
	elseif filesystems[BootMenuStage[1]][5] then
		return 'maybe'
	else
		return 'not'
	end
end

local function GetBootPage(update)
	BiosStage = 'MainScene'
	CurrentMenu = 'BootAndRepair'

	setBackground(0xcdcdcf)
	setForeground(0x0000af)
	ClearLastPage()
	set(25,2,'  Boot or repair  ')
	SetTextInTheMiddle(4,49,'Select device to boot or repair his')

	set(50,18,'←→    Select Screen')
	set(50,19,'↑↓    Select Item')
	set(50,20,'Enter Select Field')
	set(50,21,'F5    Update device list')
	set(50,22,'F9    Save and Exit')

	if BootPageFirstStart or update then
		filesystems = {}
		local address, ready, label
		for address in pairs(cl('filesystem')) do
			b = cp(address)
			label = b.getLabel()
			if label ~= 'tmpfs' then
				if (invoke(address,'exists','/init.lua') and not invoke(address, "isDirectory", "/init.lua")) or (invoke(address,'exists','/OS.lua') and not invoke(address, "isDirectory", "/OS.lua")) then 
					d=' [Ready to boot]'
					ready = true
					--OSVersion = getOS(address) -- какого то Х** не пашет
				else 
					d=' [not ready to boot]'
					ready = false
				end

				label = label or 'unknown'
				if string.len(label) > 11 then
					label = unicode.sub(label,1,8)..'...'
				end

				table.insert(filesystems,{b,d,label,address,ready,getOS(address)})
			end
		end
		BootPageFirstStart = false
	end

	for i=1,#filesystems do
		if i==BootMenuStage[1] then 
			setForeground(0xffffff) 
			set(4,5+i,'► ['..unicode.sub(filesystems[i][4],1,8)..'] '..filesystems[i][3]..filesystems[i][2])
			setForeground(0x0000af)
		else
			set(4,5+i,'  ['..unicode.sub(filesystems[i][4],1,8)..'] '..filesystems[i][3]..filesystems[i][2])
		end
	end
	BootMenuStage[2] = #filesystems

	set(51,4,'Regular hard drive...')
	set(51,6,'Address: '..unicode.sub(filesystems[BootMenuStage[1]][4],1,13))
	set(51,7,'Name: '..unicode.sub(filesystems[BootMenuStage[1]][3],1,15))
	set(51,8,'Ready to start: '..CheckDriveReadyToStart())
	set(51,9,'OS: '..filesystems[BootMenuStage[1]][6])
	set(51,10,'Total space: '..filesystems[BootMenuStage[1]][1].spaceTotal())
	set(51,11,'Used space: '..filesystems[BootMenuStage[1]][1].spaceUsed())
	set(51,12,'Free space: '..filesystems[BootMenuStage[1]][1].spaceTotal()-filesystems[BootMenuStage[1]][1].spaceUsed())
end

local function GetBiosSetingsPage()
	
end

local function BootOtr(this,last)
	if this==last then return end

	setForeground(0xffffff)
	set(4,5+this,'► ['..unicode.sub(filesystems[this][4],1,8)..'] '..filesystems[this][3]..filesystems[this][2])

	setForeground(0x0000af)
	set(4,5+last,'  ['..unicode.sub(filesystems[last][4],1,8)..'] '..filesystems[last][3]..filesystems[last][2])

	fill(50,6,24,7,' ')
	set(51,6,'Address: '..unicode.sub(filesystems[this][4],1,13))
	set(51,7,'Name: '..unicode.sub(filesystems[this][3],1,15))
	set(51,8,'Ready to start: '..CheckDriveReadyToStart())
	set(51,9,'OS: '..filesystems[this][6])
	set(51,10,'Total space: '..filesystems[this][1].spaceTotal())
	set(51,11,'Used space: '..filesystems[this][1].spaceUsed())
	set(51,12,'Free space: '..filesystems[this][1].spaceTotal()-filesystems[this][1].spaceUsed())
end

local function ServiceTheDeviceOtr(this,last)
	setForeground(0x0000af)
	if last == 1 then
		if ServiceMenuStage[2][5] then
			if ServiceMenuStage[2][6] == 'MineOS' then
				set(4,8,'  Try boot now (/OS.lua) (MineOS mode)    ')
			else
				set(4,8,'  Try boot now (/init.lua) (OpenOS mode)  ')
			end
		else
			set(4,8,'  Try boot now (not available)')
		end
	elseif last == 2 then
		if getPriorityBootAddress() == ServiceMenuStage[2][4] then
			set(4,9,'  Make disk priority bootloader [is already]')
		else
			set(4,9,'  Make disk priority bootloader [is not]    ')
		end
	elseif last == 3 then
		set(4,10,'  Format disk')
	end

	setForeground(0xffffff)
	if this == 1 then
		if ServiceMenuStage[2][5] then
			if ServiceMenuStage[2][6] == 'MineOS' then
				set(4,8,'► Try boot now (/OS.lua) (MineOS mode)    ')
			else
				set(4,8,'► Try boot now (/init.lua) (OpenOS mode)  ')
			end
		else
			set(4,8,'► Try boot now (not available)')
		end
	elseif this == 2 then
		if getPriorityBootAddress() == ServiceMenuStage[2][4] then
			set(4,9,'► Make disk priority bootloader [is already]')
		else
			set(4,9,'► Make disk priority bootloader [is not]    ')
		end
	elseif this == 3 then
		set(4,10,'► Format disk')
	end
end

local function FormatDevice(proxy)
	for _, file in ipairs(proxy.list("/")) do
		proxy.remove(file)
	end
end

local function ServiceTheDeviceSetPriorityBootAddress(address)
	if address ~= getPriorityBootAddress() then
		setPriorityBootAddress(address)

		setForeground(0xffffff)
		if getPriorityBootAddress() == ServiceMenuStage[2][4] then
			set(4,9,'► Make disk priority bootloader [is already]')
		else
			set(4,9,'► Make disk priority bootloader [is not]    ')
		end
	end
end

local function ServiceTheDevice()
	CurrentMenu = 'ServiceTheDevice'
	ServiceMenuStage = {1} 

	setBackground(0xcdcdcf)
	setForeground(0x0000af)
	fill(50,4,24,20,' ')
	fill(2,4,47,20,' ')
	set(1,5,'║')
	set(49,5,'║')
	set(1,6,'╟───────────────────────────────────────────────╢')

	ServiceMenuStage[2] = filesystems[BootMenuStage[1]]

	SetTextInTheMiddle(4,49,'Settings for the device: ')
	SetTextInTheMiddle(5,49,ServiceMenuStage[2][4])

	set(50,20,'↑↓    Select Item')
	set(50,21,'Enter Select Field')
	set(50,22,'Tab   exit to boot menu')

	setForeground(0xffffff)
	if ServiceMenuStage[2][5] then
		if ServiceMenuStage[2][6] == 'MineOS' then
			set(4,8,'► Try boot now (/OS.lua) (MineOS mode)  ')
		else
			set(4,8,'► Try boot now (/init.lua) (OpenOS mode)  ')
		end
	else
		set(4,8,'► Try boot now (not available)')
	end
	setForeground(0x0000af)

	if getPriorityBootAddress() == ServiceMenuStage[2][4] then
		set(4,9,'  Make disk priority bootloader [is already]')
	else
		set(4,9,'  Make disk priority bootloader [is not]')
	end

	set(4,10,'  Format disk')
end
------------------------------------------
local function POST()
	BiosStage = 'POST'

	local sc,gpA,iA = cl('screen')(),cl('gpu')(),cl('internet')()
	if gpA and sc then 
		pcall(invoke, gpA, 'bind', sc)
		gpu=cp(gpA)
	else 
		computer.beep(20,5) 
		computer.shutdown()  
	end

	if iA then 
		InternetInt = true 
		internet=cp(iA) 
	else
		computer.beep(2000,2)
	end

end

------------

local function BootAndRepairPageKeyListener(key)
	if key==200 and BootMenuStage[1] > 1 then --2
		local last = BootMenuStage[1]
		BootMenuStage[1] = BootMenuStage[1]-1
		BootOtr(BootMenuStage[1],last)

	elseif key==208 and BootMenuStage[1] < BootMenuStage[2] then --8
		local last = BootMenuStage[1]
		BootMenuStage[1] = BootMenuStage[1]+1
		BootOtr(BootMenuStage[1],last)

	elseif key==63 then --F5
		GetBootPage(true)

	elseif key==28 then --enter
		ServiceTheDevice()

	end
end

local function ServiceTheDevicePageKeyListener(key)
	if key==28 then --enter
		if ServiceMenuStage[1] == 1 then
			if ServiceMenuStage[2][5] then
				BootWithAddress(ServiceMenuStage[2][4])
			else
				computer.beep()
			end

		elseif ServiceMenuStage[1] == 2 then
			ServiceTheDeviceSetPriorityBootAddress(ServiceMenuStage[2][4])

		elseif ServiceMenuStage[1] == 3 then
			FormatDevice(ServiceMenuStage[2][1])

		end
	elseif key == 200 and ServiceMenuStage[1] > 1 then
		local last = ServiceMenuStage[1]
		ServiceMenuStage[1] = ServiceMenuStage[1]-1
		ServiceTheDeviceOtr(ServiceMenuStage[1], last)

	elseif key == 208 and ServiceMenuStage[1] < 3 then
		local last = ServiceMenuStage[1]
		ServiceMenuStage[1] = ServiceMenuStage[1]+1
		ServiceTheDeviceOtr(ServiceMenuStage[1], last)

	elseif key == 15 then --tab
		GetBootPage(true)
	end
end

local function keyListener()
	while true do
		local e,_,_,key = computer.pullSignal(0.5)
		if e=='key_up'then
			if key==203 and CurrentMenu ~= 'SystemInformation' then --4
				if CurrentMenu == 'BootAndRepair' then
					GetSystemInformationPage()
				end
			elseif key==205 and CurrentMenu ~= 'BiosSetings' then --6
				if CurrentMenu == 'SystemInformation' then
					GetBootPage()
				end
			elseif key==67 then --F9
				if CurrentMenu == 'BootAndRepair' or CurrentMenu == 'SystemInformation' then
					return
				end
			else
				if CurrentMenu == 'BootAndRepair' then
					BootAndRepairPageKeyListener(key)
				elseif CurrentMenu == 'ServiceTheDevice' then
					ServiceTheDevicePageKeyListener(key)
				end
			end
		end
		if CurrentMenu == 'SystemInformation' then --обновление инфы каждый проход цикла (0.5сек)
			SystemInformationPageUpdate()
		end
	end
end

local function HiMenu() -- меню приветствия
	BiosStage = 'HiMenu'

	setResolution(50,16)
	setBackground(0) -- на случай если запуск производится после ошибки биоса (синего экрана)
	fillBackground() -- заливка чёрным цветом ^^^

	set(11,1,'Advanced BIOS by titan123023')
	set(7,15,'Press F12 to enter the settings menu')
	set(8,16,'Press any key to skip this message')

	local goToMenu
	while true do
		local e,_,_,k = computer.pullSignal(5)
		if e ~= nil then
			if e=='key_up' then
				if k==88 then
					goToMenu = true
					break
				else
					break
				end
			end
		else
			break
		end
	end
	if goToMenu then
		got()
		GetSystemInformationPage()
		keyListener()
	end
	BootWithoutAddress()
end
------------

POST()
HiMenu()