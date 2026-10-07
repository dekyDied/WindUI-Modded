local Creator = require("../modules/Creator")
local New = Creator.New

local Element = {}

local ConsoleColors = {
	output  = Color3.fromRGB(200, 200, 210),
	info    = Color3.fromRGB(120, 170, 255),
	success = Color3.fromRGB(110, 220, 140),
	warning = Color3.fromRGB(255, 190, 90),
	error   = Color3.fromRGB(255, 105, 105),
	MessageOutput  = Color3.fromRGB(200, 200, 210),
	MessageInfo    = Color3.fromRGB(120, 170, 255),
	MessageWarning = Color3.fromRGB(255, 190, 90),
	MessageError   = Color3.fromRGB(255, 105, 105),
}

local function EscapeRich(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function ColorToHex(color)
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Element:New(ElementConfig)
	ElementConfig.Hover = false
	ElementConfig.TextOffset = 0
	ElementConfig.ParentConfig = ElementConfig

	local height  = ElementConfig.Height or 200
	local maxLogs = ElementConfig.MaxLogs or 300
	local title   = ElementConfig.Title or "Debug Console"
	local autoCapture = ElementConfig.AutoCapture ~= false

	local ConsoleModule = {
		__type = "Console",
		Title  = title,
		Locked = ElementConfig.Locked or false,
	}

	local Console = require("../components/window/Element")(ElementConfig)
	ConsoleModule.ConsoleFrame = Console

	local Container = New("Frame", {
		Name = "Console",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = Console.UIElements.Container,
	})

	-- Header
	local Header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = Container,
	}, {
		New("UIPadding", {
			PaddingLeft  = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
	})

	local TitleRow = New("Frame", {
		Size = UDim2.new(1, -70, 1, 0),
		BackgroundTransparency = 1,
		Parent = Header,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
		}),
	})

	New("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = Creator.Icon("terminal") or "",
		ImageColor3 = Color3.fromRGB(150, 150, 155),
		Size = UDim2.fromOffset(14, 14),
		LayoutOrder = 1,
		Parent = TitleRow,
	})

	New("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextSize = 13,
		FontFace = Font.fromEnum(Enum.Font.GothamMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		LayoutOrder = 2,
		Parent = TitleRow,
	})

	local Controls = New("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(58, 24),
		BackgroundTransparency = 1,
		Parent = Header,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
	})

	local function IconButton(iconName, order)
		local Btn = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(24, 24),
			LayoutOrder = order,
			Parent = Controls,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 7) }),
		})

		local Icon = New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Creator.Icon(iconName) or "",
			ImageColor3 = Color3.fromRGB(150, 150, 155),
			Size = UDim2.fromOffset(13, 13),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = Btn,
		})

		Btn.MouseEnter:Connect(function()
			Btn.BackgroundTransparency = 0.9
			Icon.ImageColor3 = Color3.fromRGB(240, 240, 240)
		end)
		Btn.MouseLeave:Connect(function()
			Btn.BackgroundTransparency = 1
			Icon.ImageColor3 = Color3.fromRGB(150, 150, 155)
		end)

		return Btn, Icon
	end

	local CopyBtn, CopyIcon = IconButton("copy", 1)
	local ClearBtn = IconButton("trash-2", 2)

	New("Frame", {
		Name = "Divider",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 34),
		Parent = Container,
	})

	local LogsScroll = New("ScrollingFrame", {
		Name = "Logs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 1, -35),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = Container,
	}, {
		New("UIPadding", {
			PaddingTop    = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft   = UDim.new(0, 6),
			PaddingRight  = UDim.new(0, 6),
		}),
		New("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local EmptyState = New("Frame", {
		Name = "EmptyState",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 1, -35),
		Parent = Container,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})

	New("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Creator.Icon("frown") or "",
		ImageColor3 = Color3.fromRGB(150, 150, 155),
		Size = UDim2.fromOffset(22, 22),
		LayoutOrder = 1,
		Parent = EmptyState,
	})

	New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "No logs at the moment",
		TextColor3 = Color3.fromRGB(150, 150, 155),
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.Gotham),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 14),
		LayoutOrder = 2,
		Parent = EmptyState,
	})


	local Logs = {}
	local LogCount = 0
	local Counter = 0
	local AutoScroll = true

	local function TrimLogs()
		while LogCount > maxLogs do
			local oldest = table.remove(Logs, 1)
			if oldest then
				oldest:Destroy()
				LogCount = LogCount - 1
			else
				break
			end
		end
	end

	local function AddLog(message, messageType)
		message = tostring(message or "")
		if message == "" then return end

		TrimLogs()
		Counter = Counter + 1

		local color = ConsoleColors[messageType] or ConsoleColors.output
		local dimHex = "96969B"
		local colorHex = ColorToHex(color)

		local Entry = New("TextLabel", {
			Name = "Entry",
			BackgroundTransparency = 1,
			RichText = true,
			TextSize = 12,
			FontFace = Font.fromEnum(Enum.Font.Gotham),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.25,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = Counter,
			Text = string.format(
				'<font color="#%s" transparency="0.45">[%s]</font> <font color="#%s">%s</font>',
				dimHex,
				os.date("%H:%M:%S"),
				colorHex,
				EscapeRich(message)
			),
			Parent = LogsScroll,
		})

		table.insert(Logs, Entry)
		LogCount = LogCount + 1
		EmptyState.Visible = false

		if AutoScroll then
			task.defer(function()
				LogsScroll.CanvasPosition = Vector2.new(0, LogsScroll.AbsoluteCanvasSize.Y)
			end)
		end
	end

	LogsScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local atBottom = LogsScroll.CanvasPosition.Y
			>= LogsScroll.AbsoluteCanvasSize.Y - LogsScroll.AbsoluteWindowSize.Y - 20
		AutoScroll = atBottom
	end)

	local function ClearLogs()
		for _, entry in ipairs(Logs) do
			entry:Destroy()
		end
		table.clear(Logs)
		LogCount = 0
		EmptyState.Visible = true
	end

	-- Copy
	CopyBtn.MouseButton1Click:Connect(function()
		local setclipboard = setclipboard or toclipboard
		if not setclipboard then return end

		local lines = {}
		for _, entry in ipairs(Logs) do
			local clean = entry.Text
				:gsub("<font[^>]*>", "")
				:gsub("</font>", "")
				:gsub("&lt;", "<")
				:gsub("&gt;", ">")
				:gsub("&amp;", "&")
			table.insert(lines, clean)
		end
		setclipboard(table.concat(lines, "\n"))

		CopyIcon.ImageColor3 = Color3.fromRGB(120, 220, 140)
		task.delay(0.4, function()
			if CopyIcon.Parent then
				CopyIcon.ImageColor3 = Color3.fromRGB(150, 150, 155)
			end
		end)
	end)

	ClearBtn.MouseButton1Click:Connect(ClearLogs)

	if autoCapture then
		local LogService = game:GetService("LogService")
		LogService.MessageOut:Connect(function(message, messageType)
			AddLog(message, messageType)
		end)
	end

	function ConsoleModule:Log(message, messageType)
		AddLog(message, messageType)
	end

	function ConsoleModule:Clear()
		ClearLogs()
	end

	function ConsoleModule:SetTitle(newTitle)
		local label = TitleRow:FindFirstChild("Title")
		if label then
			label.Text = tostring(newTitle or "")
		end
		ConsoleModule.Title = newTitle
	end

	return ConsoleModule.__type, ConsoleModule
end

return Element
