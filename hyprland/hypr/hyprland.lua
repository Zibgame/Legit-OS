-- LEGIT OS - Hyprland configuration (Hyprland >= 0.57, lua format)
-- Windows-like floating desktop with GNOME/Adwaita styled windows:
-- no automatic tiling, rounded corners, native client-side decorations.

local terminal    = "kgx"
local terminalAlt = "gnome-terminal"
local fileManager = "nautilus"
local launcher    = "wofi --show drun --insensitive"
local runDialog   = "wofi --show run --insensitive"
local shellCtl    = "legit-shell-ctl"

-------------------
---- MONITORS ----
-------------------
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

--------------------------
---- ENVIRONMENT ----
--------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
-- GNOME/Adwaita dark look for the apps that do not read the settings portal
-- (GTK3 + GTK4). libadwaita apps follow org.gnome.desktop.interface
-- color-scheme, which legit-desktop-init sets to "prefer-dark".
hl.env("GTK_THEME", "Adwaita:dark")
-- Qt apps draw Adwaita-like client-side titlebars instead of none.
hl.env("QT_WAYLAND_DECORATION", "adwaita")
-- Make Qt — and therefore LEGIT Shell (Quickshell) — follow the GTK/GNOME
-- settings. Without this Qt only ever looks in "hicolor", so the Win11 icon
-- theme chosen by legit-desktop-init would be ignored by the bar and the
-- Start menu.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

------------------
---- AUTOSTART ----
------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg -i /usr/share/backgrounds/legit/ocean-balcony.jpeg -m fill")
    hl.exec_cmd("pipewire >/dev/null 2>&1 & sleep 1; wireplumber >/dev/null 2>&1 &")
    hl.exec_cmd("mako")
    hl.exec_cmd("nm-applet --indicator")
    -- Export the session to D-Bus, then apply the GNOME/Adwaita dark theme and
    -- the default file manager (Nautilus) once the session bus is reachable.
    hl.exec_cmd("sleep 1; dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE; legit-desktop-init")
    hl.exec_cmd("legit-shell-start")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
end)

----------------------
---- LOOK AND FEEL ----
----------------------
hl.config({
    general = {
        gaps_in          = 0,
        gaps_out         = 0,
        border_size      = 1,
        col = {
            -- Thin hairline: GNOME windows are almost borderless.
            active_border   = "rgba(4bb3e4cc)",
            inactive_border = "rgba(ffffff22)",
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
        -- No automatic edge snapping while moving/resizing (this is already
        -- Hyprland's default; stated explicitly so it is never re-enabled).
        snap = { enabled = false },
    },
    decoration = {
        -- GNOME/Adwaita window shape: rounded corners + soft shadow.
        rounding         = 12,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = true, range = 12, render_power = 3, color = 0x66000000 },
        blur   = { enabled = true, size = 4, passes = 2 },
    },
    dwindle = { preserve_split = true },
    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = false },
    },
})

-- Discreet, GNOME-like motion (short durations, gentle easing).
hl.curve("gnomeLike", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } })
hl.animation({ leaf = "global",     enabled = true, speed = 6, bezier = "gnomeLike" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "gnomeLike" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "gnomeLike" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3, bezier = "gnomeLike" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "gnomeLike" })

----------------------
---- WINDOW RULES ----
----------------------
-- Floating-first: every window opens floating (Windows behavior).
hl.window_rule({ name = "float-all", match = { class = ".*" }, float = true })
-- NOTE: app-initiated maximize is deliberately *not* suppressed, so the GNOME
-- headerbar double-click (maximize / restore) keeps working.
-- XWayland drag fix from upstream default config.
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

--------------------------------------------
---- WINDOW GEOMETRY (Windows-like) -------
-------------------------------------------
-- Super+Arrow state machine. Two Hyprland 0.57 facts drive the design:
--   * `fullscreen({ action = "unset" })` WITHOUT `mode` is a silent no-op (it
--     answers "ok" but the window stays maximized) and every following
--     move/resize is then refused with "Window is fullscreen".
--   * the "normal" box of a maximized window is only known to Hyprland, so we
--     either record it before maximizing, or read it back right after clearing
--     the state (the Lua view of a window updates synchronously).
local geo   = {}   -- address -> { x, y, w, h } : the normal floating box
local wmode = {}   -- address -> "normal" | "maximized" | "halfT" | "halfL" | "halfR"

local function sel(w) return "address:" .. w.address end
local function box(w) return { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y } end

-- Usable area of a window's monitor: screen minus the reserved space (the LEGIT
-- Shell taskbar), so maximized / half windows never cover the bar.
local function work_area(w)
    local m = w.monitor or hl.get_active_monitor()
    if not m then return { x = 0, y = 0, w = 1280, h = 800 } end
    local r = m.reserved or {}
    local left, top     = r.left or 0, r.top or 0
    local right, bottom = r.right or 0, r.bottom or 0
    return {
        x = (m.x or 0) + left,
        y = (m.y or 0) + top,
        w = (m.width or m.size.width) - left - right,
        h = (m.height or m.size.height) - top - bottom,
    }
end

-- Clear Hyprland's maximize / fullscreen. The internal+client pair is
-- mandatory: without it the dispatcher does nothing. Returns a fresh snapshot
-- of the window (Hyprland has already restored its previous box).
local function unfullscreen(w)
    if w.fullscreen == 0 then return w end
    hl.dispatch(hl.dsp.window.fullscreen_state({
        window = sel(w), internal = 0, client = 0, action = "set",
    }))
    return hl.get_active_window() or w
end

