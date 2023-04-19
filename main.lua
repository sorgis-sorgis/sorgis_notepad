--[[
    https://github.com/sorgis-sorgis/sorgis_notepad

    note-taking addon for the vanilla World of Warcraft client
]]

local snp = {}

------------------------------------------------------
-- Utility
------------------------------------------------------
do
    local makeLogger = function(r, g, b)
        return function(...)
            local msg = ""
            for i, v in ipairs(arg) do
                msg = msg .. tostring(v) 
            end

            DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
        end
    end

    snp.log = makeLogger(1, 1, 0.5)
    snp.error = makeLogger(1, 0, 0)
end

snp.makeSlashCommand = function(aName, aBehaviour)
    local _G = _G or getfenv(0)
    local nameUpperCase = string.upper(aName)
    _G["SLASH_" .. nameUpperCase .. 1] = "/" .. aName
    SlashCmdList[nameUpperCase] = aBehaviour
end

------------------------------------------------------
-- GUI
------------------------------------------------------
snp.gui = {}
do
    local fEditBox

    local fRoot = CreateFrame("Frame", "sorgis_notepad_frame", UIParent)
    fRoot:SetWidth(350)
    fRoot:SetHeight(150)
    fRoot:SetPoint("CENTER", 0,0)
    fRoot:SetBackdrop({bgFile = "Interface/BUTTONS/WHITE8X8",})
    fRoot:SetBackdropColor(0, 0, 0, 0.35)
    fRoot:SetMinResize(250, 140)
    fRoot:EnableMouse(true)
    fRoot:SetMovable(true)
    fRoot:SetResizable(true)
    fRoot:RegisterForDrag("LeftButton")
    fRoot:SetScript("OnDragStart", function()
        if IsShiftKeyDown() then
            fRoot:StartSizing()
        else
            fRoot:StartMoving()
        end
    end)
    fRoot:SetScript("OnDragStop", function()
        fRoot:StopMovingOrSizing()
        fEditBox:SetWidth(fRoot:GetWidth() - 40)
    end)

    local fCloseButton = CreateFrame("Button", "$parentClose", fRoot)
    fCloseButton:SetWidth(24)
    fCloseButton:SetHeight(24)
    fCloseButton:SetPoint("TOPRIGHT", 0, 0)
    fCloseButton:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
    fCloseButton:SetPushedTexture("Interface/Buttons/UI-Panel-MinimizeButton-Down")
    fCloseButton:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight", "ADD")
    fCloseButton:SetScript("OnClick", function()
        fRoot:Hide()
        fEditBox:ClearFocus()
    end)

    local fHelpButton = CreateFrame("Button", "$parentHelp", fRoot, "UIPanelButtonTemplate")
    fHelpButton:SetWidth(14)
    fHelpButton:SetWidth(14)
    fHelpButton:SetHeight(14)
    fHelpButton:SetPoint("RIGHT", fCloseButton, "LEFT")
    fHelpButton:SetText("?")

    local fScrollFrame = CreateFrame("ScrollFrame", "$parent_DF", fRoot, "UIPanelScrollFrameTemplate")
    fScrollFrame:SetPoint("TOPLEFT", fRoot, 12, -30)
    fScrollFrame:SetPoint("BOTTOMRIGHT", fRoot, -30, 10)

    fEditBox = CreateFrame("EditBox", nil, fRoot)
    fEditBox:SetMultiLine(true)
    fEditBox:SetWidth(fRoot:GetWidth() - 40)
    fEditBox:SetPoint("TOPLEFT", fScrollFrame)
    fEditBox:SetPoint("BOTTOMRIGHT", fScrollFrame)
    fEditBox:SetMaxLetters(99999)
    fEditBox:SetFontObject(GameFontNormal)
    fEditBox:SetAutoFocus(false)
    fEditBox:SetScript("OnEscapePressed", function() 
        fEditBox:ClearFocus()
    end) 
    fEditBox:SetScript("OnTextChanged", function() 
        fEditBox:SetWidth(fRoot:GetWidth() - 40)
        fScrollFrame:UpdateScrollChildRect()
        sorgis_notepad_contents = fEditBox:GetText()
    end) 
    fEditBox:SetTextColor(1,1,1,1)
    fScrollFrame:SetScrollChild(fEditBox)
     
    local fHelpText = fRoot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fHelpText:SetText("left click + drag to move window,\r" .. 
        "left click + shift + drag to resize,\r" ..
        "click to start input, escape to end\r\r" ..
        "type `/snp` in chat for commands")
    fHelpText:SetTextColor(1,1,1,1);
    fHelpText:SetJustifyH("LEFT")
    fHelpText:SetPoint("TOPLEFT", 10, -30)

    fHelpButton:SetScript("OnClick", function()
        fEditBox:ClearFocus()
        fEditBox:Hide()
        fHelpText:Show()
    end)

    fRoot:SetScript("OnMouseUp", function()
        fHelpText:Hide()
        fEditBox:Show()
        fEditBox:SetFocus()
    end)

    fRoot:RegisterEvent("ADDON_LOADED")
    fRoot:RegisterEvent("PLAYER_LOGOUT")
    fRoot:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "sorgis_notepad" then
            if (sorgis_notepad_visible == true or sorgis_notepad_visible == nil) then fRoot:Show() else fRoot:Hide() end
            
            fEditBox:SetText(sorgis_notepad_contents or "")
            fEditBox:Hide()
            snp.log("sorgis_notepad has loaded. Type `/snp` to see commands.") 
        elseif event == "PLAYER_LOGOUT" then
            sorgis_notepad_visible = (fRoot:IsVisible() == 1)
        end
    end)

    snp.gui.reset = function()
        fRoot:ClearAllPoints()
        fRoot:SetPoint("CENTER", 0,0)
        fRoot:Show()
    end

    snp.gui.show = function()
        fRoot:Show()
    end
end

---------------
-- CLI
---------------
snp.makeSlashCommand("snp", function(msg)
    local params = {}
    
    for word in string.gfind(msg, "\(%w+\)") do
        table.insert(params, word)
    end

    local new_command = function(aDescription, aBehaviour)
        local out = {
            description = aDescription
        }

        setmetatable(out, {
            __call = function(self, args)
                aBehaviour(table.remove(args,1))
            end
        })

        return out
    end

    local commands = {
        reset = new_command("repositions window to the center of the screen", snp.gui.reset),
        show = new_command("shows the window if hidden", snp.gui.show),
    }

    (commands[params[1]] or function()
        if params[1] then 
            snp.log("unrecognized command: \"" .. params[1] .. "\"", 1, 0, 0) 
        end

        local helpText = "sorgis_notepad commands: \n"
        
        for k, v in commands do 
            helpText = helpText .. "`/snp " .. k .. "`" .. ": " .. v.description .. "\n"
        end

        helpText = helpText .. "text is saved to file:\r{wow}/WTF/Account/{account}/\rSavedVariables/sorgis_notepad.lua"
        
        snp.log(helpText)

    end)(params)
end)

