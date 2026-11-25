local Creator = require("../modules/Creator")
local New = Creator.New
local NewRoundFrame = Creator.NewRoundFrame
local Tween = Creator.Tween

local TagModule = require("../components/ui/Tag")

local HttpService = game:GetService("HttpService")

local SetClipboard = setclipboard or toclipboard or set_clipboard

local Element = {}

-- Discord palette
local BLURPLE = Color3.fromRGB(88, 101, 242)
local DISCORD_GREEN = Color3.fromRGB(36, 128, 70) -- primary (Join) button
local ONLINE_GREEN = Color3.fromRGB(35, 165, 90)
local SECONDARY_GRAY = Color3.fromRGB(78, 80, 88) -- secondary (copy) button
local SECONDARY_GRAY_HOVER = Color3.fromRGB(107, 109, 118)
local ONLINE_HEX = "#23A55A"
local MEMBERS_HEX = "#80848E"

local DEFAULT_BUTTON_ICON = "rbxassetid://123235027784147"
local BUTTON_HEIGHT = 34

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

-- "auto" (default), "profile", "banner", "splash" or "icon"
local function ParseBannerSource(source)
	source = string.lower(tostring(source or "auto"))
	if source == "profile" or source == "banner" or source == "splash" or source == "icon" then
		return source
	end
	return "auto"
end

local function ParseHexColor(hex)
	if typeof(hex) ~= "string" then
		return nil
	end
	local ok, color = pcall(Color3.fromHex, hex)
	return ok and color or nil
end

-- 12345 -> "12,345"
local function FormatNumber(number)
	local text = tostring(math.floor(tonumber(number) or 0))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
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

-- Asks the public Discord API about the invite (name, icon, banner, member counts, profile).
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

