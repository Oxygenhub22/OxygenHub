-- ════════════════════════════════════════════════════════════════════════════
-- OXYGENKEY | Climb a Ramp! | Tam Sürüm - HAZIR
-- ════════════════════════════════════════════════════════════════════════════

if game.PlaceId ~= 124868078719468 and game.GameId ~= 124868078719468 then
    return
end

local STORAGE_URL    = "https://api.npoint.io/45d0da3c8a900be883b3"
local ADMIN_USERNAME = "Hackerolama"
local CHECK_EVERY    = 30

-- Library
local Library
do
    local src = game:HttpGet("https://pastefy.app/2eRdp0K5/raw")
    src = src:gsub("Oxide", "OxygenHub"):gsub("oxide", "oxygenhub"):gsub("OXIDE", "OXYGENHUB")
    Library = loadstring(src)()
end
pcall(function() Library:SetTheme("Light") end)

do
    local prev = _G.OxygenKeyHub
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, dead = false }
_G.OxygenKeyHub = HUB
local function track(c) table.insert(HUB.conns, c); return c end

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or (http_request) or (request)
local SAVE_PATH   = "OxygenKey_saved.txt"

-- ════════════════════════════════════════════════════════════════════════════
-- STORAGE
-- ════════════════════════════════════════════════════════════════════════════
local function fetchStore()
    if not httpRequest then return nil, "HTTP yok" end
    local ok, res = pcall(function()
        return httpRequest({ Url = STORAGE_URL .. "?t=" .. os.time(), Method = "GET" })
    end)
    if not ok or not res or not res.Body then return nil, "Sunucu ulaşılamıyor" end
    local dok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not dok or type(data) ~= "table" then return nil, "JSON hatası" end
    data.keys = data.keys or {}
    return data, nil
end

