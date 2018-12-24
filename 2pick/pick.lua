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
local extra_fusion={1945387,3642509,12307878,13529466,16304628,19261966,20366274,22061412,33574806,40854197,41209827,48424886,48791583,49513164,69946549,74009824,74822425,75286621,85908279,94977269,45170821,30757127}
local ectra_fusion_pick={[0]=extra_fusion,[1]=extra_fusion}
local event_fusion_main={
	[0]={86120751,86120751,86120751,74063034},
	[1]={3717252,4939890,30328508,52551211},
	[2]={40044918,40044918,64184058,8949584}
}

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
function Auxiliary.SinglePick(p,list,count,ex_list,ex_count,copy,lv_diff,fixed,packed)
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
					for code in pairs(packed[thispack]) do
						local card=Duel.CreateToken(p,code)
						g:AddCard(card)
						ag:AddCard(card)
					end
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
	for p=0,1 do
		Auxiliary.SinglePick(p,list,0,nil,nil,false,false,nil,event_fusion_main)
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
	for p=0,1 do
		Auxiliary.SinglePick(p,ectra_fusion_pick,4,nil,nil,false)
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

	--Event Fusion
	Auxiliary.Load_EVENT_ExtraFusion()
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

function Auxiliary.Load_EVENT_ExtraFusion()
	-- elemental hero
	local e011=Effect.GlobalEffect()
	e011:SetType(EFFECT_TYPE_FIELD)
	e011:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e011:SetCode(EFFECT_SPSUMMON_PROC)
	e011:SetRange(LOCATION_EXTRA)
	e011:SetCondition(Auxiliary.FireEH_Condition)
	e011:SetOperation(Auxiliary.FireEH_Operation)
	local e012=Effect.GlobalEffect()
	e012:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e012:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e012:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e012:SetTarget(Auxiliary.IsFireEH)
	e012:SetLabelObject(e011)
	Duel.RegisterEffect(e012,0)
	
	local e021=Effect.GlobalEffect()
	e021:SetType(EFFECT_TYPE_FIELD)
	e021:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e021:SetCode(EFFECT_SPSUMMON_PROC)
	e021:SetRange(LOCATION_EXTRA)
	e021:SetCondition(Auxiliary.WindEH_Condition)
	e021:SetOperation(Auxiliary.WindEH_Operation)
	local e022=Effect.GlobalEffect()
	e022:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e022:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e022:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e022:SetTarget(Auxiliary.IsWindEH)
	e022:SetLabelObject(e021)
	Duel.RegisterEffect(e022,0)
	
	local e031=Effect.GlobalEffect()
	e031:SetType(EFFECT_TYPE_FIELD)
	e031:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e031:SetCode(EFFECT_SPSUMMON_PROC)
	e031:SetRange(LOCATION_EXTRA)
	e031:SetCondition(Auxiliary.EarthEH_Condition)
	e031:SetOperation(Auxiliary.EarthEH_Operation)
	local e032=Effect.GlobalEffect()
	e032:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e032:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e032:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e032:SetTarget(Auxiliary.IsEarthEH)
	e032:SetLabelObject(e031)
	Duel.RegisterEffect(e032,0)

	local e041=Effect.GlobalEffect()
	e041:SetType(EFFECT_TYPE_FIELD)
	e041:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e041:SetCode(EFFECT_SPSUMMON_PROC)
	e041:SetRange(LOCATION_EXTRA)
	e041:SetCondition(Auxiliary.LightEH_Condition)
	e041:SetOperation(Auxiliary.LightEH_Operation)
	local e042=Effect.GlobalEffect()
	e042:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e042:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e042:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e042:SetTarget(Auxiliary.IsLightEH)
	e042:SetLabelObject(e041)
	Duel.RegisterEffect(e042,0)
	
	local e051=Effect.GlobalEffect()
	e051:SetType(EFFECT_TYPE_FIELD)
	e051:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e051:SetCode(EFFECT_SPSUMMON_PROC)
	e051:SetRange(LOCATION_EXTRA)
	e051:SetCondition(Auxiliary.LightEH_Condition)
	e051:SetOperation(Auxiliary.LightEH_Operation)
	local e052=Effect.GlobalEffect()
	e052:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e052:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e052:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e052:SetTarget(Auxiliary.IsLightEH)
	e052:SetLabelObject(e051)
	Duel.RegisterEffect(e052,0)
	
	local e061=Effect.GlobalEffect()
	e061:SetType(EFFECT_TYPE_FIELD)
	e061:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e061:SetCode(EFFECT_SPSUMMON_PROC)
	e061:SetRange(LOCATION_EXTRA)
	e061:SetCondition(Auxiliary.WaterEH_Condition)
	e061:SetOperation(Auxiliary.WaterEH_Operation)
	local e062=Effect.GlobalEffect()
	e062:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e062:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e062:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e062:SetTarget(Auxiliary.IsWaterEH)
	e062:SetLabelObject(e061)
	Duel.RegisterEffect(e062,0)
	-- shadoll
	local e111=Effect.GlobalEffect()
	e111:SetType(EFFECT_TYPE_FIELD)
	e111:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e111:SetCode(EFFECT_SPSUMMON_PROC)
	e111:SetRange(LOCATION_EXTRA)
	e111:SetCondition(Auxiliary.FireShadoll_Condition)
	e111:SetOperation(Auxiliary.FireShadoll_Operation)
	local e112=Effect.GlobalEffect()
	e112:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e112:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e112:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e112:SetTarget(Auxiliary.IsFireShadoll)
	e112:SetLabelObject(e111)
	Duel.RegisterEffect(e112,0)
	
	local e121=Effect.GlobalEffect()
	e121:SetType(EFFECT_TYPE_FIELD)
	e121:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e121:SetCode(EFFECT_SPSUMMON_PROC)
	e121:SetRange(LOCATION_EXTRA)
	e121:SetCondition(Auxiliary.WindShadoll_Condition)
	e121:SetOperation(Auxiliary.WindShadoll_Operation)
	local e122=Effect.GlobalEffect()
	e122:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e122:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e122:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e122:SetTarget(Auxiliary.IsWindShadoll)
	e122:SetLabelObject(e121)
	Duel.RegisterEffect(e122,0)
	
	local e131=Effect.GlobalEffect()
	e131:SetType(EFFECT_TYPE_FIELD)
	e131:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e131:SetCode(EFFECT_SPSUMMON_PROC)
	e131:SetRange(LOCATION_EXTRA)
	e131:SetCondition(Auxiliary.EarthShadoll_Condition)
	e131:SetOperation(Auxiliary.EarthShadoll_Operation)
	local e132=Effect.GlobalEffect()
	e132:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e132:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e132:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e132:SetTarget(Auxiliary.IsEarthShadoll)
	e132:SetLabelObject(e131)
	Duel.RegisterEffect(e132,0)

	local e141=Effect.GlobalEffect()
	e141:SetType(EFFECT_TYPE_FIELD)
	e141:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e141:SetCode(EFFECT_SPSUMMON_PROC)
	e141:SetRange(LOCATION_EXTRA)
	e141:SetCondition(Auxiliary.LightShadoll_Condition)
	e141:SetOperation(Auxiliary.LightShadoll_Operation)
	local e142=Effect.GlobalEffect()
	e142:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e142:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e142:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e142:SetTarget(Auxiliary.IsLightShadoll)
	e142:SetLabelObject(e141)
	Duel.RegisterEffect(e142,0)
	
	local e151=Effect.GlobalEffect()
	e151:SetType(EFFECT_TYPE_FIELD)
	e151:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e151:SetCode(EFFECT_SPSUMMON_PROC)
	e151:SetRange(LOCATION_EXTRA)
	e151:SetCondition(Auxiliary.LightShadoll_Condition)
	e151:SetOperation(Auxiliary.LightShadoll_Operation)
	local e152=Effect.GlobalEffect()
	e152:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e152:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e152:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e152:SetTarget(Auxiliary.IsLightShadoll)
	e152:SetLabelObject(e151)
	Duel.RegisterEffect(e152,0)
	
	local e161=Effect.GlobalEffect()
	e161:SetType(EFFECT_TYPE_FIELD)
	e161:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e161:SetCode(EFFECT_SPSUMMON_PROC)
	e161:SetRange(LOCATION_EXTRA)
	e161:SetCondition(Auxiliary.WaterShadoll_Condition)
	e161:SetOperation(Auxiliary.WaterShadoll_Operation)
	local e162=Effect.GlobalEffect()
	e162:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e162:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e162:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e162:SetTarget(Auxiliary.IsWaterShadoll)
	e162:SetLabelObject(e161)
	Duel.RegisterEffect(e162,0)
	--invoker
	local e211=Effect.GlobalEffect()
	e211:SetType(EFFECT_TYPE_FIELD)
	e211:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e211:SetCode(EFFECT_SPSUMMON_PROC)
	e211:SetRange(LOCATION_EXTRA)
	e211:SetCondition(Auxiliary.FireInvoke_Condition)
	e211:SetOperation(Auxiliary.FireInvoke_Operation)
	local e212=Effect.GlobalEffect()
	e212:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e212:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e212:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e212:SetTarget(Auxiliary.IsFireInvoke)
	e212:SetLabelObject(e211)
	Duel.RegisterEffect(e212,0)
	
	local e221=Effect.GlobalEffect()
	e221:SetType(EFFECT_TYPE_FIELD)
	e221:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e221:SetCode(EFFECT_SPSUMMON_PROC)
	e221:SetRange(LOCATION_EXTRA)
	e221:SetCondition(Auxiliary.WindInvoke_Condition)
	e221:SetOperation(Auxiliary.WindInvoke_Operation)
	local e222=Effect.GlobalEffect()
	e222:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e222:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e222:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e222:SetTarget(Auxiliary.IsWindInvoke)
	e222:SetLabelObject(e221)
	Duel.RegisterEffect(e222,0)
	
	local e231=Effect.GlobalEffect()
	e231:SetType(EFFECT_TYPE_FIELD)
	e231:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e231:SetCode(EFFECT_SPSUMMON_PROC)
	e231:SetRange(LOCATION_EXTRA)
	e231:SetCondition(Auxiliary.EarthInvoke_Condition)
	e231:SetOperation(Auxiliary.EarthInvoke_Operation)
	local e232=Effect.GlobalEffect()
	e232:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e232:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e232:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e232:SetTarget(Auxiliary.IsEarthInvoke)
	e232:SetLabelObject(e231)
	Duel.RegisterEffect(e232,0)

	local e241=Effect.GlobalEffect()
	e241:SetType(EFFECT_TYPE_FIELD)
	e241:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e241:SetCode(EFFECT_SPSUMMON_PROC)
	e241:SetRange(LOCATION_EXTRA)
	e241:SetCondition(Auxiliary.LightInvoke_Condition)
	e241:SetOperation(Auxiliary.LightInvoke_Operation)
	local e242=Effect.GlobalEffect()
	e242:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e242:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e242:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e242:SetTarget(Auxiliary.IsLightInvoke)
	e242:SetLabelObject(e241)
	Duel.RegisterEffect(e242,0)
	
	local e251=Effect.GlobalEffect()
	e251:SetType(EFFECT_TYPE_FIELD)
	e251:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e251:SetCode(EFFECT_SPSUMMON_PROC)
	e251:SetRange(LOCATION_EXTRA)
	e251:SetCondition(Auxiliary.LightInvoke_Condition)
	e251:SetOperation(Auxiliary.LightInvoke_Operation)
	local e252=Effect.GlobalEffect()
	e252:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e252:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e252:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e252:SetTarget(Auxiliary.IsLightInvoke)
	e252:SetLabelObject(e251)
	Duel.RegisterEffect(e252,0)
	
	local e261=Effect.GlobalEffect()
	e261:SetType(EFFECT_TYPE_FIELD)
	e261:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e261:SetCode(EFFECT_SPSUMMON_PROC)
	e261:SetRange(LOCATION_EXTRA)
	e261:SetCondition(Auxiliary.WaterInvoke_Condition)
	e261:SetOperation(Auxiliary.WaterInvoke_Operation)
	local e262=Effect.GlobalEffect()
	e262:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e262:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e262:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e262:SetTarget(Auxiliary.IsWaterInvoke)
	e262:SetLabelObject(e261)
	Duel.RegisterEffect(e262,0)
	--fusion dragon
	local e311=Effect.GlobalEffect()
	e311:SetType(EFFECT_TYPE_FIELD)
	e311:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e311:SetCode(EFFECT_SPSUMMON_PROC)
	e311:SetRange(LOCATION_EXTRA)
	e311:SetCondition(Auxiliary.FusionDragon_Condition)
	e311:SetOperation(Auxiliary.FusionDragon_Operation)
	local e312=Effect.GlobalEffect()
	e312:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e312:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e312:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e312:SetTarget(Auxiliary.IsFusionDragon)
	e312:SetLabelObject(e311)
	Duel.RegisterEffect(e312,0)
	--phantom hero
	local e321=Effect.GlobalEffect()
	e321:SetType(EFFECT_TYPE_FIELD)
	e321:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e321:SetCode(EFFECT_SPSUMMON_PROC)
	e321:SetRange(LOCATION_EXTRA)
	e321:SetCondition(Auxiliary.PhantomHero_Condition)
	e321:SetOperation(Auxiliary.PhantomHero_Operation)
	local e322=Effect.GlobalEffect()
	e322:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e322:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e322:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e322:SetTarget(Auxiliary.IsPhantomHero)
	e322:SetLabelObject(e321)
	Duel.RegisterEffect(e322,0)
	--pplant
	local e331=Effect.GlobalEffect()
	e331:SetType(EFFECT_TYPE_FIELD)
	e331:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e331:SetCode(EFFECT_SPSUMMON_PROC)
	e331:SetRange(LOCATION_EXTRA)
	e331:SetCondition(Auxiliary.PPlant_Condition)
	e331:SetOperation(Auxiliary.PPlant_Operation)
	local e332=Effect.GlobalEffect()
	e332:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e332:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e332:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e332:SetTarget(Auxiliary.IsPPlant)
	e332:SetLabelObject(e331)
	Duel.RegisterEffect(e332,0)
	--DH
	local e341=Effect.GlobalEffect()
	e341:SetType(EFFECT_TYPE_FIELD)
	e341:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e341:SetCode(EFFECT_SPSUMMON_PROC)
	e341:SetRange(LOCATION_EXTRA)
	e341:SetCondition(Auxiliary.DH_Condition)
	e341:SetOperation(Auxiliary.DH_Operation)
	local e342=Effect.GlobalEffect()
	e342:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_GRANT)
	e342:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE)
	e342:SetTargetRange(LOCATION_EXTRA,LOCATION_EXTRA)
	e342:SetTarget(Auxiliary.IsDH)
	e342:SetLabelObject(e341)
	Duel.RegisterEffect(e342,0)
