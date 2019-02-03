local cl = component.list
local cp = component.proxy
local invoke = component.invoke

local unicode = unicode or utf8 --lua 5.3 compatibility )0))

local gpu,InternetInt,internet

local users
local filesystems

local CurrentMenu = {}
local BootMenuStage = {1}--1 - current str, 2 - max strs, 3 - label, 4 - address, 5 - ready?
local ServiceMenuStage
local BootPageFirstStart,SystemInformationPageFirstStart = true, true

local Bios = {StockSettings = {
	language = 'en'
}}

local Modifier = {}
local UI = {}

local BiosSetingsPage = {
	Element = 1, 
	Strings = {
		' Language: [en]', 							-- Language = ' Language: [en]', 		
		' Format EEPROM data',						-- FormatEEPROMData = ' Format EEPROM data',
		' Debug format EEPROM data',					-- DebugFormatEEPROMData = ' Debug format EEPROM data',
		' Debug format EEPROM code'					-- DebugFormatEEPROMCode = ' Debug format EEPROM code'
	}, 
	Descriptions = {
		--{'This option',					--Данная опция позволит модифицировать файлы запуска MineOS и OpenLoader. Это позволит запускать MineOS/SecureOS/Plan9k даже со включенным приоритетом бута.
		-- 'will allow to modify',
		-- 'the startup files of',
		-- 'MineOS and OpenLoader.',
		-- 'This will allow to load',
		-- 'MineOS SecureOS Plan9k'},
		{'Changes the language', --Меняет язык биоса. Для того, чтобы изменения вступили в силу требуется перезагрузить компьютер. [Еще не готово]
		'of the BIOS.',
		'In order for',
		'the changes',
		'to take effect,',
		'you must restart',
		'the computer.',
		'[Not ready yet]'},
		{'deletes BIOS data', --удаляет данные BIOS (сбрасывает настройки)
		'(resets settings)'
		},
	}
}

local ServiceMenuPage = {
	Descriptions = {
		{'Try to boot from',
		'the disk.',
		'If you are using MineOS',
		'then apply',
		'the bootloader patch'}, --Попытатся загрузится с диска. Если вы используете MineOS, то примените патч загрузчика
		{'Applies the bootloader',
		'patch'},
		{},
		{'Deletes all data',
		'from disk'} --Удаляет все данные c диска
	}
}


local BiosVersion = '0.12b'

local Debug = {}
------------------------------------------
computer.getBootAddress = function()
	local MemoryController = invoke(cl("eeprom")(), "getData")
	return string.sub(MemoryController,1,36) --первый адрес в контроллере (1-36 символ)
end

computer.setBootAddress = function(address)
	if string.len(address) == 36 then
		local MemoryController = invoke(cl("eeprom")(), "getData")
		local newData = address..string.sub(MemoryController,37,string.len(MemoryController)) --перезапись первых 36 символов
		return invoke(cl('eeprom')(), "setData", newData)
	end
end

function Bios.FormatData()
	--0f14248c-70d5-48c7-b664-f4fb970f0ddb!0f14248c-70d5-48c7-b664-f4fb970f0ddb!ru!
	invoke(cl('eeprom')(), "setData", '------------------------------------------------------------------------en')
end

function Bios.SetLanguage(key)
	local MemoryController = invoke(cl("eeprom")(), "getData")
	local newData = string.sub(MemoryController,1,72)..key..string.sub(MemoryController,75,string.len(MemoryController)) -- 73,74 символы - код языка
end

function Bios.GetLanguage()
	local MemoryController = invoke(cl("eeprom")(), "getData")
	return string.sub(MemoryController,73,74) -- 73,74 символы - код языка
end

function Bios.GetPriorityBootAddress()
	local MemoryController = invoke(cl("eeprom")(), "getData")
	return string.sub(MemoryController,37,72) --второй адрес в контроллере (36-73 символ)
end

