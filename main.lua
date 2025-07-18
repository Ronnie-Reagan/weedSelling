-- ui_economy_game/main.lua
local ui = require("ui")
love.mousepressed = ui.mousePressed
love.mousereleased = ui.mouseReleased
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
        monthlyCost = 2410, -- dollars
        possibleEmployees = 1 -- the cool friend
    },
    [3] = {
        screenName = "Small Apartment",
        internalName = "apartment1",
        upfrontCost = 8000,
        monthlyCost = 1000,
        possibleEmployees = 2
    },
    [4] = {
        screenName = "Suburban House",
        internalName = "house1",
        upfrontCost = 20000,
        monthlyCost = 2500,
        possibleEmployees = 3
    }
}

local player = {
    wallet = 50, -- dollars
    stash = 3.5, -- grams
    rentOwed = 0, -- backpay for rent
    life = {
        house = "basement1" -- homes[1].internalName

    }
}

local allWorkers = {
    [1] = {
        name = "James", -- screen name and system name
        role = "dealer", -- internal name
        rank = "Addict", -- screen name and system name
        personality = {
            nice = 0.8,
            mean = 0.1,
            neutral = 0.1
        },
        payroll = {
            cut = 0.12 -- 12% of their sales
        },
        loyalty = {
            limit = 0.2,
            current = 0.0
        },
        work = {
            stash = 0,
            stashLimit = 28,
            sellPrice = 20,
            paymentInterval = 7,
            sellSpeed = 28 / 7,
            arrestRisk = 0.02,
            bailCost = 200,
            daysToPay = 0,
            pendingMoney = 0
        }
    },
    [2] = {
        name = "Tom",
        role = "dealer",
        rank = "Runner",
        personality = {
            nice = 0.6,
            mean = 0.2,
            neutral = 0.2
        },
        payroll = {
            cut = 0.15
        },
        loyalty = {
            limit = 0.15,
            current = 0.0
        },
        work = {
            stash = 0,
            stashLimit = 112, -- quarter pound
            sellPrice = 18,
            paymentInterval = 14,
            sellSpeed = 112 / 14,
            arrestRisk = 0.03,
            bailCost = 300,
            daysToPay = 0,
            pendingMoney = 0
        }
    },
    [3] = {
        name = "Big Mike",
        role = "dealer",
        rank = "Distributor",
        personality = {
            nice = 0.4,
            mean = 0.4,
            neutral = 0.2
        },
        payroll = {
            cut = 0.20
        },
        loyalty = {
            limit = 0.1,
            current = 0.0
        },
        work = {
            stash = 0,
            stashLimit = 454, -- pound
            sellPrice = 15,
            paymentInterval = 30,
            sellSpeed = 454 / 30,
            arrestRisk = 0.05,
            bailCost = 500,
            daysToPay = 0,
            pendingMoney = 0
        }
    }
}

local employees = {} -- no employees

-- start remove
local price = 40
-- end remove


local autoSave = {
    active = true,
    saveTimer = 0,
    interval = 300 -- every five minutes
}

local ouncesPerPound = 16
local gramsPerOunce = 28
local sellOunceFor = 150
local timeScale = (60 * 60) -- MUST find an alternative, possibly let user define it
local second, minute, hour, day, week, month, year = 0, 0, 0, 0, 0, 0, 0
local gameState = "menu"
local previousState = nil
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
local alertQueue = {}
local currentAlert = nil
hudLabels = {}

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
        player = player,
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
        savedTimestamp = utcTime,
        rentOwed = player.rentOwed,
        employees = employees
    }
    local serialized = serializeTable(saveData)
    local encoded = love.data.encode("string", "base64", serialized)
    local success, msg = love.filesystem.write(saveFileName, encoded)
    if not success then
        print("Failed to save game: " .. tostring(msg))
    else
        showAlert("Game Saved")
        if autoSave.active == true then
            autoSave.saveTimer = love.timer.getTime()
        end
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

            player = data.player or {
                wallet = 50, -- dollars
                stash = 3.5, -- grams
                rentOwed = 0, -- backpay for rent
                life = {
                    house = "basement1" -- homes[1].internalName

                }
            }
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
            employees = data.employees or employees
            player.rentOwed = data.rentOwed or 0

            if data.savedTimestamp then
                loadingText = "Attempting to fetch UTC time"
                coroutine.yield()
                local currentTimestamp = fetchCurrentUTCTime() or os.time(os.date("!*t"))
                local elapsed = currentTimestamp - data.savedTimestamp
                if elapsed > 0 then
                    updateTimeByElapsed(elapsed) -- no time speed up for returning players
                end
            end

            loadingText = "Finishing Up..."
            coroutine.yield()
        else
            print("No save file found.")
        end

        loading = false
        if ui.states["stash"] then
            buildStashUI()
            ui.setState("stash")
        end
        gameState = "game"
    end)
