--Card B
function c89739383.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_REMOVE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(c89739383.target)
	e1:SetOperation(c89739383.activate)
	c:RegisterEffect(e1)
end
function c89739383.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(Card.IsAbleToRemove,tp,LOCATION_HAND,0,1,e:GetHandler()) end
end
function c89739383.activate(e,tp,eg,ep,ev,re,r,rp)
	local g=Duel.GetFieldGroup(tp,LOCATION_HAND,0)
	local tc=g:RandomSelect(1-tp,1):GetFirst()
	if Duel.Remove(tc,POS_FACEDOWN,REASON_EFFECT)~=0 then
		local tg=Group.CreateGroup()
		local mm_code=main_spell[0][math.random(#main_spell[0])]
		tg:AddCard(Duel.CreateToken(tp,mm_code))
		local mm2_code=main_trap[0][math.random(#main_trap[0])]
		tg:AddCard(Duel.CreateToken(tp,mm2_code))
		Duel.SendtoHand(tg,nil,REASON_EFFECT)
	end
end
