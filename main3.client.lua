--[[
    WindUI Forked Modded Example 3
]]

local MarketplaceService = game:GetService("MarketplaceService")

local ok, productInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)

local gameName = ok and productInfo and productInfo.Name or "Unknown Game"

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/mizcanscripts/WindUI-Forked-Modded/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "WindUI Library Modded",
    ImageBlur = true,
    Author = "MZXHUB",
    Version = "WindUI Modded | v1.0.2",
    Icon = "rbxassetid://120466921396914",
    Background = "https://raw.githubusercontent.com/mizcanscripts/MZX/refs/heads/main/images/mzx_background4.png",
 	--NewElements = true,
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
 	--Transparent = true,
 	ToggleKey = Enum.KeyCode.F,
    --Acrylic = true,

    --[[
    KeySystem = {
	  	Title = "Key System",
	  	Description = "Enter the correct key to unlock the window",
  		KeyValidator = function(key)
		  	return key == "HelloWorld"
  		end,
    }
 	]]

    HubCard = {
        Logo = "rbxthumb://type=GameThumbnail&id=" .. tostring(game.PlaceId) .. "&w=768&h=432",
        Title = "MZXHUB ",
        Subtitle = "gameName",
        Enabled = true,
    },
})


Window:Tag({
    Title = "v1.0.2",
    Color = Color3.fromHex("#315dff"),
    LightSweep = true,
})

local InfoTab = Window:Tab({ Title = "Information", Icon = "info" })
local AutoTab = Window:Tab({ Title = "Automation", Icon = "recycle" })
local InventoryTab = Window:Tab({ Title = "Inventory", Icon = "backpack" })
local ShopTab = Window:Tab({ Title = "Shop", Icon = "store" })
local LocationTab = Window:Tab({ Title = "Location", Icon = "map-pin" })
local WebhookTab = Window:Tab({ Title = "Webhook", Icon = "webhook" })
local PerformanceTab = Window:Tab({ Title = "Performance", Icon = "chart-line" })

Window:SelectTab(1)

local InfoSection = InfoTab:Section({
    Title = "Information",
    Icon = "zap",
    Opened = false
})

InfoTab:Divider()

InfoTab:Paragraph({
	Title = "WindUI Forked Modded",
	Desc = "WindUI is a open source UI library for Roblox Script Hubs\n\nOriginal Author: @.ftgs\nModded Author: @theycallmemiz",
	Buttons = {
		{
			Title = "GitHub",
			Callback = function()
				print("GitHub Button Clicked")
			end,
		},
		{
			Title = "Documentation",
			Variant = "Secondary",
			Callback = function()
				print("Documentation Button Clicked")
			end,
		},
	},
})

local HStack1 = InfoTab:HStack()

local VStackLeft = HStack1:VStack()
local VStackRight = HStack1:VStack()

VStackLeft:Button({
	Title = "Reload UI",
	Justify = "Center",
	Icon = "refresh-ccw",
	IconAlign = "Left",
	Color = Color3.fromHex("#F44732"),
	Callback = function()
		print("Reloading UI...")
	end,
})

VStackRight:Button({
	Title = "Rejoin Place",
	Justify = "Center",
	Icon = "log-out",
	IconAlign = "Left",
	Color = Color3.fromHex("#ffffff"),
	Callback = function()
		print("Rejoining place...")
	end,
})

local Discord = InfoTab:Section({
    Title = "Discord Server",
    Icon = "server",
    Box = true,
    BoxBorder = true,
    Opened = true
})

Discord:Paragraph({
    Title = "MZXHUB Discord Server",
    Desc = "Join Our Discord Server About Updates & Spoilers And Even More!",
    Image = "rbxassetid://120466921396914",
    Color = Color3.fromRGB(0, 0, 0)
})

Discord:Button({
    Title = "Copy Discord Server Link",
    Icon = "zap",
    Callback = function()
        setclipboard("https://dsc.gg/MZXHUB")
    end
})

local Loader = InfoTab:Section({
    Title = "Loader",
    Box = true,
    BoxBorder = true,
    Opened = true
})

Loader:Code({
    Title = "Main Loader | Share This To Someone",
    Code = [[ loadstring(game:HttpGet("https://mzx-wtf.vercel.app/script/main.lua?token=mzx-sctknJ2hq72JGnsupsIbwL72&key=mzx-J0R6qBp2kYvzXmC936"))() ]]
})

InfoTab:Button({
    Title = "Current Version",
    Callback = function()
        WindUI:Notify({
            Title = "Version",
            Content = "v1.0.2",
            Duration = 3,
        })
    end,
}) 

InfoTab:Button({
    Title = ":3",
    Callback = function()
        WindUI:Notify({
            Title = "Helllloooo...",
            Content = ":3",
            Buttons = {
                {Title = "Update Now", Type = "Underline", Callback = function() end}, -- Underline Type Is Optional Only Default Is "Button"
                {Title = "Later", Type = "Underline", Callback = function() end, CloseOnClick = false},
            },
        })
    end,
})
