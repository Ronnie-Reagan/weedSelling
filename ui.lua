local ui = {}
local delay = 0

ui.states = {}
ui.currentState = ""
ui.themes = {
    default = {
        button = {1, 0, 1, 1},
        text = {1, 1, 1, 1},
        hover = {1, 0.5, 0, 1},
        click = {0, 1, 0, 1}
    },
    dark = {
        button = {0.2, 0.2, 0.2, 1},
        text = {1, 1, 1, 1},
        hover = {0.4, 0.4, 0.4, 1},
        click = {0.6, 0.6, 0.6, 1}
    }
}
ui.customTheme = nil

function ui.setTheme(theme)
    if ui.themes[theme] then
        ui.customTheme = nil
        ui.theme = ui.themes[theme]
    elseif type(theme) == "table" then
        ui.customTheme = theme
        ui.theme = theme
    else
        error("Invalid theme specified.")
    end
end

function ui.newState(name)
    ui.states[name] = {
        buttons = {},
        toggles = {},
        labels = {}
    }
end

function ui.setState(name)
    if not ui.states[name] then
        error("State '" .. name .. "' does not exist.")
    end
    ui.currentState = name
end

function ui.addToggle(state, x, y, width, height, text, onClick, var, ...)
    if not ui.states[state] then
        error("State '" .. state .. "' does not exist")
    end

    if ... and type(...) == "table" then
        local tableLevel = 1
        local function recurve(tableToSearch)
            if tableToSearch and type(tableToSearch) == "table" then
                for k, v in pairs(tableToSearch) do
                    if type(v) == "table" then
                        recurve(v)
                    elseif type(v) == "userdata" then

                    end
                end
            end
        end

        local error, args = recurve(...)
        if error then
            print("Error in UI Module:\nAttempt to recursively search table: " .. tostring(...)  .. "\n\n" .. error .. "\n")
        end
    end
    table.insert(ui.states[state].toggles, {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        onChange = onClick,
        clicked = false,
        clickTimer = 0,
        var = var
    })

end

function ui.addLabel(state, x, y, width, height, text, shouldHaveBackground)
    if not ui.states[state] then
        error("State '" .. state .. "'' does not exist.")
    end
    table.insert(ui.states[state].labels, {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        background = shouldHaveBackground or false
    })
end

function ui.addButton(state, x, y, width, height, text, onClick)
    if not ui.states[state] then
        error("State '" .. state .. "' does not exist.")
    end
    table.insert(ui.states[state].buttons, {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        onClick = onClick,
        clicked = false,
        clickTimer = 0
    })
end

function ui.clearLabels(state)
    if ui.states[state] then
        ui.states[state].labels = {}
    end
end

function ui.clearButtons(state)
    if ui.states[state] then
        ui.states[state].buttons = {}
    end
end

function ui.updateLabelText(state, index, text)
    if ui.states[state] and ui.states[state].labels[index] then
        ui.states[state].labels[index].text = text
    end
end

function ui.updateButtonText(state, index, text)
    if ui.states[state] and ui.states[state].buttons[index] then
        ui.states[state].buttons[index].text = text
    end
end

local function isMouseOver(mouseX, mouseY, btn)
    return mouseX >= btn.x and mouseX <= btn.x + btn.width and mouseY >= btn.y and mouseY <= btn.y + btn.height
end

function ui.draw()
    if ui.currentState == "" then
        return
    end
    local theme = ui.customTheme or ui.theme or ui.themes.default
    local state = ui.states[ui.currentState]

    for _, button in ipairs(state.buttons) do
        local color = theme.button
        if button.clicked then
            color = theme.click
        else
            local mouseX, mouseY = love.mouse.getPosition()
            if isMouseOver(mouseX, mouseY, button) then
                if button.clicked then
                    color = theme.click
                else
                    color = theme.hover
                end
            end
        end

        love.graphics.setColor(color)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)

        love.graphics.setColor(theme.text)
        love.graphics.printf(button.text, button.x + (button.width / 8), button.y + button.height / 3,
                             button.width - (button.width * 0.25), "center")
    end
    -- Draw toggles
    for _, toggle in ipairs(state.toggles) do
        local color = theme.button
        local mouseX, mouseY = love.mouse.getPosition()
            if toggle.clicked then
                color = theme.click
            else
                color = theme.hover
            end

        love.graphics.setColor(color)
        love.graphics.rectangle("fill", toggle.x, toggle.y, toggle.width, toggle.height)

        if toggle.var[1] == true then
            love.graphics.setColor(0.9, 0, 0, 0.9)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.9)
        end
        love.graphics.circle("fill", toggle.x + toggle.width, toggle.y + toggle.height / 2, toggle.height / 4)
        love.graphics.setColor(theme.text)
        love.graphics.printf(toggle.text, toggle.x + 5, toggle.y + toggle.height / 3, toggle.width - 10, "center")
    end

    -- draw labels
    for _, label in ipairs(state.labels) do
        local color = theme.text
        local backgroundColor = theme.button
        if label.background == true then
            love.graphics.setColor(backgroundColor)
            love.graphics.rectangle("fill", label.x, label.y, label.width, label.height)
        end
        love.graphics.printf(label.text, label.x + (label.width / 2), label.y + (label.height / 2), label.width, "center")
    end
end

function ui.update(dt)
    delay = delay - dt
    if ui.currentState == "" then
        return
    end

end

function ui.mousePressed(x, y, btn)
    if btn ~= 1 then return end
    local state = ui.states[ui.currentState]
    for _, button in ipairs(state.buttons) do
        if isMouseOver(x, y, button) then
            button.clicked = true
        end
    end
    for _, toggle in ipairs(state.toggles) do
        if isMouseOver(x, y, toggle) then
            toggle.clicked = true
        end
    end
end


function ui.mouseReleased(x, y, btn)
    if btn ~= 1 then return end
    local state = ui.states[ui.currentState]
    for _, button in ipairs(state.buttons) do
        if button.clicked and isMouseOver(x, y, button) then
            button.onClick()
            button.clicked = false
        end
        button.clicked = false
    end
    for _, toggle in ipairs(state.toggles) do
        if isMouseOver(x, y, toggle) and toggle.clicked then
            toggle.onChange()
            for _, varvar in ipairs(toggle.var) do
                varvar = not varvar
                toggle.clicked = false
                print(toggle.text .. "realeasd, current value after release: " .. tostring(varvar))
            end
        end
        toggle.clicked = false
    end
end

return ui