function Bios.SetPriorityBootAddress(address)
	local MemoryController = invoke(cl("eeprom")(), "getData")
	local newData = string.sub(MemoryController,1,36)..address..string.sub(MemoryController,73,string.len(MemoryController)) --перезапись 37-72 символов
	return invoke(cl('eeprom')(), "setData", newData)
end

------------------------------------------
function Modifier.GetModifierOpportunity()
	if ServiceMenuStage[2][6] == 'MineOS' then
		local address = ServiceMenuStage[2][4]
		local bootCode = ""

		local handle, err = invoke(address, "open", "/OS.lua")
		if handle then
			repeat
				local chunk = invoke(address, "read", handle, math.huge)
				bootCode = bootCode..(chunk or "")
			until not chunk
		end

		if bootCode then
			--gpu.set(1,1,string.sub(bootCode,180,249)) --Визуально  выводит (всё правильно)
			--if string.sub(bootCode,180,249) == 'component.proxy(component.proxy(component.list("eeprom")()).getData())' then
			--	computer.beep() --арёт... всё правильно
			--end
			--if string.find(string.sub(bootCode,180,249),'component.proxy(component.proxy(component.list("eeprom")()).getData())') then
			--	computer.beep() --не может найти, хотя они полностью идентичны...
			--end
			-- не ищет, хотя это одно и тоже
			--gpu.set(1,1,string.find(bootCode,'component.proxy(component.proxy(component.list("eeprom")()).getData())'))

			--local indexs = {string.find(bootCode,'component.proxy(component.proxy(component.list("eeprom")()).getData())')}

			--костылёчек
			local indexs = {}
			if string.sub(bootCode,180,249) == 'component.proxy(component.proxy(component.list("eeprom")()).getData())' then
				indexs[1],indexs[2] = 179,250
			end

			if indexs[1] then
				return indexs
			else
				return false
			end
		else
			return false
		end
	end
end

function Modifier.TryModify()
	if ServiceMenuStage[2][6] == 'MineOS' then
		local address = ServiceMenuStage[2][4]
		local bootCode = ""

		local handle, err = invoke(address, "open", "/OS.lua")
		if handle then
			repeat
				local chunk = invoke(address, "read", handle, math.huge)
				bootCode = bootCode..(chunk or "")
			until not chunk
			invoke(address,'close',handle)
		end

		local newBootCode = string.sub(bootCode,1,ServiceMenuStage[3][2])..'component.proxy(computer.getBootAddress()) or component.proxy(component.proxy(component.list("eeprom")()).getData())'..string.sub(bootCode,ServiceMenuStage[3][3],string.len(bootCode))

		local handle, err = invoke(address, "open", "/OS.lua",'w')
		if handle then
			invoke(address, 'write', handle, newBootCode)
			invoke(address,'close',handle)
		end
	end
end
------------------------------------------
function Debug.FormatData()
	invoke(cl('eeprom')(), "setData",'')
end

function Debug.FormatBios()
	invoke(cl('eeprom')(), "set",'')
end
------------------------------------------
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
	invoke(address,'close',handle)

	load(bootCode)()
end

