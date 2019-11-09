ActionDuel = {}

--Action_Duel
function ActionDuel.Load_Action_Duel()
	for p=0,1 do
		local fc=Duel.CreateToken(p,19162134)
		Duel.MoveToField(fc,p,p,LOCATION_SZONE,POS_FACEUP,true)
		-- effect
		local e1=Effect.CreateEffect(fc)
		e1:SetCategory(CATEGORY_REMOVE)
		e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
		e1:SetCode(EVENT_ATTACK_ANNOUNCE)
		e1:SetRange(LOCATION_FZONE)
		e1:SetCountLimit(1)
		e1:SetCondition(ActionDuel.condition)
		e1:SetTarget(ActionDuel.atktg)
		e1:SetOperation(ActionDuel.activate)
		fc:RegisterEffect(e1)
		-- destroy replace
		local e2=Effect.CreateEffect(fc)
		e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
		e2:SetCode(EFFECT_DESTROY_REPLACE)
		e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
		e2:SetRange(LOCATION_FZONE)
		e2:SetTarget(Auxiliary.reptg)
		fc:RegisterEffect(e2)
	end
end
function ActionDuel.condition(e,tp,eg,ep,ev,re,r,rp,chk)
	return tp~=Duel.GetTurnPlayer()
end
function ActionDuel.atktg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
end
function ActionDuel.activate(e,tp,eg,ep,ev,re,r,rp)
	local d1=0
	local d2=0
	local dk1=Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)
	local dk2=Duel.GetFieldGroupCount(1-tp,LOCATION_DECK,0)
	if dk1>0 then
		for t=1,dk1 do
			if Duel.SelectYesNo(tp,aux.Stringid(30539496,3)) then
				d1=d1+1
			else
				break
			end
		end
	end
	if dk2>0 then
		for t=1,dk2 do
			if Duel.SelectYesNo(1-tp,aux.Stringid(30539496,3)) then
				d2=d2+1
			else
				break
			end
		end
	end
	local rg1=Duel.GetDecktopGroup(tp,d1)
	local rg2=Duel.GetDecktopGroup(tp,d2)
	Duel.Remove(rg1,POS_FACEDOWN,REASON_EFFECT)
	Duel.Remove(rg2,POS_FACEDOWN,REASON_EFFECT)
	if d1==d2 then
		local g=Group.CreateGroup()
		local a=Duel.GetAttacker()
		local d=Duel.GetAttackTarget()
		if d1==1 or d1==2 then
			if a and a:IsOnField() then g:AddCard(a) end
			if d and d:IsOnField() then g:AddCard(d) end
			Duel.Destroy(g,REASON_EFFECT)
		elseif d1==3 then
			if d and d:IsOnField() then g:AddCard(d) end
			Duel.Destroy(g,REASON_EFFECT)
			Duel.NegateAttack()
		end
	elseif d1>d2 then
		-- half dmg
		local e1=Effect.CreateEffect(e:GetHandler())
        e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
        e1:SetCode(EVENT_PRE_BATTLE_DAMAGE)
        e1:SetOperation(ActionDuel.hfdmg)
        e1:SetReset(RESET_PHASE+PHASE_DAMAGE)
        Duel.RegisterEffect(e1,tp)
		-- avoid destroy
		local d=Duel.GetAttackTarget()
		if d and d:IsOnField() then
			local e2=Effect.CreateEffect(e:GetHandler())
			e2:SetType(EFFECT_TYPE_SINGLE)
			e2:SetCode(EFFECT_INDESTRUCTABLE_BATTLE)
			e2:SetValue(1)
			e2:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_DAMAGE)
			d:RegisterEffect(e2)
		end
	elseif d1<d2 then
		-- inflict dmg
		Duel.Damage(tp,800,REASON_EFFECT)
	end
end
function ActionDuel.hfdmg(e,tp,eg,ep,ev,re,r,rp)
    Duel.ChangeBattleDamage(tp,math.ceil(ev/2))
end
function Auxiliary.reptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	local g=Duel.GetDecktopGroup(tp,3)
	if chk==0 then return c:IsReason(REASON_BATTLE+REASON_EFFECT) and not c:IsReason(REASON_REPLACE)
		and g:IsExists(Card.IsAbleToRemove,3,nil) end
	if Duel.SelectEffectYesNo(tp,e:GetHandler(),96) then
		Duel.DisableShuffleCheck()
		Duel.Remove(g,POS_FACEDOWN,REASON_EFFECT)
		return true
	else return false end
end

return ActionDuel