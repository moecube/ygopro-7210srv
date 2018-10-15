os=require("os")
io=require("io")
--globals
local main={[0]={},[1]={}}
local extra={[0]={},[1]={}}

local main_nonadv={[0]={},[1]={}}

local main_monster={[0]={},[1]={}}
local main_spell={[0]={},[1]={}}
local main_trap={[0]={},[1]={}}

local main_plain={[0]={},[1]={}}
local main_adv={[0]={},[1]={}}

local main_new={[0]={},[1]={}}

local extra_sp={
	[TYPE_FUSION]={[0]={},[1]={}},
	[TYPE_SYNCHRO]={[0]={},[1]={}},
	[TYPE_XYZ]={[0]={},[1]={}},
	[TYPE_LINK]={[0]={},[1]={}},
}

local xyz_plain={[0]={},[1]={}}
local xyz_adv={[0]={},[1]={}}

local extra_fixed={62709239,95169481}

function Auxiliary.SplitData(inputstr)
	local t={}
	for str in string.gmatch(inputstr,"([^|]+)") do
		table.insert(t,tonumber(str))
	end
	return t
end
function Auxiliary.LoadDB(p,pool)
	local file=io.popen("echo .exit | sqlite3 "..pool.." -cmd \"select * from datas;\"")
	for line in file:lines() do
		local data=Auxiliary.SplitData(line)
		if #data<2 then break end
		local code=data[1]
		local ot=data[2]
		local cat=data[5]
		local lv=data[8] & 0xff
		if (cat & TYPE_FUSION+TYPE_SYNCHRO+TYPE_XYZ+TYPE_LINK)>0 then
			table.insert(extra[p],code)
			for tp,list in pairs(extra_sp) do
				if (cat & tp)>0 then
					table.insert(list[p],code)
				end
			end
			if (cat & TYPE_XYZ)>0 then
				if lv>4 then
					table.insert(xyz_adv[p],code)
				else
					table.insert(xyz_plain[p],code)				
				end
			end
		elseif (cat & TYPE_TOKEN)==0 then
			if (ot==4) then
				table.insert(main_new[p],code)
			end
			if (cat & TYPE_MONSTER)>0 then
				table.insert(main_monster[p],code)
				if lv>4 then
					table.insert(main_adv[p],code)
				else
					table.insert(main_plain[p],code)
					table.insert(main_nonadv[p],code)
				end
			elseif (cat & TYPE_SPELL)>0 then
				table.insert(main_nonadv[p],code)
				table.insert(main_spell[p],code)
			elseif (cat & TYPE_TRAP)>0 then
				table.insert(main_nonadv[p],code)
				table.insert(main_trap[p],code)
			end
			table.insert(main[p],code)
		end
	end
	file:close()
