local Creator = require("../modules/Creator")
local New = Creator.New
local NewRoundFrame = Creator.NewRoundFrame
local Tween = Creator.Tween

local HttpService = game:GetService("HttpService")

local SetClipboard = setclipboard or toclipboard or set_clipboard

local Element = {}

local BLURPLE = Color3.fromRGB(88, 101, 242)
local BLURPLE_HOVER = Color3.fromRGB(71, 82, 196)

-- Accepts a bare code ("abc123"), "discord.gg/abc123", "dsc.gg/abc123"
-- or "https://discord.com/invite/abc123" and returns just the code.
local function ParseInviteCode(invite)
	if typeof(invite) ~= "string" then
		return nil
	end

	invite = invite:gsub("%s+", "")

	return invite:match("discord%.gg/([%w%-_]+)")
		or invite:match("discord%.com/invite/([%w%-_]+)")
		or invite:match("discordapp%.com/invite/([%w%-_]+)")
		or invite:match("dsc%.gg/([%w%-_]+)")
		or invite:match("^([%w%-_]+)$")
end

-- 12345 -> "12,345"
local function FormatNumber(number)
	local text = tostring(math.floor(tonumber(number) or 0))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Asks the public Discord API about the invite (name, icon, banner, member counts).
local function FetchInvite(code)
	if not Creator.Request then
		return nil, "Your executor does not support HTTP requests."
	end

	local requestOk, response = pcall(Creator.Request, {
		Url = "https://discord.com/api/v10/invites/" .. code .. "?with_counts=true",
		Method = "GET",
	})

	if not requestOk or typeof(response) ~= "table" or not response.Body then
		return nil, "Could not reach Discord."
	end

	if response.StatusCode and response.StatusCode ~= 200 then
		return nil, "Invite invalid or expired."
	end

	local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if not decodeOk or typeof(data) ~= "table" or typeof(data.guild) ~= "table" then
		return nil, "Could not read the server info."
	end

	return data
end

-- If the Discord desktop app is open, this makes it show the "Join server" prompt.
-- Returns true when the app accepted the request.
local function OpenInDiscordApp(code)
	if not Creator.Request then
		return false
	end

	local requestOk, response = pcall(Creator.Request, {
		Url = "http://127.0.0.1:6463/rpc?v=1",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Origin"] = "https://discord.com",
		},
		Body = HttpService:JSONEncode({
			cmd = "INVITE_BROWSER",
			args = { code = code },
			nonce = HttpService:GenerateGUID(false),
		}),
	})

	return requestOk and typeof(response) == "table" and (response.Success == true or response.StatusCode == 200)
end

