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
        toggles = {}
    }
end

function ui.setState(name)
    if not ui.states[name] then
        error("State '" .. name .. "' does not exist.")
    end
    ui.currentState = name
end

function ui.addToggle(state, x, y, width, height, text, onClick, ...)
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
        onClick = onClick,
        clicked = false,
        clickTimer = 0
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
                if love.mouse.isDown(1) then
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
        if isMouseOver(mouseX, mouseY, toggle) then
            if love.mouse.isDown(1) then
                color = theme.click
            else
                color = theme.hover
            end
        end

        love.graphics.setColor(color)
        love.graphics.rectangle("fill", toggle.x, toggle.y, toggle.width, toggle.height)

        love.graphics.setColor(theme.text)
        love.graphics.printf(toggle.text, toggle.x + 5, toggle.y + toggle.height / 3, toggle.width - 10, "center")
    end

end

function ui.update(dt)
    delay = delay - dt
    if ui.currentState == "" then
        return
    end
    local state = ui.states[ui.currentState]
    local mouseX, mouseY = love.mouse.getPosition()

    for _, button in ipairs(state.buttons) do
        if button.clicked then
            button.clickTimer = button.clickTimer - dt
            if button.clickTimer <= 0 then
                button.clicked = false
                button.onClick()
            end
        elseif isMouseOver(mouseX, mouseY, button) and love.mouse.isDown(1) and delay <= 0 then
            button.clicked = true
            button.clickTimer = 0.05 -- delay to show the clicked colour before proceeding with onClick()
            delay = 0.15
        end
    end
end

return ui