local function BootWithoutAddress()
	local PriorityBootAddress = Bios.GetPriorityBootAddress()
	if PriorityBootAddress and component.proxy(PriorityBootAddress) and ((invoke(PriorityBootAddress,'exists','/init.lua') and not invoke(PriorityBootAddress, "isDirectory", "init.lua")) or (invoke(PriorityBootAddress,'exists','/OS.lua') and not invoke(PriorityBootAddress, "isDirectory", "OS.lua"))) then
		computer.setBootAddress(PriorityBootAddress)

		local handle, err
		if invoke(PriorityBootAddress,'exists','/OS.lua') and not invoke(PriorityBootAddress, "isDirectory", "OS.lua") then
			handle, err = invoke(PriorityBootAddress, "open", "/OS.lua")
		elseif invoke(PriorityBootAddress,'exists','/init.lua') and not invoke(PriorityBootAddress, "isDirectory", "init.lua") then
			handle, err = invoke(PriorityBootAddress, "open", "/init.lua")
		end

		if not handle then
			error(err)
		end
		local bootCode = ""
		repeat
			local chunk = invoke(PriorityBootAddress, "read", handle, math.huge)
			bootCode = bootCode..(chunk or "")
		until not chunk
		invoke(PriorityBootAddress,'close',handle)

		load(bootCode)()
	else
		for address in pairs(cl('filesystem')) do
			if cp(address).getLabel() ~= 'tmpfs' then
				if (invoke(address,'exists','/init.lua') and not invoke(address, "isDirectory", "init.lua")) or (invoke(address,'exists','/OS.lua') and not invoke(address, "isDirectory", "OS.lua")) then 
					computer.setBootAddress(address)

					local handle, err
					if invoke(address,'exists','/OS.lua') and not invoke(address, "isDirectory", "OS.lua") then
						handle, err = invoke(address, "open", "/OS.lua")
					elseif invoke(address,'exists','/init.lua') and not invoke(address, "isDirectory", "init.lua") then
						handle, err = invoke(address, "open", "/init.lua")
					end

					if handle then
						local bootCode = ""
						repeat
							local chunk = invoke(address, "read", handle, math.huge)
							bootCode = bootCode..(chunk or "")
						until not chunk
						invoke(address,'close',handle)

						load(bootCode)()
					end
				end
			end
		end
	end
end
------------------------------------------
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
		invoke(address,'close',handle)
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
	set(6,16,'Boot priority address: '..unicode.sub(Bios.GetPriorityBootAddress(),1,18))
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
	set(6,16,'Boot priority address: '..unicode.sub(Bios.GetPriorityBootAddress(),1,18))
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
	CurrentMenu = 'BootAndRepair'

	setBackground(0xcdcdcf)
	setForeground(0x0000af)
	ClearLastPage()
	set(25,2,'  Boot or repair  ')
	SetTextInTheMiddle(4,49,'Select device to boot or repair it')

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
					d=' [Not ready to boot]'
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

	if BootMenuStage[2] ~= 0 then
		set(51,4,'Regular hard drive...')
		set(51,6,'Address: '..unicode.sub(filesystems[BootMenuStage[1]][4],1,13))
		set(51,7,'Name: '..unicode.sub(filesystems[BootMenuStage[1]][3],1,15))
		set(51,8,'Ready to boot: '..CheckDriveReadyToStart())
		set(51,9,'OS: '..filesystems[BootMenuStage[1]][6])
		set(51,10,'Total space: '..filesystems[BootMenuStage[1]][1].spaceTotal())
		set(51,11,'Used space: '..filesystems[BootMenuStage[1]][1].spaceUsed())
		set(51,12,'Free space: '..filesystems[BootMenuStage[1]][1].spaceTotal()-filesystems[BootMenuStage[1]][1].spaceUsed())
	end
end

function UI.DrawDescription(Table,element)
	setForeground(0x0000af)

	fill(50,4,24,15,' ') --очистит старое описание
	if Table.Descriptions[element] then
		local description = Table.Descriptions[element]
		for i=1,#description do
			SetTextInTheMiddle(3+i,24,description[i],50)
		end
	end
end

function BiosSetingsPage.OnChangeField(last)
	setForeground(0x0000af)
	local field
	set(4,6+last,' '..BiosSetingsPage.Strings[last])

	setForeground(0xffffff)
	set(4,6+BiosSetingsPage.Element,'►'..BiosSetingsPage.Strings[BiosSetingsPage.Element])

	UI.DrawDescription(BiosSetingsPage,BiosSetingsPage.Element)
end

