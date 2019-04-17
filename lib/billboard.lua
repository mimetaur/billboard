--- Billboard class.

-- TODO
-- could this whole thing be simplified and
-- baked into the Norns UI library as a Popup UI class?

local Billboard = {}
Billboard.__index = Billboard

-- TODO either register more fonts here
-- or create a pull request so we can work with norns fonts
-- without magic numbers
Billboard.FONTS = {CTRL_D_10_REGULAR = 28, CTRL_D_10_BOLD = 27}

local ALIGN_TYPES = {"center", "left"}
local FADEOUT_STEPS = 7

local function calculate_line_height(self)
    return util.round(self.font_size_ * self.line_height_, 1.0)
end

local function calculate_line_height_multiple(self, i)
    return util.round(calculate_line_height(self) * i, 1.0)
end

local function check_bold(self, line_num)
    if tab.contains(self.bold_lines_, line_num) then
        screen.font_face(self.bold_font_)
    else
        screen.font_face(self.font_)
    end
end

local function fadeout_rate(self)
    return (self.fadeout_time_ / FADEOUT_STEPS)
end

local function set_new_options(self, options)
    -- margins
    self.x_margin_ = options.x_margin or 7
    self.y_margin_ = options.y_margin or 7

    -- or instead set direct x, y, w, h values
    self.x_ = options.x or self.x_margin_
    self.y_ = options.y or self.y_margin_
    self.w_ = options.w or util.round(127 - self.x_margin_)
    self.h_ = options.h or util.round(63 - self.y_margin_)

    -- for placing text within the billboard frame
    self.text_x_ = options.text_x or util.round(self.x_ + (self.w_ / 2))
    self.text_y_ = options.text_y or util.round(self.y_ + (self.h_ / 2))

    -- how long the billboard is on screen for
    self.fadeout_time_ = options.fadeout_time or 0.75

    -- foreground and background levels (0 to 15)
    self.bg_ = options.bg_level or 0
    self.fg_ = options.fg_level or 14

    -- font settings
    self.font_ = options.font or Billboard.FONTS.CTRL_D_10_REGULAR
    self.bold_font_ = options.bold_font or Billboard.FONTS.CTRL_D_10_BOLD
    self.font_size_ = options.font_size or 10

    -- layout settings
    self.line_height_ = options.line_height or 1.6

    local default_alignment = "center"
    local alignment = options.align or default_alignment
    if not tab.contains(ALIGN_TYPES, alignment) then
        alignment = default_alignment
    end
    self.align_ = alignment
end

function Billboard.new(options)
    local b = {}

    -- merge options into b table
    local options = options or {}
    set_new_options(b, options)

    -- internal state
    b.active_ = false
    b.do_display_ = false
    b.message_ = ""
    b.bold_lines_ = {}
    b.curfg_ = b.fg_
    b.fade_steps_ = 0

    -- once hold completes billboard fades out
    local function fadeout_callback()
        b.fade_steps_ = b.fade_steps_ + 1
        if b.fade_steps_ == FADEOUT_STEPS then
            -- stop the fadeout
            -- and reset message state
            b.do_display_ = false
            b.message_ = ""
            b.curfg_ = b.fg_
            b.fade_steps_ = 0
        else
            -- if the foreground isn't fully faded out
            if b.curfg_ > b.bg_ then
                -- then keep fading out
                local dec = b.fg_ / FADEOUT_STEPS
                b.curfg_ = util.round(b.curfg_ - dec, 1.0)
            end
        end
    end
    b.on_fade_ = metro.init(fadeout_callback, fadeout_rate(b), FADEOUT_STEPS)

    -- this is a built in 1 sec delay callback to give
    -- the internal params on the norms a chance to
    -- settle down instead of showing billboards instantly
    local function start_callback()
        b.active_ = true
    end
    b.on_start_ = metro.init(start_callback, 1, 1)
    b.on_start_:start()

    setmetatable(b, Billboard)
    return b
end

function Billboard:set_options(options)
    set_new_options(self, options)
end

function Billboard:bold_line(line_num)
    table.insert(self.bold_lines_, line_num)
end

function Billboard:display_param(param_name, param_value, bold_value)
    local b = bold_value or true
    self:display(param_name, param_value)
    if b then
        self:bold_line(2)
    end
end

function Billboard:display(...)
    if not self.active_ then
        return
    end

    local new_msg = {}
    for _, msg in ipairs({...}) do
        table.insert(new_msg, msg)
    end

    self.message_ = new_msg
    self.curfg_ = self.fg_
    self.do_display_ = true
    self.on_fade_:start(fadeout_rate(self))
end

function Billboard:draw()
    if self.message_ and self.active_ and self.do_display_ then
        -- draw bg
        screen.level(self.bg_)
        screen.rect(self.x_, self.y_, self.w_, self.h_)
        screen.fill()

        -- draw border
        screen.level(self.curfg_)
        screen.rect(self.x_, self.y_, self.w_, self.h_)
        screen.stroke()

        -- draw message
        screen.level(self.curfg_)
        screen.move(self.text_x_, self.text_y_)
        screen.font_size(self.font_size_)

        for i, msg in ipairs(self.message_) do
            check_bold(self, i)

            if self.align_ == "center" then
                screen.text_center(msg)
            else
                screen.text(msg)
            end

            screen.move(self.text_x_, self.text_y_ + calculate_line_height_multiple(self, i))
        end

        -- return the font face and font size to default
        screen.font_size(8)
        screen.font_face(1)
    end
end

return Billboard
