-- ui_economy_game/main.lua
local ui = require("ui")

-- window stuff
local screenWidth, screenHeight = love.window.getDesktopDimensions()
local windowWidth, windowHeight = love.window.getMode()

-- Game variables

-- new variables
local homes = {
    [1] = {
        screenName = "Parent's Basement",
        internalName = "basement1",
        upfrontCost = 0, -- dollars
        monthlyCost = 500, -- dollars
        possibleEmployees = 0 -- aint nobody talk to you, loser
    },
    [2] = {
        screenName = "Trailer",
        internalName = "trailer1",
        upfrontCost = 4899, -- dollars
        monthlycost = 2410, -- dollars
        possbileEmployees = 1 -- the cool friend
    }
}

local player = {
    wallet = 50, -- dollars
    stash = 3.5, -- grams
    life = {
        house = "basement1", -- homes[1].internalName

    }
}

local allWorkers = {
    [1] = {
        name = "James", -- screen name and system name
        role = "dealer", -- internal name
        rank = "Addict", -- screen name and system name
        -- percentage in form of decimal
        personality = {
            nice = 0.8,
            mean = 0.1,
            neutral = 0.1
        },
        payroll = {
            cut = 0.12 -- 12% of their sales
        },
        loyalty = {
            limit = 0.2, -- not possible to be more than 20% loyal
            current = 0.0
        }
    }
}

local employees = {} -- no employees

-- start remove
local price = 40
local wallet = 50
local storage = 3.5
-- end remove

local ouncesPerPound = 16
local gramsPerOunce = 28
local sellOunceFor = 150
local timeScale = (60 * 60) -- MUST find an alternative, possibly let user define it
local second, minute, hour, day, week, month, year = 0, 0, 0, 0, 0, 0, 0
local gameState = "menu"
local saveFileName = "saveGame.Don"
local loading = true
local loadingCoroutine = nil
local loadingText = "Initializing..."
local loadingPercentage = 0
local loadingSteps = 0
local loadingCurrent = 0

-- Custom prices for each unit
local prices = {
    gram = 10,
    eighth = 35,
    quarter = 60,
    halfOunce = 100,
    ounce = 180,
    quarterPound = 650,
    halfPound = 1200,
    pound = 2000
}

-- Cart system
local shippingFees = 20
local deliveryTime = 10 -- hour (10am deliveries)
local cart = {
    ounces = 0,
    cost = 0,
    freeShipping = false,
    expressShipping = false,
    orders = {}
}

-- Inventory log
local history = {}
local alertMessage = ""
local alertTimer = 0