end

function showAlert(msg)
    table.insert(alertQueue, {msg = msg, timer = 3})
    if not currentAlert then
        currentAlert = table.remove(alertQueue, 1)
    end
end

local function ensureHudLabels(state)
    if hudLabels[state] then return end
    hudLabels[state] = {history = {}, employees = {}}

    local labelWidth, labelHeight = 230, 15
    local xCenter = windowWidth / 2 - labelWidth / 2
    local topY = 50
    local spacingY = 20

    local function addHudLabel(key, y)
        ui.addLabel(state, xCenter, y, labelWidth, labelHeight, "")
        hudLabels[state][key] = #ui.states[state].labels
    end

    addHudLabel("wallet", topY)
    addHudLabel("stash", topY + spacingY)
    addHudLabel("date", topY + spacingY * 2)
    addHudLabel("time", topY + spacingY * 3)
    addHudLabel("cart", topY + spacingY * 4)
    addHudLabel("shipping", topY + spacingY * 5)
    addHudLabel("express", topY + spacingY * 6)
    addHudLabel("home", topY + spacingY * 7)
    addHudLabel("alert", topY + spacingY * 8)

    local historyStartY = topY + spacingY * 9
    ui.addLabel(state, xCenter, historyStartY, labelWidth, labelHeight, "History:")
    hudLabels[state].historyHeader = #ui.states[state].labels
    for i = 1, 20 do
        ui.addLabel(state, xCenter, historyStartY + i * labelHeight, labelWidth, labelHeight, "")
        table.insert(hudLabels[state].history, #ui.states[state].labels)
    end

    local employeeStartY = 10
    ui.addLabel(state, xCenter + 150, employeeStartY, labelWidth, labelHeight, "Employees:")
    hudLabels[state].employeesHeader = #ui.states[state].labels
    for i = 1, 10 do
        ui.addLabel(state, xCenter + 150, employeeStartY + i * labelHeight, labelWidth, labelHeight, "")
        table.insert(hudLabels[state].employees, #ui.states[state].labels)
    end
end


local function updateHudLabels()
    for state, ids in pairs(hudLabels) do
        ui.updateLabelText(state, ids.wallet, "Wallet: " .. formatMoney(player.wallet))
        ui.updateLabelText(state, ids.stash, "player.stash: " .. formatStash(player.stash))
        ui.updateLabelText(state, ids.date,
            string.format("Date: Year %d, Month %d, Day %d", year, month, day + (week * 7)))
        ui.updateLabelText(state, ids.time,
            string.format("Time: %02d:%02d:%02d", hour, minute, second))
        ui.updateLabelText(state, ids.cart, "Cart: " .. cart.ounces .. " oz ($" .. cart.cost .. ")")
        ui.updateLabelText(state, ids.shipping, "Shipping: " .. (cart.freeShipping and "Free" or "$" .. shippingFees))
        ui.updateLabelText(state, ids.express, "Express: " .. (cart.expressShipping and "Yes" or "No"))
        local home = getCurrentHome()
        if home then
            ui.updateLabelText(state, ids.home, "Home: " .. home.screenName)
        else
            ui.updateLabelText(state, ids.home, "Home: N/A")
        end
        if currentAlert then
            ui.updateLabelText(state, ids.alert, "ALERT: " .. currentAlert.msg)
        else
            ui.updateLabelText(state, ids.alert, "")
        end

        -- history
        local histStart = math.max(1, #history - #ids.history + 1)
        for i = 1, #ids.history do
            local msg = history[histStart + i - 1]
            ui.updateLabelText(state, ids.history[i], msg or "")
        end

        -- employees
        for i = 1, #ids.employees do
            local emp = employees[i]
            local text = emp and (emp.name .. " (" .. emp.role .. ")") or ""
            ui.updateLabelText(state, ids.employees[i], text)
        end
    end
end

local function updateAlerts(dt)
    if currentAlert then
        currentAlert.timer = currentAlert.timer - dt
        if currentAlert.timer <= 0 then
            currentAlert = table.remove(alertQueue, 1)
        end
    end
end

local function updateEmployeesDaily()
    for _, emp in ipairs(employees) do
        local w = emp.work
        if w then
            -- restock if empty
            if w.stash <= 0 then
                local take = math.min(w.stashLimit, player.stash)
                if take > 0 then
                    w.stash = take
                    player.stash = player.stash - take
                    w.daysToPay = w.paymentInterval
                    table.insert(history, string.format("Gave %s %s to sell", emp.name, formatStash(take)))
                end
            end

            if w.stash > 0 then
                -- chance of arrest
                if math.random() < (w.arrestRisk or 0) then
                    local bail = w.bailCost or 0
                    if player.wallet >= bail then
                        player.wallet = player.wallet - bail
                        table.insert(history, string.format("Bailed out %s for %s", emp.name, formatMoney(bail)))
                    else
                        table.insert(history, string.format("%s arrested and you couldn't afford bail", emp.name))
                    end
                end

                -- daily sales
                local sold = math.min(w.sellSpeed, w.stash)
                w.stash = w.stash - sold
                w.pendingMoney = w.pendingMoney + sold * w.sellPrice
                w.daysToPay = w.daysToPay - 1

                if w.daysToPay <= 0 or w.stash <= 0 then
                    local payout = w.pendingMoney * (1 - (emp.payroll.cut or 0))
                    if payout > 0 then
                        player.wallet = player.wallet + payout
                        table.insert(history, string.format("%s paid you %s", emp.name, formatMoney(payout)))
                    end
                    w.pendingMoney = 0
                    w.daysToPay = 0
                end
            end
        end
    end
end

local function payMonthlyCosts()
    local home = getCurrentHome()
    if not home then
        return
    end

    player.rentOwed = (player.rentOwed or 0) + home.monthlyCost
    local payment = 0
    if player.wallet > 0 then
        payment = math.min(player.wallet, player.rentOwed)
        player.wallet = player.wallet - payment
        player.rentOwed = player.rentOwed - payment
    end

    table.insert(history,
                 string.format("Paid $%d toward rent for %s (Owed: $%d)", payment, home.screenName, player.rentOwed))

    if player.rentOwed > 0 then
        showAlert("Rent overdue! Owed $" .. player.rentOwed)
    end
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
        updateEmployeesDaily()
    end
    if day == 7 then
        day = 0
        week = week + 1
    end
    if week >= 4 then
        week = 0;
        month = month + 1
        payMonthlyCosts()
    end
    if month >= 12 then
        month = 0;
        year = year + 1
    end

    for _, orderData in ipairs(cart.orders) do
        if not orderData.delivered and orderData.deliveryWeek and week >= orderData.deliveryWeek and hour >=
            deliveryTime then
            player.stash = player.stash + gramsPerOunce * orderData.ounces
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
    if selectedHome == nil then
        return error("failed to find the home in the list", 2)
    end
    local upfront = selectedHome.upfrontCost
    if player.wallet < upfront then
        showAlert(string.format("INSUFFICIENT FUNDS -$%d", upfront - player.wallet))
        return
    end
    if selectedHome.possibleEmployees < currentHome.possibleEmployees then
        if #employees > selectedHome.possibleEmployees then
            showAlert(string.format("Too many employees to downgrade, fire %d",
                                    #employees - selectedHome.possibleEmployees))
            return
        end
    end
    player.life.house = selectedHome.internalName
    player.wallet = player.wallet - selectedHome.upfrontCost
    showAlert(string.format("Home Rented, open positions: %d", selectedHome.possibleEmployees))
end

local function setupHomesUI()
    ui.newState("homes")
    for i, home in ipairs(homes) do
        local label = string.format("%s - $%d upfront, $%d/mo (%d employees)%s", home.screenName, home.upfrontCost,
                                    home.monthlyCost, home.possibleEmployees,
                                    home.internalName == player.life.house and " [Current]" or "")
        ui.addButton("homes", 50, 20 + (i - 1) * 80, 475, 75, label, function()
            if home.internalName ~= player.life.house then
                buyHome(home.internalName)
                setupHomesUI()
            end
        end)
    end
    ui.addButton("homes", 50, 60 + (#homes) * 80, 200, 40, "Back", function()
        buildStashUI()
        ui.setState("stash")
    end)
    ensureHudLabels("homes")
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
    if not worker then
        return
    end
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
    if not worker then
        return
    end
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
        buildStashUI()
        ui.setState("stash")
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
    ensureHudLabels("employees")
end

function buildStashUI()
    ui.clearButtons("stash")
    ui.addButton("stash", 20, 20, 150, 40, "Streets", function()
        buildStreetsUI()
        ui.setState("streets")
    end)
    ui.addButton("stash", 20, 70, 150, 40, "Shop", function()
        buildShopUI()
        ui.setState("shop")
    end)
    ui.addButton("stash", 20, 120, 150, 40, "Homes", function()
        setupHomesUI()
        ui.setState("homes")
    end)
    ui.addButton("stash", 20, 170, 150, 40, "Employees", function()
        buildEmployeeUI()
        ui.setState("employees")
    end)
    ui.addButton("stash", 20, 220, 150, 40, "Pause", function()
        enterPause()
    end)
    ui.addToggle("stash", 200, 220, 80, 40, "AutoSave", function()
        autoSave.active = not autoSave.active
    end, {autoSave.active})
    ensureHudLabels("stash")
end

function buildStreetsUI()
    ui.clearButtons("streets")
    ui.addButton("streets", 20, 20, 100, 30, "Back", function()
        buildStashUI()
        ui.setState("stash")
    end)
    local sellDefs = {
        {label="Gram",amount=1,key="gram"},
        {label="Eighth",amount=gramsPerOunce/8,key="eighth"},
        {label="Quarter",amount=gramsPerOunce/4,key="quarter"},
        {label="Half Oz",amount=gramsPerOunce/2,key="halfOunce"},
        {label="Ounce",amount=gramsPerOunce,key="ounce"},
        {label="Pound",amount=454,key="pound"}
    }
    for i,def in ipairs(sellDefs) do
        ui.addButton("streets", 150, 20 + (i-1)*40, 200, 30,
            "Sell "..def.label.." ($"..prices[def.key]..")", function()
                if player.stash >= def.amount then
                    player.wallet = player.wallet + prices[def.key]
                    player.stash = player.stash - def.amount
                    table.insert(history, string.format("Sold %s for $%d", def.label, prices[def.key]))
                else
                    showAlert("Not enough inventory to sell " .. def.label)
                end
            end)
    end
    ensureHudLabels("streets")
end

function buildShopUI()
    ui.clearButtons("shop")
    ui.addButton("shop", 20, 20, 100, 30, "Back", function()
        buildStashUI()
        ui.setState("stash")
    end)
    ui.addButton("shop", 50, 60, 200, 40, "Buy Pound", function()
        local cost = ouncesPerPound * price
        if player.wallet >= cost then
            player.wallet = player.wallet - cost
            player.stash = player.stash + (gramsPerOunce * ouncesPerPound)
        else
            showAlert("Not enough funds to buy a pound")
        end
    end)
    ui.addButton("shop", 50, 110, 200, 40, "Add Oz to Cart", function()
        cart.ounces = cart.ounces + 1
        cart.cost = cart.ounces * price
        cart.freeShipping = cart.cost >= 500
    end)
    ui.addButton("shop", 50, 160, 200, 40, "Remove Oz from Cart", function()
        cart.ounces = math.max(0, cart.ounces - 1)
        cart.cost = cart.ounces * price
        cart.freeShipping = cart.cost >= 500
    end)
    ui.addButton("shop", 50, 210, 200, 40, "Place Order", function()
        if cart.ounces > 0 then
            local cost = cart.cost + (cart.freeShipping and 0 or shippingFees)
            if player.wallet >= cost then
                player.wallet = player.wallet - cost
                local deliveryIn = cart.expressShipping and 4 or 7
                table.insert(cart.orders, {
                    ounces = cart.ounces,
                    cost = cost,
                    deliveryWeek = week + math.ceil(deliveryIn / 7),
                    delivered = false
                })
                table.insert(history, string.format("Ordered %d oz for $%d (Delivery in %d days)", cart.ounces, cost, deliveryIn))
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
    ensureHudLabels("shop")
end

function buildPauseUI()
    ui.clearButtons("pause")
    ui.addButton("pause", 300, 200, 200, 40, "Resume", function()
        ui.setState(previousState or "stash")
    end)
    ui.addButton("pause", 300, 250, 200, 40, "Save Game", function()
        saveGame()
    end)
    ui.addButton("pause", 300, 300, 200, 40, "Main Menu", function()
        gameState = "menu"
        buildMenuUI()
        ui.setState("menu")
    end)
    ensureHudLabels("pause")
end

function buildMenuUI()
    ui.clearButtons("menu")
    ui.addButton("menu", 300, 200, 200, 60, "Start Game", function()
        gameState = "game"
        buildStashUI()
        ui.setState("stash")
    end)
    ui.addButton("menu", 300, 280, 200, 60, "Load Game", function()
        buildLoadUI()
        ui.setState("load")
    end)
end

function buildLoadUI()
    ui.clearButtons("load")
    ui.addButton("load", 20, 20, 100, 30, "Back", function()
        ui.setState("menu")
    end)
    local items = love.filesystem.getDirectoryItems("")
    local y = 60
    for _, file in ipairs(items) do
        if file:match("%.Don$") then
            local fname = file
            ui.addButton("load", 150, y, 200, 40, fname, function()
                saveFileName = fname
                loadGame()
                gameState = "game"
                buildStashUI()
                ui.setState("stash")
            end)
            y = y + 50
        end
    end
end

function enterPause()
    previousState = ui.currentState
    buildPauseUI()
    ui.setState("pause")
end

function love.load()
    loadingCoroutine = coroutine.create(function()
        loadingText = "Preparing UI..."
        coroutine.yield()
        ui.setTheme("dark")
        ui.newState("menu")
        ui.newState("stash")
        ui.newState("streets")
        ui.newState("shop")
        ui.newState("homes")
        ui.newState("employees")
        ui.newState("pause")
        ui.newState("load")
        ui.setState("menu")
        setupHomesUI()
        buildMenuUI()
        buildStashUI()
        buildStreetsUI()
        buildShopUI()
        buildPauseUI()
        buildLoadUI()
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
        updateAlerts(dt)
        updateHudLabels()
        if autoSave.active == true then
            autoSave.saveTimer = autoSave.saveTimer + dt
            if autoSave.saveTimer >= autoSave.interval then
                saveGame()
                autoSave.saveTimer = autoSave.saveTimer - autoSave.interval
                showAlert("Auto Save Complete")
            end
        end
    end
end

function love.keypressed(key)
    if gameState == "game" and key == "escape" then
        if ui.currentState ~= "pause" then
            enterPause()
        else
            ui.setState(previousState or "stash")
        end
    end
end

local readyToQuit = false
function love.quit()

    -- check if theres autosave and it recently saved (half the autosave interval or in the past minute if not autosaving)
    if autoSave.active and autoSave.saveTimer < (autoSave.interval / 2) or love.timer.getTime() - autoSave.saveTimer < 60 then
        return false
    end
    if not readyToQuit then
        showAlert("You Should Save Your Progress")
        readyToQuit = true
        return true
    else
        showAlert("Thanks For Playing!")
        return false
    end
end

function formatMoney(amount)
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then
            break
        end
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
        --love.graphics.setColor(1, 1, 1, 1)
        --love.graphics.print("Wallet: " .. formatMoney(player.wallet), 550, 50)
        --love.graphics.print("player.stash: " .. formatStash(player.stash), 550, 70)
        --love.graphics.print(string.format("Date: Year %d, Month %d, Day %d", year, month, day + (week * 7)), 550, 90)
        --love.graphics.print(string.format("Time: %02d:%02d:%02d", hour, minute, second), 550, 110)
        --love.graphics.print("Cart: " .. cart.ounces .. " oz ($" .. cart.cost .. ")", 550, 130)
        --love.graphics.print("Shipping: " .. (cart.freeShipping and "Free" or "$" .. shippingFees), 550, 150)
        --love.graphics.print("Express: " .. (cart.expressShipping and "Yes" or "No"), 550, 170)
        --local home = getCurrentHome()
        --if home then
        --    love.graphics.print("Home: " .. home.screenName, 550, 190)
        --end
        --if currentAlert then
        --    love.graphics.setColor(1, 0.2, 0.2, 1)
        --    love.graphics.print("ALERT: " .. currentAlert.msg, 550, 210)
        --    love.graphics.setColor(1, 1, 1, 1)
        --end
--
        --local y = 230
        --love.graphics.print("History:", 550, y)
        --for i = math.max(1, #history - 20), #history do
        --    love.graphics.print(history[i], 550, y + (i - math.max(1, #history - 20) + 1) * 15)
        --end
        --y = 10
        --love.graphics.print("Employees:", 550, y)
        --for i, emp in ipairs(employees) do
        --    love.graphics.print(emp.name .. " (" .. emp.role .. ")", 550, y + i * 15)
        --end
    end
end
