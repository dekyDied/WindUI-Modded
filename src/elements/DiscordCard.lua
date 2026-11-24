local Creator = require("../modules/Creator")
local New = Creator.New
local NewRoundFrame = Creator.NewRoundFrame
local Tween = Creator.Tween

local TagModule = require("../components/ui/Tag")

local HttpService = game:GetService("HttpService")

local SetClipboard = setclipboard or toclipboard or set_clipboard

local Element = {}

local DEFAULT_ACCENT = Color3.fromRGB(88, 101, 242) -- Discord blurple
local ONLINE_GREEN = Color3.fromRGB(35, 165, 90)
local ONLINE_HEX = "#23A55A"
local MEMBERS_HEX = "#80848E"

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

-- "Rounded" (default), "Circle" or "Square"
local function ParseIconShape(shape)
	shape = string.lower(tostring(shape or "Rounded"))
	if shape == "circle" then
		return "Circle"
	elseif shape == "square" then
		return "Square"
	end
	return "Rounded"
end

-- Cuts long texts without breaking multi-byte characters.
local function Truncate(text, maxChars)
	local length = utf8.len(text)
	if length and length > maxChars then
		return text:sub(1, utf8.offset(text, maxChars) - 1) .. "..."
	end
	return text
end

local function HasFeature(guild, feature)
	if typeof(guild.features) ~= "table" then
		return false
	end
	return table.find(guild.features, feature) ~= nil
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
		AccentColor = typeof(Config.AccentColor) == "Color3" and Config.AccentColor or DEFAULT_ACCENT,
		ShowBanner = Config.ShowBanner ~= false,
		ShowBadges = Config.ShowBadges ~= false,
		ShowDescription = Config.ShowDescription ~= false,
		ShowCopyButton = Config.ShowCopyButton ~= false,
		BannerHeight = Config.BannerHeight or 130,
		IconSize = Config.IconSize or 48,
		IconShape = ParseIconShape(Config.IconShape),
		Callback = Config.Callback or function() end,
		Data = nil,
		UIElements = {},
	}

	local AccentColor = DiscordCard.AccentColor
	local AccentHover = AccentColor:Lerp(Color3.new(0, 0, 0), 0.2)

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
	})

	DiscordCard.DiscordCardFrame = Frame

	-- The counters use colored dots, so the description label needs rich text.
	-- (A custom Desc from the user stays plain text.)
	if not Config.Desc then
		Frame.UIElements.Desc.RichText = true
	end

	-- Row layout: [icon] [title + badges + desc] [copy link] [join]
	local Padding = Config.Window.ElementConfig.UIPadding
	local TitleRow = Frame.UIElements.Container.TitleFrame
	local TextFrame = TitleRow.TitleFrame

	local IconSize = DiscordCard.IconSize
	local ButtonWidth = math.max(72, #DiscordCard.ButtonText * 9 + 40)
	local CopyWidth = DiscordCard.ShowCopyButton and 34 or 0
	local IsCircle = DiscordCard.IconShape == "Circle"
	local IconCorner = IsCircle and 999 or DiscordCard.IconShape == "Square" and 0 or math.floor(IconSize * 0.25)
	local ItemCount = DiscordCard.ShowCopyButton and 4 or 3

	-- ICON (+ online dot) -------------------------------------------------
	local IconHolder = New("Frame", {
		Name = "IconHolder",
		Size = UDim2.new(0, IconSize, 0, IconSize),
		BackgroundColor3 = AccentColor,
		BackgroundTransparency = 0.85,
		LayoutOrder = -99,
		Parent = TitleRow,
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(0, IconCorner),
		}),
	})

	local OnlineDot = New("Frame", {
		Name = "OnlineDot",
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(IsCircle and 0.86 or 0.94, 0, IsCircle and 0.86 or 0.94, 0),
		BackgroundColor3 = ONLINE_GREEN,
		Visible = false,
		ZIndex = 5,
		Parent = IconHolder,
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		New("UIStroke", {
			Thickness = 2.5,
			Color = Color3.fromRGB(24, 24, 28),
		}),
	})

	-- Skeleton effect: the icon placeholder breathes until the data arrives.
	local LoadingPulse = Tween(
		IconHolder,
		0.8,
		{ BackgroundTransparency = 0.6 },
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)
	LoadingPulse:Play()

	local function StopLoading()
		LoadingPulse:Cancel()
		IconHolder.BackgroundTransparency = 0.85
	end

	-- The text takes whatever space is left between the icon and the buttons.
	TextFrame.Size = UDim2.new(1, -(IconSize + ButtonWidth + CopyWidth + Padding * (ItemCount - 1)), 1, 0)

	-- Extra line with the server description (dimmer than the counters).
	local DescriptionLabel = New("TextLabel", {
		Name = "ServerDescription",
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 14,
		TextXAlignment = "Left",
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = "Y",
		LayoutOrder = 10,
		Visible = false,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		ThemeTag = {
			TextColor3 = "ElementDesc",
		},
		TextTransparency = 0.5,
		Parent = TextFrame,
	})

	-- JOIN BUTTON ---------------------------------------------------------
	local JoinFill = NewRoundFrame(10, "Squircle", {
		Name = "Fill",
		ImageColor3 = AccentColor,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local JoinLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = DiscordCard.ButtonText,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
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
		JoinLabel,
	})

	Creator.AddSignal(JoinButton.MouseEnter, function()
		Tween(JoinFill, 0.1, { ImageColor3 = AccentHover }):Play()
	end)
	Creator.AddSignal(JoinButton.MouseLeave, function()
		Tween(JoinFill, 0.1, { ImageColor3 = AccentColor }):Play()
	end)

	-- Short feedback on the button after a click ("Copied!" / "Opened!").
	local FlashId = 0
	local function Flash(text)
		FlashId = FlashId + 1
		local myId = FlashId

		JoinLabel.Text = text
		Tween(JoinFill, 0.15, { ImageColor3 = ONLINE_GREEN }):Play()

		task.delay(2, function()
			if myId ~= FlashId then
				return
			end
			JoinLabel.Text = DiscordCard.ButtonText
			Tween(JoinFill, 0.15, { ImageColor3 = AccentColor }):Play()
		end)
	end

	local function Notify(message)
		pcall(function()
			Config.WindUI:Notify({
				Title = DiscordCard.Title,
				Content = message,
				Duration = 4,
				Icon = "link",
			})
		end)
	end

	-- COPY LINK BUTTON ----------------------------------------------------
	local CopyButton
	if DiscordCard.ShowCopyButton then
		local CopyIcon = Creator.Image("link", "link", 0, Config.Window.Folder, "Button", true)
		CopyIcon.Size = UDim2.new(0, 18, 0, 18)
		CopyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		CopyIcon.Position = UDim2.new(0.5, 0, 0.5, 0)

		local CopyFill = NewRoundFrame(10, "Squircle", {
			Name = "Fill",
			ThemeTag = {
				ImageColor3 = "Text",
			},
			ImageTransparency = 0.92,
			Size = UDim2.new(1, 0, 1, 0),
		})

		CopyButton = New("TextButton", {
			Name = "CopyButton",
			Size = UDim2.new(0, CopyWidth, 0, 34),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 98,
			Parent = TitleRow,
		}, {
			CopyFill,
			CopyIcon,
		})

		Creator.AddSignal(CopyButton.MouseEnter, function()
			Tween(CopyFill, 0.1, { ImageTransparency = 0.85 }):Play()
		end)
		Creator.AddSignal(CopyButton.MouseLeave, function()
			Tween(CopyFill, 0.1, { ImageTransparency = 0.92 }):Play()
		end)
		Creator.AddSignal(CopyButton.MouseButton1Click, function()
			DiscordCard:CopyLink()
		end)
	end

	DiscordCard.UIElements.IconHolder = IconHolder
	DiscordCard.UIElements.OnlineDot = OnlineDot
	DiscordCard.UIElements.JoinButton = JoinButton
	DiscordCard.UIElements.CopyButton = CopyButton

	-- ACTIONS -------------------------------------------------------------
	function DiscordCard:CopyLink()
		if not DiscordCard.Code then
			return false
		end

		local link = "https://discord.gg/" .. DiscordCard.Code
		if SetClipboard then
			pcall(SetClipboard, link)
			Notify("Invite link copied to your clipboard.")
		else
			Notify(link)
		end

		return true
	end

	-- Join: try the Discord app first, otherwise copy the invite link.
	function DiscordCard:Join()
		if not DiscordCard.Code then
			return false
		end

		task.spawn(function()
			local openedApp = OpenInDiscordApp(DiscordCard.Code)

			if openedApp then
				Flash("Opened!")
				Notify("Check your Discord app to accept the invite.")
			else
				Flash(SetClipboard and "Copied!" or "Link sent")
				DiscordCard:CopyLink()
			end

			Creator.SafeCallback(DiscordCard.Callback, DiscordCard.Data, openedApp)
		end)

		return true
	end

	Creator.AddSignal(JoinButton.MouseButton1Click, function()
		DiscordCard:Join()
	end)

	-- DATA ----------------------------------------------------------------
	local BuiltStaticParts = false

	local function ApplyData(data)
		local guild = data.guild
		DiscordCard.Data = data

		StopLoading()

		if not Config.Title then
			DiscordCard.Title = guild.name
			Frame:SetTitle(guild.name)
		end

		-- Counters (updated on every refresh)
		local online = tonumber(data.approximate_presence_count)
		local members = tonumber(data.approximate_member_count)

		if not Config.Desc then
			local parts = {}

			if online then
				table.insert(
					parts,
					('<font color="%s">●</font> %s online'):format(ONLINE_HEX, FormatNumber(online))
				)
			end
			if members then
				table.insert(
					parts,
					('<font color="%s">●</font> %s members'):format(MEMBERS_HEX, FormatNumber(members))
				)
			end

			if #parts > 0 then
				Frame:SetDesc(table.concat(parts, "   "))
			end
		end

		OnlineDot.Visible = online ~= nil and online > 0

		if BuiltStaticParts then
			return
		end
		BuiltStaticParts = true

		-- Server description
		if DiscordCard.ShowDescription and typeof(guild.description) == "string" and guild.description ~= "" then
			DescriptionLabel.Text = Truncate((guild.description:gsub("%s+", " ")), 110)
			DescriptionLabel.Visible = true
		end

		-- Badges
		if DiscordCard.ShowBadges then
			local TagsFrame = TextFrame.ScrollingFrame
			local function AddBadge(title, color)
				TagsFrame.Visible = true
				TextFrame.Space.Visible = true
				TagModule:New({ Title = title, Color = color }, TagsFrame)
			end

			if HasFeature(guild, "VERIFIED") then
				AddBadge("Verified", AccentColor)
			end
			if HasFeature(guild, "PARTNERED") then
				AddBadge("Partnered", AccentColor)
			end
			if HasFeature(guild, "COMMUNITY") then
				AddBadge("Community", Color3.fromRGB(64, 66, 73))
			end

			local boosts = tonumber(guild.premium_subscription_count)
			if boosts and boosts > 0 then
				AddBadge(FormatNumber(boosts) .. " Boosts", Color3.fromRGB(244, 127, 255))
			end
		end

		-- Icon
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

		-- Banner: full-bleed at the top of the card, fading into the card background
		if DiscordCard.ShowBanner then
			local bannerUrl
			if guild.banner then
				bannerUrl = ("https://cdn.discordapp.com/banners/%s/%s.png?size=600"):format(guild.id, guild.banner)
			elseif guild.splash then
				bannerUrl = ("https://cdn.discordapp.com/splashes/%s/%s.png?size=600"):format(guild.id, guild.splash)
			end

			if bannerUrl then
				local Height = DiscordCard.BannerHeight

				-- Empty space in the layout, so the row starts below the banner.
				local BannerSpace = New("Frame", {
					Name = "BannerSpace",
					Size = UDim2.new(1, 0, 0, math.max(0, Height - Padding)),
					BackgroundTransparency = 1,
					LayoutOrder = -1,
					Parent = Frame.UIElements.Container,
				})

				local Banner = Creator.Image(
					bannerUrl,
					"discord-banner-" .. tostring(guild.id),
					Config.Window.ElementConfig.UICorner,
					Config.Window.Folder,
					"Banner",
					false
				)
				-- The card has inner padding; this cancels it so the banner touches the edges.
				Banner.Position = UDim2.new(0, -Padding, 0, -Padding)
				Banner.Size = UDim2.new(1, Padding * 2, 0, Height)
				Banner.Parent = Frame.UIElements.Main

				if Banner:FindFirstChild("ImageLabel") then
					New("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.5, 0.1),
							NumberSequenceKeypoint.new(0.8, 0.7),
							NumberSequenceKeypoint.new(1, 1),
						}),
						Parent = Banner.ImageLabel,
					})
				end

				-- If the image fails to download, Creator.Image destroys the frame:
				-- give the reserved space back.
				Creator.AddSignal(Banner.Destroying, function()
					BannerSpace:Destroy()
				end)

				DiscordCard.UIElements.Banner = Banner
			end
		end
	end

	function DiscordCard:Refresh()
		task.spawn(function()
			if not DiscordCard.Code then
				StopLoading()
				if not Config.Desc then
					Frame:SetDesc("Invalid invite link.")
				end
				return
			end

			local data, reason = FetchInvite(DiscordCard.Code)
			if data then
				ApplyData(data)
			else
				StopLoading()
				if not Config.Desc and not DiscordCard.Data then
					Frame:SetDesc(reason)
				end
			end
		end)
	end

	function DiscordCard:GetData()
		return DiscordCard.Data
	end

	DiscordCard:Refresh()

	-- Optional live counters: RefreshInterval = 60 (seconds, minimum 30).
	if tonumber(Config.RefreshInterval) then
		task.spawn(function()
			local interval = math.max(30, tonumber(Config.RefreshInterval))
			local Main = Frame.UIElements.Main

			while Main.Parent do
				task.wait(interval)
				if Main.Parent then
					DiscordCard:Refresh()
				end
			end
		end)
	end

	return DiscordCard.__type, DiscordCard
end

return Element
