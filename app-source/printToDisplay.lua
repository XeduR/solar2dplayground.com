--==============================================================================
-- Important! Important! Important! Important! Important! Important! Important!
--==============================================================================
-- If you want to make changes to this module and you need to use debug prints,
-- then make sure to use "_print()" inside the functions because using "print()"
-- inside the wrong function will result in an infinite loop.
--==============================================================================

-- NB!  This version of printToDisplay is outdated and heavily modified for use with Solar2D Playground
--      and as such it shouldn't be used in other projects (unless you want to start modifying it yourself).
--      If you wish to use printToDisplay in your projects, then you can download the unmodified source from
--      Spyric Games Ltd's GitHub at https://github.com/SpyricGames/Print-to-Display.

local M = {}

-- Localised functions.
local _print = print
local _type = type
local _unpack = unpack
local _tostring = tostring
local _concat = table.concat
local printToBrowser = system.getInfo( "environment" ) ~= "simulator" and require( "printToBrowser" )

M.autoscroll = true
local isConsoleOpen = false
local canScroll = false
local started = false
local output

-- Visual customisation variables.
local parent
local font = native.systemFont
local buttonSize = 32
local buttonBaseColor = { 0.2 }
local buttonImageColor = { 0.8 }
local textColor = { 0.9 }
local textColorError = { 0.9, 0, 0 }
local textColorWarning = { 0.9, 0.75, 0 }
local bgColor = { 0 }
local fontSize = 20
local alpha = 1
local width = 200
local height = 100
local anchorX = 0
local anchorY = 0
local x = display.screenOriginX
local y = display.screenOriginY
local paddingRow = 4
local paddingLeft = 10
local paddingRight = 10
local paddingTop = 10
local paddingBottom = 10
local scrollThreshold = (height-(paddingTop+paddingBottom))*0.5
local useHighlighting = true

-- Scroll the text in the console.
local maxY, objectStart, eventStart = 0
local function scroll( event )
    if event.phase == "began" then
        display.getCurrentStage():setFocus( event.target )
        event.target.isTouched = true
        objectStart, eventStart = output.y, event.y
    elseif event.phase == "moved" then
        if event.target.isTouched then
            local d = event.y - eventStart
            local toY = objectStart + d
            if toY <= 0 and toY >= -maxY then
                M.autoscroll = false
                M.controls.scroll.fill = M.controls.scroll.resume
                output.y = toY
            else
                objectStart = output.y
                eventStart = event.y
                if toY <= 0 then
                    M.autoscroll = true
                    M.controls.scroll.fill = M.controls.scroll.pause
                end
            end
        end
    else
        display.getCurrentStage():setFocus( nil )
        event.target.isTouched = false
    end
    return true
end

-- Handles the console's two buttons.
local function controls( event )
    if event.phase == "began" then
        if event.target.id == "autoscroll" then
            M.autoscroll = not M.autoscroll
            if M.autoscroll then
                M.controls.scroll.fill = M.controls.scroll.pause
            else
                M.controls.scroll.fill = M.controls.scroll.resume
            end
            
            if M.autoscroll then output.y = -maxY end
        else -- Clear all text.
            maxY = 0
            canScroll = false
            M.autoscroll = true
            M.controls.scroll.fill = M.controls.scroll.pause
            output.y = 0
            for i = 1, #output.row do
                display.remove( output.row[i] )
                output.row[i] = nil
            end
        end
    end
    return true
end

