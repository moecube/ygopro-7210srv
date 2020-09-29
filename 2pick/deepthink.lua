Deepthink={}

function Deepthink.Load_Skill_Deepthink_Rule()
	local e1=Effect.GlobalEffect()
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetTargetRange(1,1)
	--e1:SetCode(PHASE_DRAW+EVENT_PHASE_START)
	e1:SetCode(EVENT_PREDRAW)
	e1:SetCondition(Deepthink.Skill_Deepthink_Condition)
	e1:SetOperation(Deepthink.Skill_Deepthink_Operation)
	Duel.RegisterEffect(e1,0)
end

function Deepthink.Skill_Deepthink_Condition(e,tp,eg,ep,ev,re,r,rp)
	local tp=Duel.GetTurnPlayer()
	return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>1 
end

function Deepthink.Skill_Deepthink_Operation(e,tp,eg,ep,ev,re,r,rp)
	local tp=Duel.GetTurnPlayer()
	Duel.SortDecktop(tp,tp,2)
end

return Deepthink