-- MyHub Loader
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/pespapankon-del/MyHub/main/loader.lua"))()

local HttpGet = game.HttpGet
local GameId = game.GameId

local Games = loadstring(
    HttpGet(game, "https://raw.githubusercontent.com/pespapankon-del/MyHub/main/GameList.lua")
)()

local URL = Games[GameId]
if not URL then
    warn("[MyHub] ไม่รองรับเกมนี้ GameId: " .. tostring(GameId))
    return
end

warn("[MyHub] กำลังโหลด script สำหรับ GameId: " .. tostring(GameId))
loadstring(HttpGet(game, URL))()