function BiosSetingsPage.Draw()
	CurrentMenu = 'BiosSetings'

	setBackground(0xcdcdcf)
	setForeground(0x0000af)
	ClearLastPage()
	set(43,2,'  Bios settings  ')
	SetTextInTheMiddle(4,49,'BIOS setup')

	set(50,19,'←→    Select Screen')
	set(50,20,'↑↓    Select Item')
	set(50,21,'Enter Select Field')
	set(50,22,'F9    Save and Exit')

	UI.DrawDescription(BiosSetingsPage,BiosSetingsPage.Element)

	setForeground(0x0000af)
	set(4,7,' '..BiosSetingsPage.Strings[1]) -- Язык
	set(4,8,' '..BiosSetingsPage.Strings[2]) -- Сброс настроек
	set(4,9,' '..BiosSetingsPage.Strings[3]) -- Сброс настроек [Отладка]
	set(4,10,' '..BiosSetingsPage.Strings[4]) -- Форматировать биос [Отладка]

	setForeground(0xffffff)
	set(4,6+BiosSetingsPage.Element,'►'..BiosSetingsPage.Strings[BiosSetingsPage.Element])
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
	set(51,8,'Ready to boot: '..CheckDriveReadyToStart())
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
		if ServiceMenuStage[3][1] then
			set(4,9,'  Try to modify the bootloader             ')
		else
			set(4,9,'  Try to modify the bootloader [impossible]')
		end
	elseif last == 3 then
		if Bios.GetPriorityBootAddress() == ServiceMenuStage[2][4] then
			set(4,10,'  Make disk priority bootloader [is already]')
		else
			set(4,10,'  Make disk priority bootloader [is not]    ')
		end
	elseif last == 4 then
		set(4,11,'  Format disk')
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
		if ServiceMenuStage[3][1] then
			set(4,9,'► Try to modify the bootloader             ')
		else
			set(4,9,'► Try to modify the bootloader [impossible]')
		end
	elseif this == 3 then
		if Bios.GetPriorityBootAddress() == ServiceMenuStage[2][4] then
			set(4,10,'► Make disk priority bootloader [is already]')
		else
			set(4,10,'► Make disk priority bootloader [is not]    ')
		end
	elseif this == 4 then
		set(4,11,'► Format disk')
	end

	UI.DrawDescription(ServiceMenuPage,this)
end

local function FormatDevice(drive)
	for _, file in ipairs(drive.list("/")) do
		drive.remove(file)
	end
end

local function ServiceTheDeviceSetPriorityBootAddress(address)
	if address ~= Bios.GetPriorityBootAddress() then
		Bios.SetPriorityBootAddress(address)

		setForeground(0xffffff)
		if Bios.GetPriorityBootAddress() == ServiceMenuStage[2][4] then
			set(4,10,'► Make disk priority bootloader [is already]')
		else
			set(4,10,'► Make disk priority bootloader [is not]    ')
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

	local modifyOpportunityAndIndexes = Modifier.GetModifierOpportunity()
	if modifyOpportunityAndIndexes then
		ServiceMenuStage[3] = {true,modifyOpportunityAndIndexes[1],modifyOpportunityAndIndexes[2]}
		set(4,9,'  Try to modify the bootloader')
	else
		ServiceMenuStage[3] = {false}
		set(4,9,'  Try to modify the bootloader [impossible]')
	end

	if Bios.GetPriorityBootAddress() == ServiceMenuStage[2][4] then
		set(4,10,'  Make disk priority bootloader [is already]')
	else
		set(4,10,'  Make disk priority bootloader [is not]')
	end

	set(4,11,'  Format disk')

	UI.DrawDescription(ServiceMenuPage,ServiceMenuStage[1])
