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
local combo_pack=require("./2pick/combo")

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
function Auxiliary.SinglePick(p,list,count,ex_list,ex_count,copy,lv_diff,fixed,packed,optional)
	if not Duel.IsPlayerNeedToPickDeck(p) then return end
	local g1=Group.CreateGroup()
	local g2=Group.CreateGroup()
	local ag=Group.CreateGroup()
	local plist=list[p]
	local lastpack=-1
	for _,g in ipairs({g1,g2}) do
		--for i=1,count do
		--	local code=plist[math.random(#plist)]
		--	g:AddCard(Duel.CreateToken(p,code))
		--end
		local pick_count=0
		if packed then
			while true do
				local thispack=math.random(#packed)
				if thispack~=lastpack then
					lastpack=thispack
					for _,code in ipairs(packed[thispack]) do
						local card=Duel.CreateToken(p,code)
						g:AddCard(card)
						ag:AddCard(card)
					end
					break
				end
			end
		end
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
	
	if optional and ag:GetFirst():IsLocation(LOCATION_DECK) then
		Duel.ConfirmCards(p,ag)
		if Duel.SelectOption(p,1190,1192)==1 then
			Duel.Exile(ag,REASON_RULE)
			return false
		end
	end
	
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
	return true
end
function Auxiliary.ArbitraryPick(p,count,pick_lists,lists_count,copy,lv_diff,fixed)
	if not Duel.IsPlayerNeedToPickDeck(p) then return end
	local ag=Group.CreateGroup()
	local eg=Group.CreateGroup()
	for index,list in pairs(pick_lists) do
		local plist=list[p]
		local pg=Group.CreateGroup()
		local pick_count=lists_count[index]
		while pick_count>0 do
			local code=plist[math.random(#plist)]
			local lv=Duel.ReadCard(code,CARDDATA_LEVEL)
			if not ag:IsExists(Card.IsCode,1,nil,code) and not (lv_diff and pg:IsExists(Card.IsLevel,1,nil,lv)) then
				local card=Duel.CreateToken(p,code)
				ag:AddCard(card)
				pg:AddCard(card)
				pick_count=pick_count-1
			end
		end
	end
	if fixed then
		for _,code in ipairs(fixed) do
			local card=Duel.CreateToken(p,code)
			ag:AddCard(card)
		end
	end
	Duel.SendtoDeck(ag,nil,0,REASON_RULE)
	Duel.ResetTimeLimit(p,120)
	
	Duel.Hint(HINT_SELECTMSG,p,0)
	local tg=ag:Select(p,count,count,nil)
	local rg=ag
	rg:Sub(tg)
	while true do
		local finish=tg:GetCount()==count
		Duel.Hint(HINT_SELECTMSG,p,HINTMSG_TODECK)
		local sc=rg:SelectUnselect(tg,p,finish,false,count,count)
		if not sc then break end
		if tg:IsContains(sc) then
			tg:RemoveCard(sc)
			rg:AddCard(sc)
		else
			tg:AddCard(sc)
			rg:RemoveCard(sc)
		end
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
--[[
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
			Auxiliary.SinglePick(p,list,count,ex_list,ex_count,false)
		end
	end
]]--
	for i=1,5 do
		local lists={[1]=main_monster,[3]=main_spell,[4]=main_trap}
		local lists_count={[1]=4,[3]=2,[4]=2}
		if i==1 or i==2 then
			lists[1]=main_plain
			lists_count[1]=2
			lists[2]=main_adv
			lists_count[2]=2
		end
		for p=0,1 do
			Auxiliary.ArbitraryPick(p,4,lists,lists_count)
		end
	end
	
	-- combo pick
	for t=2,0,-1 do
		local reroll=t>0
		if Auxiliary.SinglePick(0,main,0,nil,nil,false,false,nil,combo_pack.pack,reroll) then
			break
		end
	end
	for t=1,0,-1 do
		local reroll=t>0
		if Auxiliary.SinglePick(1,main,0,nil,nil,false,false,nil,combo_pack.pack,reroll) then
			break
		end
	end
	
	for tp,list in pairs(extra_sp) do
		if tp~=TYPE_FUSION then
			for p=0,1 do
				lists ={[1]=list}
				counts={[1]=8}
				lv_diff=false
				if tp==TYPE_XYZ then
					lists[1]=xyz_plain
					counts[1]=6
					lists[2]=xyz_adv
					counts[2]=2
				elseif tp==TYPE_SYNCHRO then
					counts[1]=4
					lists[2]=list
					counts[2]=4
					lv_diff=true
				end
				Auxiliary.ArbitraryPick(p,4,lists,counts,false,lv_diff)
			end
		end
	end
	for p=0,1 do
		lists ={[1]=extra}
		counts={[1]=6}
		Auxiliary.ArbitraryPick(p,4,lists,counts,false,false,extra_fixed)
	end
	
	-- -- XXYYZZ Additional Picks
	-- xyz_list={91998119,91998120,91998121}
	-- for p=0,1 do
	-- 	if Duel.IsPlayerNeedToPickDeck(p) then
	-- 		local ng=Group.CreateGroup()
	-- 		local card1=Duel.CreateToken(p,2111707)
	-- 		local card2=Duel.CreateToken(p,25119460)
	-- 		local card3=Duel.CreateToken(p,99724761)
	-- 		local card4=Duel.CreateToken(p,xyz_list[math.random(#xyz_list)])
	-- 		ng:AddCard(card1)
	-- 		ng:AddCard(card2)
	-- 		ng:AddCard(card3)
	-- 		ng:AddCard(card4)
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
	return (Duel.GetLP(1-tp))-(Duel.GetLP(tp))>2499
		and Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>1
		and Duel.GetDrawCount(tp)>0
		and Duel.GetFieldGroupCount(tp,LOCATION_MZONE,0)==0
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

--EVENT ExtraFusion

-- function Auxiliary.Load_EVENT_ExtraFusion()
	-- -- elemental hero
	-- local e011=Effect.GlobalEffect()
	-- e011:SetType(EFFECT_TYPE_FIELD)
	-- e011:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	-- e011:SetCode(EFFECT_SPSUMMON_PROC)
	-- e011:SetRange(LOCATION_EXTRA)
	-- e011:SetCondition(Auxiliary.FireEH_Condition)
	-- e011:SetOperation(Auxiliary.FireEH_Operation)
	-- local e012=Effect.GlobalEffect()
	-- e012:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	-- e012:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	-- e012:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	-- e012:SetTarget(Auxiliary.IsFireEH)
	-- e012:SetLabelObject(e011)
	-- Duel.RegisterEffect(e012,0)
-- end

-- function Auxiliary.IsFireEH(e,c)
	-- return c:IsCode(1945387)
-- end
-- function Auxiliary.FireEH_spfilter1(c,tp,fc)
	-- return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost() and (c:IsFaceup() or c:IsControler(tp))
		-- and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.FireEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
-- end
-- function Auxiliary.FireEH_spfilter2(c,tp,fc,mc)
	-- local g=Group.FromCards(c,mc)
	-- return c:IsFusionAttribute(ATTRIBUTE_FIRE) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost() and (c:IsFaceup() or c:IsControler(tp))
		-- and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
-- end
-- function Auxiliary.FireEH_Condition(e,c)
	-- if c==nil then return true end
	-- local tp=c:GetControler()
	-- return Duel.IsExistingMatchingCard(Auxiliary.FireEH_spfilter1,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil,tp,c)
-- end
-- function Auxiliary.FireEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	-- local g1=Duel.GetMatchingGroup(Auxiliary.FireEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp,c)
	-- Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	-- local sg=g1:Select(tp,1,1,nil)
	-- local g2=Duel.GetMatchingGroup(Auxiliary.FireEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,c,sg:GetFirst())
	-- Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	-- local c2=g2:Select(tp,1,1,sg:GetFirst())
	-- sg:Merge(c2)
	-- Duel.SendtoGrave(sg,REASON_COST)
	-- c:CompleteProcedure()
-- end

--EVENT Metamorphosis

-- function Auxiliary.Load_EVENT_Metamorphosis()
	-- local e1=Effect.GlobalEffect()
	-- e1:SetDescription(1127)
	-- e1:SetType(EFFECT_TYPE_IGNITION)
	-- e1:SetCountLimit(1,46411259+EFFECT_COUNT_CODE_OATH)
	-- e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	-- e1:SetRange(LOCATION_MZONE)
	-- e1:SetCost(Auxiliary.EVENT_Metamorphosis_Cost)
	-- e1:SetTarget(Auxiliary.EVENT_Metamorphosis_Target)
	-- e1:SetOperation(Auxiliary.EVENT_Metamorphosis_Operation)
	-- e1:SetLabel(0)
	-- local e2=Effect.GlobalEffect()
	-- e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	-- e2:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	-- e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	-- e2:SetTarget(Auxiliary.EVENT_Metamorphosis_MonsterCheck)
	-- e2:SetLabelObject(e1)
	-- Duel.RegisterEffect(e2,0)
	-- return
-- end

-- function Auxiliary.EVENT_Metamorphosis_MonsterCheck(e,c)
	-- return c:IsType(TYPE_MONSTER)
-- end

-- function Auxiliary.EVENT_Metamorphosis_Cost(e,tp,eg,ep,ev,re,r,rp,chk)
		-- e:SetLabel(100)
	-- if chk==0 then return true end
-- end

-- function Auxiliary.EVENT_Metamorphosis_Costfilter(c,e,tp)
	-- return Duel.IsExistingMatchingCard(Auxiliary.EVENT_Metamorphosis_spfilter,tp,LOCATION_DECK,0,1,nil,c,e,tp)
-- end

-- function Auxiliary.EVENT_Metamorphosis_spfilter(c,tc,e,tp)
	-- return c:GetOriginalAttribute()==tc:GetOriginalAttribute() and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
-- end

-- function Auxiliary.EVENT_Metamorphosis_Target(e,tp,eg,ep,ev,re,r,rp,chk)
	-- if chk==0 then
		-- if e:GetLabel()~=100 then return false end
		-- e:SetLabel(0)
		-- return Duel.CheckReleaseGroup(tp,Auxiliary.EVENT_Metamorphosis_Costfilter,1,nil,e,tp)
	-- end
	-- e:SetLabel(0)
	-- local g=Duel.SelectReleaseGroup(tp,Auxiliary.EVENT_Metamorphosis_Costfilter,1,1,nil,e,tp)
	-- Duel.Release(g,REASON_COST)
	-- Duel.SetTargetCard(g)
	-- Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_DECK)
	-- Duel.SetChainLimit(aux.FALSE)
-- end

-- function Auxiliary.EVENT_Metamorphosis_Operation(e,tp,eg,ep,ev,re,r,rp)
	-- if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	-- local c=e:GetHandler()
	-- local tc=Duel.GetFirstTarget()
	-- Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	-- local cg=Duel.GetMatchingGroup(Auxiliary.EVENT_Metamorphosis_spfilter,tp,LOCATION_DECK,0,nil,tc,e,tp)
	-- if cg:GetCount()>0 then
		-- local tg=cg:RandomSelect(1-tp,1)
		-- Duel.SpecialSummon(tg,0,tp,tp,false,false,POS_FACEUP)
	-- end
-- end


-- --EVENT_XYYZ_Impact

-- function Auxiliary.Load_EVENT_XYYZ_Impact()
-- 	local e1=Effect.GlobalEffect()
-- 	e1:SetType(EFFECT_TYPE_FIELD)
-- 	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
-- 	e1:SetCode(EFFECT_SPSUMMON_PROC)
-- 	e1:SetRange(LOCATION_EXTRA)
-- 	e1:SetCondition(Auxiliary.XY_Condition)
-- 	e1:SetOperation(Auxiliary.XY_Operation)
-- 	local e2=Effect.GlobalEffect()
-- 	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
-- 	e2:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
-- 	e2:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
-- 	e2:SetTarget(Auxiliary.IsXYMoster)
-- 	e2:SetLabelObject(e1)
-- 	Duel.RegisterEffect(e2,0)
-- 	local e3=Effect.GlobalEffect()
-- 	e3:SetType(EFFECT_TYPE_FIELD)
-- 	e3:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
-- 	e3:SetCode(EFFECT_SPSUMMON_PROC)
-- 	e3:SetRange(LOCATION_EXTRA)
-- 	e3:SetCondition(Auxiliary.XYYZ_Condition)
-- 	e3:SetOperation(Auxiliary.XYYZ_Operation)
-- 	local e4=Effect.GlobalEffect()
-- 	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
-- 	e4:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
-- 	e4:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
-- 	e4:SetTarget(Auxiliary.IsXYYZMoster)
-- 	e4:SetLabelObject(e3)
-- 	Duel.RegisterEffect(e4,0)
-- end

-- function Auxiliary.IsXYMoster(e,c)
-- 	return c:IsCode(2111707) or c:IsCode(99724761) or c:IsCode(25119460)
-- end

-- function Auxiliary.IsXYYZMoster(e,c)
-- 	return c:IsCode(91998119)
-- end

-- function Auxiliary.XY_ffilter(c,fc,sub,mg,sg)
-- 	return not c:IsType(TYPE_TOKEN)  and 
-- 	(not sg or not sg:IsExists(Card.IsFusionAttribute,2,c,c:GetFusionAttribute()))
-- end

-- function Auxiliary.XY_spfilter1(c,tp,fc)
-- 	return not c:IsType(TYPE_TOKEN) and Duel.IsPlayerCanRelease(tp,c)
-- 		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.XY_spfilter2,tp,LOCATION_MZONE,0,1,c,tp,fc,c)
-- end

-- function Auxiliary.XY_spfilter2(c,tp,fc,mc)
-- 	local g=Group.FromCards(c,mc)
-- 	return not c:IsType(TYPE_TOKEN) and Duel.IsPlayerCanRelease(tp,c)  
-- 		and c:IsCanBeFusionMaterial(fc) and c:IsFusionAttribute(mc:GetFusionAttribute()) and Duel.GetLocationCountFromEx(tp,tp,g)>0
-- end

-- function Auxiliary.XY_Condition(e,c)
-- 	if c==nil then return true end
-- 	local tp=c:GetControler()
-- 	return Duel.IsExistingMatchingCard(Auxiliary.XY_spfilter1,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil,tp,c)
-- end

-- function Auxiliary.XY_Operation(e,tp,eg,ep,ev,re,r,rp,c)
-- 	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
-- 	local g1=Duel.SelectMatchingCard(tp,Auxiliary.XY_spfilter1,tp,LOCATION_MZONE,0,1,1,nil,tp,c)
-- 	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
-- 	local g2=Duel.SelectMatchingCard(tp,Auxiliary.XY_spfilter2,tp,LOCATION_MZONE,0,1,1,g1:GetFirst(),tp,c,g1:GetFirst())
-- 	g1:Merge(g2)
-- 	Duel.Release(g1,REASON_COST)
-- end

-- function Auxiliary.XYYZ_spcostfilter(c)
-- 	return c:IsAbleToRemoveAsCost() and c:IsAttribute(ATTRIBUTE_LIGHT) and c:IsType(TYPE_FUSION)
-- end

-- function Auxiliary.XYYZ_spcost_selector(c,tp,g,sg,i)
-- 	sg:AddCard(c)
-- 	g:RemoveCard(c)
-- 	local flag=false
-- 	if i<2 then
-- 		flag=g:IsExists(Auxiliary.XYYZ_spcostfilter,1,nil,tp,g,sg,i+1)
-- 	else
-- 		flag=sg:FilterCount(Card.IsAttribute,nil,ATTRIBUTE_LIGHT)>0
-- 			and sg:FilterCount(Card.IsAttribute,nil,ATTRIBUTE_LIGHT)>0
-- 	end
-- 	sg:RemoveCard(c)
-- 	g:AddCard(c)
-- 	return flag
-- end

-- function Auxiliary.XYYZ_Condition(e,c)
-- 	if c==nil then return true end
-- 	local tp=c:GetControler()
-- 	if Duel.GetLocationCountFromEx(tp)<=0 then return false end
-- 	local g=Duel.GetMatchingGroup(Auxiliary.XYYZ_spcostfilter,tp,LOCATION_GRAVE,0,nil)
-- 	local sg=Group.CreateGroup()
-- 	return g:IsExists(Auxiliary.XYYZ_spcost_selector,1,nil,tp,g,sg,1)
-- end

-- function Auxiliary.XYYZ_Operation(e,tp,eg,ep,ev,re,r,rp,c)
-- 	local g=Duel.GetMatchingGroup(Auxiliary.XYYZ_spcostfilter,tp,LOCATION_GRAVE,0,nil)
-- 	local sg=Group.CreateGroup()
-- 	for i=1,2 do
-- 		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
-- 		local g1=g:FilterSelect(tp,Auxiliary.XYYZ_spcost_selector,1,1,nil,tp,g,sg,i)
-- 		sg:Merge(g1)
-- 		g:Sub(g1)
-- 	end
-- 	Duel.Remove(sg,POS_FACEUP,REASON_COST)
-- end



-- function Auxiliary.XY_matfilter(c)
-- 	return c:IsAbleToRemoveAsCost() and not c:IsType(TYPE_TOKEN)
-- end

-- function Auxiliary.XY_att_filter1(c,tp)
-- 	return Duel.IsExistingMatchingCard(Auxiliary.XY_att_filter2,tp,0,LOCATION_MZONE,1,c,c:GetAttribute())
-- end

-- function Auxiliary.XY_att_filter2(c,att)
-- 	return c:IsAttribute(att) and not c:IsType(TYPE_TOKEN)
-- end

-- function Auxiliary.XY_spfilter1(c,tp,g)
-- 	return g:IsExists(Auxiliary.XY_spfilter2,1,c,tp,c)
-- end

-- function Auxiliary.XY_spfilter2(c,tp,mc)
-- 	return (c:IsFusionCode(62651957) and mc:IsFusionCode(64500000)
-- 		or c:IsFusionCode(64500000) and mc:IsFusionCode(62651957))
-- 		and Duel.GetLocationCountFromEx(tp,tp,Group.FromCards(c,mc))>0
-- end

-- function Auxiliary.XY_Condition(e,c)
-- 	if c==nil then return true end
-- 	local tp=c:GetControler()
-- 	local g=Duel.GetMatchingGroup(Auxiliary.XY_matfilter,tp,LOCATION_ONFIELD,0,nil)
-- 	return g:IsExists(c99724761.spfilter1,1,nil,tp,g)
-- end

-- function Auxiliary.XY_Operation(e,tp,eg,ep,ev,re,r,rp,c)
-- 	local g=Duel.GetMatchingGroup(c99724761.matfilter,tp,LOCATION_ONFIELD,0,nil)
-- 	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
-- 	local g1=g:FilterSelect(tp,c99724761.spfilter1,1,1,nil,tp,g)
-- 	local mc=g1:GetFirst()
-- 	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
-- 	local g2=g:FilterSelect(tp,c99724761.spfilter2,1,1,mc,tp,mc)
-- 	g1:Merge(g2)
-- 	Duel.Remove(g1,POS_FACEUP,REASON_COST)
-- end


-- 	--EVENT Grandpa's Cards
	
-- function Auxiliary.Load_EVENT_Grandpas_Cards()
-- 	local e1=Effect.GlobalEffect()
-- 	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
-- 	e1:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_CANNOT_DISABLE)
-- 	e1:SetCode(EVENT_BATTLED)
-- 	e1:SetTarget(Auxiliary.EVENT_Grandpas_Cards_Target)
-- 	e1:SetOperation(Auxiliary.EVENT_Grandpas_Cards_Operation)
-- 	local e2=Effect.GlobalEffect()
-- 	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
-- 	e2:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_CANNOT_DISABLE)
-- 	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
-- 	e2:SetLabelObject(e1)
-- 	Duel.RegisterEffect(e2,0)
-- end

-- function Auxiliary.EVENT_Grandpas_Cards_Target(e,tp,eg,ep,ev,re,r,rp)
-- 	local c=e:GetHandler()
-- 	if c:IsStatus(STATUS_BATTLE_DESTROYED) then return false end
-- 	local bc=c:GetBattleTarget()
-- 	return bc and bc:IsStatus(STATUS_BATTLE_DESTROYED) and not bc:IsType(TYPE_TOKEN) 
-- 		and bc:GetLeaveFieldDest()==0 and bit.band(bc:GetBattlePosition(),POS_FACEUP_ATTACK)~=0
-- end

-- function Auxiliary.EVENT_Grandpas_Cards_Operation(e,tp,eg,ep,ev,re,r,rp)
-- 	local c=e:GetHandler()
-- 	local bc=c:GetBattleTarget()
-- 	if Duel.SelectYesNo(c.GetOwner(c),94) then
-- 		if bc:IsRelateToBattle() then
-- 			local e1=Effect.CreateEffect(c)
-- 			e1:SetCode(EFFECT_SEND_REPLACE)
-- 			e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
-- 			e1:SetTarget(Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Target)
-- 			e1:SetOperation(Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Operation)
-- 			e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_DAMAGE)
-- 			bc:RegisterEffect(e1)
-- 		end
-- 		-- local code=e:GetHandler():GetCode()
-- 		Exodia_announce_filter={0x40,OPCODE_ISSETCARD,0,OPCODE_ISCODE,OPCODE_NOT,OPCODE_AND}
-- 		local ac=Duel.AnnounceCardFilter(c.GetOwner(c),table.unpack(Exodia_announce_filter))
-- 		local Yugi_Card=Duel.CreateToken(c.GetOwner(c),ac)
-- 		Duel.SendtoHand(Yugi_Card,c.GetOwner(c),0,REASON_RULE)
-- 	end
-- end

-- function Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Target(e,tp,eg,ep,ev,re,r,rp,chk)
-- 	local c=e:GetHandler()
-- 	if chk==0 then return c:GetDestination()==LOCATION_GRAVE and c:IsReason(REASON_BATTLE) end
-- 	return true
-- end

-- function Auxiliary.EVENT_Grandpas_Cards_Return_Hand_Operation(e,tp,eg,ep,ev,re,r,rp)
-- 	Duel.SendtoHand(e:GetHandler(),nil,2,REASON_RULE)
-- end


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
