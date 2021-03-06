###
# be.bastelstu.WCF.Chat
# 
# @author	Tim Düsterhus
# @copyright	2010-2012 Tim Düsterhus
# @license	Creative Commons Attribution-NonCommercial-ShareAlike <http://creativecommons.org/licenses/by-nc-sa/3.0/legalcode>
# @package	be.bastelstu.wcf.chat
###

be ?= {}
be.bastelstu ?= {}
be.bastelstu.WCF ?= {}

consoleMock = console
consoleMock ?= 
	log: () ->,
	warn: () ->,
	error: () ->

(($, window, console) ->
	be.bastelstu.WCF.Chat =
		# Tims Chat stops loading when this reaches zero
		# TODO: We need an explosion animation
		shields: 3
		
		# Templates
		titleTemplate: null
		messageTemplate: null
		
		# Notifications
		newMessageCount: null
		isActive: true
		
		# Autocompleter
		autocompleteOffset: 0
		autocompleteValue: null
		
		# Autoscroll
		oldScrollTop: null
		
		# Events
		events: 
			newMessage: $.Callbacks()
			userMenu: $.Callbacks()
		pe:
			getMessages: null
			refreshRoomList: null
			fish: null
		init: () ->
			console.log '[be.bastelstu.WCF.Chat] Initializing'
			@bindEvents()
			@events.newMessage.add $.proxy @notify, @
			
			@pe.refreshRoomList = new WCF.PeriodicalExecuter $.proxy(@refreshRoomList, @), 60e3
			@pe.getMessages = new WCF.PeriodicalExecuter $.proxy(@getMessages, @), @config.reloadTime * 1e3
			@refreshRoomList()
			@getMessages()
			
			console.log '[be.bastelstu.WCF.Chat] Finished initializing - Shields at 104 percent'
		###
		# Autocompletes a username
		###
		autocomplete: (firstChars, offset = @autocompleteOffset) ->
			users = []
			
			# Search all matching users
			for user in $ '.timsChatUser'
				username = $(user).data 'username'
				if username.indexOf(firstChars) is 0
					users.push username
			
			# None found -> return firstChars
			# otherwise return the user at the current offset
			return if users.length is 0 then firstChars else users[offset % users.length]
		###
		# Binds all the events needed for Tims Chat.
		###
		bindEvents: () ->
			# Mark window as focused
			$(window).focus $.proxy () ->
				document.title = @titleTemplate.fetch
					title: $('#timsChatRoomList .activeMenuItem a').text()
				@newMessageCount = 0
				@isActive = true
			, @
			
			# Mark window as blurred
			$(window).blur $.proxy () ->
				@isActive = false
			, @
			
			# Unload the chat
			window.onbeforeunload = $.proxy () ->
				@unload()
				return undefined
			, @
			
			# Insert a smiley
			$('.jsSmiley').click $.proxy (event) ->
				@insertText ' ' + $(event.target).attr('alt') + ' '
			, @
			
			# Switch sidebar tab
			$('.timsChatSidebarTabs li').click $.proxy (event) ->
				event.preventDefault()
				@toggleSidebarContents $ event.target
			, @
			
			# Submit Handler
			$('#timsChatForm').submit $.proxy (event) ->
				event.preventDefault()
				@submit $ event.target
			, @
			
			# Autocompleter
			$('#timsChatInput').keydown $.proxy (event) ->
				# tab key
				if event.keyCode is 9
					event.preventDefault()
					if @autocompleteValue is null
						@autocompleteValue = $('#timsChatInput').val()
					
					firstChars = @autocompleteValue.substring(@autocompleteValue.lastIndexOf(' ')+1)
					
					console.log '[be.bastelstu.WCF.Chat] Autocompleting "' + firstChars + '"'
					return if firstChars.length is 0
					
					# Insert name and increment offset
					$('#timsChatInput').val(@autocompleteValue.substring(0, @autocompleteValue.lastIndexOf(' ') + 1) + @autocomplete(firstChars) + ', ')
					@autocompleteOffset++
				else
					@autocompleteOffset = 0
					@autocompleteValue = null
			, @
			
			# Refreshes the roomlist
			$('#timsChatRoomList button').click $.proxy(@refreshRoomList, @)
			
			# Clears the stream
			$('#timsChatClear').click (event) ->
				event.preventDefault()
				$('.timsChatMessage').remove()
				@oldScrollTop = null
				$('.timsChatMessageContainer').scrollTop $('.timsChatMessageContainer ul').height()
				$('#timsChatInput').focus()
			
			# Toggle Buttons
			$('.timsChatToggle').click (event) ->
				element = $ @
				icon = element.find 'img'
				if element.data('status') is 1
					element.data 'status', 0
					icon.attr 'src', icon.attr('src').replace /enabled(\d?).([a-z]{3})$/, 'disabled$1.$2'
					element.attr 'title', element.data 'enableMessage'
				else
					element.data 'status', 1
					icon.attr 'src', icon.attr('src').replace /disabled(\d?).([a-z]{3})$/, 'enabled$1.$2'
					element.attr 'title', element.data 'disableMessage'
					
			# Immediatly scroll down when activating autoscroll
			$('#timsChatAutoscroll').click (event) ->
				$(this).parent().removeClass('default')
				if $(this).data 'status'
					$('.timsChatMessageContainer').scrollTop $('.timsChatMessageContainer ul').height()
					@oldScrollTop = $('.timsChatMessageContainer').scrollTop()
					
			# Desktop Notifications
			unless typeof window.webkitNotifications is 'undefined'
				$('#timsChatNotify').click (event) ->
					window.webkitNotifications.requestPermission() if $(this).data 'status'
					
		###
		# Changes the chat-room.
		# 
		# @param	jQuery-object	target
		###
		changeRoom: (target) ->
			window.history.replaceState {}, '', target.attr('href')
				
			$.ajax target.attr('href'), 
				dataType: 'json'
				data: 
					ajax: 1
				type: 'POST'
				success: $.proxy((data, textStatus, jqXHR) ->
					@loading = false
					target.parent().removeClass 'ajaxLoad'
					
					# Mark as active
					$('.activeMenuItem .timsChatRoom').parent().removeClass 'activeMenuItem'
					target.parent().addClass 'activeMenuItem'
					
					# Set new topic
					if data.topic is ''
						return if $('#timsChatTopic').text().trim() is ''
						
						$('#timsChatTopic').wcfBlindOut 'vertical', () ->
							$(@).text ''
					else
						$('#timsChatTopic').text data.topic
						$('#timsChatTopic').wcfBlindIn() if $('#timsChatTopic').text().trim() isnt '' and $('#timsChatTopic').is(':hidden')
					
					$('.timsChatMessage').addClass 'unloaded', 800
					@handleMessages data.messages
					document.title = @titleTemplate.fetch data
				, @)
				error: () ->
					# Reload the page to change the room the old fashion-way
					# inclusive the error-message :)
					window.location.reload true
				beforeSend: $.proxy(() ->
					return false if @loading or target.parent().hasClass 'activeMenuItem'
					
					@loading = true
					target.parent().addClass 'ajaxLoad'
				, @)
		###
		# Frees the fish
		###
		freeTheFish: () ->
			return if $.wcfIsset 'fish'
			console.warn '[be.bastelstu.WCF.Chat] Freeing the fish'
			fish = $ '<div id="fish">' + WCF.String.escapeHTML('><((((\u00B0>') + '</div>'
			fish.css
				position: 'absolute'
				top: '150px'
				left: '400px'
				color: 'black'
				textShadow: '1px 1px white'
				zIndex: 9999
			
			fish.appendTo $ 'body'
			@pe.fish = new WCF.PeriodicalExecuter(() ->
				left = Math.random() * 100 - 50
				top = Math.random() * 100 - 50
				fish = $ '#fish'
				
				left *= -1 unless fish.width() < (fish.position().left + left) < ($(document).width() - fish.width())
				top *= -1 unless fish.height() < (fish.position().top + top) < ($(document).height() - fish.height())
				
				fish.text '><((((\u00B0>' if left > 0
				fish.text '<\u00B0))))><' if left < 0
				
				fish.animate
					top: '+=' + top
					left: '+=' + left
				, 1e3
			, 1.5e3)
		###
		# Loads new messages.
		###
		getMessages: () ->
			$.ajax 'index.php/Chat/Message/',
				dataType: 'json'
				type: 'POST'
				success: $.proxy((data, textStatus, jqXHR) ->
					@handleMessages(data.messages)
					@handleUsers(data.users)
				, @)
				error: $.proxy((jqXHR, textStatus, errorThrown) ->
					console.error '[be.bastelstu.WCF.Chat] Battle Station hit - shields at ' + (--@shields / 3 * 104) + ' percent'
					if @shields is 0
						@pe.refreshRoomList.stop()
						@pe.getMessages.stop()
						@freeTheFish()
						console.error '[be.bastelstu.WCF.Chat] We got destroyed, but could free our friend the fish before he was killed as well. Have a nice life in freedom!'
						alert 'herp i cannot load messages'
				, @)
		###
		# Inserts the new messages.
		#
		# @param	array<object>	messages
		###
		handleMessages: (messages) ->
			# Disable scrolling automagically when user manually scrolled
			unless @oldScrollTop is null
				if $('.timsChatMessageContainer').scrollTop() < @oldScrollTop
					if $('#timsChatAutoscroll').data('status') is 1
						$('#timsChatAutoscroll').click()
						$('#timsChatAutoscroll').parent().addClass('default').fadeOut('slow').fadeIn('slow')
			
			# Insert the messages
			for message in messages
				continue if $.wcfIsset 'timsChatMessage' + message.messageID # Prevent problems with race condition
				@events.newMessage.fire message
				
				output = @messageTemplate.fetch message
				li = $ '<li></li>'
				li.attr 'id', 'timsChatMessage'+message.messageID
				li.addClass 'timsChatMessage timsChatMessage'+message.type
				li.addClass 'ownMessage' if message.sender is WCF.User.userID
				li.append output
				
				li.appendTo $ '.timsChatMessageContainer > ul'
				
			# Autoscroll down
			if $('#timsChatAutoscroll').data('status') is 1
				$('.timsChatMessageContainer').scrollTop $('.timsChatMessageContainer ul').height()
			@oldScrollTop = $('.timsChatMessageContainer').scrollTop()
		###
		# Builds the userlist.
		#
		# @param	array<object>	users
		###
		handleUsers: (users) ->
			foundUsers = { }
			for user in users
				id = 'timsChatUser-'+user.userID
				element = $ '#'+id
				
				# Move the user to the correct position
				if element[0]
					console.log '[be.bastelstu.WCF.Chat] Moving User: "' + user.username + '"'
					element = element.detach()
					if user.awayStatus?
						element.addClass 'timsChatAway'
						element.attr 'title', user.awayStatus
					else
						element.removeClass 'timsChatAway'
						element.removeAttr 'title'
						element.data 'tooltip', ''
					$('#timsChatUserList').append element
				# Insert the user
				else
					console.log '[be.bastelstu.WCF.Chat] Inserting User: "' + user.username + '"'
					li = $ '<li></li>'
					li.attr 'id', id
					li.addClass 'timsChatUser'
					li.addClass 'jsTooltip'
					if user.awayStatus?
						li.addClass 'timsChatAway'
						li.attr 'title', user.awayStatus
					li.data 'username', user.username
					a = $ '<a href="javascript:;">'+user.username+'</a>'
					a.click $.proxy (event) ->
						event.preventDefault()
						@toggleUserMenu $ event.target
					, @
					li.append a
					menu = $ '<ul></ul>'
					menu.addClass 'timsChatUserMenu'
					menu.append $ '<li><a href="javascript:;">' + WCF.Language.get('wcf.chat.query') + '</a></li>'
					menu.append $ '<li><a href="javascript:;">' + WCF.Language.get('wcf.chat.kick') + '</a></li>'
					menu.append $ '<li><a href="javascript:;">' + WCF.Language.get('wcf.chat.ban') + '</a></li>'
					menu.append $ '<li><a href="index.php/User/' + user.userID + '">' + WCF.Language.get('wcf.chat.profile') + '</a></li>'
					@events.userMenu.fire user, menu
					li.append menu
					li.appendTo $ '#timsChatUserList'
				
				foundUsers[id] = true
			
			# Remove users that were not found
			$('.timsChatUser').each () ->
				if typeof foundUsers[$(@).attr('id')] is 'undefined'
					console.log '[be.bastelstu.WCF.Chat] Removing User: "' + $(@).data('username') + '"'
					$(@).remove();
					
			
			$('#toggleUsers .wcf-badge').text(users.length);
		###
		# Inserts text into our input.
		# 
		# @param	string	text
		# @param	object	options
		###
		insertText: (text, options) ->
			options = $.extend
				append: true
				submit: false
			, options or {}
			
			text = $('#timsChatInput').val() + text if options.append
			$('#timsChatInput').val(text)
			$('#timsChatInput').keyup()
			
			if (options.submit)
				$('#timsChatForm').submit()
			else
				$('#timsChatInput').focus()
		###
		# Sends a notification about a message.
		#
		# @param	object	message
		###
		notify: (message) ->
			return if @isActive or $('#timsChatNotify').data('status') is 0
			@newMessageCount++
			
			document.title = '(' + @newMessageCount + ') ' + @titleTemplate.fetch
				 title: $('#timsChatRoomList .activeMenuItem a').text()
			
			# Desktop Notifications
			if typeof window.webkitNotifications isnt 'undefined'
				if window.webkitNotifications.checkPermission() is 0
					title = WCF.Language.get 'wcf.chat.newMessages'
					icon = WCF.Icon.get 'be.bastelstu.wcf.chat.chat'
					content = message.username + message.separator + ' ' + message.message
					notification = window.webkitNotifications.createNotification icon, title, content
					notification.show()
					setTimeout(() ->
						notification.cancel()
					, 5e3)
		###
		# Refreshes the room-list.
		###
		refreshRoomList: () ->
			console.log '[be.bastelstu.WCF.Chat] Refreshing the roomlist'
			$('#toggleRooms a').addClass 'ajaxLoad'
			
			$.ajax $('#toggleRooms a').data('refreshUrl'),
				dataType: 'json'
				type: 'POST'
				success: $.proxy((data, textStatus, jqXHR) ->
					$('#timsChatRoomList li').remove()
					$('#toggleRooms a').removeClass 'ajaxLoad'
					$('#toggleRooms .wcf-badge').text data.length
					
					for room in data
						li = $ '<li></li>'
						li.addClass 'activeMenuItem' if room.active
						$('<a href="' + room.link + '">' + room.title + '</a>').addClass('timsChatRoom').appendTo li
						$('#timsChatRoomList ul').append li
						
					$('.timsChatRoom').click $.proxy (event) ->
						return if typeof window.history.replaceState is 'undefined'
						event.preventDefault()
						@changeRoom $ event.target
					, @
					
					console.log '[be.bastelstu.WCF.Chat] Found ' + data.length + ' rooms'
				, @)
		###
		# Handles submitting of messages.
		# 
		# @param	jQuery-object	target
		###
		submit: (target) ->
			# Break if input contains only whitespace
			return false if $('#timsChatInput').val().trim().length is 0
			
			# Finally free the fish
			@freeTheFish() if $('#timsChatInput').val().trim().toLowerCase() is '/free the fish'
			
			text = $('#timsChatInput').val()
			$('#timsChatInput').val('').focus().keyup()
			$.ajax $('#timsChatForm').attr('action'), 
				data:
					text: text
					smilies: $('#timsChatSmilies').data 'status'
				type: 'POST',
				beforeSend: (jqXHR) ->
					$('#timsChatInput').addClass 'ajaxLoad'
				success: $.proxy((data, textStatus, jqXHR) ->
					@getMessages()
				, @)
				complete: () ->
					$('#timsChatInput').removeClass 'ajaxLoad'
		###
		# Toggles between user- and room-list.
		# 
		# @param	jQuery-object	target
		###
		toggleSidebarContents: (target) ->
			return if target.parents('li').hasClass 'active'
			
			if target.parents('li').attr('id') is 'toggleUsers'
				$('#toggleUsers').addClass 'active'
				$('#toggleRooms').removeClass 'active'
				
				$('#timsChatRoomList').hide()
				$('#timsChatUserList').show()
			else if target.parents('li').attr('id') is 'toggleRooms'
				$('#toggleRooms').addClass 'active'
				$('#toggleUsers').removeClass 'active'
				
				$('#timsChatUserList').hide()
				$('#timsChatRoomList').show()
		###
		# Toggles the user-menu.
		#
		# @param	jQuery-object	target
		###
		toggleUserMenu: (target) ->
			li = target.parent()
			
			if li.hasClass 'activeMenuItem'
				li.find('.timsChatUserMenu').wcfBlindOut 'vertical', () ->
					li.removeClass 'activeMenuItem'
			else
				li.addClass 'activeMenuItem'
				li.find('.timsChatUserMenu').wcfBlindIn 'vertical'
		###
		# Unloads the chat.
		###
		unload: () ->
			$.ajax @config.unloadURL,
				type: 'POST'
				async: false
)(jQuery, @, consoleMock)
