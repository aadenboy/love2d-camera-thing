require "boiler"
require "keys"
require "vector"
require "camera"

local noto = love.graphics.newFont("notosansmono.ttf")
local debuto = love.graphics.newImageFont("perhaps.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"_~@$^{}\\<>|�")

local models = require("models")

local function rayPlaneIntersect(rayOrigin, rayDir, planePoint, planeNormal)
    local denom = planeNormal:dotprod(rayDir)
    if math.abs(denom) > 1e-6 then
        local diff = planePoint - rayOrigin
        local t = diff:dotprod(planeNormal) / denom
        if t >= 0 then
            return rayOrigin + rayDir * t
        end
    end
    return nil
end

local function project(p1)
    local proj = (((p1.pos - camera.position) * camera.z):rotaround(Vector2.new(0, 0), 0 - camera.r) / Vector2.new(1, math.pi)) - Vector2.new(0, (p1.height - camera.height) * camera.z)
    return proj + Vector2.new(window.width / 2, window.height / 2), proj
end

local function pointInTriangle(pt, v1, v2, v3)
    local dX = pt.x - v3.x
    local dY = pt.y - v3.y
    local dX21 = v3.x - v2.x
    local dY12 = v2.y - v1.y
    local D = dY12 * (v3.x - v1.x) + (v1.y - v3.y) * dX21
    local s = dY12 * dX + (v1.x - v3.x) * dY
    local t = (v3.y - v1.y) * dX + dX21 * dY
    return s >= 0 and t >= 0 and (s + t) <= D
end

camera.height = 0

-- not used yet
local map = {
    {pos = Vector2.new(0, 0), height = 0, size = Vector2.new(1, 1), r = 0, tall = 1, color = fromHEX("aaa"), type = 0}
}



local shapequeue = {}

function queue3D(vertexes, sx, sy, sz, position, height, rotation, color)
    shapequeue[#shapequeue+1] = {
        vertexes = vertexes,
        sx = sx,
        sy = sy,
        sz = sz,
        position = position,
        height = height,
        rotation = rotation,
        color = color
    }
end

local polyqueue = {}
function from3D(vertexes, sx, sy, sz, position, height, rotation, color)
    color = color or {"fff"}

    local vn = {}
    -- synopsis: used to draw a shape in 3D
    -- from3D(vertexes, sx, sy, sz, position, height, size, tall, rotation, [color="fff"])
    -- vertexes: table   - list of all the vertexes of a shape, pairs of three form a triangle
    -- sx:       number  - X scaling of the shape
    -- sy:       number  - Y scaling of the shape
    -- sz:       number  - Z scaling of the shape
    -- position: vector2 - position horizontally
    -- height:   number  - position vertically
    -- rotation: number  - rotation on the Y axis
    -- color:    table   - table of colors for each triangle, if no color is assigned it uses last index

    for i=1, #vertexes, 3 do
        if vertexes[i] ~= nil then
            vn[i], vn[i+2] = Vector2.new(vertexes[i], vertexes[i+2]):rotaround(Vector2.new(0, 0), rotation):unpack()
        end
    end

    local function queue(tri, col, depth, func)
        polyqueue[#polyqueue+1] = {depth = depth, func = func, tri = tri, col = col, qdata = {
            position = position, height = height
        }}
    end

    for i=1, #vn, 9 do
        local p1 = {pos = Vector2.new(vn[i],   vn[i+2]) * Vector2.new(sx, sz) + position, height = vertexes[i+1] * sy + height}
        local p2 = {pos = Vector2.new(vn[i+3], vn[i+5]) * Vector2.new(sx, sz) + position, height = vertexes[i+4] * sy + height}
        local p3 = {pos = Vector2.new(vn[i+6], vn[i+8]) * Vector2.new(sx, sz) + position, height = vertexes[i+7] * sy + height}
        
        p1.np, p1.proj = project(p1)
        p2.np, p2.proj = project(p2)
        p3.np, p3.proj = project(p3)

        local centroid = {pos = (p1.pos + p2.pos + p3.pos) / 3, height = (p1.height + p2.height + p3.height) / 3}
        local depth    = (centroid.pos - camera.position):magnitude() + math.abs(centroid.height - camera.height)

        local a = {pos = p2.pos - p1.pos, height = p2.height - p1.height}
        local b = {pos = p3.pos - p1.pos, height = p3.height - p1.height}

        local nx = a.height * b.pos.y  - a.pos.y  * b.height
        local nh = a.pos.y  * b.pos.x  - a.pos.x  * b.pos.y
        local ny = a.pos.x  * b.height - a.height * b.pos.x

        local ms, msp = project({pos = Vector2.middle(p1.pos, p2.pos, p3.pos), height = (p1.height + p2.height + p3.height)/3})
        local me, mep = project({pos = Vector2.middle(p1.pos, p2.pos, p3.pos) + Vector2.new(nx, ny), height = (p1.height + p2.height + p3.height)/3 + nh})
        local mnh, mnhp = project({pos = Vector2.middle(p1.pos, p2.pos, p3.pos) + Vector2.new(nx, ny), height = (p1.height + p2.height + p3.height)/3})

        local ang = msp:anglefrom(mnhp)
        if ang >= 0 and ang <= 180 then
            queue({p1, p2, p3}, color[(i - 1) / 9 + 1] or color[#color], depth, function()
                love.graphics.setColor(fromHEX(color[(i - 1) / 9 + 1] or color[#color]))
                love.graphics.polygon("fill", {p1.np.x, p1.np.y, p2.np.x, p2.np.y, p3.np.x, p3.np.y})

                if debugcam.using then
                    love.graphics.setColor(fromHEX("00f"))
                    love.graphics.line(ms.x, ms.y, me.x, me.y)
                end
            end)
        end
    end
end

camera.z = 1
camera.height = 2

function love.draw()
    love.graphics.setFont(noto)
    window:refresh()
    keyboard:refresh()

    if keyboard.up.pressed    then camera.height = camera.height + 5 end
    if keyboard.down.pressed  then camera.height = camera.height - 5 end
    if keyboard.left.pressed  then camera.r = camera.r - 1 end
    if keyboard.right.pressed then camera.r = camera.r + 1 end
    if keyboard.w.pressed     then camera.position = camera.position + Vector2.fromAngle(camera.r - 90)  * 5 end
    if keyboard.a.pressed     then camera.position = camera.position + Vector2.fromAngle(camera.r - 180) * 5 end
    if keyboard.s.pressed     then camera.position = camera.position + Vector2.fromAngle(camera.r - 270) * 5 end
    if keyboard.d.pressed     then camera.position = camera.position + Vector2.fromAngle(camera.r)       * 5 end

    if keyboard.tab.clicked then debugcam.using = not debugcam.using end

    queue3D(models.DSplaneY, 300, 300, 30, Vector2.new(0, 0), 0, 0, {"f00", "a00", "0ff", "0aa", "00f", "00a", "0ff", "0aa", "ff0", "aa0"})
    queue3D(models.DSplaneY, 300, 300, 30, Vector2.new(0, 300), 0, 0, {"f00", "a00", "0ff", "0aa", "00f", "00a", "0ff", "0aa", "ff0", "aa0"})
    queue3D(models.DSplaneY, 30, 300, 3000, Vector2.new(300, 0), 0, 90, {"f00", "a00", "0ff", "0aa", "00f", "00a", "0ff", "0aa", "ff0", "aa0"})
    queue3D(models.cube, 30, 30, 300, Vector2.new(200, 0), 30, 0, {"f00", "a00", "0f0", "0a0", "00f", "00a", "0ff", "0aa", "ff0", "aa0"})
    --queue3D(models.cube, 30, 30, 300, Vector2.new(60, 0), 60, 0, {"f00", "a00", "0f0", "0a0", "00f", "00a", "0ff", "0aa", "ff0", "aa0"})
    --queue3D(models.cube, 30, 30, 300, Vector2.new(90, 0), 30, 0, {"f00", "a00", "0f0", "0a0", "00f", "00a", "0ff", "0aa", "ff0", "aa0"})
    -- from3D({-0.5,0,0;0.5,0,0;0,0.5,0; -0.5,0,0;0.5,0,0;0,-0.5,0}, 10, 10, 10, camera.position, camera.height, camera.r + 180, {"0f0"})

    -- ... --
    -- ... --
    -- ... --
    camera.r = camera.r % 360

    table.sort(shapequeue, function(a, b) -- hate this so much!! not WORKING.
        if a.position.x ~= b.position.x and a.position.y ~= b.position.y then -- somewhat untested
            if camera.r <= 89 and camera.r >= 0 then
                return a.position.x > b.position.x and a.position.y < b.position.y
            elseif camera.r <= 359 and camera.r >= 270 then
                return a.position.x < b.position.x and a.position.y > b.position.y
            elseif camera.r <= 269 and camera.r >= 180 then
                return not (a.position.x > b.position.x and a.position.y < b.position.y)
            elseif camera.r <= 179 and camera.r >= 90 then
                return not (a.position.x < b.position.x and a.position.y > b.position.y)
            end
        elseif a.position.x == b.position.x and a.position.y ~= b.position.y then -- untested cases
            if camera.r <= 89 and camera.r >= 0 then
                return a.position.y < b.position.y
            elseif camera.r <= 359 and camera.r >= 270 then
                return a.position.y < b.position.y
            elseif camera.r <= 269 and camera.r >= 180 then
                return not (a.position.y < b.position.y)
            elseif camera.r <= 179 and camera.r >= 90 then
                return not (a.position.y < b.position.y)
            end
        elseif a.position.x ~= b.position.x and a.position.y == b.position.y then
            if camera.r <= 89 and camera.r >= 0 then -- now this one is also acting up?????
                return a.position.x < b.position.x
            elseif camera.r <= 359 and camera.r >= 270 then
                return a.position.x < b.position.x
            elseif camera.r <= 269 and camera.r >= 180 then -- REALLY weird case
                return a.position.x < b.position.x
            elseif camera.r <= 179 and camera.r >= 90 then
                return not (a.position.x < b.position.x)
            end
        else
            -- ...
        end
    end)

    for _,v in ipairs(shapequeue) do
        from3D(v.vertexes, v.sx, v.sy, v.sz, v.position, v.height, v.rotation, v.color)
    end

    for _,v in ipairs(polyqueue) do
        v.func()
    end

    if debugcam.using then
        love.graphics.setFont(debuto)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.polygon("fill", {10,25, 160,25, 160,175, 10,175})
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("XZ Map", 10, 10)
        love.graphics.polygon("line", {10,25, 160,25, 160,175, 10,175})
        love.graphics.setColor(0, 1, 0)
        love.graphics.polygon("line", {75,100, 95,100, 85,100, 85,90, 85,110, 85,100})

        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.polygon("fill", {170,25, 320,25, 320,175, 170,175})
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("XY Map", 170, 10)
        love.graphics.polygon("line", {170,25, 320,25, 320,175, 170,175})
        love.graphics.setColor(0, 1, 0)
        love.graphics.polygon("line", {235,100, 255,100, 245,100, 245,90, 245,110, 245,100})

        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.polygon("fill", {330,25, 480,25, 480,175, 330,175})
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("ZY Map", 330, 10)
        love.graphics.polygon("line", {330,25, 480,25, 480,175, 330,175})
        love.graphics.setColor(0, 1, 0)
        love.graphics.polygon("line", {395,100, 415,100, 405,100, 405,90, 405,110, 405,100})

        for _,v in ipairs(polyqueue) do
            v.tri[1].pos = v.tri[1].pos - camera.position
            v.tri[2].pos = v.tri[2].pos - camera.position
            v.tri[3].pos = v.tri[3].pos - camera.position

            v.tri[1].height = v.tri[1].height - camera.height
            v.tri[2].height = v.tri[2].height - camera.height
            v.tri[3].height = v.tri[3].height - camera.height

            love.graphics.setColor(fromHEX(v.col.."a"))
            love.graphics.polygon("line", {
                v.tri[1].pos.x / 2 + 85,
                v.tri[1].pos.y / 2 + 100,
                v.tri[2].pos.x / 2 + 85,
                v.tri[2].pos.y / 2 + 100,
                v.tri[3].pos.x / 2 + 85,
                v.tri[3].pos.y / 2 + 100
            })

            love.graphics.polygon("line", {
                v.tri[1].pos.x  / 2 + 245,
                v.tri[1].height / -2 + 100,
                v.tri[2].pos.x  / 2 + 245,
                v.tri[2].height / -2 + 100,
                v.tri[3].pos.x  / 2 + 245,
                v.tri[3].height / -2 + 100
            })

            love.graphics.polygon("line", {
                v.tri[1].pos.y  / 2 + 405,
                v.tri[1].height / -2 + 100,
                v.tri[2].pos.y  / 2 + 405,
                v.tri[2].height / -2 + 100,
                v.tri[3].pos.y  / 2 + 405,
                v.tri[3].height / -2 + 100
            })
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print("CamPos: {position = "..camera.position..", height = "..camera.height.."}\nCamRot: "..camera.r.."\nCamZoom: "..camera.z, 10, 190)
    end

    shapequeue = {}
    polyqueue = {}
    
end