-- Add a new chunk of text to the output window.
local function printToDisplay( ... )
    local t = {...}
    for i = 1, #t do
        t[i] = _tostring( t[i] )
    end
    local text = _concat( t, "    " )

    local _y
    if #output.row > 0 then
        _y = output.row[#output.row].y + output.row[#output.row].height + paddingRow
    else
        _y = y+paddingTop - height*0.5
    end

    output.row[#output.row+1] = display.newText( {
        parent = output,
        text = text,
        x = output.row[#output.row] and output.row[#output.row].x or paddingLeft-width*0.5,
        y = output.row[#output.row] and output.row[#output.row].y+output.row[#output.row].height+paddingRow or paddingTop-height*0.5,
        width = width - (paddingLeft + paddingRight),
        height = 0,
        font = font,
        fontSize = fontSize
    } )
    output.row[#output.row].anchorX, output.row[#output.row].anchorY = 0, 0

    if useHighlighting then
        if output.row[#output.row].text:sub(1,6) == "ERROR:" then
            output.row[#output.row]:setFillColor( _unpack( textColorError ) )
        elseif output.row[#output.row].text:sub(1,8) == "WARNING:" then
            output.row[#output.row]:setFillColor( _unpack( textColorWarning ) )
        else
            output.row[#output.row]:setFillColor( _unpack( textColor ) )
        end
    else
        output.row[#output.row]:setFillColor( _unpack( textColor ) )
    end

    if not canScroll and output.row[#output.row].y + output.row[#output.row].height >= scrollThreshold then
        canScroll = true
    end

    if canScroll then
        maxY = output.row[#output.row].y + output.row[#output.row].height - scrollThreshold
        if M.autoscroll then
            output.y = -maxY
        end
    end
end

-- Modify the original print function to also print to browser and display consoles (if available).
-- print() is set inside resetPrint() so that it can be restored if the user accidentally messes with it.
function M.resetPrint()
    function print( ... )
        if isConsoleOpen then printToDisplay( ... ) end
        if printToBrowser then printToBrowser.log( ... ) end
        _print( ... )
    end
end

-- Optional function that will customise any or all visual features of the module.
function M.setStyle( s )
    if type( s ) ~= "table" then
        print( "WARNING: bad argument to 'setStyle' (table expected, got " .. type( s ) .. ")." )
    else -- Validate all and update only valid, passed parameters.
        if type( s.buttonSize ) == "number" then buttonSize = s.buttonSize end
        if type( s.parent ) == "table" and s.parent.insert then parent = s.parent end
        if type( s.useHighlighting ) == "boolean" then useHighlighting = s.useHighlighting end
        if type( s.buttonBaseColor ) == "table" then buttonBaseColor = s.buttonBaseColor end
        if type( s.buttonImageColor ) == "table" then buttonImageColor = s.buttonImageColor end
        if type( s.font ) == "string" or type( s.font ) == "userdata" then font = s.font end
        if type( s.fontSize ) == "number" then fontSize = s.fontSize end
        if type( s.width ) == "number" then width = s.width end
        if type( s.height ) == "number" then height = s.height end
        if type( s.anchorX ) == "number" then anchorX = s.anchorX end
        if type( s.anchorY ) == "number" then anchorY = s.anchorY end
        if type( s.x ) == "number" then x = s.x end
        if type( s.y ) == "number" then y = s.y end
        if type( s.paddingRow ) == "number" then paddingRow = s.paddingRow end
        if type( s.paddingLeft ) == "number" then paddingLeft = s.paddingLeft end
        if type( s.paddingRight ) == "number" then paddingRight = s.paddingRight end
        if type( s.paddingTop ) == "number" then paddingTop = s.paddingTop end
        if type( s.textColor ) == "table" then textColor = s.textColor end
        if type( s.bgColor ) == "table" then bgColor = s.bgColor end
        if type( s.alpha ) == "number" then alpha = s.alpha end
        scrollThreshold = (height-(paddingTop+paddingBottom))*0.5
        -- If printToDisplay is already running, then clear it.
        if started then
            M.stop()
            M.start()
        end
    end
end

-- Create the UI and make the default print() calls also "print" on screen.
function M.start()
    if not started then
        started = true
        -- Create container where the background and text are added.
        M.ui = display.newContainer( width, height )
        if parent then parent:insert( M.ui ) end
        M.ui.anchorX, M.ui.anchorY = anchorX, anchorY
        M.ui.x, M.ui.y = x, y
        M.ui.alpha = alpha
        -- Create the background.
        M.ui.bg = display.newRect( M.ui, 0, 0, width, height )
        M.ui.bg:setFillColor( _unpack( bgColor ) )
        -- All rows of text are added to output group.
        output = display.newGroup()
        M.ui:insert( output, true )
        output.row = {}
        -- Create external control buttons
        M.controls = display.newGroup()
        if parent then parent:insert( M.controls ) end

        local buttonOffsetX = (1-anchorX)*width
        local buttonOffsetY = anchorY*height
        
        M.controls.scroll = display.newRect( M.controls, x+buttonOffsetX+buttonSize*0.5+4, y-buttonOffsetY+buttonSize*0.5, buttonSize, buttonSize )
        M.controls.scroll.pause = {
            type = "image",
            filename = "ui/buttonPause.png"
        }
        M.controls.scroll.resume = {
            type = "image",
            filename = "ui/buttonResume.png"
        }
        M.controls.scroll.fill = M.controls.scroll.pause
        M.controls.scroll:addEventListener( "touch", controls )
        M.controls.scroll.id = "autoscroll"
        
        M.controls.clear = display.newImageRect( M.controls, "ui/buttonClear.png", buttonSize, buttonSize )
        M.controls.clear.x, M.controls.clear.y = x+buttonOffsetX+buttonSize*0.5+4, y-buttonOffsetY+buttonSize
        M.controls.clear:addEventListener( "touch", controls )
        M.controls.clear.id = "clear"
        
        isConsoleOpen = true
        printToDisplay( "print() will output text here and in your browser console (F12).\n " )
        
        maxY = 0
        M.ui.bg:addEventListener( "touch", scroll )
    end
end

-- Restore the normal functionality to print() and clean up the UI.
function M.stop()
    if started then
        started = false
        canScroll = false
        isConsoleOpen = false
        M.ui.bg:removeEventListener( "touch", scroll )        
        display.remove( output )
        output = nil
        display.remove( M.controls )
        M.controls = nil
        display.remove( M.ui )
        M.ui = nil
    end
end

M.resetPrint()
return M