end
--to do: multi card pools
function Auxiliary.LoadCardPools()
	local pool_list={}
	local file=io.popen("ls 2pick/*.cdb")
	for pool in file:lines() do
		table.insert(pool_list,pool)
	end
	file:close()
	for p=0,1 do
		Auxiliary.LoadDB(p,pool_list[math.random(#pool_list)])
	end
end

function Auxiliary.SaveDeck()
	for p=0,1 do
		local g=Duel.GetFieldGroup(p,0xff,0)
		Duel.SavePickDeck(p,g)
	end
end
function Auxiliary.SinglePick(p,list,count,ex_list,ex_count,copy,lv_diff,fixed)
	if not Duel.IsPlayerNeedToPickDeck(p) then return end
	local g1=Group.CreateGroup()
	local g2=Group.CreateGroup()
	local ag=Group.CreateGroup()
	local plist=list[p]
	for _,g in ipairs({g1,g2}) do
		--for i=1,count do
		--	local code=plist[math.random(#plist)]
		--	g:AddCard(Duel.CreateToken(p,code))
		--end
		local pick_count=0
		while pick_count<count do
			local code=plist[math.random(#plist)]
			local lv=Duel.ReadCard(code,CARDDATA_LEVEL)
			if not ag:IsExists(Card.IsCode,1,nil,code) and not (lv_diff and g:IsExists(Card.IsLevel,1,nil,lv)) then
				local card=Duel.CreateToken(p,code)
				g:AddCard(card)
				ag:AddCard(card)
				pick_count=pick_count+1
			end
		end
		if ex_list and ex_count then
			--for i=1,ex_count do
			--	local code=ex_plist[math.random(#ex_plist)]
			--	g:AddCard(Duel.CreateToken(p,code))
			--end
			local ex_plist=ex_list[p]
			local ex_pick_count=0
			while ex_pick_count<ex_count do
				local code=ex_plist[math.random(#ex_plist)]
				local lv=Duel.ReadCard(code,CARDDATA_LEVEL)
				if not ag:IsExists(Card.IsCode,1,nil,code) and not (lv_diff and g:IsExists(Card.IsLevel,1,nil,lv)) then
					local card=Duel.CreateToken(p,code)
					g:AddCard(card)
					ag:AddCard(card)
					ex_pick_count=ex_pick_count+1
				end
			end
		end
		if fixed then
			for _,code in ipairs(fixed) do
				local card=Duel.CreateToken(p,code)
				g:AddCard(card)
				ag:AddCard(card)
			end
		end
		Duel.SendtoDeck(g,nil,0,REASON_RULE)
	end
	Duel.ResetTimeLimit(p,90)
	
	local tg=Group.CreateGroup()
	local rg=ag
	while true do
		local finish=tg:GetCount()>0
		Duel.Hint(HINT_SELECTMSG,p,HINTMSG_TODECK)
		local sc=rg:SelectUnselect(tg,p,finish,false,#g1,#g2)
		if not sc then break end
		tg=g1:IsContains(sc) and g1 or g2
		rg=g1:IsContains(sc) and g2 or g1
	end
	
	if tg:GetFirst():IsLocation(LOCATION_DECK) then
		Duel.ConfirmCards(p,tg)
	end
	Duel.Exile(rg,REASON_RULE)
	if copy then
		local g3=Group.CreateGroup()
		for nc in aux.Next(tg) do
			local copy_code=nc:GetOriginalCode()
			g3:AddCard(Duel.CreateToken(p,copy_code))
		end
		Duel.SendtoDeck(g3,nil,0,REASON_RULE)
	end
end
function Auxiliary.StartPick(e)
	for p=0,1 do
		if Duel.IsPlayerNeedToPickDeck(p) then
			local g=Duel.GetFieldGroup(p,0xff,0)
			Duel.Exile(g,REASON_RULE)
		end
	end
	for i=1,5 do
		local list=main
		local count=4
		local ex_list=nil
		local ex_count=nil
		if i==1 or i==2 then
			list=main_plain
			count=3
			ex_list=main_adv
			ex_count=1
		elseif i==3 then
			list=main_plain
			--Adding New Cards
			count=3
			ex_list=main_new
			ex_count=1
		elseif i==4 then
			list=main_spell
		elseif i==5 then
			list=main_trap
		end
		for p=0,1 do
			Auxiliary.SinglePick(p,list,count,ex_list,ex_count,true)
		end
	end
	for tp,list in pairs(extra_sp) do
		if tp~=TYPE_FUSION then
			for p=0,1 do
				if tp==TYPE_XYZ then
					Auxiliary.SinglePick(p,xyz_plain,3,xyz_adv,1,false)
				else
					local lv_diff=(tp==TYPE_SYNCHRO)
					Auxiliary.SinglePick(p,list,4,nil,nil,false,lv_diff)
				end
			end
		end
	end
	for i=1,2 do
		for p=0,1 do
			if i==1 then
				Auxiliary.SinglePick(p,extra,4,nil,nil,false)
			else
				Auxiliary.SinglePick(p,extra,2,nil,nil,false,false,extra_fixed)
			end
		end
	end
	
	-- -- Shadoll Additional Picks
	-- for p=0,1 do
	-- 	if Duel.IsPlayerNeedToPickDeck(p) then
	-- 		Duel.Hint(HINT_CARD,p,86938484)
	-- 		local ng=Group.CreateGroup()
	-- 		local card1=Duel.CreateToken(p,86938484)
	-- 		local card2=Duel.CreateToken(p,86938484)
	-- 		local card3=Duel.CreateToken(p,74822425)
	-- 		local card4=Duel.CreateToken(p,19261966)
	-- 		local card5=Duel.CreateToken(p,20366274)
	-- 		local card6=Duel.CreateToken(p,48424886)
	-- 		local card7=Duel.CreateToken(p,74009824)
	-- 		local card8=Duel.CreateToken(p,94977269)
	-- 		ng:AddCard(card1)
	-- 		ng:AddCard(card2)
	-- 		ng:AddCard(card3)
	-- 		ng:AddCard(card4)
	-- 		ng:AddCard(card5)
	-- 		ng:AddCard(card6)
	-- 		ng:AddCard(card7)
	-- 		ng:AddCard(card8)
	-- 		Duel.SendtoDeck(ng,nil,0,REASON_RULE)
	-- 	end
	-- end
	
	Auxiliary.SaveDeck()
	for p=0,1 do
		if Duel.IsPlayerNeedToPickDeck(p) then
			Duel.ShuffleDeck(p)
			Duel.ResetTimeLimit(p)
		end
	end
	for p=0,1 do
		Duel.Draw(p,Duel.GetStartCount(p),REASON_RULE)
	end
	e:Reset()
end

function Auxiliary.Load2PickRule()
	math.randomseed(os.time())
	Auxiliary.LoadCardPools()
	local e1=Effect.GlobalEffect()
	e1:SetType(EFFECT_TYPE_FIELD | EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_ADJUST)
	e1:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e1:SetOperation(Auxiliary.StartPick)
	Duel.RegisterEffect(e1,0)

	--Skill DrawSense Specials
	Auxiliary.Load_Skill_DrawSense_Rule()

	--EVENT Grandpa's Cards
	Auxiliary.Load_EVENT_Grandpas_Cards()
end

	--Skill_DrawSense_Rule

function Auxiliary.Load_Skill_DrawSense_Rule()
	local e1=Effect.GlobalEffect()
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetTargetRange(1,1)
	--e1:SetCode(PHASE_DRAW+EVENT_PHASE_START)
	e1:SetCode(EVENT_PREDRAW)
	e1:SetCondition(Auxiliary.Skill_DrawSense_Condition)
	e1:SetOperation(Auxiliary.Skill_DrawSense_Operation)
	Duel.RegisterEffect(e1,0)
end

function Auxiliary.Skill_DrawSense_Condition(e,tp,eg,ep,ev,re,r,rp)
	local tp=Duel.GetTurnPlayer()
	return (Duel.GetLP(1-tp))-(Duel.GetLP(tp))>1999
		and Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>1
		and Duel.GetDrawCount(tp)>0
		--and Duel.IsExistingMatchingCard(Auxiliary.Skill_DestinyDraw_SearchFilter,tp,LOCATION_DECK,0,1,nil)
end

function Auxiliary.Skill_DrawSense_Operation(e,tp,eg,ep,ev,re,r,rp)
	local tp=Duel.GetTurnPlayer()
	local dt=Duel.GetDrawCount(tp)
	if dt~=0 then
		_replace_count=0
		_replace_max=dt
		-- local e1=Effect.CreateEffect(e:GetHandler())
		-- e1:SetType(EFFECT_TYPE_FIELD)
		-- e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		-- e1:SetCode(EFFECT_DRAW_COUNT)
		-- e1:SetTargetRange(1,0)
		-- e1:SetReset(RESET_PHASE+PHASE_DRAW)
		-- e1:SetValue(0)
		-- Duel.RegisterEffect(e1,tp)

		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_CARDTYPE)
		local SenseType=(Duel.AnnounceType(tp))

		if (SenseType==0 and Duel.IsExistingMatchingCard(Card.IsType,tp,LOCATION_DECK,0,1,nil,TYPE_MONSTER)) then
			g=Duel.GetMatchingGroup(Card.IsType,tp,LOCATION_DECK,0,nil,TYPE_MONSTER)
			local SenseCard=g:RandomSelect(tp,1)
			local tc=SenseCard:GetFirst()
			if tc then
				Duel.ShuffleDeck(tp)
				Duel.MoveSequence(tc,0)
			end
			--Duel.Draw(tp,1,REASON_RULE)
		elseif (SenseType==1 and Duel.IsExistingMatchingCard(Card.IsType,tp,LOCATION_DECK,0,1,nil,TYPE_SPELL)) then
			g=Duel.GetMatchingGroup(Card.IsType,tp,LOCATION_DECK,0,nil,TYPE_SPELL)
			local SenseCard=g:RandomSelect(tp,1)
			local tc=SenseCard:GetFirst()
			if tc then
				Duel.ShuffleDeck(tp)
				Duel.MoveSequence(tc,0)
			end
			--Duel.Draw(tp,1,REASON_RULE)
		elseif (SenseType==2 and Duel.IsExistingMatchingCard(Card.IsType,tp,LOCATION_DECK,0,1,nil,TYPE_TRAP)) then
			g=Duel.GetMatchingGroup(Card.IsType,tp,LOCATION_DECK,0,nil,TYPE_TRAP)
			local SenseCard=g:RandomSelect(tp,1)
			local tc=SenseCard:GetFirst()
			if tc then
				Duel.ShuffleDeck(tp)
				Duel.MoveSequence(tc,0)
			end
			--Duel.Draw(tp,1,REASON_RULE)
		else 
			Duel.ShuffleDeck(tp)
			--Duel.Draw(tp,1,REASON_RULE)
		end
	end
end

	--EVENT Grandpa's Cards
	
function Auxiliary.Load_EVENT_Grandpas_Cards()
	local e1=Effect.GlobalEffect()
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e1:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetCode(EVENT_BATTLED)
	e1:SetTarget(Auxiliary.EVENT_Grandpas_Cards_Target)
	e1:SetOperation(Auxiliary.EVENT_Grandpas_Cards_Operation)
	local e2=Effect.GlobalEffect()
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e2:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_CANNOT_DISABLE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetLabelObject(e1)
	Duel.RegisterEffect(e2,0)
end

function Auxiliary.EVENT_Grandpas_Cards_Target(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsStatus(STATUS_BATTLE_DESTROYED) then return false end
	local bc=c:GetBattleTarget()
	return bc and bc:IsStatus(STATUS_BATTLE_DESTROYED) and not bc:IsType(TYPE_TOKEN) and bc:GetLeaveFieldDest()==0
end

function Auxiliary.EVENT_Grandpas_Cards_Operation(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local bc=c:GetBattleTarget()
	if Duel.SelectYesNo(c.GetOwner(c),94) then
		if bc:IsRelateToBattle() then
			local e1=Effect.CreateEffect(c)
			e1:SetCode(EFFECT_SEND_REPLACE)
			e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
			e1:SetTarget(Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Target)
			e1:SetOperation(Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Operation)
			e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_DAMAGE)
			bc:RegisterEffect(e1)
		end
		-- local code=e:GetHandler():GetCode()
		Exodia_announce_filter={0x40,OPCODE_ISSETCARD,OPCODE_ISCODE,OPCODE_NOT,OPCODE_AND}
		local ac=Duel.AnnounceCardFilter(c.GetOwner(c),table.unpack(Exodia_announce_filter))
		local Yugi_Card=Duel.CreateToken(c.GetOwner(c),ac)
		Duel.SendtoHand(Yugi_Card,c.GetOwner(c),0,REASON_RULE)
	end
end

function Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Target(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then return c:GetDestination()==LOCATION_GRAVE and c:IsReason(REASON_BATTLE) end
	return true
end

function Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Operation(e,tp,eg,ep,ev,re,r,rp)
	Duel.SendtoHand(e:GetHandler(),nil,2,REASON_RULE)
end


	--Shadoll Event

-- function Auxiliary.Load_Shadow_Rule()
-- 	local e1=Effect.GlobalEffect()
-- 	e1:SetDescription(1166)
-- 	e1:SetType(EFFECT_TYPE_FIELD)
-- 	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
-- 	e1:SetCode(EFFECT_SPSUMMON_PROC)
-- 	e1:SetRange(LOCATION_EXTRA)
-- 	e1:SetCondition(Auxiliary.LinkCondition(nil,2,2,nil))
-- 	e1:SetTarget(Auxiliary.LinkTarget(nil,2,2,nil))
-- 	e1:SetOperation(Auxiliary.LinkOperation(nil,2,2,nil))
-- 	e1:SetValue(SUMMON_TYPE_LINK)
-- 	local e2=Effect.GlobalEffect()
-- 	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
-- 	e2:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
-- 	e2:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
-- 	e2:SetTarget(Auxiliary.IsConstruct)
-- 	e2:SetLabelObject(e1)
-- 	Duel.RegisterEffect(e2,0)
-- 	return
-- end

-- function Auxiliary.IsConstruct(e,c)
-- 	return c:IsCode(86938484)
-- end

	--DestinyDraw Rule

-- function Auxiliary.Load_Skill_DestinyDraw_Rule()
-- 	local e1=Effect.GlobalEffect()
-- 	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
-- 	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
-- 	e1:SetTargetRange(1,1)
-- 	e1:SetCode(PHASE_DRAW+EVENT_PHASE_START)
-- 	e1:SetCondition(Auxiliary.Skill_DestinyDraw_Condition)
-- 	e1:SetOperation(Auxiliary.Skill_DestinyDraw_Operation)
-- 	Duel.RegisterEffect(e1,0)
-- end

-- function Auxiliary.Skill_DestinyDraw_SearchFilter(c)
-- 	return c:IsAbleToHand()
-- end

-- function Auxiliary.Skill_DestinyDraw_Condition(e,tp,eg,ep,ev,re,r,rp)
-- 	local tp=Duel.GetTurnPlayer()
-- 	return (Duel.GetLP(1-tp))-(Duel.GetLP(tp))>2999
-- 		and Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>4 
-- 		and Duel.GetDrawCount(tp)>0
-- 		and Duel.IsExistingMatchingCard(Auxiliary.Skill_DestinyDraw_SearchFilter,tp,LOCATION_DECK,0,1,nil)
-- end

-- function Auxiliary.Skill_DestinyDraw_Operation(e,tp,eg,ep,ev,re,r,rp)
-- 	local tp=Duel.GetTurnPlayer()
-- 	local dt=Duel.GetDrawCount(tp)
-- 	if dt~=0 then
-- 		_replace_count=0
-- 		_replace_max=dt
-- 		local e1=Effect.CreateEffect(e:GetHandler())
-- 		e1:SetType(EFFECT_TYPE_FIELD)
-- 		e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
-- 		e1:SetCode(EFFECT_DRAW_COUNT)
-- 		e1:SetTargetRange(1,0)
-- 		e1:SetReset(RESET_PHASE+PHASE_DRAW)
-- 		e1:SetValue(0)
-- 		Duel.RegisterEffect(e1,tp)
-- 		Duel.ConfirmDecktop(tp,5)
-- 		local g=Duel.GetDecktopGroup(tp,5)
-- 		if g:GetCount()>0 then
-- 			Duel.Hint(HINT_SELECTMSG,p,HINTMSG_ATOHAND)
-- 			local sg=g:Select(tp,1,1,nil)
-- 				if sg:GetFirst():IsAbleToHand() then
-- 				Duel.SendtoHand(sg,nil,REASON_EFFECT)
-- 				Duel.ConfirmCards(1-tp,sg)
-- 				Duel.ShuffleHand(tp)
-- 			else
-- 				Duel.SendtoGrave(sg,REASON_RULE)
-- 			end
-- 			Duel.ShuffleDeck(tp)
-- 		end
-- 	end
-- end
