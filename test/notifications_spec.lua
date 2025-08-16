describe("Notifications", function()
	local notifications
	local config

	before_each(function()
		-- Mock vim environment
		_G.vim = _G.vim or {}
		_G.vim.notify = function(msg, level, opts)
			return msg
		end
		_G.vim.api = _G.vim.api or {}
		_G.vim.api.nvim_echo = function(msg, history, opts)
			return msg[1][1]
		end
		_G.vim.log = { levels = { INFO = 1 } }

		-- Reset the notifications module before each test
		package.loaded["maorun.code-stats.notifications"] = nil
		package.loaded["maorun.code-stats.logging"] = nil
		notifications = require("maorun.code-stats.notifications")

		-- Default config for testing
		config = {
			notifications = {
				enabled = true,
				level_up = {
					enabled = true,
					message = "🎉 Level Up! %s reached level %d!",
				},
			},
		}
	end)

	describe("setup", function()
		it("should configure notifications with provided config", function()
			notifications.setup(config)
			-- Setup should complete without errors
			assert.is.truthy(true)
		end)
	end)

	describe("level_up", function()
		it("should send notification when notifications are enabled", function()
			notifications.setup(config)

			-- Mock vim.notify to capture the call
			local notification_sent = false
			local notification_message = ""
			_G.vim.notify = function(msg, level, opts)
				notification_sent = true
				notification_message = msg
			end

			notifications.level_up("lua", 2)

			assert.is.truthy(notification_sent)
			assert.are.equal("🎉 Level Up! lua reached level 2!", notification_message)
		end)

		it("should not send notification when notifications are disabled", function()
			config.notifications.enabled = false
			notifications.setup(config)

			local notification_sent = false
			_G.vim.notify = function(msg, level, opts)
				notification_sent = true
			end

			notifications.level_up("lua", 2)

			assert.is.falsy(notification_sent)
		end)

		it("should not send notification when level_up notifications are disabled", function()
			config.notifications.level_up.enabled = false
			notifications.setup(config)

			local notification_sent = false
			_G.vim.notify = function(msg, level, opts)
				notification_sent = true
			end

			notifications.level_up("lua", 2)

			assert.is.falsy(notification_sent)
		end)

		it("should use custom message format", function()
			config.notifications.level_up.message = "Custom: %s advanced to level %d!"
			notifications.setup(config)

			local notification_message = ""
			_G.vim.notify = function(msg, level, opts)
				notification_message = msg
			end

			notifications.level_up("python", 3)

			assert.are.equal("Custom: python advanced to level 3!", notification_message)
		end)

		it("should fallback to nvim_echo when vim.notify is not available", function()
			notifications.setup(config)

			-- Remove vim.notify to test fallback
			_G.vim.notify = nil

			local echo_called = false
			local echo_message = ""
			_G.vim.api.nvim_echo = function(msg, history, opts)
				echo_called = true
				echo_message = msg[1][1]
			end

			notifications.level_up("javascript", 4)

			assert.is.truthy(echo_called)
			assert.are.equal("🎉 Level Up! javascript reached level 4!", echo_message)
		end)
	end)
end)
