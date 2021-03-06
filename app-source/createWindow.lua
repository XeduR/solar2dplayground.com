local window = {}

local defaultFont = "fnt/OpenSansRegular.ttf"
local scrollRate = 30

local copyToClipboard
local environment = system.getInfo( "environment" )
if environment ~= "simulator" then
    copyToClipboard = require( "copyToClipboard" )
    -- Scroll direction seems to be reversed with browsers/HTML5 builds.
    scrollRate = -scrollRate
end

window.activeWindow = nil
window.windowOpen = nil
window.tooltip = nil

-- Handle asset window scrolling when the window background is touched.
local objectStart, eventStart
local function scrollImagesWindow( event )
    if event.phase == "began" then
        display.getCurrentStage():setFocus( event.target )
        event.target.isTouched = true
        objectStart, eventStart = window.activeWindow.y, event.y
    elseif event.phase == "moved" then
        if event.target.isTouched then
            local d = event.y - eventStart
            local toY = objectStart + d
            local maxY = window.activeWindow.scroll.maxY
            if toY <= 0 and toY >= -maxY then
                window.activeWindow.y = toY
            else
                objectStart = window.activeWindow.y
                eventStart = event.y
            end
            window.activeWindow.scrollHandle.y = window.activeWindow.scrollHandle.yStart - (window.activeWindow.y/maxY)*430
        end
    else
        display.getCurrentStage():setFocus( nil )
        event.target.isTouched = false
    end
    return true
end

-- Handle asset window scrolling when the scroll handle is touched.
local function scrollImagesHandle( event )
    if event.phase == "began" then
        display.getCurrentStage():setFocus( event.target )
        event.target.isTouched = true
        objectStart, eventStart = window.activeWindow.y, event.y
    elseif event.phase == "moved" then
        if event.target.isTouched then
            local d = event.y - eventStart
            local toY = objectStart + d
            local maxY = window.activeWindow.scroll.maxY
            if event.y <= 116 then
                eventStart = event.y
                event.target.y = 116
                window.activeWindow.y = 0
            elseif event.y >= 546 then
                eventStart = event.y
                event.target.y = 546
                window.activeWindow.y = -maxY
            else
                event.target.y = event.y
                window.activeWindow.y = -((event.y-116)/430)*maxY
            end
        end
    else
        display.getCurrentStage():setFocus( nil )
        event.target.isTouched = false
    end
    return true
end

-- Handle asset window scrolling when mouse wheel is scrolled.
local function mouseScroll( event )
    if window.windowOpen and event.type == "scroll" then
        local dY
        if event.scrollY > 0 then
            dY = scrollRate
        else
            dY = -scrollRate
        end
        local toY = window.activeWindow.y - dY
        local maxY = window.activeWindow.scroll.maxY
        if dY < 0 and toY >= 0 then
            window.activeWindow.y = 0
        elseif dY > 0 and toY <= -maxY then
            window.activeWindow.y = -maxY
        else
            window.activeWindow.y = toY
        end
        window.activeWindow.scrollHandle.y = window.activeWindow.scrollHandle.yStart - (window.activeWindow.y/maxY)*430
    end
end
Runtime:addEventListener( "mouse", mouseScroll )

local function playSound( event )
    if event.phase == "began" then
        audio.play( event.target.sfx )
    end
    return true
end

-- Copy the clicked asset's filepath and name to clipboard & show tooltip to user.
local function copyPathToBrowser( event )
    if event.phase == "began" then
        local tooltip = window.tooltip
        local id = event.target.id
        
        if copyToClipboard then copyToClipboard.copy( id ) end
        if tooltip.inTransition then transition.cancel( tooltip ) end
        tooltip.inTransition = true
        
        tooltip.x, tooltip.y = event.x, event.y - tooltip.bg.height*0.5 - 20
        tooltip.txt.text = "Copied to clipboard: " .. id
        tooltip.bg.height = tooltip.txt.height + 20
        tooltip.bg.width = tooltip.txt.width + 20
        tooltip.alpha = 1
        transition.to( tooltip, { delay=500, time=500, alpha=0, onComplete=function() tooltip.inTransition = false end })
    end
    return true
end

local function addCopyListener( target, id )
    target:addEventListener( "touch", copyPathToBrowser )
    target.id = "\"" .. id .. "\""
end

function window.createTooltip( tooltip )
    window.tooltip = tooltip
    tooltip.bg = display.newRoundedRect( tooltip, 0, 0, 200, 80, 12 )
    tooltip.bg:setFillColor(0.1)
    tooltip.bg.strokeWidth = 2
    tooltip.bg:setStrokeColor( 0.93, 0.67, 0.07 )
    tooltip.txt = display.newText( tooltip, "", tooltip.bg.x, tooltip.bg.y + (environment ~= "simulator" and 6 or 0), defaultFont, 20 )
    tooltip.txt:setFillColor( 1 )
    tooltip.alpha = 0
end

local function compare( a, b )
    return a < b
end

