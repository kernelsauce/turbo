-----------------------------------------------------------------------------------
-- Yet Another Class Implementation
--
-- Julien Patte [julien.patte AT gmail DOT com] - 19 Jan 2006
--
-- Inspired from code written by Kevin Baca, Sam Lie, Christian Lindig and others
-----------------------------------------------------------------------------------

-- internal function 'newInstance'

local function newInstance(class, ...) 

 local function makeInstance(class)
  local inst = {}
  if class:super()~=nil then
   inst.super = makeInstance(class:super())
  else 
   inst.super = {}
  end 
  
  function inst:class() return class end
  setmetatable(inst, class.static)
  
  return inst
 end
 
 local inst = makeInstance(class) 
 inst:init(unpack(arg))
 return inst
end

-----------------------------------------------------------------------------------
-- internal function 'classMade'

local function classMade(class, obj) 
 if type(obj)~="table" or type(obj.class)~="function" then return false end
 local c = obj:class()
 if c==class then return true end
 if type(c)~="table" or type(c.inherits)~="function" then return false end
 return c:inherits(class) 
end

-----------------------------------------------------------------------------------
-- internal function 'subclass'

local function subclass(baseClass, name) 
 if type(name)~="string" then name = "Unnamed" end
 
 local b = baseClass.static
 
	-- need to copy everything here because events can't be found through metatables
 local c_istuff = { __tostring=b.__tostring, __eq=b.__eq, __add=b.__add, __sub=b.__sub, 
	__mul=b.__mul, __div=b.__div, __mod=b.__mod, __pow=b.__pow, __unm=b.__unm, 
	__len=b.__len, __lt=b.__lt, __le=b.__le, __concat=b.__concat, __call=b.__call}
 function c_istuff.init(inst,...) inst.super:init() end
 function c_istuff.__index(inst, key) return c_istuff[key] or inst.super[key] end

 local c_cstuff = {}
 function c_cstuff.name(class) return name end
 function c_cstuff.super(class) return baseClass end
 function c_cstuff.inherits(class, other) return (baseClass==other or baseClass:inherits(other)) end
 c_cstuff.static = c_istuff
 c_cstuff.made = classMade
 c_cstuff.new = newInstance
 c_cstuff.subclass = subclass

 local c = {}
 local function tos() return ("class "..name) end
 setmetatable(c, { __newindex = c_istuff, __index = c_cstuff, __tostring = tos, __call = newInstance } )
 
 return c
end

-----------------------------------------------------------------------------------
-- The 'Object' class

local function obj_newitem() error "May not modify the class 'Object'. Subclass it instead." end
local obj_istuff = {}
function obj_istuff.init(inst,...) end
obj_istuff.__index = obj_istuff
obj_istuff.__newindex = obj_newitem
function obj_istuff.__tostring(inst) return ("a "..inst:class():name()) end

local obj_cstuff = {}
local obj_cstuff = {}
function obj_cstuff.name(class) return "Object" end
function obj_cstuff.super(class) return nil end
function obj_cstuff.inherits(class, other) return false end
obj_cstuff.static = obj_istuff
obj_cstuff.made = classMade
obj_cstuff.new = newInstance
obj_cstuff.subclass = subclass

Object = {}
local function tos() return ("class Object") end
setmetatable(Object, { __newindex = obj_newitem, __index = obj_cstuff, __tostring = tos, __call = newInstance } )

----------------------------------------------------------------------
-- function 'newclass'

function newclass(name, baseClass)
 baseClass = baseClass or Object
 return baseClass:subclass(name)
end

-- end of code
