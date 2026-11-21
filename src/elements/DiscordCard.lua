local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))

local Creator = require("../modules/Creator")
local New = Creator.New

local Element = {}

local function GetFont(weight)
	return Font.new(Creator.Font, weight)
end

local function FormatNumber(number)
	local reversed = tostring(math.floor(number)):reverse():gsub("(%d%d%d)", "%1,")
	return (reversed:reverse():gsub("^,", ""))
end

-- Accepts "abc123", "discord.gg/abc123" or "https://discord.com/invite/abc123"
local function ParseInvite(invite)
	local text = tostring(invite or "")
	return text:match("discord%.gg/([%w%-_]+)") or text:match("discord%.com/invite/([%w%-_]+)") or text
end

-- Downloads an image, shows it on the label and deletes the saved file
-- as soon as Roblox has finished loading it (so nothing is left on disk).
local function ApplyImage(Label, Url, FileName)
	local Request = Creator.Request
	if not (Request and writefile and getcustomasset) then
		return
	end

	local requested, response = pcall(Request, { Url = Url, Method = "GET" })
	if not requested or not response or response.StatusCode ~= 200 then
		return
	end

	if not pcall(writefile, FileName, response.Body) then
		return
	end

	local gotAsset, asset = pcall(getcustomasset, FileName)
	if gotAsset and asset and Label.Parent then
		Label.Image = asset

		-- wait until the image is really loaded (max 10s) before deleting its file
		local startedAt = os.clock()
		while Label.Parent and not Label.IsLoaded and os.clock() - startedAt < 10 do
			task.wait(0.1)
		end
	end

	if delfile then
		pcall(delfile, FileName)
	end
end

