local Players = game:GetService("Players")

local player_list = {}
local player_turn = -1
local player_hands = {}

local deck = {}
local discard_stack = {}

local game_running = false

---------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- incoming from client
local RequestCard = ReplicatedStorage.RequestCard
local SwapCardPosition = ReplicatedStorage.SwapCardPosition
local DiscardCard = ReplicatedStorage.DiscardCard
local TakeDiscard = ReplicatedStorage.TakeDiscard

-- outgoing to client
local RecycleFade = ReplicatedStorage.RecycleFade
---------------------------------------------------------------

-----------------------------------------------------------------------------
							-- game starters
-----------------------------------------------------------------------------

function reset_deck()
	deck = {}
	for i = 1, 54 do
		table.insert(deck, i)
	end
end

function reset_discard()
	discard_stack = {}

	table.insert(discard_stack, table.remove(deck, math.random(1, #deck)))
end

function select_players()
	player_list = {}
	
	for _, player in ipairs(Players:GetChildren()) do
		table.insert(player_list, player)
	end
end

function handout_cards()
	player_hands = {}
	for i = 1, 5 do
		for k, player in ipairs(player_list) do
			if i == 1 then
				table.insert(player_hands, {})
			end
			table.insert(player_hands[k], table.remove(deck, math.random(1, #deck)))
		end
	end
end

function player_exists(player)
	return player and player.PlayerGui and player.PlayerGui.ScreenGui
end

-----------------------------------------------------------------------------
							-- win checks
-----------------------------------------------------------------------------

-- 5 of a kind (need joker)
function is_five(hand, jokers)
	--print("check 5")
	if jokers == 0 then
		return false
	end
	
	local value = hand[1] % 13

	for i = 2, (5 - jokers) do
		if value ~= hand[i] % 13 then
			return false
		end
	end

	return "five of a kind"
end

-- 5 suited straight (can have joker)
function is_straight(hand, jokers)
	--print("check straight")
	local spare_jokers = jokers
	
	-- first check if same suit
	for i = 1, ((5-1) - jokers) do
		if math.ceil(hand[i] / 13) ~= math.ceil(hand[i+1] / 13) then
			return false
		end
	end
	
	-- then check if they are in a row, knowing we wont cross suit boundaries
	for i = 1, ((5-1) - jokers) do
		-- comparison good
		if hand[i+1] - hand[i] == 1 then
			
		-- comparison one off, do we have joker?	
		elseif hand[i+1] - hand[i] == 1 + 1 then
			if spare_jokers >= 1 then
				spare_jokers -= 1
			else
				return false
			end
			
		-- comparison two off, do we have two jokers?	
		elseif hand[i+1] - hand[i] == 1 + 2 then
			if spare_jokers >= 2 then
				spare_jokers -= 2
			else
				return false
			end
			
	-- need to check if A,10,J,Q,K
		-- comparison good, A -> 10
		elseif hand[i] % 13 == 1 and hand[i+1] - hand[i] == 9 then
			
		-- comparison one off, A -> J + joker(10)
		elseif hand[i] % 13 == 1 and hand[i+1] - hand[i] == 9 + 1 then	
			if spare_jokers >= 1 then
				spare_jokers -= 1
			else
				return false
			end
			
		-- comparison two off, A -> Q + 2 jokers(10, J)
		elseif hand[i] % 13 == 1 and hand[i+1] - hand[i] == 9 + 2 then
			if spare_jokers >= 2 then
				spare_jokers -= 2
			else
				return false
			end
			
		-- comparison more than two off, not straight	
		else
			return false
		end
	end
	
	return "straight flush"
end

function is_hand_winner(hand)
	local copy = table.clone(hand)
	table.sort(copy)
	
	-- joker check:
	local jokers = (table.find(copy, 53) and 1 or 0) + (table.find(copy, 54) and 1 or 0)
	
	local result = is_five(copy, jokers) or is_straight(copy, jokers)
	
	if result then
		for i, player in ipairs(player_list) do
			if not player_exists(player) then
				continue
			end
			
			local players_hand = player.PlayerGui.ScreenGui.Frame.cards.cards

			for k, card in ipairs(player_hands[i]) do
				players_hand[k].Interactable = false
			end
		end
	end
	
	return result
end

function show_winner(player, hand_type)
	if not player_exists(player) then
		return
	end	

	local winning_hand = player.PlayerGui.ScreenGui.Frame.cards.cards:Clone()

	table.sort(player_hands[player_turn])

	for i, card in ipairs(player_hands[player_turn]) do
		local face, color = translate_card(card)

		winning_hand[i].Text = face
		winning_hand[i].TextColor = color
	end

	for _, any_player in ipairs(Players:GetChildren()) do
		if not player_exists(any_player) then
			continue
		end

		local winner_copy = any_player.PlayerGui.ScreenGui.Frame.winner:Clone()

		winner_copy.Visible = true

		local copy_hand = winning_hand:Clone()

		copy_hand.Parent = winner_copy.Frame

		winner_copy.Parent = any_player.PlayerGui.ScreenGui.Frame

		winner_copy.TextLabel.Text = player.Name .. " wins with a " .. hand_type .. "!"

		game:GetService("Debris"):AddItem(winner_copy, 10)

		task.wait(10)
		game_running = false
	end
end

-----------------------------------------------------------------------------
								-- updating card guis
-----------------------------------------------------------------------------

local suits = {"♠", "♥", "♣", "♦"}
local colors = {Color3.fromRGB(0,0,0), Color3.fromRGB(199, 38, 38), Color3.fromRGB(7,69,64), Color3.fromRGB(241,90,38)}
local values = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

function translate_card(number)
	number = tonumber(number)
	
	if number > 52 then
		return "Joker", BrickColor.new(colors[1])
	end
	
	local value = values[number % 13]
	if number % 13 == 0 then
		value = values[13]
	end
	
	local card_group = math.ceil(number / 13)
	local suit = suits[card_group]
	local color = BrickColor.new(colors[card_group])
	
	return value .. suit, color
end

function show_hands()
	for i, player in ipairs(player_list) do
		if not player_exists(player) then
			continue
		end	
	
		local players_hand = player.PlayerGui.ScreenGui.Frame.cards.cards
		
		for k, card in ipairs(player_hands[i]) do
			local face, color = translate_card(card)
			
			players_hand[k].Text = face
			players_hand[k].TextColor = color
			players_hand[k].Interactable = true
		end
		
		players_hand["6"].Interactable = true
	end
end

function update_discard()
	for _, player in ipairs(player_list) do
		if not player_exists(player) then
			continue
		end	
		
		local player_discard_button = player.PlayerGui.ScreenGui.Frame.discard.TextButton
		
		if #discard_stack == 0 then
			player_discard_button.Text = ""
			return
		end
		
		local face, color = translate_card(discard_stack[#discard_stack])
		
		player_discard_button.Text = face
		player_discard_button.TextColor = color
	end
end

-----------------------------------------------------------------------------
							-- turn handling
-----------------------------------------------------------------------------

function turn_timer(player)
	if #player_list == 1 then
		player.PlayerGui.ScreenGui.Frame.extras.timer.Visible = false
		return
	end

	local player_num = table.find(player_list, player)

	local timer = 20
	while timer > 0 and player_turn == player_list[player_num] do
		if not player_exists(player) then
			return
		end

		if #player_list == 1 then
			player.PlayerGui.ScreenGui.Frame.extras.timer.Visible = false
			return
		end

		for _, any_player in ipairs(player_list) do
			if not player_exists(any_player) then
				continue
			end

			any_player.PlayerGui.ScreenGui.Frame.extras.timer.Visible = true
			any_player.PlayerGui.ScreenGui.Frame.extras.timer.Text = player.Name .. "'s turn with " .. timer .. " seconds left!"
		end

		player.PlayerGui.ScreenGui.Frame.extras.timer.Text = "You have " .. timer .. " seconds left in your turn!"

		task.wait(1)
	end

	if player_turn == player_list[player_num] then
		if #player_hands[player_num] > 5 then
			table.insert(discard_stack, table.remove(player_hands[player_num], math.random(1, #player_hands[player_num])))

			show_hands()

			update_discard()
		end

		next_player_turn()
	end
end

function enable_turn_guis(player)
	local player_frame = player.PlayerGui.ScreenGui.Frame
	
	local discard_gui = player_frame.discard
	local deck_gui = player_frame.deck

	discard_gui.TextButton.Interactable = true
	deck_gui.TextButton.Interactable = true

	deck_gui.draw.Visible = true
	discard_gui.draw.Visible = true
	
	player_frame.extras.your_turn.Visible = true
	
	turn_timer(player)
end

function try_player_turn()
	local player = player_list[player_turn]
	
	if player_exists(player) then
		enable_turn_guis(player)
		
		return
	end
	
	-- else player doesnt exist, try again
	
	task.wait(1)
	
	if player_exists(player) then
		enable_turn_guis(player)
		
		return
	end
	
	-- else player 1 still didnt load. now move to player 2 if there is one
	
	for _, player_new in ipairs(player_list) do
		if player_new == player then
			continue
		end
		
		if player_exists(player_new) then
			enable_turn_guis(player_new)

			return
		end
	end
	
	-- no player working, start new game
	game_running = false
end

function next_player_turn()
	player_turn += 1
	
	if player_turn > #player_list then
		first_player_turn()
		return
	end
	
	try_player_turn()
end

function first_player_turn()
	player_turn = 1
	try_player_turn()
end

-----------------------------------------------------------------------------
						-- player joined/left updates
-----------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	if not game_running then
		return
	end
		
	local player_gui = player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui"):WaitForChild("Frame"):WaitForChild("cards"):WaitForChild("cards"):WaitForChild("6")
	--player.CharacterAdded:Wait()
	
	table.insert(player_list, player)
	
	table.insert(player_hands, {})
	for i = 1, 5 do
		if #deck == 0 then
			recycle_deck()
		end
		
		table.insert(player_hands[#player_hands], table.remove(deck, math.random(1, #deck)))
	end
	
	show_hands()
	update_discard()
	
	local res = is_hand_winner(player_hands[#player_hands])
	if res then
		show_winner(player_list[#player_list], res)
		return
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local player_num = table.find(player_list, player)
	
	if player_num then
		if player_num == player_turn then
			-- adjust for player who left
			player_turn -= 1
			
			next_player_turn()
		end
		
		-- return hand to deck
		for _, card in ipairs(player_hands[player_num]) do
			table.insert(deck, card)
		end
		
		table.remove(player_list, player_num)
		table.remove(player_hands, player_num)
		
		if #player_list == 0 then
			game_running = false
		end
	end
end)

-----------------------------------------------------------------------------
							-- player actions
-----------------------------------------------------------------------------

SwapCardPosition.OnServerEvent:Connect(function(player, card_1, card_2)
	if not player_exists(player) then
		return 
	end	
	
	local player_number = tonumber(table.find(player_list, player))
	
	local card_1, card_2 = tonumber(card_1), tonumber(card_2)

	local temp_slot = player_hands[player_number][card_1]
	player_hands[player_number][card_1] = player_hands[player_number][card_2]
	player_hands[player_number][card_2] = temp_slot
	
	local player_cards = player.PlayerGui.ScreenGui.Frame.cards.cards
	
	local first = player_cards[card_1]
	local second = player_cards[card_2]
	
	local temp_card = first.Text
	first.Text = second.Text
	second.Text = temp_card
	
	local temp_color = first.TextColor
	first.TextColor = second.TextColor
	second.TextColor = temp_color
end)

function players_turn(player)
	return table.find(player_list, player) == player_turn
end

function add_card_to_hand(player, card)
	table.insert(player_hands[player_turn], card)
	
	local player_card = player.PlayerGui.ScreenGui.Frame.cards.cards["6"]
	
	player_card.Visible = true
	
	local face, color = translate_card(card)
	player_card.Text = face
	player_card.TextColor = color
	
	player.PlayerGui.ScreenGui.Frame.deck.TextButton.Interactable = false
	
	player.PlayerGui.ScreenGui.Frame.deck.draw.Visible = false
	player.PlayerGui.ScreenGui.Frame.discard.draw.Visible = false
end

function set_border_color(player, color)
	for _, child in ipairs(player.PlayerGui.ScreenGui.Frame.cards.cards:GetChildren()) do
		if child.ClassName == "TextButton" then
			child.BorderColor3 = color
		end
	end
end

function return_card_state(player)
	player.PlayerGui.ScreenGui.Frame.discard.discard.Visible = true
	set_border_color(player, Color3.fromRGB(199, 38, 38))
end

function normal_state(player)
	player.PlayerGui.ScreenGui.Frame.discard.discard.Visible = false
	set_border_color(player, Color3.fromRGB(0,0,0))
end

TakeDiscard.OnServerEvent:Connect(function(player)
	if not players_turn(player) then
		return
	end
	
	if not player_exists(player) then
		return
	end	
	
	local card = table.remove(discard_stack, #discard_stack)
	
	update_discard()
	
	add_card_to_hand(player, card)
	
	return_card_state(player)
end)

function recycle_deck()
	deck = table.clone(discard_stack)
	discard_stack = {}
	
	update_discard()
	
	for _, player in ipairs(player_list) do
		if not player_exists(player) then
			continue
		end
		
		local recycle_gui = player.PlayerGui.ScreenGui.Frame.extras.recycle:Clone()
		
		recycle_gui.Visible = true
		recycle_gui.Parent = player.PlayerGui.ScreenGui.Frame.extras
		
		game:GetService("Debris"):AddItem(recycle_gui, 2.5)
	end
	
	RecycleFade:FireAllClients()
end

RequestCard.OnServerEvent:Connect(function(player)
	if not players_turn(player) then
		return
	end
	
	if not player_exists(player) then
		return
	end
		
	local card = table.remove(deck, math.random(1, #deck))
	
	if #deck == 0 then
		recycle_deck()
	end
	
	add_card_to_hand(player, card)
	
	return_card_state(player)
end)

DiscardCard.OnServerEvent:Connect(function(player, card_location)
	if not players_turn(player) then
		return
	end
	
	if not player_exists(player) then
		return
	end

	table.insert(discard_stack, table.remove(player_hands[player_turn], card_location))
	
	update_discard()
	
	local player_frame = player.PlayerGui.ScreenGui.Frame
	local player_cards = player_frame.cards.cards
	
	if card_location ~= 6 then
		for i = card_location, 5 do
			player_cards[i].Text = player_cards[i+1].Text
			player_cards[i].TextColor = player_cards[i+1].TextColor
		end
	end
	
	player_cards["6"].Visible = false
	player_frame.discard.TextButton.Interactable = false
	
	player_frame.extras.your_turn.Visible = false
	
	normal_state(player)
	
	local res = is_hand_winner(player_hands[player_turn])
	if res then
		show_winner(player, res)
		return
	end
	
	next_player_turn()
end)

-----------------------------------------------------------------------------
							-- start game
-----------------------------------------------------------------------------

function start_game()
	player_turn = -1

	reset_deck()

	select_players()

	handout_cards()

	reset_discard()

	show_hands()

	update_discard()

	-- check if anyone dealt a winning hand
	for i, hand in ipairs(player_hands) do
		local res = is_hand_winner(hand)
		if res then
			show_winner(player_list[i], res)
			return
		end
	end

	first_player_turn()
end

task.wait(5)

while true do
	task.wait(1)
	if game_running then
		continue
	end
	
	game_running = true
	
	start_game()
end