function Element:New(Config)
	local DiscordCard = {
		__type = "DiscordCard",
		Invite = Config.Invite,
		Code = ParseInviteCode(Config.Invite),
		Title = Config.Title or "Discord Server",
		Desc = Config.Desc or "Loading server info...",
		ButtonText = Config.ButtonText or "Join",
		ShowBanner = Config.ShowBanner ~= false,
		BannerHeight = Config.BannerHeight or 100,
		IconSize = Config.IconSize or 44,
		IconRounded = Config.IconRounded ~= false,
		Callback = Config.Callback or function() end,
		Data = nil,
		UIElements = {},
	}

	local Frame = require("../components/window/Element")({
		Title = DiscordCard.Title,
		Desc = DiscordCard.Desc,
		Parent = Config.Parent,
		Window = Config.Window,
		Hover = false,
		TextOffset = 0,
		Justify = "Between",
		Tab = Config.Tab,
		Index = Config.Index,
		ElementTable = DiscordCard,
		ParentConfig = Config,
		Size = Config.Size,
		Tags = Config.Tags,
		ThumbnailSize = DiscordCard.BannerHeight,
	})

	DiscordCard.DiscordCardFrame = Frame

	-- Row layout: [icon] [title + desc] [join button]
	local Padding = Config.Window.ElementConfig.UIPadding
	local TitleRow = Frame.UIElements.Container.TitleFrame
	local TextFrame = TitleRow.TitleFrame

	local IconSize = DiscordCard.IconSize
	local ButtonWidth = math.max(72, #DiscordCard.ButtonText * 9 + 40)
	local IconCorner = DiscordCard.IconRounded and 999 or 10

	local IconHolder = New("Frame", {
		Name = "IconHolder",
		Size = UDim2.new(0, IconSize, 0, IconSize),
		BackgroundColor3 = BLURPLE,
		BackgroundTransparency = 0.85,
		LayoutOrder = -99,
		Parent = TitleRow,
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(0, IconCorner),
		}),
	})

	-- The text takes whatever space is left between the icon and the button.
	TextFrame.Size = UDim2.new(1, -(IconSize + ButtonWidth + Padding * 2), 1, 0)

	local JoinFill = NewRoundFrame(10, "Squircle", {
		Name = "Fill",
		ImageColor3 = BLURPLE,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local JoinButton = New("TextButton", {
		Name = "JoinButton",
		Size = UDim2.new(0, ButtonWidth, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 99,
		Parent = TitleRow,
	}, {
		JoinFill,
		New("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = DiscordCard.ButtonText,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 16,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		}),
	})

	DiscordCard.UIElements.IconHolder = IconHolder
	DiscordCard.UIElements.JoinButton = JoinButton

	Creator.AddSignal(JoinButton.MouseEnter, function()
		Tween(JoinFill, 0.1, { ImageColor3 = BLURPLE_HOVER }):Play()
	end)
	Creator.AddSignal(JoinButton.MouseLeave, function()
		Tween(JoinFill, 0.1, { ImageColor3 = BLURPLE }):Play()
	end)

	-- Join: try the Discord app first, otherwise copy the invite link.
	function DiscordCard:Join()
		if not DiscordCard.Code then
			return false
		end

		task.spawn(function()
			local link = "https://discord.gg/" .. DiscordCard.Code
			local openedApp = OpenInDiscordApp(DiscordCard.Code)
			local message

			if openedApp then
				message = "Check your Discord app to accept the invite."
			elseif SetClipboard then
				pcall(SetClipboard, link)
				message = "Invite link copied to your clipboard."
			else
				message = link
			end

			pcall(function()
				Config.WindUI:Notify({
					Title = DiscordCard.Title,
					Content = message,
					Duration = 4,
					Icon = "link",
				})
			end)

			Creator.SafeCallback(DiscordCard.Callback, DiscordCard.Data, openedApp)
		end)

		return true
	end

	Creator.AddSignal(JoinButton.MouseButton1Click, function()
		DiscordCard:Join()
	end)

	local function ApplyData(data)
		local guild = data.guild
		DiscordCard.Data = data

		if not Config.Title then
			DiscordCard.Title = guild.name
			Frame:SetTitle(guild.name)
		end

		if not Config.Desc then
			local parts = {}
			local online = tonumber(data.approximate_presence_count)
			local members = tonumber(data.approximate_member_count)

			if online then
				table.insert(parts, FormatNumber(online) .. " online")
			end
			if members then
				table.insert(parts, FormatNumber(members) .. " members")
			end

			Frame:SetDesc(#parts > 0 and table.concat(parts, "  •  ") or guild.description)
		end

		if guild.icon then
			local IconImage = Creator.Image(
				("https://cdn.discordapp.com/icons/%s/%s.png?size=128"):format(guild.id, guild.icon),
				"discord-icon-" .. tostring(guild.id),
				IconCorner,
				Config.Window.Folder,
				"Image",
				false
			)
			IconImage.Size = UDim2.new(1, 0, 1, 0)
			IconImage.Parent = IconHolder
		end

		if DiscordCard.ShowBanner then
			local bannerUrl
			if guild.banner then
				bannerUrl = ("https://cdn.discordapp.com/banners/%s/%s.png?size=600"):format(guild.id, guild.banner)
			elseif guild.splash then
				bannerUrl = ("https://cdn.discordapp.com/splashes/%s/%s.png?size=600"):format(guild.id, guild.splash)
			end

			if bannerUrl then
				Frame:SetThumbnail(bannerUrl, DiscordCard.BannerHeight)
			end
		end
	end

	function DiscordCard:Refresh()
		task.spawn(function()
			if not DiscordCard.Code then
				if not Config.Desc then
					Frame:SetDesc("Invalid invite link.")
				end
				return
			end

			local data, reason = FetchInvite(DiscordCard.Code)
			if data then
				ApplyData(data)
			elseif not Config.Desc then
				Frame:SetDesc(reason)
			end
		end)
	end

	function DiscordCard:GetData()
		return DiscordCard.Data
	end

	DiscordCard:Refresh()

	return DiscordCard.__type, DiscordCard
end

return Element