function Element:New(Config)
	local WindUI = Config.WindUI

	local DiscordCardModule = {
		__type = "DiscordCard",
		Invite = ParseInvite(Config.Invite),
		Title = Config.Title,
		Desc = Config.Desc or Config.Description,
		JoinText = Config.JoinText or "Join Server",
		CopyText = Config.CopyText or "Copy Invite",
		ShowCounts = Config.ShowCounts ~= false,
		Radius = Config.Radius or 14,
	}

	local RefreshId = 0
	local Destroyed = false

	local function Notify(icon, content, duration)
		if WindUI and WindUI.Notify then
			WindUI:Notify({
				Icon = icon,
				Title = "Discord",
				Content = content,
				Duration = duration or 3,
			})
		end
	end

	local function GetLink()
		return "https://discord.gg/" .. DiscordCardModule.Invite
	end

	local function CopyInvite()
		if setclipboard then
			setclipboard(GetLink())
			Notify("copy", "Invite link copied!")
		else
			Notify("triangle-alert", "Your executor can't copy to the clipboard. Invite: " .. GetLink(), 6)
		end
	end

	-- Asks the Discord desktop app (if it is open) to show the invite.
	-- If that doesn't work, it falls back to copying the link.
	local function JoinServer()
		local Request = Creator.Request
		if Request then
			local sent, response = pcall(Request, {
				Url = "http://127.0.0.1:6463/rpc?v=1",
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["Origin"] = "https://discord.com",
				},
				Body = HttpService:JSONEncode({
					cmd = "INVITE_BROWSER",
					nonce = HttpService:GenerateGUID(false),
					args = { code = DiscordCardModule.Invite },
				}),
			})
			if sent and response and response.StatusCode == 200 then
				Notify("geist:logo-discord", "Check your Discord app to join!")
				return
			end
		end
		CopyInvite()
	end

	------------------------------------------------------------
	-- Building the card
	------------------------------------------------------------
	local function Label(props)
		props.BackgroundTransparency = 1
		props.TextXAlignment = Enum.TextXAlignment.Left
		props.ThemeTag = props.ThemeTag or { TextColor3 = "Text" }
		return New("TextLabel", props)
	end

	local function Dot(color)
		return New("Frame", {
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end

	-- The banner image is taller than its holder and the holder clips it, so only the
	-- top corners stay rounded (the rounded bottom corners are cut off).
	local BannerImage = New("ImageLabel", {
		Name = "Banner",
		Size = UDim2.new(1, 0, 0, 80),
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop,
		Image = "",
		ThemeTag = { BackgroundColor3 = "Accent" },
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, DiscordCardModule.Radius) }),
		-- soft fade: fully visible at the top, blending into the card at the bottom
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.6, 0.15),
				NumberSequenceKeypoint.new(1, 0.75),
			}),
		}),
	})

	local BannerHolder = New("Frame", {
		Name = "BannerHolder",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 1,
	}, {
		BannerImage,
	})

	local IconImage = New("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(56, 56),
		BorderSizePixel = 0,
		Image = "",
		LayoutOrder = 1,
		ThemeTag = { BackgroundColor3 = "Accent" },
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local NameLabel = Label({
		Name = "ServerName",
		Size = UDim2.new(1, 0, 0, 22),
		Text = DiscordCardModule.Title or "Discord Server",
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = GetFont(Enum.FontWeight.Bold),
		LayoutOrder = 1,
	})

	local OnlineLabel = Label({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "Loading...",
		TextSize = 13,
		TextTransparency = 0.25,
		FontFace = GetFont(Enum.FontWeight.Medium),
		LayoutOrder = 2,
	})

	local MembersLabel = Label({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextSize = 13,
		TextTransparency = 0.25,
		FontFace = GetFont(Enum.FontWeight.Medium),
		LayoutOrder = 4,
	})

	local OnlineDot = Dot(Color3.fromRGB(35, 165, 90))
	OnlineDot.LayoutOrder = 1
	OnlineDot.Visible = false

	local MemberDot = Dot(Color3.fromRGB(148, 155, 164))
	MemberDot.LayoutOrder = 3
	MemberDot.Visible = false

	local StatusRow = New("Frame", {
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		OnlineDot,
		OnlineLabel,
		MemberDot,
		MembersLabel,
	})

	local InfoColumn = New("Frame", {
		Name = "Info",
		Size = UDim2.new(1, -68, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, {
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
		NameLabel,
		StatusRow,
	})

	local Header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
		IconImage,
		InfoColumn,
	})

	local DescriptionLabel = Label({
		Name = "Description",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = DiscordCardModule.Desc or "",
		TextSize = 13,
		TextWrapped = true,
		TextTransparency = 0.35,
		FontFace = GetFont(Enum.FontWeight.Regular),
		Visible = (DiscordCardModule.Desc or "") ~= "",
		LayoutOrder = 2,
	})

	local function MakeButton(text, order, width, callback, primary)
		local Button = New("TextButton", {
			Size = UDim2.new(width, -4, 1, 0),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			TextSize = 14,
			FontFace = GetFont(Enum.FontWeight.SemiBold),
			LayoutOrder = order,
			BackgroundTransparency = primary and 0 or 0.9,
			TextColor3 = primary and Color3.fromRGB(255, 255, 255) or nil,
			ThemeTag = primary and { BackgroundColor3 = "Button" }
				or { BackgroundColor3 = "Text", TextColor3 = "Text" },
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
		Button.MouseButton1Click:Connect(callback)
		return Button
	end

	local ButtonsRow = New("Frame", {
		Name = "Buttons",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		MakeButton(DiscordCardModule.JoinText, 1, 0.62, JoinServer, true),
		MakeButton(DiscordCardModule.CopyText, 2, 0.38, CopyInvite, false),
	})

	local Body = New("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, {
		New("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
		Header,
		DescriptionLabel,
		ButtonsRow,
	})

	local Card = New("Frame", {
		Name = "DiscordCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Parent = Config.Parent,
		ThemeTag = {
			BackgroundColor3 = "ElementBackground",
			BackgroundTransparency = "ElementBackgroundTransparency",
		},
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, DiscordCardModule.Radius) }),
		New("UIStroke", {
			Thickness = 1,
			Transparency = 0.9,
			ThemeTag = { Color = "Text" },
		}),
		New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		BannerHolder,
		Body,
	})

	DiscordCardModule.Card = Card

	------------------------------------------------------------
	-- Filling the card with real server data
	------------------------------------------------------------
	function DiscordCardModule:Refresh()
		RefreshId = RefreshId + 1
		local Id = RefreshId

		task.spawn(function()
			local Request = Creator.Request
			if not Request then
				OnlineLabel.Text = "Server info unavailable"
				return
			end

			local requested, response = pcall(Request, {
				Url = "https://discord.com/api/v9/invites/" .. DiscordCardModule.Invite .. "?with_counts=true",
				Method = "GET",
			})

			-- the card was destroyed or another refresh started while we were waiting
			if Destroyed or Id ~= RefreshId then
				return
			end

			if not requested or not response or response.StatusCode ~= 200 then
				OnlineLabel.Text = "Invite not found"
				return
			end

			local parsed, data = pcall(function()
				return HttpService:JSONDecode(response.Body)
			end)
			if not parsed or type(data) ~= "table" or not data.guild then
				OnlineLabel.Text = "Invite not found"
				return
			end

			local guild = data.guild
			NameLabel.Text = DiscordCardModule.Title or guild.name

			local description = DiscordCardModule.Desc or guild.description
			if description and description ~= "" then
				DescriptionLabel.Text = description
				DescriptionLabel.Visible = true
			end

			if DiscordCardModule.ShowCounts and data.approximate_member_count then
				OnlineDot.Visible = true
				MemberDot.Visible = true
				OnlineLabel.Text = FormatNumber(data.approximate_presence_count or 0) .. " Online"
				MembersLabel.Text = FormatNumber(data.approximate_member_count) .. " Members"
			else
				OnlineLabel.Text = ""
			end

			-- images are downloaded in the background and their files are deleted after use
			if guild.icon then
				task.spawn(
					ApplyImage,
					IconImage,
					"https://cdn.discordapp.com/icons/" .. guild.id .. "/" .. guild.icon .. ".png?size=128",
					"DiscordCard_" .. guild.id .. "_icon.png"
				)
			end

			if guild.banner then
				task.spawn(
					ApplyImage,
					BannerImage,
					"https://cdn.discordapp.com/banners/" .. guild.id .. "/" .. guild.banner .. ".png?size=480",
					"DiscordCard_" .. guild.id .. "_banner.png"
				)
			end
		end)
	end

	function DiscordCardModule:SetInvite(invite)
		DiscordCardModule.Invite = ParseInvite(invite)
		OnlineLabel.Text = "Loading..."
		OnlineDot.Visible = false
		MemberDot.Visible = false
		MembersLabel.Text = ""
		DiscordCardModule:Refresh()
	end

	function DiscordCardModule:Destroy()
		Destroyed = true
		Card:Destroy()
	end

	DiscordCardModule:Refresh()

	return DiscordCardModule.__type, DiscordCardModule
end

return Element
