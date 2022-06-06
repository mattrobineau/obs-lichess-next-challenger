local ffi = require("ffi")
ffi.cdef [[
    const char* get_next_challenger();
    void connect_to_feed(const char *token);
    void terminate();
]]

local lib = ffi.load('g:/repositories/obs/obs-lichess-next-challenger/target/debug/obs_lichess_next_opponent.dll')

obs = obslua
source_name = ""
token = ""
next_challenger = ""
template = "%s"
is_source_enabled = false

function script_properties()
    local props = obs.obs_properties_create()

    local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()

    -- As long as the sources are not empty, then
    if sources ~= nil then
        -- iterate over all the sources
        for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_id(source)
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)
        end
    end

    obs.source_list_release(sources)

    obs.obs_properties_add_text(props, "token", "Personal Access Token", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "template", "Template", obs.OBS_TEXT_DEFAULT)

    return props
end

-- called to set the initial default values
function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "token", token)
    obs.obs_data_set_default_string(settings, "template", template)
end

-- called when settings are changes
function script_update(settings)
    token = obs.obs_data_get_string(settings, "token")
    source_name = obs.obs_data_get_string(settings, "source")
    template = obs.obs_data_get_string(settings, "template")

    -- When a user changes the Text source
    -- check if the source is enabled or disabled
    -- connect if enabled
    local source = obs.obs_get_source_by_name(source_name)
    local enabled = "disabled"
    is_source_enabled = obs.obs_source_enabled(source)
    if is_source_enabled then
        enabled = "enabled"
    end
    print("obs_lichess_next_opponent source " .. source_name .. " is " .. enabled)
    -- reset in case token has changed
    reset()
end

function script_load(settings)
    print("obs_lichess_next_opponent script loaded")
    -- Setup delegates
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
    obs.signal_handler_connect(sh, "source_activate", source_activated)
    token = obs.obs_data_get_string(settings, "token")
    source_name = obs.obs_data_get_string(settings, "source")
    template = obs.obs_data_get_string(settings, "template")
    connect()
end

function source_activated(data)
    print("source_activated called")
    local source = obs.calldata_source(data, "source")

    if source ~= nil then
        local name = obs.obs_source_get_name(source)
        print("source " .. name .. " is activated")
        -- Is it our source?
        if name == source_name then
            print("obs_lichess_next_opponent source activated")
            is_source_enabled = true
            connect()
        end
    end
end

function connect()
    if not is_source_enabled then
        if token == '' or token == nil then
            set_text("Error: token")
            print("obs_lichess_next_opponent Token is not set")
        else
            print("obs_lichess_next_opponent connecting to feed")
            lib.connect_to_feed(token)
            is_source_enabled = true
            set_text("")
            obs.timer_add(set_challenger, 10000) -- 10 seconds
            print("obs_lichess_next_opponent timer added in connect")
        end
    end
end

function source_deactivated(data)
    local source = obs.calldata_source(data, "source")
    if source ~= nil then
        local name = obs.obs_source_get_name(source)
        -- Is it our source?
        if (name == source_name) then
            print("obs_lichess_next_opponent source deactivated")
            lib.terminate()
            is_source_enabled = false
        end
    end
end

function script_unload(settings)
    print("obs_lichess_next_opponent unload")
    --lib.terminate()
end

function reset()
    print("obs_lichess_next_opponent reset")
    lib.terminate()
    connect()
end

function set_challenger()
    if not is_source_enabled then
        obs.remove_current_callback()
        return
    end
    print("obs_lichess_next_opponent getting next challenger")
    local next_challenger_name = ffi.string(lib.get_next_challenger())
    local text = template:format(next_challenger_name)
    set_text(text)
end

function set_text(text)
    local source = obs.obs_get_source_by_name(source_name)

    if source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end
