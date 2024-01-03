grid = {}

WINDOW_WIDTH = 600
WINDOW_HEIGHT = WINDOW_WIDTH

GRID_SIZE = 60
CELL_SIZE = WINDOW_HEIGHT / GRID_SIZE

DEBUG_MODE = false
IS_GRID_ON = false

GAME_STATE = 'help'

-- This aproach is bad because of having maximum seconds and not miliseconds
SECONDS_BEFORE_STEP = 0.0125
PREV_TIME = os.time()

-- I will use this one instead
COUNTER = 0

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    
    love.window.setMode(
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        {
            fullscreen = false;
            vsync = true;
            resizable = true;
        }
    )
    
    love.window.setTitle('Game of Life Simulator. FPS: --')

    -- Font initialization
    headerFont = love.graphics.newFont('header.ttf', 50)
    regularFont = love.graphics.newFont('header.ttf', 25)


    -- Grid initialization with zeros (dead cells)
    for i=0, GRID_SIZE do
        grid[i] = {}
        for j=0, GRID_SIZE do
            grid[i][j] = 0
        end
    end

    -- You can place live cells below this text or just use the mouse on the grid
    -- grid[15][16] = 1
    -- grid[16][17] = 1               #
    -- grid[17][15] = 1                 #
    -- grid[17][16] = 1             # # # 
    -- grid[17][17] = 1     That's just an example
end

function love.update(dt)
    love.window.setTitle('Game of Life Simulator. FPS: ' .. tostring(love.timer.getFPS()))
    
    if GAME_STATE ~= 'help' then
        COUNTER = COUNTER + 1
        
        local mouseX, mouseY = love.mouse.getPosition()
        local cellX, cellY

        if love.mouse.isDown(1) then
            cellX, cellY = globalToCellCoordinates(mouseX, mouseY)
            grid[cellY][cellX] = 1
        elseif love.mouse.isDown(2) then
            cellX, cellY = globalToCellCoordinates(mouseX, mouseY)
            grid[cellY][cellX] = 0
        end

        if GAME_STATE == 'running' then
            if COUNTER > 10 then
                COUNTER = 0
                simulationStep()
            end
        end
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'return' then
        GAME_STATE = 'stopped'
    elseif key == 'space' then
        GAME_STATE = GAME_STATE == 'stopped' and 'running' or 'stopped'
    elseif key == 'd' then
        DEBUG_MODE = DEBUG_MODE == false and true or false
    elseif key == 'g' then
        IS_GRID_ON = IS_GRID_ON == false and true or false
    elseif key == 'r' then
        resetGrid()
    end
end