end

function Auxiliary.IsFireEH(e,c)
	return c:IsCode(1945387)
end
function Auxiliary.FireEH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.FireEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.FireEH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_FIRE) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.FireEH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.FireEH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.FireEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.FireEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.FireEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsWindEH(e,c)
	return c:IsCode(3642509)
end
function Auxiliary.WindEH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.WindEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.WindEH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_WIND) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.WindEH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.WindEH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.WindEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.WindEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.WindEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsEarthEH(e,c)
	return c:IsCode(16304628)
end
function Auxiliary.EarthEH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.EarthEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.EarthEH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_EARTH) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.EarthEH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.EarthEH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.EarthEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.EarthEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.EarthEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsLightEH(e,c)
	return c:IsCode(22061412)
end
function Auxiliary.LightEH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.LightEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.LightEH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_LIGHT) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.LightEH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.LightEH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.LightEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.LightEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.LightEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsDarkEH(e,c)
	return c:IsCode(33574806)
end
function Auxiliary.DarkEH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.DarkEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.DarkEH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.DarkEH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.DarkEH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.DarkEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.DarkEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.DarkEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsWaterEH(e,c)
	return c:IsCode(40854197)
end
function Auxiliary.WaterEH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x3008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.WaterEH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.WaterEH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_WATER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.WaterEH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.WaterEH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.WaterEH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.WaterEH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.WaterEH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsFireShadoll(e,c)
	return c:IsCode(48424886)
end
function Auxiliary.FireShadoll_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x9d) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.FireShadoll_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.FireShadoll_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_FIRE) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.FireShadoll_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.FireShadoll_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.FireShadoll_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.FireShadoll_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.FireShadoll_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsWindShadoll(e,c)
	return c:IsCode(74009824)
end
function Auxiliary.WindShadoll_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x9d) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.WindShadoll_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.WindShadoll_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_WIND) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.WindShadoll_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.WindShadoll_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.WindShadoll_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.WindShadoll_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.WindShadoll_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsEarthShadoll(e,c)
	return c:IsCode(74822425)
end
function Auxiliary.EarthShadoll_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x9d) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.EarthShadoll_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.EarthShadoll_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_EARTH) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.EarthShadoll_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.EarthShadoll_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.EarthShadoll_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.EarthShadoll_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.EarthShadoll_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsLightShadoll(e,c)
	return c:IsCode(20366274)
end
function Auxiliary.LightShadoll_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x9d) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.LightShadoll_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.LightShadoll_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_LIGHT) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.LightShadoll_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.LightShadoll_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.LightShadoll_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.LightShadoll_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.LightShadoll_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsDarkShadoll(e,c)
	return c:IsCode(94977269)
end
function Auxiliary.DarkShadoll_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x9d) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.DarkShadoll_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.DarkShadoll_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.DarkShadoll_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.DarkShadoll_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.DarkShadoll_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.DarkShadoll_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.DarkShadoll_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsWaterShadoll(e,c)
	return c:IsCode(19261966)
end
function Auxiliary.WaterShadoll_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x9d) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.WaterShadoll_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.WaterShadoll_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_WATER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.WaterShadoll_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.WaterShadoll_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.WaterShadoll_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.WaterShadoll_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.WaterShadoll_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsFireInvoke(e,c)
	return c:IsCode(12307878)
end
function Auxiliary.FireInvoke_spfilter1(c,tp,fc)
	return c:IsFusionCode(86120751) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.FireInvoke_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.FireInvoke_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_FIRE) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.FireInvoke_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.FireInvoke_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.FireInvoke_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.FireInvoke_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.FireInvoke_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsWindInvoke(e,c)
	return c:IsCode(49513164)
end
function Auxiliary.WindInvoke_spfilter1(c,tp,fc)
	return c:IsFusionCode(86120751) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.WindInvoke_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.WindInvoke_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_WIND) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.WindInvoke_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.WindInvoke_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.WindInvoke_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.WindInvoke_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.WindInvoke_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsEarthInvoke(e,c)
	return c:IsCode(48791583)
end
function Auxiliary.EarthInvoke_spfilter1(c,tp,fc)
	return c:IsFusionCode(86120751) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.EarthInvoke_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.EarthInvoke_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_EARTH) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.EarthInvoke_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.EarthInvoke_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.EarthInvoke_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.EarthInvoke_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.EarthInvoke_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsLightInvoke(e,c)
	return c:IsCode(75286621)
end
function Auxiliary.LightInvoke_spfilter1(c,tp,fc)
	return c:IsFusionCode(86120751) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.LightInvoke_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.LightInvoke_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_LIGHT) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.LightInvoke_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.LightInvoke_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.LightInvoke_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.LightInvoke_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.LightInvoke_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsDarkInvoke(e,c)
	return c:IsCode(13529466)
end
function Auxiliary.DarkInvoke_spfilter1(c,tp,fc)
	return c:IsFusionCode(86120751) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.DarkInvoke_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.DarkInvoke_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.DarkInvoke_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.DarkInvoke_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.DarkInvoke_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.DarkInvoke_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.DarkInvoke_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsWaterInvoke(e,c)
	return c:IsCode(12307878)
end
function Auxiliary.WaterInvoke_spfilter1(c,tp,fc)
	return c:IsFusionCode(86120751) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.WaterInvoke_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.WaterInvoke_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_WATER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.WaterInvoke_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.WaterInvoke_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.WaterInvoke_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.WaterInvoke_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.WaterInvoke_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsFusionDragon(e,c)
	return c:IsCode(41209827)
end
function Auxiliary.FusionDragon_spfilter1(c,tp,fc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.FusionDragon_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.FusionDragon_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.FusionDragon_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.FusionDragon_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.FusionDragon_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.FusionDragon_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.FusionDragon_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsPhantomHero(e,c)
	return c:IsCode(45170821)
end
function Auxiliary.PhantomHero_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0x8) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.PhantomHero_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.PhantomHero_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionSetCard(0x8) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.PhantomHero_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.PhantomHero_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.PhantomHero_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.PhantomHero_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.PhantomHero_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsPPlant(e,c)
	return c:IsCode(69946549)
end
function Auxiliary.PPlant_spfilter1(c,tp,fc)
	return c:IsFusionType(TYPE_FUSION) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.PPlant_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.PPlant_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.PPlant_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.PPlant_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.PPlant_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.PPlant_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.PPlant_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

function Auxiliary.IsDH(e,c)
	return c:IsCode(30757127)
end
function Auxiliary.DH_spfilter1(c,tp,fc)
	return c:IsFusionSetCard(0xc008) and c:IsType(TYPE_MONSTER) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.IsExistingMatchingCard(Auxiliary.DH_spfilter2,tp,LOCATION_MZONE,LOCATION_MZONE,1,c,tp,fc,c)
end
function Auxiliary.DH_spfilter2(c,tp,fc,mc)
	local g=Group.FromCards(c,mc)
	return c:IsFusionAttribute(ATTRIBUTE_DARK) and c:IsFusionType(TYPE_EFFECT) and c:IsAbleToGraveAsCost()
		and c:IsCanBeFusionMaterial(fc) and Duel.GetLocationCountFromEx(tp,tp,g)>0
end
function Auxiliary.DH_Condition(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.IsExistingMatchingCard(Auxiliary.DH_cfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
end
function Auxiliary.DH_Operation(e,tp,eg,ep,ev,re,r,rp,c)
	local g1=Duel.GetMatchingGroup(Auxiliary.DH_spfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local sg=g1:Select(tp,1,1,nil)
	local g2=Duel.GetMatchingGroup(Auxiliary.DH_spfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,sg:GetFirst(),tp,sg:GetFirst())
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local c2=g2:Select(tp,1,1,sg:GetFirst())
	sg:Merge(c2)
	Duel.SendtoGrave(sg,REASON_COST)
	c:CompleteProcedure()
end

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
-- 	return Duel.IsExistingMatchingCard(Auxiliary.XY_spfilter1,tp,LOCATION_MZONE,0,1,nil,tp,c)
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
