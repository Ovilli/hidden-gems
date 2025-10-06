#!/usr/bin/env lua
local json = require("json")

-- Unbuffered stdout so the runner sees each move immediately
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

local bot_x
local bot_y
local gem_pos
local walls = {}
local wall_map = {}
local gem_is_visible = false
local next_move_x
local next_move_y
local moves = { "N", "S", "E", "W" }
local visited = {}

-- Deterministic RNG
math.randomseed(1)

local first_tick = true


local function update_walls(wall_list)
    wall_map = {}
    for _, w in ipairs(wall_list) do
        wall_map[w[1] .. "," .. w[2]] = true
    end
end


local function is_wall(x, y)
    return wall_map[x .. "," .. y] == true
end


local function is_visited(x, y)
    return visited[x .. "," .. y] == true
end


local function find_best_move_to_gem()
    if gem_is_visible and gem_pos then
        if bot_x < gem_pos[1] then
            next_move_x = bot_x + 1
        elseif bot_x > gem_pos[1] then
            next_move_x = bot_x - 1
        else
            next_move_x = bot_x
        end

        if bot_y < gem_pos[2] then
            next_move_y = bot_y + 1
        elseif bot_y > gem_pos[2] then
            next_move_y = bot_y - 1
        else
            next_move_y = bot_y
        end
    else
        next_move_x, next_move_y = bot_x, bot_y
    end
end

local function go_to_best_pos()
    local directions = {
        { dx = 1, dy = 0, move = "E" },
        { dx = -1, dy = 0, move = "W" },
        { dx = 0, dy = 1, move = "S" },
        { dx = 0, dy = -1, move = "N" },
    }

    for _, dir in ipairs(directions) do
        local nx, ny = bot_x + dir.dx, bot_y + dir.dy
        if not is_wall(nx, ny) and not is_visited(nx, ny) then
            print(dir.move)
            return
        end
    end
    print(moves[math.random(#moves)])
end


local function next_move()
    if not next_move_x or not next_move_y then
        go_to_best_pos()
        return
    end

    if next_move_x > bot_x and not is_wall(bot_x + 1, bot_y) then
        print("E")
    elseif next_move_x < bot_x and not is_wall(bot_x - 1, bot_y) then
        print("W")
    elseif next_move_y > bot_y and not is_wall(bot_x, bot_y + 1) then
        print("S")
    elseif next_move_y < bot_y and not is_wall(bot_x, bot_y - 1) then
        print("N")
    else
        go_to_best_pos()
    end
end

-- Main loop
for line in io.lines() do
    local ok, data = pcall(json.decode, line)
    if first_tick and type(data) == "table" and type(data.config) == "table" then
        local w = data.config.width or "?"
        local h = data.config.height or "?"
        io.stderr:write(string.format("Explorer bot (Lua) launching on a %sx%s map\n", w, h))
    end
    first_tick = false

    bot_x, bot_y = data.bot[1], data.bot[2]
    visited[bot_x .. "," .. bot_y] = true

    if data.visible_gems and #data.visible_gems > 0 then
        gem_pos = data.visible_gems[1].position
        gem_is_visible = true
    else
        gem_is_visible = false
    end

    walls = data.wall or {}
    update_walls(walls)

    find_best_move_to_gem()
    next_move()
end
