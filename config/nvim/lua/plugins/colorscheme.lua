-- Read theme from ~/.config/omaterm/nvim.theme, default to "default" (terminal ANSI colors)
local theme_file = vim.fn.expand("~/.config/omaterm/nvim.theme")
local theme = "tokyonight"

local ok, lines = pcall(vim.fn.readfile, theme_file)
if ok and #lines > 0 and lines[1]:match("%S") then
	theme = vim.trim(lines[1])
end

local colorscheme_by_theme = {
	["osaka-jade"] = "bamboo",
	ristretto = "monokai-pro",
}

return {
	-- All Omarchy theme plugins (lazy-loaded, only selected one activates)
	{ "ribru17/bamboo.nvim", lazy = true, priority = 1000 },
	{ "bjarneo/aether.nvim", lazy = true, priority = 1000 },
	{ "bjarneo/ethereal.nvim", lazy = true, priority = 1000 },
	{ "bjarneo/hackerman.nvim", lazy = true, priority = 1000 },
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = true,
		priority = 1000,
		opts = function(_, opts)
			opts = opts or {}
			if theme == "catppuccin-latte" then
				opts.flavour = "latte"
			end
			return opts
		end,
	},
	{ "sainnhe/everforest", lazy = true, priority = 1000 },
	{ "kepano/flexoki-neovim", lazy = true, priority = 1000 },
	{ "ellisonleao/gruvbox.nvim", lazy = true, priority = 1000 },
	{ "rebelot/kanagawa.nvim", lazy = true, priority = 1000 },
	{ "omacom-io/lumon.nvim", lazy = true, priority = 1000 },
	{ "tahayvr/matteblack.nvim", lazy = true, priority = 1000 },
	{
		"loctvl842/monokai-pro.nvim",
		lazy = true,
		priority = 1000,
		opts = function(_, opts)
			opts = opts or {}
			if theme == "ristretto" then
				opts.filter = "ristretto"
				opts.override = function()
					return {
						NonText = { fg = "#948a8b" },
						MiniIconsGrey = { fg = "#948a8b" },
						MiniIconsRed = { fg = "#fd6883" },
						MiniIconsBlue = { fg = "#85dacc" },
						MiniIconsGreen = { fg = "#adda78" },
						MiniIconsYellow = { fg = "#f9cc6c" },
						MiniIconsOrange = { fg = "#f38d70" },
						MiniIconsPurple = { fg = "#a8a9eb" },
						MiniIconsAzure = { fg = "#a8a9eb" },
						MiniIconsCyan = { fg = "#85dacc" },
					}
				end
			end
			return opts
		end,
	},
	{ "shaunsingh/nord.nvim", lazy = true, priority = 1000 },
	{ "OldJobobo/retro-82.nvim", lazy = true, priority = 1000 },
	{ "rose-pine/neovim", name = "rose-pine", lazy = true, priority = 1000 },
	{ "folke/tokyonight.nvim", lazy = true, priority = 1000 },
	{ "bjarneo/vantablack.nvim", lazy = true, priority = 1000 },
	{ "bjarneo/white.nvim", lazy = true, priority = 1000 },
	{ "xero/miasma.nvim", lazy = true, priority = 1000 },

	-- Apply selected theme
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = colorscheme_by_theme[theme] or theme,
		},
	},
}
