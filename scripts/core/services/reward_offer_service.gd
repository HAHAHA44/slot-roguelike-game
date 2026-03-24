class_name RewardOfferService
extends RefCounted

func build_turn_offer(run_session: RunSession) -> Array[Dictionary]:
	return [
		{
			"kind": "add_token",
			"phase_index": run_session.phase_index,
			"weight_profile": {"rarity": "weighted", "tags": "open"},
		},
		{
			"kind": "remove_token",
			"phase_index": run_session.phase_index,
			"weight_profile": {"rarity": "none", "tags": "cleanup"},
		},
		{
			"kind": "random_token",
			"phase_index": run_session.phase_index,
			"weight_profile": {"rarity": "weighted", "tags": "phase_biased"},
		},
	]
