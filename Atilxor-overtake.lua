-- Comments Translated


-- VERY IMPORTANT TO REMEMBER! **
-- Author: Atilxor
-- VERY IMPORTANT TO REMEMBER! **

local requiredSpeed = 95

-- prepare function to execute before the main start
function script.prepare(dt)
    -- Display the player's car speed in the dedicated console
    ac.debug("speed", ac.getCarState(1).speedKmh)
    -- Check the condition to continue execution
    return ac.getCarState(1).speedKmh > 60
end

-- Event status:
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore = 0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0

-- update function to execute at each frame
function script.update(dt)
    -- If the elapsed time is zero, the message "Let's start!" is displayed
    if timePassed == 0 then
        addMessage("Let's start!", 0)
    end

    -- Get the player's car status
    local player = ac.getCarState(1)

    -- If engineLifeLeft is less than 1
    if player.engineLifeLeft < 1 then
        -- If the total score is greater than the highest recorded score, the highest score is calculated correctly
        if totalScore > highestScore then
            highestScore = math.floor(totalScore)
            -- Send a chat message to the game with the score and text
            ac.sendChatMessage("Scored " .. totalScore .. " points.")
        end
        -- The total score is reset to zero, and the engineLifeLeft is restored to the initial state
        totalScore = 0
        comboMeter = 1
        return
    end

    -- Increase elapsed time by the amount of time passed since the last frame
    timePassed = timePassed + dt

    -- Calculate the combo decay rate based on elapsed time and car speed
    local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

    -- Get the game simulator state
    local sim = ac.getSimState()

    -- Increase the number of cars to match the number of car states in the cars array
    while sim.carsCount > #carsState do
        carsState[#carsState + 1] = {}
    end

    -- If the wheels warning timeout is greater than zero, decrease it
    if wheelsWarningTimeout > 0 then
        wheelsWarningTimeout = wheelsWarningTimeout - dt
    elseif player.wheelsOutside > 0 then
        -- If the car's wheels are off the track, display a warning message
        if wheelsWarningTimeout == 0 then
        end
        addMessage("The car is off the track", -1)
        wheelsWarningTimeout = 60
    end

    if player.speedKmh < requiredSpeed then
        if dangerouslySlowTimer > 3 then
            if totalScore > highestScore then
                highestScore = math.floor(totalScore)
                ac.sendChatMessage("Scored " .. totalScore .. " points.")
            end
            totalScore = 0
            comboMeter = 1
        else
            if dangerouslySlowTimer == 0 then
                addMessage("Increase your speed!", -1)
            end
        end
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        return
    else
        dangerouslySlowTimer = 0
    end

    for i = 1, ac.getSimState().carsCount do
        local car = ac.getCarState(i)
        local state = carsState[i]

        if car.pos:closerToThan(player.pos, 10) then
            local drivingAlong = math.dot(car.look, player.look) > 0.2
            if not drivingAlong then
                state.drivingAlong = false

                if not state.nearMiss and car.pos:closerToThan(player.pos, 3) then
                    state.nearMiss = true

                    if car.pos:closerToThan(player.pos, 2.5) then
                        comboMeter = comboMeter + 3
                        addMessage("Very close near miss!", 1)
                    else
                        comboMeter = comboMeter + 1
                        addMessage("Near miss: bonus combo", 0)
                    end
                end
            end

            if car.collidedWith == 0 then
                addMessage("Collision", -1)
                state.collided = true

                if totalScore > highestScore then
                    highestScore = math.floor(totalScore)
                    ac.sendChatMessage("Scored " .. totalScore .. " points.")
                end
                totalScore = 0
                comboMeter = 1
            end

            if not state.overtaken and not state.collided and state.drivingAlong then
                local posDir = (car.pos - player.pos):normalize()
                local posDot = math.dot(posDir, car.look)
                state.maxPosDot = math.max(state.maxPosDot, posDot)
                if posDot < -0.5 and state.maxPosDot > 0.5 then
                    totalScore = totalScore + math.ceil(10 * comboMeter)
                    comboMeter = comboMeter + 1
                    comboColor = comboColor + 90
                    addMessage("Overtake", comboMeter > 20 and 1 or 0)
                    state.overtaken = true
                end
            end
        else
            state.maxPosDot = -1
            state.overtaken = false
            state.collided = false
            state.drivingAlong = true
            state.nearMiss = false
        end
    end
end

local messages = {}
local glitter = {}
local glitterCount = 0

function addMessage(text, mood)
    for i = math.min(#messages + 1, 4), 2, -1 do
        messages[i] = messages[i - 1]
        messages[i].targetPos = i
    end
    messages[1] = {text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood}
    if mood == 1 then
        for i = 1, 60 do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
            glitterCount = glitterCount + 1
            glitter[glitterCount] = {
                color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
                pos = vec2(80, 140) + dir * vec2(40, 20),
                velocity = dir:normalize():scale(0.2 + math.random()),
                life = 0.5 + 0.5 * math.random()
            }
        end
    end
end

local function updateMessages(dt)
    comboColor = comboColor + dt * 10 * comboMeter
    if comboColor > 360 then
        comboColor = comboColor - 360
    end
    for i = 1, #messages do
        local m = messages[i]
        m.age = m.age + dt
        m.currentPos = math.applyLag(m.currentPos, m.targetPos, 0.8, dt)
    end
    for i = glitterCount, 1, -1 do
        local g = glitter[i]
        g.pos:add(g.velocity)
        g.velocity.y = g.velocity.y + 0.02
        g.life = g.life - dt
        g.color.mult = math.saturate(g.life * 4)
        if g.life < 0 then
            if i < glitterCount then
                glitter[i] = glitter[glitterCount]
            end
            glitterCount = glitterCount - 1
        end
    end
    if comboMeter > 10 and math.random() > 0.98 then
        for i = 1, math.floor(comboMeter) do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
            glitterCount = glitterCount + 1
            glitter[glitterCount] = {
                color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
                pos = vec2(195, 75) + dir * vec2(40, 20),
                velocity = dir:normalize():scale(0.2 + math.random()),
                life = 0.5 + 0.5 * math.random()
            }
        end
    end
end

local speedWarning = 0
function script.drawUI()
    local uiState = ac.getUiState()
    updateMessages(uiState.dt)

    local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
    speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

    local colorDark = rgbm(0.4, 0.4, 0.4, 1)
    local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
    local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
    local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

    local function speedMeter(ref)
        ui.drawRectFilled(ref + vec2(0, -4), ref + vec2(180, 5), colorDark, 1)
        ui.drawLine(ref + vec2(0, -4), ref + vec2(0, 4), colorGrey, 1)
        ui.drawLine(ref + vec2(requiredSpeed, -4), ref + vec2(requiredSpeed, 4), colorGrey, 1)

        local speed = math.min(ac.getCarState(1).speedKmh, 180)
        if speed > 1 then
            ui.drawLine(ref + vec2(0, 0), ref + vec2(speed, 0), colorAccent, 4)
        end
    end

    ui.beginTransparentWindow("overtakeScore", vec2(100, 100), vec2(400 * 0.5, 400 * 0.5))
    ui.beginOutline()

    ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
    ui.pushFont(ui.Font.Main)
    ui.text('Made By Atilxor\'')
    ui.text("Highest Score: " .. highestScore .. " pts")
    ui.popFont()
    ui.popStyleVar()

    ui.pushFont(ui.Font.Title)
    ui.text(totalScore .. " pts")
    ui.sameLine(0, 20)
    ui.beginRotation()
    ui.textColored(math.ceil(comboMeter * 10) / 10 .. "x", colorCombo)
    if comboMeter > 20 then
        ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
    end
    ui.popFont()
    ui.endOutline(rgbm(0, 0, 0, 0.3))

    ui.offsetCursorY(20)
    ui.pushFont(ui.Font.Main)
    local startPos = ui.getCursor()
    for i = 1, #messages do
        local m = messages[i]
        local f = math.saturate(4 - m.currentPos) * math.saturate(8 - m.age)
        ui.setCursor(startPos + vec2(20 * 0.5 + math.saturate(1 - m.age * 10) ^ 2 * 50, (m.currentPos - 1) * 15))
        ui.textColored(
            m.text,
            m.mood == 1 and rgbm(0, 1, 0, f) or m.mood == -1 and rgbm(1, 0, 0, f) or rgbm(1, 1, 1, f)
        )
    end
    for i = 1, glitterCount do
        local g = glitter[i]
        if g ~= nil then
            ui.drawLine(g.pos, g.pos + g.velocity * 4, g.color, 2)
        end
    end
    ui.popFont()
    ui.setCursor(startPos + vec2(0, 4 * 30))

    ui.pushStyleVar(ui.StyleVar.Alpha, speedWarning)
    ui.setCursorY(0)
    ui.pushFont(ui.Font.Main)
    ui.textColored("Keep speed above " .. requiredSpeed .. " km/h:", colorAccent)
    speedMeter(ui.getCursor() + vec2(-9 * 0.5, 4 * 0.2))

    ui.popFont()
    ui.popStyleVar()

    ui.endTransparentWindow()
end