function table.serialize(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and string.format("[%q]", k) or "[" .. k .. "]"
        local value
        if type(v) == "number" then
            value = tostring(v)
        elseif type(v) == "string" then
            value = string.format("%q", v)
        elseif type(v) == "table" then
            value = table.serialize(v)
        else
            value = "nil"
        end
        result = result .. key .. "=" .. value .. ","
    end
    return result .. "}"
end

local http = require("socket.http")
local ltn12 = require("ltn12")

local function serializeTable(t)
    local function serialize(o)
        local ttype = type(o)
        if ttype == "number" then
            return tostring(o)
        elseif ttype == "string" then
            return string.format("%q", o)
        elseif ttype == "table" then
            local s = "{"
            for k, v in pairs(o) do
                s = s .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
            end
            return s .. "}"
        elseif ttype == "boolean" then
            return o and "true" or "false"
        elseif o == nil then
            return "nil"
        else
            error("Cannot serialize type " .. ttype)
        end
    end
    return serialize(t)
end

function saveGame()
    -- Save current UTC timestamp (seconds since epoch)
    local utcTime = os.time(os.date("!*t")) -- UTC time

    local saveData = {
        wallet = wallet,
        storage = storage,
        price = price,
        second = second,
        minute = minute,
        hour = hour,
        day = day,
        week = week,
        month = month,
        year = year,
        prices = prices,
        cart = cart,
        history = history,
        savedTimestamp = utcTime
    }
    local serialized = serializeTable(saveData)
    local encoded = love.data.encode("string", "base64", serialized)
    local success, msg = love.filesystem.write(saveFileName, encoded)
    if not success then
        print("Failed to save game: " .. tostring(msg))
    end
end

-- Fetch current UTC timestamp via HTTP (example uses a simple API that returns time in JSON)
local function fetchCurrentUTCTime()
    local response_body = {}
    local res, code = http.request {
        url = "http://worldtimeapi.org/api/timezone/Etc/UTC",
        sink = ltn12.sink.table(response_body),
        method = "GET",
        headers = {
            ["Accept"] = "application/json"
        }
    }
    if code == 200 then
        local json = table.concat(response_body)
        local data = love.filesystem.load("json.lua") and require("json") or require("dkjson")
        local parsed = data.decode(json)
        if parsed and parsed.unixtime then
            print("parsed unix time: " .. parsed.unixtime)
            return parsed.unixtime
        end
    end
    print("failed to fetch the curent time")
    return nil -- fallback if HTTP request fails
end

-- Adjust in-game time variables based on elapsed seconds
local function updateTimeByElapsed(secondsElapsed)
    -- Convert all in-game time to total seconds, add elapsed, then convert back
    local totalSeconds =
        second + minute * 60 + hour * 3600 + day * 86400 + week * 604800 + month * 2629743 + -- average month seconds
        year * 31556926 -- average year seconds

    totalSeconds = totalSeconds + secondsElapsed

    -- Convert back to time units
    year = math.floor(totalSeconds / 31556926)
    totalSeconds = totalSeconds % 31556926

    month = math.floor(totalSeconds / 2629743)
    totalSeconds = totalSeconds % 2629743

    week = math.floor(totalSeconds / 604800)
    totalSeconds = totalSeconds % 604800

    day = math.floor(totalSeconds / 86400)
    totalSeconds = totalSeconds % 86400

    hour = math.floor(totalSeconds / 3600)
    totalSeconds = totalSeconds % 3600

    minute = math.floor(totalSeconds / 60)
    second = totalSeconds % 60
end

function loadGame()
    loading = true
    loadingCoroutine = coroutine.create(function()
        loadingText = "Checking for valid save file..."
        coroutine.yield()
        if love.filesystem.getInfo(saveFileName) then
            loadingText = "Loading saved data..."
            coroutine.yield()
            local contents = love.filesystem.read(saveFileName)
            local decoded = love.data.decode("string", "base64", contents)
            local chunk = loadstring("return " .. decoded)
            local data = chunk()

            wallet = data.wallet or 0
            storage = data.storage or 0
            price = data.price or 40
            second = data.second or 0
            minute = data.minute or 0
            hour = data.hour or 0
            day = data.day or 0
            week = data.week or 0
            month = data.month or 0
            year = data.year or 0
            prices = data.prices or prices
            cart = data.cart or cart
            history = data.history or {}

            if data.savedTimestamp then
                loadingText = "Attempting to fetch UTC time"
                coroutine.yield()
                local currentTimestamp = fetchCurrentUTCTime() or os.time(os.date("!*t"))
                local elapsed = currentTimestamp - data.savedTimestamp
                if elapsed > 0 then
                    -- FIX: scale real time to game time
                    local scaledGameSeconds = elapsed * timeScale
                    updateTimeByElapsed(scaledGameSeconds)
                end
            end

            loadingText = "Finishing Up..."
            coroutine.yield()
        else
            print("No save file found.")
        end

        loading = false
    end)
end

function showAlert(msg)
    alertMessage = msg
    alertTimer = 3 -- seconds
end

function progressTime(dtt)
    second = second + (1 * (dtt * timeScale))
    if second >= 60 then
        second = second - 60
        minute = minute + 1
    end
    if minute == 60 then
        minute = 0
        hour = hour + 1
    end
    if hour == 24 then
        hour = 0
        day = day + 1
    end
    if day == 7 then
        day = 0
        week = week + 1
    end
    if week >= 4 then
        week = 0;
        month = month + 1
    end
    if month >= 12 then
        month = 0;
        year = year + 1
    end

    for _, orderData in ipairs(cart.orders) do
        if not orderData.delivered and orderData.deliveryWeek and week >= orderData.deliveryWeek and hour >=
            deliveryTime then
            storage = storage + gramsPerOunce * orderData.ounces
            showAlert("Received delivery of " .. orderData.ounces .. " oz")
            table.insert(history, string.format("Received %d oz on Week %d", orderData.ounces, week))
            orderData.delivered = true
        end
    end
end

function getCurrentHome()
    for _, home in ipairs(homes) do
        if home.internalName == player.life.house then
            return home
        end
    end
    return nil
end

function buyHome(internalName)
    local currentHome, selectedHome = getCurrentHome(), nil
    for _, home in ipairs(homes) do
        if home.internalName == internalName then
            selectedHome = home
        end
    end
    if selectedHome == nil then return error("failed to find the home in the list", 2) end
    local upfront = selectedHome.upfrontCost
    if player.wallet < upfront then
        alertMessage = string.format("INSUFFICIENT FUNDS -$%d", upfront - player.wallet)
        alertTimer = 3
        return
    end
    if selectedHome.possibleEmployees < currentHome.possibleEmployees then
        if #employees < selectedHome.possibleEmployees then
            alertMessage = string.format("Too many employees to downgrade, fire %d", #employees - selectedHome.possibleEmployees)
            alertTimer = 3
            return
        end
    end
    player.life.house = selectedHome.internalName
    player.wallet = player.wallet - selectedHome.upfrontCost
    alertTimer = 3
    alertMessage = string.format("Purchase Complete, open positions: %d", selectedHome.possibleEmployees)
end

local function isEmployeeHired(worker)
    for _, emp in ipairs(employees) do
        if emp == worker then
            return true
        end
    end
    return false
end

function hireEmployee(index)
    local worker = allWorkers[index]
    if not worker then return end
    local home = getCurrentHome()
    if #employees >= home.possibleEmployees then
        showAlert("No open positions available")
        return
    end
    if isEmployeeHired(worker) then
        showAlert(worker.name .. " already hired")
        return
    end
    table.insert(employees, worker)
    showAlert("Hired " .. worker.name)
end

function fireEmployee(index)
    local worker = allWorkers[index]
    if not worker then return end
    for i, emp in ipairs(employees) do
        if emp == worker then
            table.remove(employees, i)
            showAlert("Fired " .. worker.name)
            return
        end
    end
end

function buildEmployeeUI()
    ui.clearButtons("employees")
    ui.addButton("employees", 20, 20, 100, 30, "Back", function()
        ui.setState("game")
    end)
    local y = 70
    for i, worker in ipairs(allWorkers) do
        local label = (isEmployeeHired(worker) and "Fire " or "Hire ") .. worker.name
        local idx = i
        ui.addButton("employees", 150, y, 200, 40, label, function()
            if isEmployeeHired(worker) then
                fireEmployee(idx)
            else
                hireEmployee(idx)
            end
            buildEmployeeUI()
        end)
        y = y + 50
    end
end


function love.load()
    loadingCoroutine = coroutine.create(function()
        -- Step 1: Setup UI
        loadingText = "Preparing UI..."
        coroutine.yield()
        ui.setTheme("dark")
        ui.newState("menu")
        ui.newState("game")
        ui.newState("employees")
        ui.setState("menu")

        -- Step 2: Build Buttons
        loadingText = "Creating menu..."
        coroutine.yield()
        ui.addButton("menu", 300, 200, 200, 60, "Start Game", function()
            gameState = "game"
            ui.setState("game")
        end)

        ui.addButton("menu", 300, 280, 200, 60, "Load Game", function()
            loadGame()
            gameState = "game"
            ui.setState("game")
        end)

        -- Step 3: Game Buttons
        loadingText = "Preparing game interface..."
        coroutine.yield()
        ui.addButton("game", 50, 50, 200, 40, "Buy Pound", function()
            local cost = ouncesPerPound * price
            if wallet >= cost then
                wallet = wallet - cost
                storage = storage + (gramsPerOunce * ouncesPerPound)
            else
                showAlert("Not enough funds to buy a pound")
            end
        end)

        ui.addButton("game", 50, 100, 200, 40, "Add Oz to Cart", function()
            cart.ounces = cart.ounces + 1
            cart.cost = cart.ounces * price
            cart.freeShipping = cart.cost >= 500
        end)

        ui.addButton("game", 50, 150, 200, 40, "Remove Oz from Cart", function()
            cart.ounces = cart.ounces - 1
            cart.cost = cart.ounces * price
            cart.freeShipping = cart.cost >= 500
        end)

        ui.addButton("game", 50, 200, 200, 40, "Place Order", function()
            if cart.ounces > 0 then
                local cost = cart.cost + (cart.freeShipping and 0 or shippingFees)
                if wallet >= cost then
                    wallet = wallet - cost
                    local deliveryIn = cart.expressShipping and 4 or 7
                    table.insert(cart.orders, {
                        ounces = cart.ounces,
                        cost = cost,
                        deliveryWeek = week + math.ceil(deliveryIn / 7),
                        delivered = false
                    })
                    table.insert(history, string.format("Ordered %d oz for $%d (Delivery in %d days)", cart.ounces,
                                                        cost, deliveryIn))
                    cart.ounces = 0
                    cart.cost = 0
                    cart.freeShipping = false
                    cart.expressShipping = false
                else
                    showAlert("Not enough funds to place order")
                end
            else
                showAlert("Cart is empty")
            end
        end)

        ui.addButton("game", 50, 250, 200, 40, "Save Game", function()
            saveGame()
            showAlert("Game saved")
        end)

        ui.addButton("game", 50, 300, 200, 40, "Manage Employees", function()
            buildEmployeeUI()
            ui.setState("employees")
        end)

        -- Step 4: Sell buttons
        loadingText = "Setting up pricing buttons..."
        coroutine.yield()
        local sellDefs = {{
            label = "Gram",
            amount = 1,
            key = "gram"
        }, {
            label = "Eighth",
            amount = gramsPerOunce / 8,
            key = "eighth"
        }, {
            label = "Quarter",
            amount = gramsPerOunce / 4,
            key = "quarter"
        }, {
            label = "Half Oz",
            amount = gramsPerOunce / 2,
            key = "halfOunce"
        }, {
            label = "Ounce",
            amount = gramsPerOunce,
            key = "ounce"
        }, {
            label = "Pound",
            amount = 454,
            key = "pound"
        }}

        for i, def in ipairs(sellDefs) do
            ui.addButton("game", 300, 30 + (i - 1) * 40, 200, 30,
                         "Sell " .. def.label .. " ($" .. prices[def.key] .. ")", function()
                if storage >= def.amount then
                    wallet = wallet + prices[def.key]
                    storage = storage - def.amount
                    table.insert(history, string.format("Sold %s for $%d", def.label, prices[def.key]))
                else
                    showAlert("Not enough inventory to sell " .. def.label)
                end
            end)
            loadingCurrent = loadingCurrent + 1
            loadingPercentage = (loadingCurrent / 14) * windowWidth / 2
            loadingText = string.format("Adding sell option: %s...", def.label)
            coroutine.yield()

        end
        loading = false
    end)
end

function love.update(dt)
    ui.update(dt)
    if loading and loadingCoroutine then
        local success, message = coroutine.resume(loadingCoroutine)
        if not success then
            print("Loading coroutine error: " .. tostring(message))
            loading = false
        end
    end

    if gameState == "game" then
        progressTime(dt)
        if alertTimer > 0 then
            alertTimer = alertTimer - dt
            if alertTimer <= 0 then
                alertMessage = ""
            end
        end
    end
end

local readyToQuit = false
function love.quit()
	if not readyToQuit then
        alertTimer = 3
        alertMessage = "You Should Save Your Progress"
		readyToQuit = true
		return true
	else
        alertTimer = 1
		alertMessage = "Thanks For Playing!"
        quittingTime = 1000 -- 1000 ms
        repeat
            quittingTime = quittingTime - (love.timer.getDelta() / 1000 --[[1000ns]])
        until quittingTime <= 0
		return false
	end
end

function formatMoney(amount)
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return "$" .. formatted
end

function formatStash(stashGrams)
    local gramsPerOunce = 28
    local ouncesPerPound = 16
    local gramsPerPound = gramsPerOunce * ouncesPerPound

    if stashGrams < gramsPerOunce then
        return string.format("%dg", math.floor(stashGrams + 0.5))
    elseif stashGrams < gramsPerPound then
        return string.format("%.2f oz", stashGrams / gramsPerOunce)
    else
        local pounds = stashGrams / gramsPerPound
        return string.format("%.2f lbs", pounds)
    end
end

function love.draw()
    if loading then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(loadingText, 0, (windowHeight / 4) * 3, windowWidth, "center")

        local barW = windowWidth / 2
        local barH = windowHeight / 16
        local barX = windowWidth / 4
        local barY = (windowHeight / 4) * 3 + 50

        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", barX, barY, barW, barH)

        love.graphics.setColor(0.6, 0.9, 0.3, 1)
        love.graphics.rectangle("fill", barX, barY, loadingPercentage, barH)

        return
    end
    ui.draw()
    if gameState == "game" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Wallet: " .. formatMoney(wallet), 550, 50)
        love.graphics.print("Storage: " .. formatStash(storage), 550, 70)
        love.graphics.print(string.format("Date: Year %d, Month %d, Day %d", year, month, day + (week * 7)), 550, 90)
        love.graphics.print(string.format("Time: %02d:%02d:%02d", hour, minute, second), 550, 110)
        love.graphics.print("Cart: " .. cart.ounces .. " oz ($" .. cart.cost .. ")", 550, 130)
        love.graphics.print("Shipping: " .. (cart.freeShipping and "Free" or "$" .. shippingFees), 550, 150)
        love.graphics.print("Express: " .. (cart.expressShipping and "Yes" or "No"), 550, 170)

        if alertMessage ~= "" then
            love.graphics.setColor(1, 0.2, 0.2, 1)
            love.graphics.print("ALERT: " .. alertMessage, 550, 190)
            love.graphics.setColor(1, 1, 1, 1)
        end

        local y = 210
        love.graphics.print("History:", 550, y)
        for i = math.max(1, #history - 20), #history do
            love.graphics.print(history[i], 550, y + (i - math.max(1, #history - 20) + 1) * 15)
        end
        y = y + (math.min(20, #history) + 2) * 15
        love.graphics.print("Employees:", 550, y)
        for i, emp in ipairs(employees) do
            love.graphics.print(emp.name .. " (" .. emp.role .. ")", 550, y + i * 15)
        end
    end
end