-- Is this box one of the boxes the shortcuts produce? Used so a snapped box is
-- never mistaken for the window's "normal" geometry.
local function is_snapped_box(w, a)
    local tol  = 3
    local half = math.floor(a.w / 2)
    local function near(v, t) return math.abs(v - t) <= tol end
    if near(w.size.x, a.w) and near(w.size.y, a.h) then return true end
    if near(w.size.x, a.w) and near(w.size.y, math.floor(a.h / 2)) then return true end
    if near(w.size.y, a.h) and (near(w.size.x, half) or near(w.size.x, a.w - half)) then
        return true
    end
    return false
end

-- Remember the first "normal" box we see; never overwrite it with the box a
-- maximized/half state produced, so restore always returns to the original.
local function remember(w)
    if geo[w.address] or w.floating == false or w.fullscreen ~= 0 then return end
    if is_snapped_box(w, work_area(w)) then return end
    geo[w.address] = box(w)
end

-- Resize FIRST, then move. Resizing a floating window makes Hyprland re-place
-- it, which silently clobbers a position set just before (the window ended up
-- tens/hundreds of pixels off, half off-screen).
local function apply(w, x, y, ww, hh)
    hl.dispatch(hl.dsp.window.resize({ window = sel(w), x = ww, y = hh, relative = false }))
    hl.dispatch(hl.dsp.window.move({   window = sel(w), x = x,  y = y,  relative = false }))
end

local function maximize(w)
    hl.dispatch(hl.dsp.window.fullscreen({ window = sel(w), mode = "maximized", action = "set" }))
    wmode[w.address] = "maximized"
end

-- What is the window doing right now? Hyprland's own state comes first, so a
-- window maximized by the app (headerbar double-click) is understood too.
local function state_of(w)
    if w.fullscreen ~= 0 then return "maximized" end
    return wmode[w.address] or "normal"
end

-- Super is part of every window shortcut, and the Start menu is opened by the
-- *release* of Super alone. Without this guard the menu pops up (bottom-left,
-- dark panel) right after each Super+Arrow. A short one-shot timer keeps the
-- two behaviours apart.
local menu_suppressed = false
local function suppress_start_menu()
    menu_suppressed = true
    hl.timer(function() menu_suppressed = false end, { timeout = 500, type = "oneshot" })
end

-- Super+Up : normal -> maximize, maximized -> TOP half, half -> maximize.
local function win_up()
    local w = hl.get_active_window(); if not w then return end
    suppress_start_menu()
    local st = state_of(w)
    if st == "normal" then
        remember(w)
        maximize(w)
    elseif st == "maximized" then
        local r = unfullscreen(w)   -- Hyprland restores the previous box...
        remember(r)                 -- ...which becomes the box to restore to
        local a = work_area(r)
        apply(r, a.x, a.y, a.w, math.floor(a.h / 2))
        wmode[r.address] = "halfT"
    else
        maximize(w)                 -- from a half: back to maximized
    end
end

-- Super+Down : restore the original size AND position, or minimize when the
-- window is already in its normal floating state.
local function win_down()
    local w = hl.get_active_window(); if not w then return end
    suppress_start_menu()
    if state_of(w) ~= "normal" then
        local r = unfullscreen(w)
        local g = geo[r.address]
        if g then apply(r, g.x, g.y, g.w, g.h) end
        geo[r.address]   = nil
        wmode[r.address] = "normal"
        return
    end
    -- Already normal: hide it on the special workspace, the taskbar button
    -- brings it back (same behaviour as before).
    hl.dispatch(hl.dsp.window.move({ window = sel(w), workspace = "special:min" }))
end

-- Super+Left / Super+Right : half of the usable area (taskbar stays visible).
local function win_half(dir)
    local w = hl.get_active_window(); if not w then return end
    suppress_start_menu()
    if state_of(w) == "maximized" then
        w = unfullscreen(w)
        remember(w)
    else
        remember(w)
    end
    local a    = work_area(w)
    local half = math.floor(a.w / 2)
    if dir == "left" then
        apply(w, a.x, a.y, half, a.h)
        wmode[w.address] = "halfL"
    else
        apply(w, a.x + half, a.y, a.w - half, a.h)
        wmode[w.address] = "halfR"
    end
end

----------------------
---- KEYBINDINGS ----
-----------------------
local mainMod = "SUPER"

-- Super alone opens the Start menu, unless we just ran a window shortcut.
hl.bind(mainMod .. " + SUPER_L", function()
    if menu_suppressed then return end
    hl.dispatch(hl.dsp.exec_cmd(shellCtl .. " startmenu"))
end, { release = true })

-- Window management (Windows-style)
hl.bind("ALT + F4",  hl.dsp.window.close())
hl.bind(mainMod .. " + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + C",  hl.dsp.window.close())
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + UP",    function() win_up()        end)
hl.bind(mainMod .. " + DOWN",  function() win_down()      end)
hl.bind(mainMod .. " + LEFT",  function() win_half("left")  end)
hl.bind(mainMod .. " + RIGHT", function() win_half("right") end)
hl.bind(mainMod .. " + T",   hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",   hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Launchers (Windows + Ubuntu)
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(runDialog))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd(launcher))
hl.bind("CTRL + ALT + T",       hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + SHIFT + T", hl.dsp.exec_cmd(terminalAlt))
hl.bind(mainMod .. " + D",      hl.dsp.workspace.toggle_special("desktop"))
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("swaylock -f"))

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd("mkdir -p ~/Pictures && grim ~/Pictures/legit-shot-$(date +%s).png"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures && grim -g \"$(slurp)\" ~/Pictures/legit-shot-$(date +%s).png"))

-- Workspaces 1..5
for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end

-- Hardware keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })