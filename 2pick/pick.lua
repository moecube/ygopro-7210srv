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
			end
		end
		Duel.SendtoDeck(g,nil,0,REASON_RULE)
	end
	Duel.ResetTimeLimit(p,90)
	Duel.Hint(HINT_SELECTMSG,p,HINTMSG_TODECK)
	local sc=g1:SelectUnselect(g2,p,false,false,#g1,#g2)
	local tg=g1:IsContains(sc) and g1 or g2
	local rg=g1:IsContains(sc) and g2 or g1
	if sc:IsLocation(LOCATION_DECK) then
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
	
	-- World Cup
	for p=0,1 do
		if Duel.IsPlayerNeedToPickDeck(p) then
			Duel.Hint(HINT_CARD,p,72332074)
			local ng=Group.CreateGroup()
			local card1=Duel.CreateToken(p,72332074)
			local card2=Duel.CreateToken(p,72332074)
			ng:AddCard(card1)
			ng:AddCard(card2)
			Duel.SendtoDeck(ng,nil,0,REASON_RULE)
		end
	end
	
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

	--Alphan Spike Specials
	Auxiliary.LoadAlphanRule()
end

--functions for Alphan Spike Specials
function Auxiliary.AlphanTarget(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(Card.IsAbleToDeck,tp,0,LOCATION_ONFIELD,1,nil)
		and Duel.GetFieldGroupCount(tp,0,LOCATION_EXTRA)>0 and Duel.IsPlayerCanSpecialSummon(1-tp) end
	local g=Duel.GetMatchingGroup(Card.IsAbleToDeck,tp,0,LOCATION_ONFIELD,nil)
	Duel.SetOperationInfo(0,CATEGORY_TODECK,g,g:GetCount(),0,0)
end
function Auxiliary.AlphanSPfilter(c,e,tp)
	return c:IsType(TYPE_MONSTER) and c:IsCanBeSpecialSummoned(e,0,tp,true,false)
end
function Auxiliary.AlphanActivate(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetMatchingGroup(Card.IsAbleToDeck,tp,0,LOCATION_ONFIELD,nil)
	if Duel.SendtoDeck(g,nil,2,REASON_EFFECT)~=0
		and Duel.GetLocationCount(1-tp,LOCATION_MZONE)>0
		and Duel.IsExistingMatchingCard(Auxiliary.AlphanSPfilter,1-tp,LOCATION_EXTRA,0,1,nil,e,1-tp) then
		Duel.BreakEffect()
		Duel.Hint(HINT_SELECTMSG,1-tp,HINTMSG_SPSUMMON)
		local g=Duel.SelectMatchingCard(1-tp,Auxiliary.AlphanSPfilter,1-tp,LOCATION_EXTRA,0,1,1,nil,e,1-tp)
		local tc=g:GetFirst()
		if tc then
			Duel.SpecialSummon(tc,0,1-tp,1-tp,true,false,POS_FACEUP)
		end
	end
end

function Auxiliary.LoadAlphanRule()
	local e1=Effect.GlobalEffect()
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TODECK)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(Auxiliary.AlphanTarget)
	e1:SetOperation(Auxiliary.AlphanActivate)
	local e2=Effect.GlobalEffect()
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e2:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_SET_AVAILABLE)
	e2:SetTargetRange(LOCATION_HAND+LOCATION_SZONE,LOCATION_HAND+LOCATION_SZONE)
	e2:SetTarget(Auxiliary.IsAlphanSpike)
	e2:SetLabelObject(e1)
	Duel.RegisterEffect(e2,0)
end
function Auxiliary.IsAlphanSpike(e,c)
	return c:IsCode(72332074)
end