-- Downloads a PNG from the Discord CDN and returns a rbxasset:// path for it.
-- Returns nil when the image does not exist (404) or the executor can't load files.
local function LoadRemoteImage(url, folder, name)
	if not (Creator.Request and writefile and getcustomasset) then
		return nil
	end

	local requestOk, response = pcall(Creator.Request, { Url = url, Method = "GET" })
	if not requestOk or typeof(response) ~= "table" or typeof(response.Body) ~= "string" then
		return nil
	end
	if response.StatusCode and response.StatusCode ~= 200 then
		return nil
	end
	-- A real PNG starts with "\137PNG"; anything else is an error page.
	if response.Body:sub(2, 4) ~= "PNG" then
		return nil
	end

	local directory = "WindUI/" .. tostring(folder) .. "/assets"
	if makefolder and isfolder and not isfolder(directory) then
		pcall(makefolder, directory)
	end

	local path = directory .. "/.DiscordCard-" .. name:gsub("[^%w%-_]", "_") .. ".png"
	if not pcall(writefile, path, response.Body) then
		return nil
	end

	local assetOk, asset = pcall(getcustomasset, path)
	return assetOk and asset or nil
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
		ButtonIcon = Config.ButtonIcon == nil and DEFAULT_BUTTON_ICON or Config.ButtonIcon, -- false = no icon
		AccentColor = typeof(Config.AccentColor) == "Color3" and Config.AccentColor or DISCORD_GREEN,
		ShowBanner = Config.ShowBanner ~= false,
		BannerSource = ParseBannerSource(Config.BannerSource),
		ShowBadges = Config.ShowBadges ~= false,
		ShowDescription = Config.ShowDescription ~= false,
		ShowCopyButton = Config.ShowCopyButton ~= false,
		BannerHeight = Config.BannerHeight or 90,
		IconSize = Config.IconSize or 64,
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

	-- Layout: the info row ([icon] [text]) and, below it, a full-width buttons row.
	local Padding = Config.Window.ElementConfig.UIPadding
	local Main = Frame.UIElements.Main
	local Container = Frame.UIElements.Container
	local TitleRow = Container.TitleFrame
	local TextFrame = TitleRow.TitleFrame

	local IconSize = DiscordCard.IconSize
	local CopyWidth = DiscordCard.ShowCopyButton and BUTTON_HEIGHT or 0
	local IsCircle = DiscordCard.IconShape == "Circle"
	local IconCorner = IsCircle and 999 or DiscordCard.IconShape == "Square" and 0 or math.floor(IconSize * 0.25)

	-- ICON (+ online dot) -------------------------------------------------
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

	local OnlineDot = New("Frame", {
		Name = "OnlineDot",
		Size = UDim2.new(0, 16, 0, 16),
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

	-- The text takes whatever space is left next to the icon.
	TextFrame.Size = UDim2.new(1, -(IconSize + Padding), 1, 0)

	-- Dimmer info line under the counters (the server description).
	local function CreateInfoLabel(name, order)
		return New("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Text = "",
			TextSize = 14,
			TextXAlignment = "Left",
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			LayoutOrder = order,
			Visible = false,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			ThemeTag = {
				TextColor3 = "ElementDesc",
			},
			TextTransparency = 0.5,
			Parent = TextFrame,
		})
	end

	local DescriptionLabel = CreateInfoLabel("ServerDescription", 10)

	-- BUTTONS ROW (full width, Discord style) ------------------------------
	local ButtonsRow = New("Frame", {
		Name = "ButtonsRow",
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = 50,
		Parent = Container,
	}, {
		New("UIListLayout", {
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 8),
		}),
	})

	-- Join button: green, with the icon + label centered.
	local JoinFill = NewRoundFrame(8, "Squircle", {
		Name = "Fill",
		ImageColor3 = AccentColor,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local JoinIcon
	if DiscordCard.ButtonIcon then
		JoinIcon = New("ImageLabel", {
			Name = "JoinIcon",
			Size = UDim2.new(0, 20, 0, 20),
			BackgroundTransparency = 1,
			Image = DiscordCard.ButtonIcon,
			ImageColor3 = Color3.new(1, 1, 1),
			LayoutOrder = 1,
		})
	end

	local JoinLabel = New("TextLabel", {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = "XY",
		BackgroundTransparency = 1,
		Text = DiscordCard.ButtonText,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16,
		LayoutOrder = 2,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
	})

	local JoinButton = New("TextButton", {
		Name = "JoinButton",
		Size = UDim2.new(1, -(CopyWidth + (DiscordCard.ShowCopyButton and 8 or 0)), 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		Parent = ButtonsRow,
	}, {
		JoinFill,
		New("Frame", {
			Name = "Content",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			New("UIListLayout", {
				FillDirection = "Horizontal",
				HorizontalAlignment = "Center",
				VerticalAlignment = "Center",
				SortOrder = "LayoutOrder",
				Padding = UDim.new(0, 8),
			}),
			JoinIcon,
			JoinLabel,
		}),
	})

	Creator.AddSignal(JoinButton.MouseEnter, function()
		Tween(JoinFill, 0.1, { ImageColor3 = AccentHover }):Play()
	end)
	Creator.AddSignal(JoinButton.MouseLeave, function()
		Tween(JoinFill, 0.1, { ImageColor3 = AccentColor }):Play()
	end)

	-- If the icon asset can't be loaded (wrong id, a Decal id or a private asset),
	-- swap it for a built-in icon so the button never ends up with an empty gap.
	if JoinIcon then
		task.spawn(function()
			local waited = 0
			while JoinIcon.Parent and not JoinIcon.IsLoaded and waited < 5 do
				task.wait(0.25)
				waited = waited + 0.25
			end

			if JoinIcon.Parent and not JoinIcon.IsLoaded then
				local Fallback = Creator.Image("log-in", "log-in", 0, Config.Window.Folder, "Button", false)
				Fallback.Size = UDim2.new(0, 20, 0, 20)
				Fallback.LayoutOrder = 1
				Fallback.Parent = JoinIcon.Parent
				JoinIcon:Destroy()
			end
		end)
	end

	-- Short feedback on the button after a click ("Copied!" / "Opened!").
	local FlashId = 0
	local function Flash(text)
		FlashId = FlashId + 1
		local myId = FlashId

		JoinLabel.Text = text
		Tween(JoinFill, 0.15, { ImageColor3 = BLURPLE }):Play()

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

	-- Copy link button: gray (Discord's secondary button), square.
	local CopyButton
	if DiscordCard.ShowCopyButton then
		local CopyIcon = Creator.Image("link", "link", 0, Config.Window.Folder, "Button", true)
		CopyIcon.Size = UDim2.new(0, 18, 0, 18)
		CopyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		CopyIcon.Position = UDim2.new(0.5, 0, 0.5, 0)

		local CopyFill = NewRoundFrame(8, "Squircle", {
			Name = "Fill",
			ImageColor3 = SECONDARY_GRAY,
			Size = UDim2.new(1, 0, 1, 0),
		})

		CopyButton = New("TextButton", {
			Name = "CopyButton",
			Size = UDim2.new(0, CopyWidth, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 2,
			Parent = ButtonsRow,
		}, {
			CopyFill,
			CopyIcon,
		})

		Creator.AddSignal(CopyButton.MouseEnter, function()
			Tween(CopyFill, 0.1, { ImageColor3 = SECONDARY_GRAY_HOVER }):Play()
		end)
		Creator.AddSignal(CopyButton.MouseLeave, function()
			Tween(CopyFill, 0.1, { ImageColor3 = SECONDARY_GRAY }):Play()
		end)
		Creator.AddSignal(CopyButton.MouseButton1Click, function()
			DiscordCard:CopyLink()
		end)
	end

	DiscordCard.UIElements.IconHolder = IconHolder
	DiscordCard.UIElements.OnlineDot = OnlineDot
	DiscordCard.UIElements.ButtonsRow = ButtonsRow
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

	-- IMAGES (the server's real icon and banner) ------------------------------
	local function BuildIcon(guild)
		if not guild.icon then
			return
		end

		local asset = LoadRemoteImage(
			("https://cdn.discordapp.com/icons/%s/%s.png?size=256"):format(guild.id, guild.icon),
			Config.Window.Folder,
			"icon-" .. tostring(guild.icon)
		)

		if asset and IconHolder.Parent then
			New("ImageLabel", {
				Name = "Icon",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Image = asset,
				ScaleType = "Crop",
				Parent = IconHolder,
			}, {
				New("UICorner", {
					CornerRadius = UDim.new(0, IconCorner),
				}),
			})
		end
	end

	-- Banner: full-bleed at the top of the card, fading into the card background.
	-- Source order in "auto": profile banner -> invite splash -> server banner ->
	-- (no image) the server's brand color.
	local function BuildBanner(guild, profile)
		if not DiscordCard.ShowBanner then
			return
		end

		local id = tostring(guild.id)
		local candidates = {}

		local function AddBanner(hash)
			if typeof(hash) == "string" then
				table.insert(candidates, {
					url = ("https://cdn.discordapp.com/banners/%s/%s.png?size=600"):format(id, hash),
					name = "banner-" .. hash,
				})
			end
		end
		local function AddProfile()
			AddBanner(profile.custom_banner_hash)
			AddBanner(profile.banner_hash)
		end
		local function AddSplash()
			if typeof(guild.splash) == "string" then
				table.insert(candidates, {
					url = ("https://cdn.discordapp.com/splashes/%s/%s.png?size=600"):format(id, guild.splash),
					name = "splash-" .. guild.splash,
				})
			end
		end
		local function AddIcon()
			if typeof(guild.icon) == "string" then
				table.insert(candidates, {
					url = ("https://cdn.discordapp.com/icons/%s/%s.png?size=512"):format(id, guild.icon),
					name = "iconbanner-" .. guild.icon,
					dark = true,
				})
			end
		end

		local source = DiscordCard.BannerSource
		if source == "profile" then
			AddProfile()
		elseif source == "banner" then
			AddBanner(guild.banner)
		elseif source == "splash" then
			AddSplash()
		elseif source == "icon" then
			AddIcon()
		else
			AddProfile()
			AddSplash()
			AddBanner(guild.banner)
		end

		local asset, dark
		for _, candidate in ipairs(candidates) do
			asset = LoadRemoteImage(candidate.url, Config.Window.Folder, candidate.name)
			if asset then
				dark = candidate.dark
				break
			end
		end

		local brandColor = ParseHexColor(profile.brand_color_primary)
		if not asset and not brandColor then
			return
		end
		if not Main.Parent then
			return -- the card was destroyed while the image was downloading
		end

		local Height = DiscordCard.BannerHeight
		local Radius = Config.Window.ElementConfig.UICorner

		-- Empty space in the layout, so the info row starts below the banner.
		New("Frame", {
			Name = "BannerSpace",
			Size = UDim2.new(1, 0, 0, math.max(0, Height - Padding)),
			BackgroundTransparency = 1,
			LayoutOrder = -1,
			Parent = Container,
		})

		-- The image is taller than the visible area: its rounded bottom corners sit
		-- below the point where the fade is already fully transparent.
		local ImageHeight = Height + Radius * 2
		local FadeEnd = Height / ImageHeight

		local Banner = New("ImageLabel", {
			Name = "Banner",
			-- The card has inner padding; this cancels it so the banner touches the edges.
			Position = UDim2.new(0, -Padding, 0, -Padding),
			Size = UDim2.new(1, Padding * 2, 0, ImageHeight),
			BackgroundColor3 = brandColor or BLURPLE,
			BackgroundTransparency = asset and 1 or 0.3,
			Image = asset or "",
			ImageColor3 = dark and Color3.fromRGB(140, 140, 140) or Color3.new(1, 1, 1),
			ScaleType = "Crop",
			ZIndex = 0, -- always behind the card content
			Parent = Main,
		}, {
			New("UICorner", {
				CornerRadius = UDim.new(0, Radius),
			}),
			New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(FadeEnd * 0.5, 0.1),
					NumberSequenceKeypoint.new(FadeEnd * 0.8, 0.7),
					NumberSequenceKeypoint.new(FadeEnd, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		DiscordCard.UIElements.Banner = Banner
	end

	-- DATA ----------------------------------------------------------------
	local BuiltStaticParts = false

	local function ApplyData(data)
		local guild = data.guild
		local profile = typeof(data.profile) == "table" and data.profile or {}
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
		local description = typeof(guild.description) == "string" and guild.description
			or typeof(profile.description) == "string" and profile.description
			or ""
		if DiscordCard.ShowDescription and description ~= "" then
			DescriptionLabel.Text = Truncate((description:gsub("%s+", " ")), 110)
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
				AddBadge("Verified", BLURPLE)
			end
			if HasFeature(guild, "PARTNERED") then
				AddBadge("Partnered", BLURPLE)
			end
			if HasFeature(guild, "COMMUNITY") then
				AddBadge("Community", Color3.fromRGB(64, 66, 73))
			end

			local boosts = tonumber(guild.premium_subscription_count)
			if boosts and boosts > 0 then
				AddBadge(FormatNumber(boosts) .. " Boosts", Color3.fromRGB(244, 127, 255))
			end
		end

		-- Images are downloaded in the background so the text shows up right away.
		task.spawn(BuildIcon, guild)
		task.spawn(BuildBanner, guild, profile)
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