end
------------------------------------------
local function POST()
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

	if invoke(cl("eeprom")(), "getData") == '' then
		Bios.FormatData()
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
			if ServiceMenuStage[3][1] then
				Modifier.TryModify()
				local modifyOpportunityAndIndexes = Modifier.GetModifierOpportunity()
				if modifyOpportunityAndIndexes then
					ServiceMenuStage[3] = {true,modifyOpportunityAndIndexes[1],modifyOpportunityAndIndexes[2]}
				else
					ServiceMenuStage[3] = {false}
				end

				ServiceTheDeviceOtr(ServiceMenuStage[1],ServiceMenuStage[1])
			end

		elseif ServiceMenuStage[1] == 3 then
			ServiceTheDeviceSetPriorityBootAddress(ServiceMenuStage[2][4])

		elseif ServiceMenuStage[1] == 4 then
			FormatDevice(ServiceMenuStage[2][1])

		end
	elseif key == 200 and ServiceMenuStage[1] > 1 then
		local last = ServiceMenuStage[1]
		ServiceMenuStage[1] = ServiceMenuStage[1]-1
		ServiceTheDeviceOtr(ServiceMenuStage[1], last)

	elseif key == 208 and ServiceMenuStage[1] < 4 then
		local last = ServiceMenuStage[1]
		ServiceMenuStage[1] = ServiceMenuStage[1]+1
		ServiceTheDeviceOtr(ServiceMenuStage[1], last)

	elseif key == 15 then --tab
		GetBootPage(true)
	end
end

function BiosSetingsPage.FunctionStarter()
	local element = BiosSetingsPage.Element
	if element == 1 then


	elseif element == 2 then
		Bios.FormatData()

	elseif element == 3 then
		Debug.FormatData()

	elseif element == 4 then
		Debug.FormatBios()

	end
	BiosSetingsPage.Draw()
end

function BiosSetingsPage.KeyListener(key)
	if key==28 then
		BiosSetingsPage.FunctionStarter()
	elseif key == 200 and BiosSetingsPage.Element > 1 then
		local last = BiosSetingsPage.Element
		BiosSetingsPage.Element = BiosSetingsPage.Element-1
		BiosSetingsPage.OnChangeField(last)

	elseif key == 208 and BiosSetingsPage.Element < 4 then
		local last = BiosSetingsPage.Element
		BiosSetingsPage.Element = BiosSetingsPage.Element+1
		BiosSetingsPage.OnChangeField(last)
	end
end

local function keyListener()
	while true do
		local e,_,_,key = computer.pullSignal(0.5)
		if e=='key_up'then
			if key==203 and CurrentMenu ~= 'SystemInformation' then --4
				if CurrentMenu == 'BootAndRepair' then
					GetSystemInformationPage()
				elseif CurrentMenu == 'BiosSetings' then
					GetBootPage()
				end
			elseif key==205 and CurrentMenu ~= 'BiosSetings' then --6
				if CurrentMenu == 'SystemInformation' then
					GetBootPage()
				elseif CurrentMenu == 'BootAndRepair' then
					BiosSetingsPage.Draw()
				end
			elseif key==67 then --F9
				if CurrentMenu == 'BootAndRepair' or CurrentMenu == 'SystemInformation' or CurrentMenu == 'BiosSetings' then
					return
				end
			else
				if CurrentMenu == 'BootAndRepair' then
					BootAndRepairPageKeyListener(key)
				elseif CurrentMenu == 'ServiceTheDevice' then
					ServiceTheDevicePageKeyListener(key)
				elseif CurrentMenu == 'BiosSetings' then
					BiosSetingsPage.KeyListener(key)
				end
			end
		end
		if CurrentMenu == 'SystemInformation' then --обновление инфы каждый проход цикла (0.5сек)
			SystemInformationPageUpdate()
		end
	end
end

local function HiMenu() -- меню приветствия
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
	SetTextInTheMiddle(8,50,'No bootable device found!')

	while true do
		local e,_,_,k = computer.pullSignal(0.5)
		if e=='key_up' and k==88 then
			break
		end
		computer.beep()
	end
	got()
	GetSystemInformationPage()
	keyListener()
end
------------

POST()
HiMenu()
