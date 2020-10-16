-- Copyright (c) 2020 Jurian Vierbergen, Some Rights Reserved
-- Subject to the MPL-2.0 License

local module = table.create(3,0)
module.__index = module

local Initialization = table.create(2,0)
local functionality = table.create(3,0)
local Storage = table.create(0,0)
local Calls = table.create(0,0)

local HttpService = game:GetService("HttpService")

-- 		[[ internal functions ]]
-- functionalitites related to instance based keys
function Generate(Variable)
	Storage[Variable] = HttpService:GenerateGUID(false)
	return Storage[Variable]
end

function GetDebugId(Variable)
	if Storage[Variable] then
		return Storage[Variable]
	end
end

-- metatable creation from template
function CreateMetaTable(self, _Call, _Value, TableName, Store)
	local meta = setmetatable({
		__META__Internal_Value = _Value,
		__META__TableName = rawget(self, "__META__TableName")
	}, functionality)
	
	return meta
end

-- first occuring index finding
function LoopTablesForIndex(Table, Index)
	local Value
	Index = tostring(Index)
	
	local function Loop(Table, Index)
		for i,v in pairs(Table) do
			local index = tostring(i)
			
			if typeof(i) == "Instance" then
				local InstanceDebugId = GetDebugId(i)
				if not InstanceDebugId then
					index = Generate(i)
				else
					index = InstanceDebugId
				end
			end
			
			if index:sub(1,8) == "__META__" then index = index:sub(9, #i) end
			
			if index == Index then 
				Value = v
				return
			elseif index ~= Index and typeof(v) == "table" then
				Loop(v, Index)
			end
		end
	end
	
	Loop(Table, Index)
	
	return Value
end

-- new indexation from the outside
function ExternalLoopAndSet(Table, Index, Value)
	for i,v in pairs(Table) do
		if i == Index then
			rawset(Table, i, Value)
			return
		elseif i ~= Index and typeof(v) == "table" then
			ExternalLoopAndSet(Table[i], Index, Value)
		end
	end
end

function MetaMethodCheck(self, Name)
	local Meta = getmetatable(self)
	if Meta[Name] then
		return function()
			return Meta[Name](self)
		end
	end
end

-- Methods of the first occuring metatable (retrieved from .new(), they require some specific structured indexation)
function Initialization.__index(self, index)
	return functionality.__index(self, index)
end

function Initialization.__newindex(self, index, value)
	return ExternalLoopAndSet(self, index, value)
end

function Initialization.GetRaw(self)
	return self["__META__Internal_Value"] 
end

function Initialization.Dispose(self)
	if Calls[self.__META__TableName] then
		Calls[self.__META__TableName] = nil
	end
	
	for i,v in pairs(self) do
		self[i] = nil
	end
	
	setmetatable(self, nil)
	self = nil
	return nil
end

-- Metamethods of all the other tables other than the one returned by .new(), Preventing :Dispose() usage.
function functionality.__index(self, index)
	
	local M_ReturnValue = MetaMethodCheck(self, index)
	if M_ReturnValue then
		return M_ReturnValue
	end
	
	if typeof(index) == "Instance" then
		local InstanceDebugId = GetDebugId(index)
		index = (InstanceDebugId == nil) and Generate(index) or InstanceDebugId
	end
	
	local Value = LoopTablesForIndex(rawget(self, "__META__Internal_Value") or self, index)
	if Value then
		local LoadedTable = (rawget(self, "__META__Shared")) and rawget(Calls[rawget(self, "__META__TableName")], index) or nil
		if LoadedTable then return LoadedTable end
		
		if typeof(Value) == "table" then
			return CreateMetaTable(self, index, Value, rawget(self, "__META__TableName"), false)
		else
			return Value
		end
	end
end

function functionality.__newindex(self, index, value)
	ExternalLoopAndSet(self, index, value)
end

function functionality.GetRaw(self)
	return self["__META__Internal_Value"] 
end

-- public functionalities from require
function module.new(Target, Shared, TargetName)
	Shared = (Shared == nil or Shared == false) and false or (Shared == true) and true
	TargetName = (TargetName == nil) and HttpService:GenerateGUID(false) or TargetName

	local PsuedoTable = table.create(0, 0)
	PsuedoTable["__META__Internal_Value"] = Target
	for i,v in pairs(Target) do
		local index = i
		if typeof(i) == "Instance" then
			index = Generate(i)
		end
		PsuedoTable["__META__" .. index] = v
	end

	PsuedoTable.__META__TableName = TargetName
	PsuedoTable.__META__Shared = Shared

	local Meta = setmetatable(PsuedoTable, Initialization)
	if Shared then
		Calls[TargetName] = table.create(0,0)
		Calls[TargetName]["__METAINIT__"] = Meta
	end

	return Meta
end

function module.GetTable(Name)
	if Name and Calls[Name] then
		return Calls[Name].__METAINIT__
	elseif not Name then
		return Calls
	end
end

return module