function love.draw()
    if DEBUG_MODE == true then
        love.graphics.clear(100/255, 100/255, 100/255, 255/255)
    else
        love.graphics.clear(255/255, 255/255, 255/255, 255/255)
    end

    if GAME_STATE == 'help' then
        love.graphics.setColor(0/255, 0/255, 0/255, 255/255)
        
        local rectWidth = WINDOW_WIDTH - 2 * 10
        local rectHeight = WINDOW_HEIGHT / 2 - 10

        love.graphics.rectangle(
            'line',
            10,
            10,
            rectWidth,
            rectHeight
        )

        love.graphics.setFont(headerFont)

        love.graphics.printf(
            'Game of Life Simulator',
            10,
            10,
            rectWidth,
            'center'
        )

        love.graphics.setFont(regularFont)

        love.graphics.printf(
            'Controls:\n\'D\'\t-\tTurn on/off debug mode\n\'G\'\t-\tTurn on/off grid\n\'R\'\t-\tRestart grid\n\'Space\'\t-\tTurn on/off simulation (stopped by default)\n\nPress \'Enter\' to hide this message',
            15,
            75,
            rectWidth,
            'left'
        )
    else
        -- Render cells
        local x = 0
        local y = 0

        for i=0, GRID_SIZE do
            for j=0, GRID_SIZE do
                local neighboors = countNeighboors(i, j)

                if grid[i][j] == 1 then
                    love.graphics.setColor(0/255, 0/255, 0/255, 255/255)
                    
                    love.graphics.rectangle(
                        'fill',
                        x,
                        y,
                        CELL_SIZE,
                        CELL_SIZE
                    )
            
                    if DEBUG_MODE == true then
                        -- Print on the cell count of it's neighboors
                        love.graphics.setColor(255/255, 255/255, 255/255, 255/255)

                        local textX, textY = cellToGlobalCoordinates(j, i)
                        love.graphics.printf(
                            tostring(countNeighboors(i, j)),
                            textX,
                            textY,
                            CELL_SIZE,
                            'left'
                        )
                    end

                else
                    -- Pink cell shows that it will be alive on the next step
                    if DEBUG_MODE == true and neighboors == 3 then
                        love.graphics.setColor(255/255, 0/255, 255/255, 255/255)
                        
                        love.graphics.rectangle(
                            'fill',
                            x,
                            y,
                            CELL_SIZE,
                            CELL_SIZE
                        )
                    else
                        love.graphics.setColor(0/255, 0/255, 0/255, 255/255)
                        
                        if IS_GRID_ON == true then
                            love.graphics.rectangle(
                                'line',
                                x,
                                y,
                                CELL_SIZE,
                                CELL_SIZE
                            )
                        else
                            love.graphics.setColor(255/255, 255/255, 255/255, 255/255)

                            love.graphics.rectangle(
                                'fill',
                                x,
                                y,
                                CELL_SIZE,
                                CELL_SIZE
                            )
                        end
                    end

                    if DEBUG_MODE == true then
                        -- Print on the cell count of it's neighboors
                        love.graphics.setColor(0/255, 0/255, 0/255, 255/255)

                        local textX, textY = cellToGlobalCoordinates(j, i)
                        love.graphics.printf(
                            tostring(countNeighboors(i, j)),
                            textX,
                            textY,
                            CELL_SIZE,
                            'left'
                        )
                    end
                end

                x = x + CELL_SIZE
            end

            x = 0
            y = y + CELL_SIZE
        end
    end
end

function simulationStep()
    --[[
        The Game of Life rules:
            - Live cell:
                - Stays alive if has 2 or 3 neighboors
                - Dies if has < 2 or > 3 neighboors
            - Dead cell:
                - Becomes alive if has 3 neighboors
                - Stays dead otherwise 
    --]]    

    local newGrid = {}
    for i=0, GRID_SIZE do
        newGrid[i] = {}
        for j=0, GRID_SIZE do
            newGrid[i][j] = 0
        end
    end

    for i=0, GRID_SIZE do
        for j=0, GRID_SIZE do
            local neighboors = countNeighboors(i, j)

            -- If alive
            if grid[i][j] == 1 then
                if neighboors < 2 or neighboors > 3 then
                    newGrid[i][j] = 0
                else
                    newGrid[i][j] = 1
                end
            else
                if neighboors == 3 then
                    newGrid[i][j] = 1
                end
            end
        end
    end

    for i=0, GRID_SIZE do
        for j=0, GRID_SIZE do
            grid[i][j] = newGrid[i][j]
        end
    end
end

function countNeighboors(i, j)
    count = 0

    startI = math.max(0, i - 1)
    startJ = math.max(0, j - 1)
    endI = math.min(GRID_SIZE, i + 1)
    endJ = math.min(GRID_SIZE, j + 1)

    for m=startI, endI do
        for n=startJ, endJ do
            count = count + grid[m][n]
        end
    end

    -- Deleting our central cell value because it can't be it's neighboor
    count = count - grid[i][j]

    return count
end

function globalToCellCoordinates(x, y)
    local cellX = 0
    local cellY = 0

    -- Converting global to cell coordinates
    for i=0, GRID_SIZE do
        for j=0, GRID_SIZE do
            if x >= j * CELL_SIZE and x <= j * CELL_SIZE + CELL_SIZE then
                if y >= i * CELL_SIZE and y <= i * CELL_SIZE + CELL_SIZE then
                    cellX = j
                    cellY = i
                    break
                end
            end
        end
    end

    return cellX, cellY
end

function cellToGlobalCoordinates(x, y)
    local globalX = 0
    local globalY = 0

    globalX = x * CELL_SIZE
    globalY = y * CELL_SIZE

    return globalX, globalY
end

function resetGrid()
    GAME_STATE = 'stopped'
    
    for i=0, GRID_SIZE do
        for j=0, GRID_SIZE do
            grid[i][j] = 0
        end
    end
end