-- Create a list of assets and organise them alphabetically.
local function getAssetList( folder )
    local list = {}
    
    for file in lfs.dir( system.pathForFile( folder, system.ResourceDirectory ) ) do
        if file ~= "." and file ~= ".." and not file:find("(.txt)") then
            list[#list+1] = folder .. file
        end
    end
    table.sort( list, compare )
    
    return list
end

-- Create and automatically populate asset windows.
function window.new( windowName, group, toggleAssets )
    local background = display.newRoundedRect( group.window, 480, 320, 800, 600, 8 )
    background:setFillColor(0,0.9)
    background:addEventListener( "touch", scrollImagesWindow )
    
    local buttonClose = display.newImageRect( group.window, "ui/buttonClose.png", 48, 48 )
    buttonClose:addEventListener( "touch", toggleAssets )
    buttonClose.x, buttonClose.y = background.x+background.width*0.5-32, background.y-background.height*0.5+32
    
    local title = display.newText( group.window, "", 480, 50, defaultFont, 28 )
    local copyright = display.newText( group.window, "", 480, title.y, defaultFont, 20 )
    copyright:setFillColor( 0.93, 0.67, 0.07 )
    copyright.y = title.y + title.height*0.5 + 4
    copyright.anchorY = 0
    
    group.scrollHandle = display.newRoundedRect( group.window, buttonClose.x, buttonClose.y+buttonClose.height+16, 16, 32, 16 )
    group.scrollHandle:addEventListener( "touch", scrollImagesHandle )
    group.scrollHandle.yStart = group.scrollHandle.y
    group.scrollHandle:setFillColor( 0.93, 0.67, 0.07 )
    
    -- Traverse the asset folders create scrollable lists of them to the menu window.
    local column, row, assetFontSize = 0, 1, 18
    if windowName == "Images" then
        title.text = "Scroll to view all useable images"
        copyright.text = "These images were created by Ponywolf (ponywolf.com)"
        
        local list = getAssetList( "img/" )
        for i = 1, #list do
            local filename = list[i]
            local x, y = -240+column*240, -350+row*220
            
            local asset = display.newImage( group, filename, x, y )
            addCopyListener( asset, filename )
            if asset.width > 180 or asset.height > 120 then
                local xScale = 160 / asset.width
                local yScale = 120 / asset.height
                local scale = math.min( xScale, yScale )
                asset.xScale, asset.yScale = scale, scale
            end
            asset.anchorY = 1
            
            asset.name = display.newText( group, "\"" .. filename .. "\"", x, y+12, defaultFont, assetFontSize )
            addCopyListener( asset.name, filename )
            asset.name.anchorY = 0
            
            asset.size = display.newText( group, "width: ".. asset.width .. ", height: " .. asset.height, x, y+40, defaultFont, assetFontSize )
            addCopyListener( asset.size, filename )
            asset.size.anchorY = 0
            
            column = column+1
            if column == 3 then
                row = row+1
                column = 0
            end
        end
        -- NB! This may need to be adjusted if more assets are added.
        group.scroll.maxY = row > 2 and 215*(row-2.5) or 0
        
    elseif windowName == "SFX" then
        title.text = "Scroll to view all useable sound effects"
        copyright.text = "These audio files were created by Kenney (www.kenney.nl)"
                
        local list = getAssetList( "sfx/" )
        for i = 1, #list do
            local filename = list[i]
            local x, y = -170+column*340, -300+row*120
            
            local asset = display.newImageRect( group, "ui/buttonAudio.png", 320, 60 )
            asset.x, asset.y = x, y
            asset.anchorY = 1
            asset:addEventListener( "touch", playSound )
            asset.sfx = audio.loadSound( filename )                
            
            asset.name = display.newText( group, "\"" .. filename .. "\"", x, y+12, defaultFont, assetFontSize )
            addCopyListener( asset.name, filename )
            asset.name.anchorY = 0
            
            column = column+1
            if column == 2 then
                row = row+1
                column = 0
            end
        end
        -- NB! This may need to be adjusted if more assets are added.
        group.scroll.maxY = row > 4 and 120*(row-4.5) or 0
        
    elseif windowName == "Fonts" then
        title.text = "Scroll to view all useable fonts"
        copyright.text = "These fonts can be downloaded from www.fontsquirrel.com"
    
        local folder = "fnt/"
        local placeholder = "AaBbCcDdEeFfGgHhIiJjKk"
        local placeholderFontSize = 28
        local list = getAssetList( "fnt/" )
        for i = 1, #list do
            local filename = list[i]
            local x, y = 0, -320+row*140
            
            local asset = display.newRect( group, x, y, 600, 4 ) 
            asset:setFillColor(0.93, 0.67, 0.07)
            asset.anchorY = 1
            
            asset.text = display.newText( group, placeholder, x, y-asset.height-12, filename, placeholderFontSize )
            addCopyListener( asset.text, filename )
            asset.text.anchorY = 1
            
            asset.name = display.newText( group, "\"" .. filename .. "\"", x, y+12, defaultFont, assetFontSize )
            addCopyListener( asset.name, filename )
            asset.name.anchorY = 0
            
            row = row+1
        end
        -- NB! This may need to be adjusted if more assets are added.
        group.scroll.maxY = row > 3 and 140*(row-4) or 0
        
    end
    -- There should always be scrollable content, but just future proofing
    -- this in case someone adds new asset windows in the future (or smth).
    if group.scroll.maxY <= 0 then
        group.scrollHandle.isVisible = false
    end
end

return window