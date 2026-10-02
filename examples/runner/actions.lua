--- Input actions shared by every example. The engine adds the locked ui_*
--- actions itself; the runner reserves ui_cancel (Escape) for "back to the
--- picker", so examples should not react to it.
return {
  deadzone = 0.25,
  actions = {
    { name = "move_left",  label = "Move left",  category = "Movement", bindings = { "key:a", "key:left",  "axis:leftx-", "pad:dpleft" } },
    { name = "move_right", label = "Move right", category = "Movement", bindings = { "key:d", "key:right", "axis:leftx+", "pad:dpright" } },
    { name = "move_up",    label = "Move up",    category = "Movement", bindings = { "key:w", "key:up",    "axis:lefty-", "pad:dpup" } },
    { name = "move_down",  label = "Move down",  category = "Movement", bindings = { "key:s", "key:down",  "axis:lefty+", "pad:dpdown" } },
    { name = "action",     label = "Action",     category = "Actions",  bindings = { "key:space", "mouse:1", "pad:a" } },
    { name = "secondary",  label = "Secondary",  category = "Actions",  bindings = { "key:lshift", "mouse:2", "pad:x" } },
    { name = "pause",      label = "Pause",      category = "System",   bindings = { "key:p", "pad:start" } },
  },
}