local function saveStore(data)
    if not httpRequest then return false end
    local body = HttpService:JSONEncode(data)
    local ok = pcall(function()
        httpRequest({
            Url = STORAGE_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
    return ok
end

local function genKey()
    local s = ""
    for _ = 1, 32 do s = s .. string.format("%x", math.random(0, 15)) end
    return s
end

local function saveLocal(k) if type(writefile) == "function" then pcall(writefile, SAVE_PATH, tostring(k)) end end
local function loadLocal()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
    if not isfile(SAVE_PATH) then return nil end
    local ok, c = pcall(readfile, SAVE_PATH)
    return ok and c or nil
end
local function deleteLocal() if type(delfile) == "function" then pcall(delfile, SAVE_PATH) end end

-- ════════════════════════════════════════════════════════════════════════════
-- VALIDATION
-- ════════════════════════════════════════════════════════════════════════════
local function validateKey(store, key)
    if not store or not store.keys then return false, "Veri yok" end
    key = string.lower(tostring(key)):gsub("%s", "")
    local entry = store.keys[key]
    if not entry then return false, "Geçersiz key" end
    if entry.revoked then return false, "İptal edilmiş" end
    if os.time() > entry.expires_at then return false, "Süresi bitmiş" end
    local uses = entry.uses or {}
    for _, n in ipairs(uses) do
        if n == LocalPlayer.Name then return true, "re-login" end
    end
    if #uses >= (entry.max_uses or 1) then return false, "Limit doldu" end
    return true, "yeni"
end

-- ════════════════════════════════════════════════════════════════════════════
-- WINDOW
-- ════════════════════════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Name = "OxygenHub | Climb a Ramp!",
    LoadingAnimation = true,
    LoadingText = "OxygenHub",
    LoadingDuration = 2.0,
})
task.defer(function() task.wait(0.4); pcall(function() Library:SetTheme("Light") end) end)

local function Notify(t, c, k, d)
    pcall(function() Window:Notify({ Title = t, Content = c, Type = k or "Info", Duration = d or 3 }) end)
end
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then Notify("Error", tostring(err):sub(1, 100), "Error", 4) end
    end
end

local isAdmin = (LocalPlayer.Name == ADMIN_USERNAME)

-- ════════════════════════════════════════════════════════════════════════════
-- BUILD MAIN MENU
-- ════════════════════════════════════════════════════════════════════════════
local Workspace           = game:GetService("Workspace")
local TeleportService     = game:GetService("TeleportService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Camera              = Workspace.CurrentCamera

local function BuildMain()
    if _G.__OxyMainBuilt then return end
    _G.__OxyMainBuilt = true

    local WalkSpeedEnabled, WalkSpeedValue = false, 16
    local InfJumpEnabled = false
    local NoclipEnabled = false
    local AntiFlingEnabled, lastSafePos = true, nil
    local AntiStaffEnabled = true
    local STAFF_USER_ID = 878711784
    local TargetPlayerCount = 5
    local AntiStaffConnection = nil
    local autoBuyModifiersEnabled = false
    local autoFarmEnabled = false
    local isRebirthing = false
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    track(PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "ConfettiGui" then task.defer(function() child:Destroy() end) end
    end))

    local function HopRandom()
        local urls = {
            "https://games.roproxy.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        }
        local data
        for _, u in ipairs(urls) do
            local ok, r = pcall(function() return game:HttpGet(u) end)
            if ok and r then
                local d, j = pcall(function() return HttpService:JSONDecode(r) end)
                if d and j and j.data then data = j; break end
            end
        end
        if data and data.data then
            local list = {}
            for _, v in ipairs(data.data) do
                if type(v) == "table" and v.id ~= game.JobId then table.insert(list, v.id) end
            end
            if #list > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, list[math.random(1, #list)])
            end
        end
    end

    local function CheckStaff()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == STAFF_USER_ID then
                Notify("Anti Staff", "Staff detected! Hopping...", "Warning", 3)
                task.wait(0.3); HopRandom(); return true
            end
        end
        return false
    end

    -- Main
    local MainTab = Window:AddTab({ Name = "Main", Subtitle = "Cash, items & auto", Icon = "home" })
    local CashSub = MainTab:AddSubTab("Cash & Rebirth")
    local ItemsSub = MainTab:AddSubTab("Items")
    local AutoSub = MainTab:AddSubTab("Auto")

    CashSub:AddButton({
        Name = "INF Cash", Primary = true,
        Callback = safe(function()
            local ev = ReplicatedStorage:WaitForChild("CashOutEvent", 5)
            if ev then ev:FireServer(math.huge, math.huge); Notify("Cash", "Fired", "Success") end
        end)
    })
    CashSub:AddButton({
        Name = "Max Rebirths (1300)", Primary = true,
        Callback = safe(function()
            if isRebirthing then return end
            isRebirthing = true
            local ev = ReplicatedStorage:WaitForChild("RebirthEvent", 5)
            if not ev then isRebirthing = false; return end
            for i = 1, 1300 do ev:FireServer("Single"); if i % 100 == 0 then task.wait() end end
            task.wait(2); isRebirthing = false
            Notify("Rebirth", "Done", "Success")
        end)
    })

    ItemsSub:AddButton({
        Name = "Buy All Shoes & Equip Best", Primary = true,
        Callback = safe(function()
            local buy = ReplicatedStorage:WaitForChild("BuyShoeEvent", 5)
            local eq = ReplicatedStorage:WaitForChild("EquipShoeEvent", 5)
            if not buy or not eq then return end
            local shoes = {"Classic","Blue","Green","Wooden","Rock","Brick","Sand","Rust","Iron","Camo","Flowery","Cheese","Candy","Brainrot","Birthday","Christmas","Halloween","Easter","Firework","Winter","Summer","Autumn","Spring","Water","Cloudy","Rainy","Thunder","Ice","Lava","Toxic","Electric","Gold","Chrome","Diamond","Obsidian","Rainbow","Glitch","Earth","Moon","Mars","Sun","Starry","Galaxy","Devil","Angel","Heavenly","Slime","Graffitti","Emoji","Comic","Translucent","Phantom","Soulfire","Void","Dark Matter","Nebula","Supernova","Black Hole","Cosmic","Quantum","Cyber","Holographic","Mythic","Legendary","Divine","Celestial"}
            for _, s in ipairs(shoes) do pcall(function() buy:FireServer(s) end) end
            pcall(function() eq:FireServer(shoes[#shoes]) end)
            Notify("Shoes", "Done", "Success")
        end)
    })
    ItemsSub:AddButton({
        Name = "Buy All Trails & Equip Best", Primary = true,
        Callback = safe(function()
            local buy = ReplicatedStorage:WaitForChild("BuyTrailEvent", 5)
            local eq = ReplicatedStorage:WaitForChild("EquipTrailEvent", 5)
            if not buy or not eq then return end
            local trails = {"Starter","Blue","Green","Red","Purple","Black","Midnight","Lava","Diamond"}
            local owned = LocalPlayer:WaitForChild("OwnedTrails", 5)
            if owned then
                for _, t in ipairs(trails) do
                    if not owned:FindFirstChild(t) then pcall(function() buy:FireServer(t) end) end
                end
                task.wait(0.5)
                pcall(function() eq:FireServer("Diamond") end)
                Notify("Trails", "Done", "Success")
            end
        end)
    })

    AutoSub:AddToggle({
        Name = "Auto Buy Modifiers", Default = false, Flag = "AutoMods",
        Callback = function(v)
            autoBuyModifiersEnabled = v
            if v then
                task.spawn(function()
                    local ev = ReplicatedStorage:WaitForChild("BuyModifierEvent", 5)
                    if not ev then return end
                    local mods = {"SlipAndSlideModifierFrame","LowGravityModifierFrame","LightsOutModifierFrame","GiantModifierFrame","x2CashModifierFrame","x2WinsModifierFrame"}
                    while autoBuyModifiersEnabled and not HUB.dead do
                        for _, m in ipairs(mods) do
                            local t = Workspace:GetAttribute(m .. "_EndTime")
                            if not t or os.time() >= t then pcall(function() ev:FireServer(m) end) end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })
    AutoSub:AddToggle({
        Name = "Auto Farm Win", Default = false, Flag = "AutoFarm",
        Callback = function(v)
            autoFarmEnabled = v
            if v then
                task.spawn(function()
                    local TARGET = Vector3.new(17, 1386, -1533)
                    while autoFarmEnabled and not HUB.dead do
                        pcall(function()
                            local g = PlayerGui:FindFirstChild("ConfettiGui")
                            if g then g:Destroy() end
                            local c = LocalPlayer.Character
                            if c and c:FindFirstChild("HumanoidRootPart") then
                                local root = c.HumanoidRootPart
                                local f = Workspace:FindFirstChild("WinParts")
                                local tp = f and f:FindFirstChild("WinPart6Starter", true)
                                if tp then
                                    if firetouchinterest then
                                        firetouchinterest(root, tp, 0); task.wait()
                                        firetouchinterest(root, tp, 1)
                                    else root.CFrame = tp.CFrame end
                                else root.CFrame = CFrame.new(TARGET) end
                            end
                        end)
                        task.wait(0.1)
                    end
                end)
            end
        end
    })

    local CharTab = Window:AddTab({ Name = "Character", Subtitle = "Movement", Icon = "user" })
    local MoveSub = CharTab:AddSubTab("Movement")
    local ProtectSub = CharTab:AddSubTab("Protection")
    local ServerSub = CharTab:AddSubTab("Server")

    MoveSub:AddToggle({ Name = "WalkSpeed", Default = false, Flag = "WS",
        Callback = function(v) WalkSpeedEnabled = v
            if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end
    })
    MoveSub:AddSlider({ Name = "WalkSpeed Value", Min = 16, Max = 2000, Default = 16, Flag = "WSV",
        Callback = function(v) WalkSpeedValue = v end
    })
    MoveSub:AddToggle({ Name = "Infinite Jump", Default = false, Flag = "IJ",
        Callback = function(v) InfJumpEnabled = v end
    })
    MoveSub:AddToggle({ Name = "Noclip", Default = false, Flag = "NC",
        Callback = function(v) NoclipEnabled = v end
    })
    ProtectSub:AddToggle({ Name = "Anti-Fling", Default = true, Flag = "AF",
        Callback = function(v) AntiFlingEnabled = v end
    })
    ProtectSub:AddToggle({ Name = "Anti-Staff", Default = true, Flag = "AS",
        Callback = function(v)
            AntiStaffEnabled = v
            if v then
                task.spawn(CheckStaff)
                if not AntiStaffConnection then
                    AntiStaffConnection = Players.PlayerAdded:Connect(function(p)
                        if AntiStaffEnabled and p.UserId == STAFF_USER_ID then
                            Notify("Anti Staff", "Staff! Hopping...", "Warning", 3)
                            task.wait(0.3); HopRandom()
                        end
                    end)
                end
            else
                if AntiStaffConnection then AntiStaffConnection:Disconnect(); AntiStaffConnection = nil end
            end
        end
    })
    ServerSub:AddToggle({ Name = "Anti-AFK", Default = true, Flag = "AFK",
        Callback = function(v)
            if v and not _G.OxyAFK then
                _G.OxyAFK = LocalPlayer.Idled:Connect(function()
                    VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
                end)
            elseif not v and _G.OxyAFK then _G.OxyAFK:Disconnect(); _G.OxyAFK = nil end
        end
    })
    ServerSub:AddButton({ Name = "Rejoin", Primary = true,
        Callback = safe(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    })
    ServerSub:AddButton({ Name = "Server Hop",
        Callback = safe(function() HopRandom() end)
    })

    if not _G.OxyAFK then
        _G.OxyAFK = LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
        end)
    end
    AntiStaffConnection = Players.PlayerAdded:Connect(function(p)
        if AntiStaffEnabled and p.UserId == STAFF_USER_ID then
            Notify("Anti Staff", "Staff! Hopping...", "Warning", 3)
            task.wait(0.3); HopRandom()
        end
    end)

    track(RunService.Stepped:Connect(function()
        if HUB.dead then return end
        if NoclipEnabled and LocalPlayer.Character then
            for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
        if AntiFlingEnabled then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character then
                    local r = pl.Character:FindFirstChild("HumanoidRootPart")
                    if r and (r.AssemblyAngularVelocity.Magnitude > 50 or r.AssemblyLinearVelocity.Magnitude > 100) then
                        for _, pt in ipairs(pl.Character:GetDescendants()) do
                            if pt:IsA("BasePart") then pt.CanCollide = false end
                        end
                    end
                end
            end
        end
    end))

    track(RunService.Heartbeat:Connect(function()
        if HUB.dead then return end
        pcall(function()
            if WalkSpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid.WalkSpeed = WalkSpeedValue
            end
        end)
        if AntiFlingEnabled then
            pcall(function()
                local c = LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    if r.AssemblyLinearVelocity.Magnitude > 250 or r.AssemblyAngularVelocity.Magnitude > 250 then
                        r.AssemblyLinearVelocity = Vector3.new()
                        r.AssemblyAngularVelocity = Vector3.new()
                        if lastSafePos then r.CFrame = lastSafePos end
                    else lastSafePos = r.CFrame end
                end
            end)
        end
    end))

    track(UserInputService.JumpRequest:Connect(function()
        if HUB.dead then return end
        pcall(function()
            if InfJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end))
end

-- ════════════════════════════════════════════════════════════════════════════
-- ADMIN
-- ════════════════════════════════════════════════════════════════════════════
if isAdmin then
    Notify("OxygenKey", "Admin girişi. Menü açıldı.", "Success", 3)
    BuildMain()

    local AdminTab = Window:AddTab({ Name = "Admin", Subtitle = "Key management", Icon = "gear" })
    local CreateSub = AdminTab:AddSubTab("Create Key")
    local ListSub   = AdminTab:AddSubTab("Manage Keys")

    local durationHours = 24
    local maxUses = 1

    CreateSub:AddSlider({ Name = "Süre (saat)", Min = 1, Max = 720, Default = 24, Suffix = "h", Flag = "K_DUR",
        Callback = function(v) durationHours = v end
    })
    CreateSub:AddSlider({ Name = "Max Kullanıcı", Min = 1, Max = 100, Default = 1, Suffix = " kişi", Flag = "K_USE",
        Callback = function(v) maxUses = v end
    })
    CreateSub:AddButton({
        Name = "KEY OLUŞTUR", Primary = true,
        Callback = safe(function()
            local key = genKey()
            local store, err = fetchStore()
            if not store then Notify("Hata", tostring(err), "Error", 4); return end
            store.keys[key] = {
                created_by = LocalPlayer.Name,
                created_at = os.time(),
                expires_at = os.time() + durationHours * 3600,
                max_uses   = maxUses,
                uses       = {},
                revoked    = false,
            }
            if saveStore(store) then
                Notify("KEY OLUŞTURULDU", "Süre: " .. durationHours .. "h | Max: " .. maxUses, "Success", 5)
                Notify("KEY", key, "Info", 15)
                if type(setclipboard) == "function" then
                    pcall(setclipboard, key)
                    Notify("Kopyalandı", "Key panoya kopyalandı!", "Success", 3)
                end
            else
                Notify("Hata", "Kaydedilemedi", "Error", 4)
            end
        end)
    })

    ListSub:AddButton({
        Name = "TÜM KEYLERİ GÖSTER", Primary = true,
        Callback = safe(function()
            local store, err = fetchStore()
            if not store then Notify("Hata", tostring(err), "Error", 4); return end
            local count = 0
            for k, v in pairs(store.keys) do
                count = count + 1
                if count > 8 then break end
                local status = v.revoked and "🔴 İPTAL" or (os.time() > v.expires_at and "⏰ BİTTİ" or "🟢 AKTİF")
                local uses = v.uses or {}
                local userList = #uses > 0 and table.concat(uses, ", ") or "kimse"
                Notify("Key " .. count, k:sub(1, 16) .. "... | " .. status .. " | " .. userList, "Info", 10)
            end
            if count == 0 then Notify("Key", "Hiç key yok", "Info", 3) end
        end)
    })

    local revokeIn = ListSub:AddInput({ Name = "Key (32 karakter)", Default = "", Placeholder = "Kopyala/yapıştır" })
    ListSub:AddButton({
        Name = "İPTAL ET",
        Callback = safe(function()
            local k = string.lower(tostring(revokeIn:Get() or "")):gsub("%s", "")
            if #k ~= 32 then Notify("Hata", "32 karakter olmalı", "Error", 3); return end
            local store, err = fetchStore()
            if not store or not store.keys[k] then Notify("Hata", "Key bulunamadı", "Error", 4); return end
            store.keys[k].revoked = true
            if saveStore(store) then
                Notify("İPTAL", "Key iptal edildi", "Success", 4)
                Notify("Bilgi", "Kullanan 30sn içinde kick yiyecek", "Warning", 5)
            end
        end)
    })
    ListSub:AddButton({
        Name = "İPTALİ KALDIR",
        Callback = safe(function()
            local k = string.lower(tostring(revokeIn:Get() or "")):gsub("%s", "")
            if #k ~= 32 then return end
            local store = fetchStore()
            if not store or not store.keys[k] then return end
            store.keys[k].revoked = false
            if saveStore(store) then Notify("Aktif", "Key tekrar açıldı", "Success", 4) end
        end)
    })
    ListSub:AddButton({
        Name = "KEY SİL",
        Callback = safe(function()
            local k = string.lower(tostring(revokeIn:Get() or "")):gsub("%s", "")
            if #k ~= 32 then return end
            local store = fetchStore()
            if not store then return end
            store.keys[k] = nil
            if saveStore(store) then Notify("Silindi", "Kalıcı silindi", "Success", 4) end
        end)
    })

    HUB.Unload = function()
        HUB.dead = true
        for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
        if _G.OxyAFK then pcall(function() _G.OxyAFK:Disconnect() end); _G.OxyAFK = nil end
        pcall(function() Window:Destroy() end)
        _G.OxygenKeyHub = nil
        _G.__OxyMainBuilt = nil
    end
    return
end

-- ════════════════════════════════════════════════════════════════════════════
-- NORMAL KULLANICI - KEY GİRİŞİ
-- ════════════════════════════════════════════════════════════════════════════
local KeyTab = Window:AddTab({ Name = "Key", Subtitle = "Authentication", Icon = "lock" })
local AuthSub = KeyTab:AddSubTab("Enter Key")

AuthSub:AddParagraph({
    Title = "OxygenHub Key Sistemi",
    Content = "Menüye erişmek için 32 karakterli key girmelisin.\nKey'i Hackerolama'dan iste."
})

local keyInput = AuthSub:AddInput({
    Name = "Key", Default = "", Placeholder = "f86e774863f658580dc366db63f13266"
})

local function doAuth(key)
    key = string.lower(tostring(key)):gsub("%s", "")
    if #key ~= 32 then return false, "32 karakter olmalı" end
    local store, err = fetchStore()
    if not store then return false, tostring(err) end
    local ok, reason = validateKey(store, key)
    if not ok then return false, reason end
    if reason == "yeni" then
        store.keys[key].uses = store.keys[key].uses or {}
        table.insert(store.keys[key].uses, LocalPlayer.Name)
        saveStore(store)
    end
    saveLocal(key)
    return true, "ok"
end

AuthSub:AddButton({
    Name = "KEY DOĞRULA", Primary = true,
    Callback = safe(function()
        local k = keyInput:Get()
        Notify("Kontrol", "Sunucuya bağlanılıyor...", "Info", 2)
        local ok, reason = doAuth(k)
        if not ok then Notify("Hata", reason, "Error", 4); return end
        Notify("Başarılı", "Key doğrulandı!", "Success", 3)
        task.wait(0.4)
        pcall(function()
            if KeyTab._hBtn then KeyTab._hBtn.Visible = false end
            if KeyTab._page then KeyTab._page.Visible = false end
        end)
        BuildMain()
    end)
})

AuthSub:AddButton({
    Name = "KAYITLI KEY'İ SİL",
    Callback = function()
        deleteLocal()
        Notify("Silindi", "Kayıtlı key temizlendi", "Warning", 3)
    end
})

task.spawn(function()
    task.wait(1.5)
    local saved = loadLocal()
    if not saved or #saved ~= 32 then return end
    Notify("Auto Login", "Kayıtlı key kontrol ediliyor...", "Info", 2)
    local ok, reason = doAuth(saved)
    if ok then
        Notify("Auto Login", "Hoş geldin!", "Success", 3)
        pcall(function()
            if KeyTab._hBtn then KeyTab._hBtn.Visible = false end
            if KeyTab._page then KeyTab._page.Visible = false end
        end)
        BuildMain()
    else
        Notify("Auto Login", "Key geçersiz: " .. reason, "Warning", 4)
        deleteLocal()
    end
end)

task.spawn(function()
    while not HUB.dead do
        task.wait(CHECK_EVERY)
        local saved = loadLocal()
        if saved and _G.__OxyMainBuilt then
            local store = fetchStore()
            if store then
                local ok = validateKey(store, saved)
                if not ok then
                    pcall(function()
                        LocalPlayer:Kick("OxyDetected — key revoked")
                    end)
                    HUB.dead = true
                    break
                end
            end
        end
    end
end)

HUB.Unload = function()
    HUB.dead = true
    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    HUB.conns = {}
    if _G.OxyAFK then pcall(function() _G.OxyAFK:Disconnect() end); _G.OxyAFK = nil end
    pcall(function() Window:Destroy() end)
    _G.OxygenKeyHub = nil
    _G.__OxyMainBuilt = nil
end

Notify("OxygenKey", "Key gir ve menüyü aç.", "Info", 4)
